/*
 * SmartTrash ESP32 Firmware - Versi Sederhana
 */
#include <WiFi.h>
#include <HTTPClient.h>
#include <ESP32Servo.h>
#include <ArduinoJson.h>

const char* WIFI_SSID     = "Employees";
const char* WIFI_PASSWORD = "###HorizonU";
const char* SERVER_BASE   = "http://10.60.4.211/smartsampah/backend/api";
const char* ESP32_KEY     = "esp32_smartsampah_key";

#define SERVO_PIN 18
#define TRIG_ORG  5
#define ECHO_ORG  17
#define TRIG_NON  26
#define ECHO_NON  27

Servo myServo;
int lastLogId = 0;
unsigned long lastUpdate = 0;

void setup() {
  Serial.begin(115200);
  
  // Setup Sensor
  pinMode(TRIG_ORG, OUTPUT); pinMode(ECHO_ORG, INPUT);
  pinMode(TRIG_NON, OUTPUT); pinMode(ECHO_NON, INPUT);
  
  // Setup Servo
  myServo.attach(SERVO_PIN);
  myServo.write(90); // Posisi netral di tengah
  delay(500);        // Beri waktu bergerak ke tengah
  myServo.detach();  // Matikan sinyal agar tidak bergetar

  // Setup WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");                                                                                
  while (WiFi.status() != WL_CONNECTED) { 
    delay(500); 
    Serial.print("."); 
  }
  Serial.println("\nConnected!");
}

float getDistance(int trig, int echo) {
  digitalWrite(trig, LOW); delayMicroseconds(2);
  digitalWrite(trig, HIGH); delayMicroseconds(10);
  digitalWrite(trig, LOW);
  
  // Timeout 30ms (jarak max ~500cm)
  float dist = pulseIn(echo, HIGH, 30000) * 0.034 / 2;
  
  // Jika error (0), kembalikan 30 (anggap kosong)
  return (dist == 0) ? 30.0 : dist; 
}

void sendStatus(float org, float non) {
  HTTPClient http;
  http.begin(String(SERVER_BASE) + "/trash_status.php");
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-ESP32-KEY", ESP32_KEY);
  
  String payload = "{\"bin_id\":1,\"level_organic\":" + String(org) + ",\"level_nonorganic\":" + String(non) + "}";
  int code = http.POST(payload);
  Serial.println("Kirim Status: HTTP " + String(code));
  http.end();
}

void checkServo() {
  HTTPClient http;
  http.begin(String(SERVER_BASE) + "/esp32_poll.php?key=" + String(ESP32_KEY) + "&bin_id=1");
  
  if (http.GET() == 200) {
    JsonDocument doc;
    deserializeJson(doc, http.getString());
    
    if (doc["success"] && doc["data"]["has_data"]) {
      int logId = doc["data"]["log_id"];
      
      // Jika ada data baru yang belum dieksekusi
      if (logId > lastLogId) {
        lastLogId = logId;
        String action = doc["data"]["servo_action"].as<String>();
        action.toLowerCase();
        
        Serial.println(">>> Action Baru: " + action);
        
        // Aktifkan servo sebelum bergerak
        if (!myServo.attached()) {
          myServo.attach(SERVO_PIN);
        }
        
        // Cek Organik (Kanan)
        if (action.indexOf("right") >= 0 || action.indexOf("organik") >= 0 || action.indexOf("organic") >= 0) {
          myServo.write(150); // Ke kanan
          delay(1500);        // Tunggu sampah jatuh
          myServo.write(90);  // Kembali netral
        } 
        // Cek Anorganik (Kiri)
        else if (action.indexOf("left") >= 0 || action.indexOf("anorganik") >= 0 || action.indexOf("non") >= 0) {
          myServo.write(30);  // Ke kiri
          delay(1500);        // Tunggu sampah jatuh
          myServo.write(90);  // Kembali netral
        }
        
        // Tunggu servo kembali ke tengah dengan sempurna lalu matikan sinyalnya
        delay(500);
        myServo.detach();
      }
    }
  }
  http.end();
}

void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    // 1. Kirim status jarak setiap 2 detik
    if (millis() - lastUpdate > 2000) {
      lastUpdate = millis();
      float distOrg = getDistance(TRIG_ORG, ECHO_ORG);
      float distNon = getDistance(TRIG_NON, ECHO_NON);
      
      Serial.println("Jarak -> Org: " + String(distOrg) + " cm, Non: " + String(distNon) + " cm");
      sendStatus(distOrg, distNon);
    }
    
    // 2. Cek database untuk melihat apakah ada instruksi servo baru
    checkServo();
  }
  
  // Delay ringan agar loop tidak memberatkan ESP32
  delay(200);
}
