/*
 * Configuration Header
 * All configurable parameters for the vibration monitor
 */

#ifndef CONFIG_H
#define CONFIG_H

// ==================== FIRMWARE VERSION ====================
#define FIRMWARE_VERSION "1.0.0-alpha"

// ==================== HARDWARE PINS ====================
// I2C for MPU6050
#define I2C_SDA_PIN 4   // GP4
#define I2C_SCL_PIN 5   // GP5

// E-stop output (active LOW)
#define ESTOP_GPIO_PIN 15  // GP15 -> LinuxCNC E-stop input

// Status LED
#define STATUS_LED_PIN 16  // GP16 (or use built-in LED on GP25)

// Optional: Trigger input from LinuxCNC (for synchronized logging)
#define TRIGGER_INPUT_PIN 14  // GP14 (optional)

// ==================== SENSOR CONFIGURATION ====================
#define MPU6050_I2C_ADDRESS 0x68  // Default MPU6050 address

// Sensor ranges
#define ACCEL_RANGE MPU6050_RANGE_4_G    // ±4g range
#define GYRO_RANGE  MPU6050_RANGE_500_DEG  // ±500°/s range

// ==================== SAMPLING PARAMETERS ====================
#define DEFAULT_SAMPLE_RATE 100  // Hz - samples per second
#define MIN_SAMPLE_RATE 10       // Minimum allowed
#define MAX_SAMPLE_RATE 200      // Maximum allowed (limited by I2C speed)

// ==================== VIBRATION THRESHOLDS ====================
// All values in G-force (1G = 9.81 m/s²)

#define DEFAULT_THRESHOLD_WARNING   2.0   // Yellow LED, log warning
#define DEFAULT_THRESHOLD_CRITICAL  4.0   // Red LED, consider feed override
#define DEFAULT_THRESHOLD_EMERGENCY 6.0   // Trigger E-stop

// Hysteresis to prevent oscillation between states
#define DEFAULT_HYSTERESIS 0.2  // Must drop this much below threshold to clear

// ==================== E-STOP CONFIGURATION ====================
#define ESTOP_ACTIVE_STATE LOW   // E-stop triggers when pin is LOW
#define ESTOP_NORMAL_STATE HIGH  // Normal operation = HIGH

// Debounce time for E-stop (milliseconds)
#define ESTOP_DEBOUNCE_MS 50

// ==================== WIFI CONFIGURATION ====================
#define WIFI_ENABLED_DEFAULT true

// Access Point mode (default)
#define WIFI_SSID_DEFAULT "CNC-VibMon"
#define WIFI_PASSWORD_DEFAULT "vibration123"  // Change this!

// Client mode (alternative - connect to existing network)
// #define WIFI_MODE_CLIENT
// #define WIFI_CLIENT_SSID "YourNetworkSSID"
// #define WIFI_CLIENT_PASSWORD "YourNetworkPassword"

// mDNS hostname (access via http://pico-vibmon.local)
#define MDNS_HOSTNAME "pico-vibmon"

// Web server port
#define WEB_SERVER_PORT 80

// WebSocket update rate (Hz) - lower than sample rate to reduce WiFi load
#define WEBSOCKET_UPDATE_RATE 10  // 10 updates per second

// ==================== USB SERIAL CONFIGURATION ====================
#define SERIAL_BAUD_RATE 115200

// CSV output format
#define CSV_DELIMITER ","
#define CSV_PRECISION 3  // Decimal places for float values

// ==================== LED STATUS INDICATORS ====================
#define LED_GREEN       0  // Solid green = OK
#define LED_YELLOW      1  // Slow blink = Warning
#define LED_RED         2  // Solid red = Critical
#define LED_RED_BLINK   3  // Fast blink = E-stop

// Blink rates (milliseconds)
#define LED_BLINK_SLOW  500
#define LED_BLINK_FAST  200

// ==================== DATA BUFFER ====================
// Ring buffer size for inter-core communication
#define RING_BUFFER_SIZE 10

// USB serial transmit buffer
#define USB_TX_BUFFER_SIZE 1024

// ==================== FLASH STORAGE ====================
// Configuration stored in LittleFS
#define CONFIG_FILE_PATH "/config.json"

// Data logging to flash (optional feature)
#define FLASH_LOG_ENABLED false
#define FLASH_LOG_MAX_SIZE (512 * 1024)  // 512 KB max log file

// ==================== WATCHDOG ====================
#define WATCHDOG_ENABLED true
#define WATCHDOG_TIMEOUT_MS 1000  // 1 second - Core 0 must update within this time

// ==================== CALIBRATION ====================
// Sensor calibration offsets (determined during calibration)
#define ACCEL_OFFSET_X 0.0
#define ACCEL_OFFSET_Y 0.0
#define ACCEL_OFFSET_Z 0.0

#define GYRO_OFFSET_X 0.0
#define GYRO_OFFSET_Y 0.0
#define GYRO_OFFSET_Z 0.0

// ==================== DEBUG OPTIONS ====================
#define DEBUG_SERIAL_OUTPUT true   // Print debug messages
#define DEBUG_TIMING false         // Print loop timing info
#define DEBUG_BUFFER_STATUS false  // Print buffer fill level

// ==================== ADVANCED FEATURES ====================
// Future features (not yet implemented)
#define FEATURE_FFT_ANALYSIS false      // Real-time FFT on Pico
#define FEATURE_ADAPTIVE_THRESHOLD false // Auto-adjust thresholds
#define FEATURE_OTA_UPDATE false         // Over-the-air firmware update
#define FEATURE_SD_LOGGING false         // Log to SD card

#endif // CONFIG_H
