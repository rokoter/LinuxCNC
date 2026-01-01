#!/usr/bin/env python3
"""
CNC Vibration Monitor - LinuxCNC HAL Component

This component:
1. Reads sensor data from Pico via USB serial
2. Updates HAL pins with vibration levels
3. Triggers E-stop on emergency conditions
4. Logs data to CSV files

Usage:
    loadusr -W vibration_monitor.py --port /dev/ttyACM0
"""

import hal
import time
import sys
import serial
import argparse
import threading
import csv
from datetime import datetime
from collections import deque
import math

class VibrationMonitor:
    def __init__(self, port, baudrate=115200, log_enabled=True):
        self.port = port
        self.baudrate = baudrate
        self.log_enabled = log_enabled
        
        # Create HAL component
        self.h = hal.component("vibration")
        
        # Output pins (to LinuxCNC)
        self.h.newpin("current", hal.HAL_FLOAT, hal.HAL_OUT)
        self.h.newpin("peak", hal.HAL_FLOAT, hal.HAL_OUT)
        self.h.newpin("rms", hal.HAL_FLOAT, hal.HAL_OUT)
        self.h.newpin("status", hal.HAL_S32, hal.HAL_OUT)
        self.h.newpin("estop-trigger", hal.HAL_BIT, hal.HAL_OUT)
        self.h.newpin("connected", hal.HAL_BIT, hal.HAL_OUT)
        
        # Input pins (from LinuxCNC)
        self.h.newpin("enable", hal.HAL_BIT, hal.HAL_IN)
        self.h.newpin("threshold-warn", hal.HAL_FLOAT, hal.HAL_IN)
        self.h.newpin("threshold-crit", hal.HAL_FLOAT, hal.HAL_IN)
        self.h.newpin("reset-peak", hal.HAL_BIT, hal.HAL_IN)
        
        # Set default threshold values
        self.h["threshold-warn"] = 2.0
        self.h["threshold-crit"] = 4.0
        
        # Mark component as ready
        self.h.ready()
        
        # Internal state
        self.running = True
        self.connected = False
        self.peak_value = 0.0
        self.rms_window = deque(maxlen=100)  # 1 second at 100Hz
        self.last_reset_peak = False
        
        # Serial connection
        self.ser = None
        self.connect_serial()
        
        # CSV logger
        self.csv_file = None
        self.csv_writer = None
        if self.log_enabled:
            self.init_csv_logger()
        
        # Statistics
        self.packets_received = 0
        self.errors = 0
        self.last_stats_time = time.time()
        
        print(f"[VibMon] HAL component initialized on {port}")
    
    def connect_serial(self):
        """Connect to Pico via USB serial"""
        try:
            self.ser = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                timeout=1.0
            )
            self.connected = True
            self.h["connected"] = True
            print(f"[VibMon] Connected to {self.port} at {self.baudrate} baud")
        except serial.SerialException as e:
            print(f"[VibMon] ERROR: Could not open {self.port}: {e}")
            self.connected = False
            self.h["connected"] = False
    
    def init_csv_logger(self):
        """Initialize CSV file for logging"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"vibration_log_{timestamp}.csv"
        
        try:
            self.csv_file = open(filename, 'w', newline='')
            self.csv_writer = csv.writer(self.csv_file)
            self.csv_writer.writerow([
                'timestamp', 'time_ms', 
                'accel_x', 'accel_y', 'accel_z',
                'gyro_x', 'gyro_y', 'gyro_z',
                'magnitude', 'status'
            ])
            print(f"[VibMon] Logging to {filename}")
        except IOError as e:
            print(f"[VibMon] WARNING: Could not create log file: {e}")
            self.log_enabled = False
    
    def parse_sensor_data(self, line):
        """Parse CSV line from Pico
        
        Format: VIB:DATA,timestamp,ax,ay,az,gx,gy,gz,mag,status
        """
        try:
            parts = line.strip().split(',')
            
            if parts[0] == "VIB:DATA" and len(parts) == 10:
                data = {
                    'timestamp': int(parts[1]),
                    'accel_x': float(parts[2]),
                    'accel_y': float(parts[3]),
                    'accel_z': float(parts[4]),
                    'gyro_x': float(parts[5]),
                    'gyro_y': float(parts[6]),
                    'gyro_z': float(parts[7]),
                    'magnitude': float(parts[8]),
                    'status': parts[9]
                }
                return data
            
            elif parts[0] == "VIB:ESTOP":
                # Emergency stop message from Pico
                print(f"[VibMon] EMERGENCY STOP from Pico: {line}")
                self.trigger_estop()
                return None
            
            elif parts[0] in ["VIB:STATUS", "VIB:BOOT", "VIB:HEADER"]:
                # Info messages
                print(f"[VibMon] {line}")
                return None
            
            else:
                return None
                
        except (ValueError, IndexError) as e:
            self.errors += 1
            if self.errors % 100 == 0:
                print(f"[VibMon] Parse errors: {self.errors}")
            return None
    
    def update_hal_pins(self, data):
        """Update HAL pins with sensor data"""
        if not data:
            return
        
        # Update current vibration level
        self.h["current"] = data['magnitude']
        
        # Update peak value
        if data['magnitude'] > self.peak_value:
            self.peak_value = data['magnitude']
            self.h["peak"] = self.peak_value
        
        # Update RMS (rolling window)
        self.rms_window.append(data['magnitude'])
        rms = math.sqrt(sum(x*x for x in self.rms_window) / len(self.rms_window))
        self.h["rms"] = rms
        
        # Update status
        status_map = {'OK': 0, 'WARNING': 1, 'CRITICAL': 2, 'ESTOP': 3}
        self.h["status"] = status_map.get(data['status'], 0)
        
        # Check for emergency condition
        if data['status'] == 'ESTOP':
            self.trigger_estop()
    
    def trigger_estop(self):
        """Trigger software E-stop via HAL"""
        print("[VibMon] *** TRIGGERING E-STOP ***")
        self.h["estop-trigger"] = True
        # Note: E-stop trigger should be wired in HAL to halui.estop.activate
    
    def check_hal_inputs(self):
        """Check for changes in HAL input pins"""
        # Check for peak reset request
        reset_peak = self.h["reset-peak"]
        if reset_peak and not self.last_reset_peak:
            print("[VibMon] Resetting peak value")
            self.peak_value = 0.0
            self.h["peak"] = 0.0
        self.last_reset_peak = reset_peak
        
        # TODO: Handle threshold updates from HAL
        # Send new thresholds to Pico via serial commands
    
    def log_data(self, data):
        """Write data to CSV file"""
        if not self.log_enabled or not self.csv_writer:
            return
        
        try:
            now = datetime.now().isoformat()
            self.csv_writer.writerow([
                now, data['timestamp'],
                data['accel_x'], data['accel_y'], data['accel_z'],
                data['gyro_x'], data['gyro_y'], data['gyro_z'],
                data['magnitude'], data['status']
            ])
            
            # Flush periodically
            self.packets_received += 1
            if self.packets_received % 100 == 0:
                self.csv_file.flush()
                
        except IOError as e:
            print(f"[VibMon] Error writing to log: {e}")
    
    def print_stats(self):
        """Print statistics periodically"""
        now = time.time()
        if now - self.last_stats_time > 10.0:  # Every 10 seconds
            elapsed = now - self.last_stats_time
            rate = self.packets_received / elapsed
            print(f"[VibMon] Stats: {rate:.1f} Hz, {self.errors} errors, "
                  f"Peak: {self.peak_value:.2f}G, Current: {self.h['current']:.2f}G")
            self.packets_received = 0
            self.errors = 0
            self.last_stats_time = now
    
    def run(self):
        """Main loop - read serial and update HAL"""
        print("[VibMon] Starting main loop...")
        
        while self.running:
            try:
                # Check if component should be enabled
                if not self.h["enable"]:
                    time.sleep(0.1)
                    continue
                
                # Check serial connection
                if not self.connected:
                    print("[VibMon] Attempting to reconnect...")
                    self.connect_serial()
                    time.sleep(1.0)
                    continue
                
                # Read line from serial
                if self.ser and self.ser.in_waiting > 0:
                    try:
                        line = self.ser.readline().decode('utf-8', errors='ignore')
                        
                        # Parse data
                        data = self.parse_sensor_data(line)
                        
                        if data:
                            # Update HAL pins
                            self.update_hal_pins(data)
                            
                            # Log to CSV
                            self.log_data(data)
                    
                    except serial.SerialException as e:
                        print(f"[VibMon] Serial error: {e}")
                        self.connected = False
                        self.h["connected"] = False
                
                # Check HAL input pins
                self.check_hal_inputs()
                
                # Print stats
                self.print_stats()
                
                # Small sleep to prevent CPU spinning
                time.sleep(0.001)
                
            except KeyboardInterrupt:
                print("[VibMon] Shutting down...")
                break
            except Exception as e:
                print(f"[VibMon] Unexpected error: {e}")
                import traceback
                traceback.print_exc()
    
    def cleanup(self):
        """Clean up resources"""
        print("[VibMon] Cleaning up...")
        self.running = False
        
        if self.ser and self.ser.is_open:
            self.ser.close()
        
        if self.csv_file:
            self.csv_file.close()
        
        print("[VibMon] Shutdown complete")

def main():
    parser = argparse.ArgumentParser(description='CNC Vibration Monitor HAL Component')
    parser.add_argument('--port', type=str, default='/dev/ttyACM0',
                        help='Serial port for Pico (default: /dev/ttyACM0)')
    parser.add_argument('--baudrate', type=int, default=115200,
                        help='Serial baud rate (default: 115200)')
    parser.add_argument('--no-log', action='store_true',
                        help='Disable CSV logging')
    
    args = parser.parse_args()
    
    # Create and run monitor
    monitor = VibrationMonitor(
        port=args.port,
        baudrate=args.baudrate,
        log_enabled=not args.no_log
    )
    
    try:
        monitor.run()
    finally:
        monitor.cleanup()

if __name__ == '__main__':
    main()
