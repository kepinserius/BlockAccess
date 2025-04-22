#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <EEPROM.h>
#include <qrcode.h>
#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// OLED Display Configuration
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Pin Definitions
#define RELAY_PIN 26      // Door lock relay
#define LED_GREEN 25      // Green LED for access granted
#define LED_RED 33        // Red LED for access denied
#define BUZZER_PIN 32     // Buzzer for audio feedback

// WiFi Configuration
const char* ssid = "YourWiFiSSID";
const char* password = "YourWiFiPassword";

// API Configuration
const char* apiUrl = "https://your-api-endpoint.com/check-access";
const char* apiKey = "your-api-key";

// Device Configuration
String deviceId = "esp32-001";
String doorId = "1";
String doorName = "Main Entrance";

// Cache Configuration
#define EEPROM_SIZE 512
#define MAX_CACHED_USERS 10
struct CachedUser {
  char userId[20];
  unsigned long expiryTime;
};

// QR Code Configuration
QRCode qrcode;

// Function Prototypes
void setupWiFi();
void setupDisplay();
void generateQRCode();
void displayQRCode();
bool checkAccess(String userId);
bool checkAccessOnline(String userId);
bool checkAccessOffline(String userId);
void cacheAccessRights(String userId, unsigned long expiryTime);
void clearCachedUsers();
void grantAccess();
void denyAccess();
void logAccessAttempt(String userId, bool wasSuccessful);

void setup() {
  // Initialize Serial
  Serial.begin(115200);
  Serial.println("BlockAccess Door Controller");
  
  // Initialize EEPROM
  EEPROM.begin(EEPROM_SIZE);
  
  // Initialize GPIO
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_RED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  
  // Set initial state
  digitalWrite(RELAY_PIN, LOW);
  digitalWrite(LED_GREEN, LOW);
  digitalWrite(LED_RED, LOW);
  digitalWrite(BUZZER_PIN, LOW);
  
  // Setup Display
  setupDisplay();
  
  // Setup WiFi
  setupWiFi();
  
  // Generate and display QR code
  generateQRCode();
  displayQRCode();
}

void loop() {
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected. Reconnecting...");
    setupWiFi();
  }
  
  // In a real implementation, this would handle incoming QR scan requests
  // For demonstration, we'll simulate a QR scan every 10 seconds
  
  // Check if there's data available on Serial
  if (Serial.available() > 0) {
    String userId = Serial.readStringUntil('\n');
    userId.trim();
    
    if (userId.length() > 0) {
      Serial.println("Received user ID: " + userId);
      
      // Check access
      bool hasAccess = checkAccess(userId);
      
      // Handle access result
      if (hasAccess) {
        Serial.println("Access granted for user: " + userId);
        grantAccess();
      } else {
        Serial.println("Access denied for user: " + userId);
        denyAccess();
      }
      
      // Log access attempt
      logAccessAttempt(userId, hasAccess);
      
      // Redisplay QR code after a few seconds
      delay(5000);
      displayQRCode();
    }
  }
  
  delay(100);
}

void setupWiFi() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("Connecting to WiFi...");
  display.display();
  
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("");
    Serial.println("WiFi connected");
    Serial.println("IP address: ");
    Serial.println(WiFi.localIP());
    
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("WiFi connected!");
    display.println(WiFi.localIP().toString());
    display.display();
    delay(2000);
  } else {
    Serial.println("");
    Serial.println("WiFi connection failed");
    
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("WiFi failed!");
    display.println("Operating in offline mode");
    display.display();
    delay(2000);
  }
}

void setupDisplay() {
  // Initialize OLED display
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;); // Don't proceed, loop forever
  }
  
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("BlockAccess");
  display.println(doorName);
  display.println("Initializing...");
  display.display();
  delay(2000);
}

void generateQRCode() {
  // Create QR code data: doorId:deviceId
  String qrData = doorId + ":" + deviceId;
  Serial.println("QR Code data: " + qrData);
  
  // Initialize QR code
  uint8_t qrcodeData[qrcode_getBufferSize(3)];
  qrcode_initText(&qrcode, qrcodeData, 3, 0, qrData.c_str());
}

void displayQRCode() {
  display.clearDisplay();
  
  // Display door info
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println(doorName);
  display.println("Scan to access:");
  display.display();
  
  // Calculate QR code position (centered)
  int qrSize = qrcode.size * 2;
  int qrX = (SCREEN_WIDTH - qrSize) / 2;
  int qrY = 20;
  
  // Display QR code
  for (uint8_t y = 0; y < qrcode.size; y++) {
    for (uint8_t x = 0; x < qrcode.size; x++) {
      if (qrcode_getModule(&qrcode, x, y)) {
        display.fillRect(qrX + x*2, qrY + y*2, 2, 2, SSD1306_WHITE);
      }
    }
  }
  
  display.display();
}

bool checkAccess(String userId) {
  // First try online verification
  if (WiFi.status() == WL_CONNECTED) {
    return checkAccessOnline(userId);
  } else {
    // Fallback to offline verification
    return checkAccessOffline(userId);
  }
}

bool checkAccessOnline(String userId) {
  HTTPClient http;
  
  // Prepare the URL
  String url = String(apiUrl);
  
  // Start the request
  http.begin(url);
  
  // Add headers
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-API-Key", apiKey);
  
  // Prepare the JSON payload
  StaticJsonDocument<200> doc;
  doc["userId"] = userId;
  doc["doorId"] = doorId;
  doc["deviceId"] = deviceId;
  doc["timestamp"] = millis();
  
  String requestBody;
  serializeJson(doc, requestBody);
  
  // Send the request
  int httpResponseCode = http.POST(requestBody);
  
  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.println("HTTP Response code: " + String(httpResponseCode));
    Serial.println("Response: " + response);
    
    // Parse the JSON response
    StaticJsonDocument<200> responseDoc;
    DeserializationError error = deserializeJson(responseDoc, response);
    
    if (!error) {
      bool hasAccess = responseDoc["hasAccess"];
      
      // If the user has access, cache it for offline use
      if (hasAccess) {
        unsigned long expiryTime = responseDoc["expiryTime"];
        cacheAccessRights(userId, expiryTime);
      }
      
      return hasAccess;
    } else {
      Serial.println("Failed to parse JSON response");
      return false;
    }
  } else {
    Serial.println("Error on HTTP request: " + String(httpResponseCode));
    return false;
  }
}

bool checkAccessOffline(String userId) {
  Serial.println("Checking access offline for user: " + userId);
  
  // Read cached users from EEPROM
  for (int i = 0; i < MAX_CACHED_USERS; i++) {
    int address = i * sizeof(CachedUser);
    CachedUser user;
    EEPROM.get(address, user);
    
    // Check if this entry is valid
    if (user.userId[0] != 0) {
      String cachedUserId = String(user.userId);
      
      // Check if this is the user we're looking for
      if (cachedUserId == userId) {
        // Check if the access is still valid
        unsigned long currentTime = millis();
        if (currentTime < user.expiryTime) {
          return true;
        } else {
          Serial.println("Access expired for user: " + userId);
          return false;
        }
      }
    }
  }
  
  // User not found in cache
  return false;
}

void cacheAccessRights(String userId, unsigned long expiryTime) {
  Serial.println("Caching access rights for user: " + userId);
  
  // Find an empty slot or the oldest entry
  int oldestIndex = 0;
  unsigned long oldestTime = ULONG_MAX;
  
  for (int i = 0; i < MAX_CACHED_USERS; i++) {
    int address = i * sizeof(CachedUser);
    CachedUser user;
    EEPROM.get(address, user);
    
    // If we find an empty slot, use it
    if (user.userId[0] == 0) {
      oldestIndex = i;
      break;
    }
    
    // Otherwise, track the oldest entry
    if (user.expiryTime < oldestTime) {
      oldestTime = user.expiryTime;
      oldestIndex = i;
    }
  }
  
  // Create the new cached user
  CachedUser newUser;
  userId.toCharArray(newUser.userId, sizeof(newUser.userId));
  newUser.expiryTime = expiryTime;
  
  // Save to EEPROM
  int address = oldestIndex * sizeof(CachedUser);
  EEPROM.put(address, newUser);
  EEPROM.commit();
  
  Serial.println("Cached user at index: " + String(oldestIndex));
}

void clearCachedUsers() {
  Serial.println("Clearing all cached users");
  
  for (int i = 0; i < MAX_CACHED_USERS; i++) {
    int address = i * sizeof(CachedUser);
    CachedUser emptyUser = {0};
    EEPROM.put(address, emptyUser);
  }
  
  EEPROM.commit();
}

void grantAccess() {
  // Update display
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("Access");
  display.println("Granted!");
  display.display();
  
  // Activate relay to unlock door
  digitalWrite(RELAY_PIN, HIGH);
  
  // Visual and audio feedback
  digitalWrite(LED_GREEN, HIGH);
  
  // Beep pattern for access granted
  for (int i = 0; i < 2; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
  }
  
  // Keep door unlocked for 5 seconds
  delay(5000);
  
  // Reset outputs
  digitalWrite(RELAY_PIN, LOW);
  digitalWrite(LED_GREEN, LOW);
}

void denyAccess() {
  // Update display
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("Access");
  display.println("Denied!");
  display.display();
  
  // Visual and audio feedback
  digitalWrite(LED_RED, HIGH);
  
  // Beep pattern for access denied
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(200);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
  }
  
  // Keep red LED on for 3 seconds
  delay(3000);
  
  // Reset outputs
  digitalWrite(LED_RED, LOW);
}

void logAccessAttempt(String userId, bool wasSuccessful) {
  // Only log if we have WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Cannot log access attempt: WiFi not connected");
    return;
  }
  
  HTTPClient http;
  
  // Prepare the URL for logging
  String url = String(apiUrl) + "/log";
  
  // Start the request
  http.begin(url);
  
  // Add headers
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-API-Key", apiKey);
  
  // Prepare the JSON payload
  StaticJsonDocument<200> doc;
  doc["userId"] = userId;
  doc["doorId"] = doorId;
  doc["deviceId"] = deviceId;
  doc["timestamp"] = millis();
  doc["wasSuccessful"] = wasSuccessful;
  
  String requestBody;
  serializeJson(doc, requestBody);
  
  // Send the request
  int httpResponseCode = http.POST(requestBody);
  
  if (httpResponseCode > 0) {
    Serial.println("Access log sent successfully");
  } else {
    Serial.println("Error sending access log: " + String(httpResponseCode));
  }
  
  http.end();
}
