#include "FirebaseESP8266.h" 
#include <ESP8266WiFi.h>

 
#define FIREBASE_HOST "gangnam-hydro-default-rtdb.firebaseio.com" 
#define FIREBASE_AUTH "UxLv4hOLUcaL6YNn72ySngjORQVZR6etmZynCLgT"
#define WIFI_SSID "juntae" // 연결 가능한 wifi의 ssid
#define WIFI_PASSWORD "93679626" // wifi 비밀번호
 

FirebaseData firebaseData;
FirebaseJson json;
const int sensorPin = D1;

int water_pin = A0;
int count = 0; 
String color;

void setup() // wifi 접속 과정.
{
  Serial.begin(9600);
 
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.println();
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED)
  {
    Serial.print(".");
    delay(500);
  }
  Serial.println();
  Serial.print("Connected with IP: ");
  Serial.println(WiFi.localIP());
  Serial.println();

  pinMode(water_pin, INPUT);
  pinMode(sensorPin, INPUT);
  
  Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
  Firebase.reconnectWiFi(true);
 
  firebaseData.setBSSLBufferSize(1024, 1024);
  firebaseData.setResponseSize(1024);
  Firebase.setReadTimeout(firebaseData, 1000 * 60);
  Firebase.setwriteSizeLimit(firebaseData, "tiny");
}

void loop()
{
  int waterLevel = analogRead(water_pin);
  int sensorValue = digitalRead(sensorPin);

  if(waterLevel > 400){
    count++;
  }

  float percentage = (count / 50.0) * 100;
  char percent[10];

  itoa(percentage, percent, 10);

  if (sensorValue == LOW){
    color = "red";
  } 
  else{
      if(waterLevel > 400){
        color = "blue";
      }
      else{
        color = "none";
      }
    }
  
/* if(Firebase.getInt(firebaseData, "Int Data Tag")){
  int valInt = firebaseData.intData();
  // write Code...
 }
 if(Firebase.getFloat(firebaseData, "Float Data Tag")){
  float valFloat = firebaseData.floatData();
  // write Code...
 }
 if(Firebase.getString(firebaseData, "String Data Tag")){
  String valStr = firebaseData.stringData();
  // write Code...
 }*/

 //Firebase.setBool(firebaseData, "BoolData", /*Bool Data*/);
 //Firebase.setInt(firebaseData, "Percentage", percentage);
 //Firebase.setFloat(firebaseData, "FloatData", /*Float Data*/);
 Firebase.setString(firebaseData, "Percentage", percent);
 Firebase.setString(firebaseData, "Color", color);
 delay(1000); // 1초마다 반복
}
