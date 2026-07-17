//Paper: 1.2 kg
//Plastic: 2.0 kg
//Metal: 4.5 kg
//Verre: 3.5 kg
//Other: 2.5 kg

#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include <Arduino.h>
#include <WiFi.h>
#include <FirebaseESP32.h>
#include <ESP32QRCodeReader.h>
#include <ESP32Servo.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <HX711.h>

// ─────────────────────────────────────────────────────────────────────────
// ── CREDENTIALS ──────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
#define WIFI_SSID     "Ch"
#define WIFI_PASSWORD "123456789"
#define FIREBASE_HOST "ecorewind-6b5d6-default-rtdb.europe-west1.firebasedatabase.app"
#define FIREBASE_AUTH "CBNA3aBgvqCGoiG5rPY1WmC5fMh49PqPzE8227ze"

// ─────────────────────────────────────────────────────────────────────────
// ── TIMING ───────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
#define USER_LID_TIME      5000
#define COLLECTOR_LID_TIME 8000
#define MESSAGE_TIME       1500
#define QR_COOLDOWN_MS     15000

// ─────────────────────────────────────────────────────────────────────────
// ── PINS ─────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
#define SERVO1_PIN     2
#define SERVO2_PIN     4
#define LCD_SDA        15
#define LCD_SCL        13
#define HX711_DOUT     1
#define HX711_SCK      3
#define LCD_ADDR       0x27

// ─────────────────────────────────────────────────────────────────────────
// ── GLOBALS ───────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
FirebaseData   fbdo;
FirebaseConfig config;
FirebaseAuth   auth;

ESP32QRCodeReader reader(CAMERA_MODEL_AI_THINKER);

Servo servo1;
Servo servo2;

LiquidCrystal_I2C lcd(LCD_ADDR, 16, 2);

bool          busy        = false;
bool          ignoreQR    = false;
String        lastQR      = "";
unsigned long lastQRTime  = 0;
QueueHandle_t qrQueue;
volatile bool readingDistance = false;

HX711 scale;

const float CAL_FACTOR = 98520.0f;

#define BIN_ID "BIN-GENERAL-001"

const float POINTS_PER_KG      = 500.0f;
const float BIN_FULL_WEIGHT_KG = 2.5f;

// ─────────────────────────────────────────────────────────────────────────
// ── SERVOS ───────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
void openUserServo() {
  servo1.attach(SERVO1_PIN);
  servo1.write(90);
  delay(USER_LID_TIME);
  servo1.write(0);
  delay(500);
  servo1.detach();
}

void openCollectorServo() {
  servo2.attach(SERVO2_PIN);
  servo2.write(90);
  delay(COLLECTOR_LID_TIME);
  servo2.write(0);
  delay(500);
  servo2.detach();
}

// ─────────────────────────────────────────────────────────────────────────
// ── LCD ─────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
void oledShow(const char* l1, const char* l2 = "") {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(l1);
  lcd.setCursor(0, 1);
  lcd.print(l2);
}

// ─────────────────────────────────────────────────────────────────────────
// ── FIREBASE ─────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
void updateUserScore(String qrID, int points) {
  String scorePath = "/utilisateurs/" + qrID + "/score";
  float oldScore = 0.0f;

  if (!Firebase.getFloat(fbdo, scorePath)) {
    Serial.println("[FIREBASE] Impossible de lire le score: " + fbdo.errorReason());
    return;
  }

  oldScore = fbdo.floatData();
  int newScore = (int)(oldScore + (float)points);

  if (!Firebase.setInt(fbdo, scorePath, newScore)) {
    Serial.println("[FIREBASE] Impossible de mettre a jour le score: " + fbdo.errorReason());
  } else {
    Serial.printf("[FIREBASE] Score mis a jour: %.0f -> %d\n", oldScore, newScore);
  }
}

void updateBinWeight(float weightKg) {
  String basePath = "/poubelles/" + String(BIN_ID);

  Firebase.setFloat(fbdo, basePath + "/poids", weightKg);

  if (weightKg >= BIN_FULL_WEIGHT_KG) {
    Firebase.setString(fbdo, basePath + "/etat", "plein");
    Serial.println("[BIN] Etat: plein");
  } else {
    Firebase.setString(fbdo, basePath + "/etat", "vide");
    Serial.println("[BIN] Etat: vide");
  }
}

// ─────────────────────────────────────────────────────────────────────────
// ── WEIGHT ───────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
float readBinWeightKg() {
  if (!scale.is_ready()) {
    Serial.println("[HX711] Capteur non pret");
    return 0;
  }

  float w = scale.get_units(10);

  if (abs(w) < 0.005f) w = 0;
  if (w < 0)           w = 0;

  Serial.printf("[HX711] Poids lu: %.3f kg\n", w);
  return w;
}

// ─────────────────────────────────────────────────────────────────────────
// ── FIREBASE USER CHECK ───────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
void checkUser(const String& qrID) {
  busy     = true;
  ignoreQR = true;

  Serial.println("[QR] ID detecte: " + qrID);

  // ── WiFi check avec timeout ──
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Deconnecte, tentative de reconnexion...");
    oledShow("WiFi", "Reconnexion...");
    WiFi.reconnect();
    int tries = 0;
    while (WiFi.status() != WL_CONNECTED && tries < 20) {
      delay(500);
      tries++;
    }
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WiFi] Echec reconnexion");
      oledShow("Erreur WiFi", "Reessayez");
      delay(MESSAGE_TIME);
      oledShow("EcoRewind", "Scannez QR code");
      ignoreQR = false;
      busy     = false;
      return;
    }
    Serial.println("[WiFi] Reconnecte: " + WiFi.localIP().toString());
  }

  oledShow("Verification", "Un instant...");

  String path = "/utilisateurs/" + qrID;

  if (Firebase.getString(fbdo, path + "/role")) {
    String role = fbdo.stringData();
    Serial.println("[FIREBASE] Role: " + role);

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Utilisateur:");
    lcd.setCursor(0, 1);
    lcd.print(role);
    delay(MESSAGE_TIME);

    if (role == "user") {
      oledShow("Mesure", "Avant depot");
      float weightBefore = readBinWeightKg();

      oledShow("Ouverture", "Couvercle...");
      openUserServo();
      delay(3000);

      oledShow("Mesure", "Apres depot");
      float weightAfter   = readBinWeightKg();
      float addedWeightKg = weightAfter - weightBefore;
      if (addedWeightKg < 0.005f) addedWeightKg = 0;

      int points = (int)(addedWeightKg * POINTS_PER_KG);
      Serial.printf("[USER] Poids ajoute: %.3f kg -> %d points\n", addedWeightKg, points);

      updateBinWeight(weightAfter);
      if (points > 0) {
        updateUserScore(qrID, points);
      }
      oledShow("Merci!", "Points ajoutes");

    } else if (role == "collector") {
      oledShow("Ouverture", "Mode vidage");
      openCollectorServo();
      scale.tare(20);
      updateBinWeight(0);
      oledShow("Bac vide", "Merci!");

    } else {
      // educator, admin, etc
      oledShow("Bonjour", role.c_str());
    }

  } else {
    Serial.println("[FIREBASE] Erreur: " + fbdo.errorReason());
    oledShow("Erreur", "Inconnu");
  }

  delay(MESSAGE_TIME);
  oledShow("EcoRewind", "Scannez QR code");
  delay(300);
  ignoreQR = false;
  busy     = false;
}

// ─────────────────────────────────────────────────────────────────────────
// ── QR TASK (Core 1) ─────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
void qrTask(void* pvParameters) {
  struct QRCodeData qrCodeData = {};

  while (true) {
    if (reader.receiveQrCode(&qrCodeData, 100)) {
      if (qrCodeData.valid) {
        String id = String((const char*)qrCodeData.payload);

        if (id == lastQR && millis() - lastQRTime < QR_COOLDOWN_MS) {
          vTaskDelay(200 / portTICK_PERIOD_MS);
          continue;
        }
        lastQR     = id;
        lastQRTime = millis();

        char buf[100];
        id.toCharArray(buf, 100);

        if (qrQueue != NULL) {
          xQueueOverwrite(qrQueue, buf);
        }
      }
    }
    vTaskDelay(200 / portTICK_PERIOD_MS);
  }
}

// ─────────────────────────────────────────────────────────────────────────
// ── SETUP ────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

  // ── Serial (74880 baud) ──────────────────────────────────────────────
  Serial.begin(74880);
  delay(500);
  Serial.println("\n\n====== EcoRewind Demarrage ======");

  delay(500);
  setCpuFrequencyMhz(160);
  btStop();

  // ── QR Reader ────────────────────────────────────────────────────────
  reader.setup();

  // ── LCD ──────────────────────────────────────────────────────────────
  Wire.begin(LCD_SDA, LCD_SCL);
  lcd.init();
  lcd.backlight();
  oledShow("EcoRewind", "Demarrage...");
  Serial.println("[LCD] Initialise");

  // ── WiFi ─────────────────────────────────────────────────────────────
  oledShow("EcoRewind", "WiFi...");
  Serial.print("[WiFi] Connexion a: ");
  Serial.println(WIFI_SSID);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  WiFi.setTxPower(WIFI_POWER_15dBm);

  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries < 30) {
    delay(500);
    Serial.print(".");
    tries++;
  }
  Serial.println();

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] ECHEC de connexion !");
    oledShow("WiFi echoue", "Verifiez reseau");
  } else {
    Serial.print("[WiFi] Connecte ! IP: ");
    Serial.println(WiFi.localIP());
    oledShow("WiFi OK", WiFi.localIP().toString().c_str());
    delay(1000);

    // ── Firebase ───────────────────────────────────────────────────────
    oledShow("EcoRewind", "Firebase...");
    Serial.println("[Firebase] Initialisation...");
    fbdo.setBSSLBufferSize(1024, 512);
    fbdo.setResponseSize(256);
    config.host                       = FIREBASE_HOST;
    config.signer.tokens.legacy_token = FIREBASE_AUTH;
    Firebase.begin(&config, &auth);
    Firebase.reconnectWiFi(true);
    Serial.println("[Firebase] OK");

    // ── HX711 ─────────────────────────────────────────────────────────
    Serial.println("[HX711] Initialisation...");
    scale.begin(HX711_DOUT, HX711_SCK);
    scale.set_scale(CAL_FACTOR);
    delay(1000);
    scale.tare(20);
    Serial.println("[HX711] Tare effectuee");
  }

  // ── QR Queue & Task ───────────────────────────────────────────────────
  qrQueue = xQueueCreate(1, sizeof(char) * 100);
  delay(1000);

  reader.beginOnCore(1);
  xTaskCreate(qrTask, "onQrCode", 16 * 1024, NULL, 4, NULL);

  oledShow("EcoRewind", "Scannez QR code");
  Serial.println("[SETUP] Pret ! En attente de QR code...");
}

// ─────────────────────────────────────────────────────────────────────────
// ── LOOP ─────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
void loop() {
  char buf[100];

  if (xQueueReceive(qrQueue, buf, 0) == pdTRUE) {
    checkUser(String(buf));
  }

  delay(100);
}
