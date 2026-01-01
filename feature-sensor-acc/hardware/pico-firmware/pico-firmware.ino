/*
 * CNC Vibration Monitor - Pico W Firmware
 * 
 * Dual-core architecture:
 * - Core 0: Safety-critical sensor reading and E-stop
 * - Core 1: USB serial and WiFi management
 * 
 * Hardware: RP2040 Pico W + MPU6050/ADXL345
 */

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <LittleFS.h>
#include <ArduinoJson.h>
#include "config.h"

// ==================== GLOBAL OBJECTS ====================
Adafruit_MPU6050 mpu;
AsyncWebServer server(80);
AsyncWebSocket ws("/ws");

// ==================== SHARED DATA (between cores) ====================
struct SensorData {
  uint32_t timestamp;
  float accel_x, accel_y, accel_z;
  float gyro_x, gyro_y, gyro_z;
  float magnitude;
  uint8_t status;  // 0=OK, 1=WARN, 2=CRIT, 3=ESTOP
};

// Ring buffer for inter-core communication
#define BUFFER_SIZE 10
volatile SensorData dataBuffer[BUFFER_SIZE];
volatile int writeIndex = 0;
volatile int readIndex = 0;
volatile bool newDataAvailable = false;

// Configuration (loaded from flash)
struct Config {
  float threshold_warning;
  float threshold_critical;
  float threshold_emergency;
  float hysteresis;
  int sample_rate;
  bool wifi_enabled;
  char wifi_ssid[32];
  char wifi_password[64];
} config;

// ==================== CORE 0: SAFETY CRITICAL ====================
void setup() {
  // Initialize serial for debugging
  Serial.begin(115200);
  delay(1000);
  Serial.println("VIB:BOOT,Vibration Monitor Starting...");
  
  // Load configuration from flash
  loadConfig();
  
  // Initialize I2C for MPU6050
  Wire.setSDA(I2C_SDA_PIN);
  Wire.setSCL(I2C_SCL_PIN);
  Wire.begin();
  
  // Initialize MPU6050
  if (!mpu.begin()) {
    Serial.println("VIB:ERROR,MPU6050 not found!");
    triggerEmergencyStop("Sensor initialization failed");
    while (1) {
      delay(1000);
    }
  }
  
  // Configure sensor ranges
  mpu.setAccelerometerRange(MPU6050_RANGE_4_G);
  mpu.setGyroRange(MPU6050_RANGE_500_DEG);
  mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
  
  // Setup E-stop GPIO
  pinMode(ESTOP_GPIO_PIN, OUTPUT);
  digitalWrite(ESTOP_GPIO_PIN, HIGH);  // Normal = HIGH (active LOW)
  
  // Status LED
  pinMode(STATUS_LED_PIN, OUTPUT);
  
  Serial.println("VIB:STATUS,Core 0 initialized - Safety monitoring active");
  
  // Start Core 1 tasks
  // Note: Core 1 setup happens automatically via setup1()
}

void loop() {
  // CORE 0 MAIN LOOP - SAFETY CRITICAL
  // This runs at maximum priority and speed
  
  static unsigned long lastSampleTime = 0;
  unsigned long currentTime = millis();
  
  // Sample at configured rate (default 100Hz = 10ms interval)
  if (currentTime - lastSampleTime >= (1000 / config.sample_rate)) {
    lastSampleTime = currentTime;
    
    // Read sensor
    sensors_event_t accel, gyro, temp;
    mpu.getEvent(&accel, &gyro, &temp);
    
    // Calculate total acceleration magnitude
    float magnitude = sqrt(
      accel.acceleration.x * accel.acceleration.x +
      accel.acceleration.y * accel.acceleration.y +
      accel.acceleration.z * accel.acceleration.z
    ) / 9.81;  // Convert to G-force
    
    // Determine status based on thresholds
    uint8_t status = 0;  // OK
    static float lastMagnitude = 0;
    
    if (magnitude > config.threshold_emergency) {
      status = 3;  // EMERGENCY - trigger E-stop
      triggerEmergencyStop("Vibration exceeded emergency threshold");
    }
    else if (magnitude > config.threshold_critical) {
      status = 2;  // CRITICAL
      setStatusLED(LED_RED);
    }
    else if (magnitude > config.threshold_warning) {
      status = 1;  // WARNING
      setStatusLED(LED_YELLOW);
    }
    else if (lastMagnitude > config.threshold_warning && 
             magnitude < config.threshold_warning - config.hysteresis) {
      // Hysteresis: only return to OK if dropped below warning - hysteresis
      status = 0;  // OK
      setStatusLED(LED_GREEN);
    }
    
    lastMagnitude = magnitude;
    
    // Store data in ring buffer for Core 1
    int nextWrite = (writeIndex + 1) % BUFFER_SIZE;
    if (nextWrite != readIndex) {  // Check if buffer not full
      dataBuffer[writeIndex].timestamp = currentTime;
      dataBuffer[writeIndex].accel_x = accel.acceleration.x;
      dataBuffer[writeIndex].accel_y = accel.acceleration.y;
      dataBuffer[writeIndex].accel_z = accel.acceleration.z;
      dataBuffer[writeIndex].gyro_x = gyro.gyro.x;
      dataBuffer[writeIndex].gyro_y = gyro.gyro.y;
      dataBuffer[writeIndex].gyro_z = gyro.gyro.z;
      dataBuffer[writeIndex].magnitude = magnitude;
      dataBuffer[writeIndex].status = status;
      
      writeIndex = nextWrite;
      newDataAvailable = true;
    }
  }
  
  // Minimal delay to prevent watchdog timeout
  delay(1);
}

// ==================== CORE 1: COMMUNICATION ====================
void setup1() {
  // Core 1 handles USB serial and WiFi (non-critical)
  Serial.println("VIB:STATUS,Core 1 initialized - Communication active");
  
  // Send CSV header
  Serial.println("VIB:HEADER,timestamp,ax,ay,az,gx,gy,gz,mag,status");
  
  // Initialize WiFi if enabled
  if (config.wifi_enabled) {
    initWiFi();
    initWebServer();
  }
}

void loop1() {
  // CORE 1 MAIN LOOP - COMMUNICATION (non-blocking)
  
  // Process USB serial data output
  if (newDataAvailable && readIndex != writeIndex) {
    SensorData data = dataBuffer[readIndex];
    readIndex = (readIndex + 1) % BUFFER_SIZE;
    
    // Send data as CSV over USB serial
    Serial.print("VIB:DATA,");
    Serial.print(data.timestamp);
    Serial.print(",");
    Serial.print(data.accel_x, 3);
    Serial.print(",");
    Serial.print(data.accel_y, 3);
    Serial.print(",");
    Serial.print(data.accel_z, 3);
    Serial.print(",");
    Serial.print(data.gyro_x, 3);
    Serial.print(",");
    Serial.print(data.gyro_y, 3);
    Serial.print(",");
    Serial.print(data.gyro_z, 3);
    Serial.print(",");
    Serial.print(data.magnitude, 3);
    Serial.print(",");
    Serial.println(statusToString(data.status));
    
    // Send to WebSocket clients if WiFi enabled
    if (config.wifi_enabled && ws.count() > 0) {
      sendWebSocketData(data);
    }
    
    newDataAvailable = false;
  }
  
  // Process incoming serial commands from PC
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    processSerialCommand(cmd);
  }
  
  // Handle WiFi tasks
  if (config.wifi_enabled) {
    ws.cleanupClients();
  }
  
  delay(1);  // Small delay to prevent tight loop
}

// ==================== HELPER FUNCTIONS ====================

void triggerEmergencyStop(const char* reason) {
  // Set E-stop GPIO LOW (active low trigger)
  digitalWrite(ESTOP_GPIO_PIN, LOW);
  
  // Send emergency message via serial
  Serial.print("VIB:ESTOP,");
  Serial.print(millis());
  Serial.print(",");
  Serial.println(reason);
  
  // Set LED to red blinking
  setStatusLED(LED_RED_BLINK);
  
  // Log to WiFi if available
  if (config.wifi_enabled) {
    // Broadcast emergency to all WebSocket clients
    String msg = "{\"type\":\"emergency\",\"reason\":\"" + String(reason) + "\"}";
    ws.textAll(msg);
  }
  
  // Halt Core 0 - requires manual reset
  while (1) {
    digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN));
    delay(200);
  }
}

void setStatusLED(uint8_t mode) {
  static unsigned long lastBlink = 0;
  static bool blinkState = false;
  
  switch (mode) {
    case LED_GREEN:
      digitalWrite(STATUS_LED_PIN, HIGH);
      break;
    case LED_YELLOW:
      // Slow blink
      if (millis() - lastBlink > 500) {
        blinkState = !blinkState;
        digitalWrite(STATUS_LED_PIN, blinkState);
        lastBlink = millis();
      }
      break;
    case LED_RED:
      digitalWrite(STATUS_LED_PIN, LOW);
      break;
    case LED_RED_BLINK:
      // Fast blink
      if (millis() - lastBlink > 200) {
        blinkState = !blinkState;
        digitalWrite(STATUS_LED_PIN, blinkState);
        lastBlink = millis();
      }
      break;
  }
}

const char* statusToString(uint8_t status) {
  switch (status) {
    case 0: return "OK";
    case 1: return "WARNING";
    case 2: return "CRITICAL";
    case 3: return "ESTOP";
    default: return "UNKNOWN";
  }
}

void loadConfig() {
  // Load configuration from LittleFS
  // For now, use defaults (TODO: implement flash storage)
  config.threshold_warning = DEFAULT_THRESHOLD_WARNING;
  config.threshold_critical = DEFAULT_THRESHOLD_CRITICAL;
  config.threshold_emergency = DEFAULT_THRESHOLD_EMERGENCY;
  config.hysteresis = DEFAULT_HYSTERESIS;
  config.sample_rate = DEFAULT_SAMPLE_RATE;
  config.wifi_enabled = WIFI_ENABLED_DEFAULT;
  strcpy(config.wifi_ssid, WIFI_SSID_DEFAULT);
  strcpy(config.wifi_password, WIFI_PASSWORD_DEFAULT);
}

void processSerialCommand(String cmd) {
  // Parse commands from PC
  // Format: CMD:ACTION,param1,param2
  
  if (cmd.startsWith("CMD:GET_CONFIG")) {
    Serial.print("VIB:CONFIG,");
    Serial.print(config.threshold_warning);
    Serial.print(",");
    Serial.print(config.threshold_critical);
    Serial.print(",");
    Serial.println(config.threshold_emergency);
  }
  else if (cmd.startsWith("CMD:SET_THRESHOLD")) {
    // Parse: CMD:SET_THRESHOLD,warning,2.5
    // TODO: Implement threshold updates
  }
  else if (cmd.startsWith("CMD:RESET")) {
    // Software reset
    rp2040.reboot();
  }
}

void initWiFi() {
  // Initialize WiFi as Access Point (default) or Client
  Serial.println("VIB:WIFI,Initializing...");
  
  // For now, create AP (TODO: add client mode)
  WiFi.mode(WIFI_AP);
  WiFi.softAP(config.wifi_ssid, config.wifi_password);
  
  IPAddress IP = WiFi.softAPIP();
  Serial.print("VIB:WIFI,AP Started - IP: ");
  Serial.println(IP);
}

void initWebServer() {
  // Setup WebSocket
  ws.onEvent(onWebSocketEvent);
  server.addHandler(&ws);
  
  // Serve static files (TODO: implement HTML pages)
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request){
    request->send(200, "text/html", "<h1>CNC Vibration Monitor</h1><p>WebSocket on /ws</p>");
  });
  
  // API endpoints
  server.on("/api/status", HTTP_GET, handleAPIStatus);
  server.on("/api/config", HTTP_GET, handleAPIGetConfig);
  server.on("/api/config", HTTP_POST, handleAPISetConfig);
  
  server.begin();
  Serial.println("VIB:WIFI,Web server started");
}

void onWebSocketEvent(AsyncWebSocket *server, AsyncWebSocketClient *client, 
                      AwsEventType type, void *arg, uint8_t *data, size_t len) {
  if (type == WS_EVT_CONNECT) {
    Serial.printf("VIB:WIFI,WebSocket client #%u connected\n", client->id());
  }
  else if (type == WS_EVT_DISCONNECT) {
    Serial.printf("VIB:WIFI,WebSocket client #%u disconnected\n", client->id());
  }
}

void sendWebSocketData(SensorData data) {
  // Send sensor data as JSON via WebSocket
  StaticJsonDocument<256> doc;
  doc["type"] = "data";
  doc["timestamp"] = data.timestamp;
  doc["magnitude"] = data.magnitude;
  doc["status"] = statusToString(data.status);
  
  JsonArray accel = doc.createNestedArray("accel");
  accel.add(data.accel_x);
  accel.add(data.accel_y);
  accel.add(data.accel_z);
  
  String output;
  serializeJson(doc, output);
  ws.textAll(output);
}

void handleAPIStatus(AsyncWebServerRequest *request) {
  // Return current system status
  StaticJsonDocument<256> doc;
  doc["version"] = FIRMWARE_VERSION;
  doc["uptime"] = millis();
  doc["wifi_clients"] = ws.count();
  doc["config"]["warning"] = config.threshold_warning;
  doc["config"]["critical"] = config.threshold_critical;
  doc["config"]["emergency"] = config.threshold_emergency;
  
  String output;
  serializeJson(doc, output);
  request->send(200, "application/json", output);
}

void handleAPIGetConfig(AsyncWebServerRequest *request) {
  // Return configuration as JSON
  StaticJsonDocument<512> doc;
  doc["thresholds"]["warning"] = config.threshold_warning;
  doc["thresholds"]["critical"] = config.threshold_critical;
  doc["thresholds"]["emergency"] = config.threshold_emergency;
  doc["thresholds"]["hysteresis"] = config.hysteresis;
  doc["sample_rate"] = config.sample_rate;
  
  String output;
  serializeJson(doc, output);
  request->send(200, "application/json", output);
}

void handleAPISetConfig(AsyncWebServerRequest *request) {
  // Update configuration from POST request
  // TODO: Parse JSON body and update config
  request->send(200, "application/json", "{\"status\":\"ok\"}");
}
