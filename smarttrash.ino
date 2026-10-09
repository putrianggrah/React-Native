/*
 * =============================================================
 *  SmartTrash ESP32 Firmware
 *  Hardware : ESP32 DevKit V1
 *  Sensors  : HC-SR04 Ultrasonic, Servo Motor (SG90/MG996R)
 *  Author   : SmartTrash Team
 * =============================================================
 */

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ESP32Servo.h>
#include <ArduinoJson.h>
#include <Preferences.h>

// ---------------------------------------------------------------
//  WiFi Credentials — GANTI dengan WiFi Anda
// ---------------------------------------------------------------
const char* WIFI_SSID     = "Employees";
const char* WIFI_PASSWORD = "###HorizonU";

// ---------------------------------------------------------------
//  Backend API — GANTI dengan IP Laragon Anda
// ---------------------------------------------------------------
const char* SERVER_BASE    = "http://10.60.4.211/smartsampah/backend/api";
const char* ESP32_KEY      = "esp32_smartsampah_key";
const int   BIN_ID         = 1;

// ---------------------------------------------------------------
//  Pin Definitions & Wiring Guide
// ---------------------------------------------------------------
//  SERVO MOTOR:
//  - VCC (Red)            -> 5V / VIN
//  - GND (Black / Brown)  -> GND
//  - SIG (Orange / Yellow)-> GPIO 18
//
//  ULTRASONIC ORGANIC:
//  - VCC         -> 5V / VIN
//  - GND         -> GND
//  - TRIG        -> GPIO 5
//  - ECHO        -> GPIO 17
//
//  ULTRASONIC NON-ORGANIC:
//  - VCC         -> 5V / VIN
//  - GND         -> GND
//  - TRIG        -> GPIO 26
//  - ECHO        -> GPIO 27
//
//  STATUS LED:
//  - Built-in LED -> GPIO 2
// ---------------------------------------------------------------
#define SERVO_PIN         18
#define TRIG_PIN_ORG      5
#define ECHO_PIN_ORG      17
#define TRIG_PIN_NON      26
#define ECHO_PIN_NON      27
#define LED_STATUS        2

// ---------------------------------------------------------------
//  Settings
// ---------------------------------------------------------------
#define BIN_DEPTH_CM        30    // Total bin depth (cm)
#define FULL_THRESHOLD_CM   6     // Distance <= 6 cm (80% full for 30cm bin)
#define NORMAL_THRESHOLD_CM 24    // Distance >= 24 cm (20% full for 30cm bin)
#define SERVO_NEUTRAL       90    // degrees — center position
#define SERVO_TILT_ANGLE    60    // degrees — tilt from neutral (left ~30°, right ~150°)

#define SERVO_ORGANIC       (SERVO_NEUTRAL + SERVO_TILT_ANGLE)  // right
#define SERVO_NON_ORGANIC   (SERVO_NEUTRAL - SERVO_TILT_ANGLE)  // left
#define POLL_INTERVAL_MS    150   // Poll API every 150ms (lebih responsif)
#define STATUS_INTERVAL_MS  2000  // Send bin status every 2 seconds
#define NOTIF_INTERVAL_MS   3000  // Send full-bin notification every 3 seconds

// ---------------------------------------------------------------
//  Global Objects & Variables
// ---------------------------------------------------------------
Servo trashServo;
Preferences preferences;

// Timers (non-blocking)
unsigned long lastStatusTime = 0;
unsigned long lastPollTime   = 0;
unsigned long lastNotifTime  = 0;

// NVS stored last processed log ID
int lastLogId = -1;

// Strike counters for "FULL" status debouncing
int strikeOrg = 0;
int strikeNon = 0;

// Global bin levels
float distOrg = 30.0, distNon = 30.0;
int   pctOrg  = 0,    pctNon  = 0;

// Previous status for change detection
bool prevOrgFull = false;
bool prevNonFull = false;

// ---------------------------------------------------------------
//  Forward Declarations
// ---------------------------------------------------------------
void connectWiFi();
float readDistanceCm(int trig, int echo, String name);
void moveServo(String type);
void updateLEDStatus();
void sendBinStatus(int distOrg, int distNon, bool statusChanged);
void sendBinStatus(int distOrg, int distNon);
void pollClassification();

// ---------------------------------------------------------------
//  Setup
// ---------------------------------------------------------------
void setup() {
  Serial.begin(9600);
  Serial.println("\n=== SmartTrash ESP32 v1.0 ===");

  // Pins
  pinMode(TRIG_PIN_ORG, OUTPUT);
  pinMode(ECHO_PIN_ORG, INPUT);
  pinMode(TRIG_PIN_NON, OUTPUT);
  pinMode(ECHO_PIN_NON, INPUT);
  pinMode(LED_STATUS,   OUTPUT);

  // Servo — initialize to neutral then detach (silent)
  ESP32PWM::allocateTimer(1);
  trashServo.setPeriodHertz(50);
  trashServo.attach(SERVO_PIN, 500, 2400);
  trashServo.write(SERVO_NEUTRAL);
  delay(1000);
  trashServo.detach();
  pinMode(SERVO_PIN, OUTPUT);
  digitalWrite(SERVO_PIN, LOW); // Pin LOW = tidak ada noise ke servo
  Serial.println("[SERVO] Initialized at neutral 90° (Detached + Pin LOW).\n");

  // Preferences (NVS)
  preferences.begin("smarttrash", false);
  lastLogId = preferences.getInt("last_log_id", -1);
  preferences.end();
  Serial.printf("[PREFS] Last processed Log ID: %d\n", lastLogId);

  // WiFi
  connectWiFi();
}

// ---------------------------------------------------------------
//  Main Loop — FULLY NON-BLOCKING
//  Sensor reading, notification, and poll ALL run every cycle.
//  Nothing blocks the loop, so servo can always respond.
// ---------------------------------------------------------------
void loop() {
  unsigned long now = millis();

  // Reconnect WiFi if disconnected
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Reconnecting...");
    connectWiFi();
  }

  // ---- 1. Read ultrasonic distances ----
  distOrg = readDistanceCm(TRIG_PIN_ORG, ECHO_PIN_ORG, "ORGANIC");
  delay(50);
  distNon = readDistanceCm(TRIG_PIN_NON, ECHO_PIN_NON, "NON-ORGANIC");

  // ---- 2. Debounce ORGANIC ----
  float debouncedDistOrg = distOrg;
  if (distOrg > 0) {
    if (distOrg <= FULL_THRESHOLD_CM) {
      strikeOrg++;
      if (strikeOrg > 5) strikeOrg = 5;
    } else {
      strikeOrg--;
      if (strikeOrg < 0) strikeOrg = 0;
    }
    if (strikeOrg >= 4) {
      debouncedDistOrg = 5.0;
      if (strikeOrg == 5) Serial.println("[DEBOUNCE] ORGANIK terkonfirmasi PENUH!");
    } else if (distOrg <= FULL_THRESHOLD_CM) {
      debouncedDistOrg = FULL_THRESHOLD_CM + 1;
      Serial.printf("[DEBOUNCE] ORGANIK strike %d/5...\n", strikeOrg);
    }
  }

  // ---- 3. Debounce NON-ORGANIC ----
  float debouncedDistNon = distNon;
  if (distNon > 0) {
    if (distNon <= FULL_THRESHOLD_CM) {
      strikeNon++;
      if (strikeNon > 5) strikeNon = 5;
    } else {
      strikeNon--;
      if (strikeNon < 0) strikeNon = 0;
    }
    if (strikeNon >= 4) {
      debouncedDistNon = 5.0;
      if (strikeNon == 5) Serial.println("[DEBOUNCE] ANORGANIK terkonfirmasi PENUH!");
    } else if (distNon <= FULL_THRESHOLD_CM) {
      debouncedDistNon = FULL_THRESHOLD_CM + 1;
      Serial.printf("[DEBOUNCE] ANORGANIK strike %d/5...\n", strikeNon);
    }
  }

  // ---- 4. Calculate fill percentage ----
  pctOrg = (debouncedDistOrg > 0) ? (int)((1.0f - (debouncedDistOrg / (float)BIN_DEPTH_CM)) * 100.0f) : 0;
  pctNon = (debouncedDistNon > 0) ? (int)((1.0f - (debouncedDistNon / (float)BIN_DEPTH_CM)) * 100.0f) : 0;
  pctOrg = max(0, min(100, pctOrg));
  pctNon = max(0, min(100, pctNon));

  // Log values
  if (distOrg > 0) Serial.printf("[ORG] Raw: %.1f cm | Debounced: %.1f cm (%d%%) | ", distOrg, debouncedDistOrg, pctOrg);
  if (distNon > 0) Serial.printf("[NON] Raw: %.1f cm | Debounced: %.1f cm (%d%%)\n", distNon, debouncedDistNon, pctNon);

  // ---- 5. Update LED ----
  updateLEDStatus();

  // ---- 6. NON-BLOCKING full-bin notification (every 3 seconds) ----
  // This does NOT block the loop — pollClassification() always runs!
  if (pctOrg > 80 || pctNon > 80) {
    if (now - lastNotifTime >= NOTIF_INTERVAL_MS) {
      lastNotifTime = now;
      Serial.println(">>> [ ALERT ] TEMPAT SAMPAH PENUH! <<<");
      sendBinStatus((int)debouncedDistOrg, (int)debouncedDistNon, true);
    }
  } else if (pctOrg < 20 && pctNon < 20) {
    if (millis() % 10000 < 500) Serial.println(">>> [ STATUS ] NORMAL <<<");
  }

  // ---- 7. Send regular bin status to backend ----
  if (now - lastStatusTime >= STATUS_INTERVAL_MS) {
    lastStatusTime = now;
    sendBinStatus((int)debouncedDistOrg, (int)debouncedDistNon);
  }

  // ---- 8. Poll for classification → move servo ----
  // This ALWAYS runs, even when bin is full → servo can always drop trash
  if (now - lastPollTime >= POLL_INTERVAL_MS) {
    lastPollTime = now;
    pollClassification();
  }

  // Tidak ada delay besar di sini — loop berjalan secepat mungkin
  // agar polling servo lebih responsif
  delay(30);
}

// ---------------------------------------------------------------
//  Ultrasonic: read distance in cm (3 retries)
// ---------------------------------------------------------------
float readDistanceCm(int trig, int echo, String name) {
  pinMode(trig, OUTPUT);
  pinMode(echo, INPUT);

  for (int i = 0; i < 3; i++) {
    digitalWrite(trig, LOW);
    delayMicroseconds(10);
    digitalWrite(trig, HIGH);
    delayMicroseconds(12);
    digitalWrite(trig, LOW);

    long duration = pulseIn(echo, HIGH, 35000);

    if (duration > 0) {
      float distance = duration * 0.034f / 2.0f;
      if (distance >= 2.0f && distance <= 450.0f) {
        return distance;
      }
    }
    delay(20);
  }

  Serial.printf("[DEBUG] %s: FAILED. Check wiring.\n", name.c_str());
  return -1;
}

// ---------------------------------------------------------------
//  Move servo: left=organic, right=non-organic, then return
// ---------------------------------------------------------------
void moveServo(String type) {
  int targetAngle = SERVO_NEUTRAL;

  // Clean the string: remove whitespace and convert to lowercase
  type.trim();
  type.toLowerCase();

  // DEBUG: Print exact received value with length
  Serial.printf("[SERVO] Received action: '%s' (len=%d)\n", type.c_str(), type.length());

  // Use indexOf for robust matching (handles extra characters)
  // Non-organic is now LEFT, Organic is now RIGHT based on your hardware setup
  bool isOrganic    = (type.indexOf("right") >= 0 || type.indexOf("organic") >= 0 || type.indexOf("organik") >= 0);
  bool isNonOrganic = (type.indexOf("left") >= 0 || type.indexOf("non") >= 0 || type.indexOf("anorganik") >= 0);

  // "non-organic" contains "organic", so check non-organic FIRST
  if (isNonOrganic) {
    targetAngle = SERVO_NON_ORGANIC;
    Serial.printf("[SERVO] -> LEFT/NON-ORGANIC (%d°)\n", targetAngle);
  } else if (isOrganic) {
    targetAngle = SERVO_ORGANIC;
    Serial.printf("[SERVO] -> RIGHT/ORGANIC (%d°)\n", targetAngle);
  } else {
    Serial.printf("[SERVO] Type '%s' unknown, not moving.\n", type.c_str());
    return;
  }

  Serial.printf("[SERVO] Moving from %d° to %d°...\n", SERVO_NEUTRAL, targetAngle);

  // Attach servo, langsung konfirmasi posisi netral agar tidak loncat
  trashServo.attach(SERVO_PIN, 500, 2400);
  trashServo.write(SERVO_NEUTRAL); // Paksa di netral dulu sebelum gerak
  delay(30); // Minimal stabilize time

  // Step-by-step movement — step 3°, 8ms per step (lebih cepat dari sebelumnya)
  int current = SERVO_NEUTRAL;
  int step = (targetAngle > current) ? 3 : -3;
  while (abs(current - targetAngle) > 3) {
    current += step;
    trashServo.write(current);
    delay(8);
  }
  trashServo.write(targetAngle);
  Serial.printf("[SERVO] Arrived at %d°. Waiting for trash to fall...\n", targetAngle);
  delay(900);  // Hold — cukup untuk sampah jatuh

  // Return to neutral (step-by-step)
  current = targetAngle;
  step = (SERVO_NEUTRAL > current) ? 3 : -3;
  while (abs(current - SERVO_NEUTRAL) > 3) {
    current += step;
    trashServo.write(current);
    delay(8);
  }
  trashServo.write(SERVO_NEUTRAL);
  delay(200);

  // Detach setelah selesai agar servo tidak getar saat idle
  trashServo.detach();
  pinMode(SERVO_PIN, OUTPUT);
  digitalWrite(SERVO_PIN, LOW); // Paksa pin LOW agar tidak ada noise
  Serial.println("[SERVO] Done. Back to neutral (90°), detached, pin LOW.");
}

// ---------------------------------------------------------------
//  Update LED Status Indicator
// ---------------------------------------------------------------
void updateLEDStatus() {
  if (pctOrg > 80 || pctNon > 80) {
    digitalWrite(LED_STATUS, (millis() / 150) % 2);  // Rapid blink
  } else if (pctOrg < 20 && pctNon < 20) {
    digitalWrite(LED_STATUS, HIGH);                   // Solid on
  } else {
    digitalWrite(LED_STATUS, (millis() / 800) % 2);   // Slow blink
  }
}

// ---------------------------------------------------------------
//  POST bin level to backend (with status_changed flag)
// ---------------------------------------------------------------
void sendBinStatus(int distOrg, int distNon, bool statusChanged) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SERVER_BASE) + "/trash_status.php";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-ESP32-KEY", ESP32_KEY);

  JsonDocument doc;
  doc["bin_id"]           = BIN_ID;
  doc["level_organic"]    = distOrg;
  doc["level_nonorganic"] = distNon;
  doc["status_changed"]   = statusChanged;

  String body;
  serializeJson(doc, body);

  int code = http.POST(body);
  if (code > 0) {
    String resp = http.getString();
    Serial.printf("[STATUS] HTTP %d -> %s\n", code, resp.c_str());
  } else {
    Serial.printf("[STATUS] Error: %s\n", http.errorToString(code).c_str());
  }
  http.end();
}

// ---------------------------------------------------------------
//  POST bin level to backend (without status_changed flag)
// ---------------------------------------------------------------
void sendBinStatus(int distOrg, int distNon) {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SERVER_BASE) + "/trash_status.php";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-ESP32-KEY", ESP32_KEY);

  JsonDocument doc;
  doc["bin_id"]           = BIN_ID;
  doc["level_organic"]    = distOrg;
  doc["level_nonorganic"] = distNon;

  String body;
  serializeJson(doc, body);

  int code = http.POST(body);
  if (code > 0) {
    String resp = http.getString();
    Serial.printf("[STATUS] HTTP %d -> %s\n", code, resp.c_str());
  } else {
    Serial.printf("[STATUS] Error: %s\n", http.errorToString(code).c_str());
  }
  http.end();
}

// ---------------------------------------------------------------
//  GET latest classification from backend -> move servo
// ---------------------------------------------------------------
void pollClassification() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SERVER_BASE) + "/esp32_poll.php?key=" + ESP32_KEY + "&bin_id=" + BIN_ID;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  int code = http.GET();
  if (code == 200) {
    String resp = http.getString();
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, resp);

    if (!err && doc["success"].as<bool>()) {
      bool hasData = doc["data"]["has_data"].as<bool>();

      if (hasData) {
        int    logId  = doc["data"]["log_id"].as<int>();
        String action = doc["data"]["servo_action"].as<String>();
        String type   = doc["data"]["trash_type"].as<String>();

        // Auto-heal: database reset detection
        if (logId < lastLogId) {
          Serial.printf("[POLL] DB reset detected (logId %d < lastLogId %d). Resetting.\n", logId, lastLogId);
          lastLogId = 0;
        }

        // Process only new logs
        if (logId > lastLogId) {
          if (lastLogId == -1) {
            // First time boot (no NVS data), sync state without moving servo
            Serial.printf("[POLL] First boot detected. Syncing lastLogId to %d without moving servo.\n", logId);
          } else {
            Serial.printf("[POLL] New data #%d! Moving servo...\n", logId);

            // Flash LED
            for (int i = 0; i < 3; i++) {
              digitalWrite(LED_STATUS, HIGH); delay(100);
              digitalWrite(LED_STATUS, LOW);  delay(100);
            }

            // Move servo immediately based on classification action
            moveServo(action);
          }

          // Warn if target bin is full
          if ((action.indexOf("right") >= 0 || (action.indexOf("organic") >= 0 && action.indexOf("non") < 0)) && pctOrg > 80) {
            Serial.println("[POLL] WARNING: ORGANIC bin full (>80%). Servo moved right regardless.");
          } else if ((action.indexOf("left") >= 0 || action.indexOf("non") >= 0) && pctNon > 80) {
            Serial.println("[POLL] WARNING: NON-ORGANIC bin full (>80%). Servo moved left regardless.");
          }

          // Save lastLogId to NVS
          lastLogId = logId;
          preferences.begin("smarttrash", false);
          preferences.putInt("last_log_id", lastLogId);
          preferences.end();
          Serial.printf("[POLL] Log #%d processed & saved.\n", logId);
        }
      } else {
        // DB empty — reset
        if (lastLogId > 0) {
          lastLogId = 0;
          Serial.println("[POLL] DB empty. Resetting lastLogId to 0.");
        }
      }
    }
  } else {
    Serial.printf("[POLL] HTTP error: %d\n", code);
  }
  http.end();
}

// ---------------------------------------------------------------
//  WiFi connect with retry
// ---------------------------------------------------------------
void connectWiFi() {
  Serial.printf("\n[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    digitalWrite(LED_STATUS, HIGH);
  } else {
    Serial.println("\n[WiFi] Failed to connect - running offline");
    digitalWrite(LED_STATUS, LOW);
  }
}
