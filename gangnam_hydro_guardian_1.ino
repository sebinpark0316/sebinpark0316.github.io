#define LED_R 50       // R의 핀 번호 5
#define LED_G 48       // G의 핀 번호 4
#define LED_B 46       // B의 핀 번호 3

int water_pin = A0;    // 수분수위센서 A0에 연결
int magneticPin = 36;  // 자기장 센서 디지털 인터페이스
int magneticAnalogPin = A1; // 자기장 센서 아날로그 인터페이스
int magneticValDigital; // 디지털 읽기 값
int magneticValAnalog; // 아날로그 읽기 값

void setup() {
  Serial.begin(9600);   // Serial monitor 구동 전원입력

  pinMode(magneticPin, INPUT); // 자기장 센서 디지털 인터페이스 설정
  pinMode(magneticAnalogPin, INPUT); // 자기장 센서 아날로그 인터페이스 설정
  pinMode(water_pin, INPUT); // 수분수위센서 A0핀을 입력으로 설정

  pinMode(LED_R, OUTPUT);
  pinMode(LED_G, OUTPUT);
  pinMode(LED_B, OUTPUT);
}

void loop() {
  // 자기장 센서 값 읽기
  magneticValDigital = digitalRead(magneticPin); 
  magneticValAnalog = analogRead(magneticAnalogPin);

  // 수위 센서 값 읽기
  int waterLevel = analogRead(water_pin); 

  // 센서 값 출력
  Serial.print("Magnetic Digital: ");
  Serial.print(magneticValDigital);
  Serial.print("\tWater Level: ");
  Serial.println(waterLevel);
  
  delay(100);  // 입력값을 보여주는데 0.1초 설정
  
  if (magneticValDigital == LOW) { // 자기장이 감지되지 않으면 (맨홀 뚜껑이 없음)
    digitalWrite(LED_R, HIGH); // 빨간 LED ON
    digitalWrite(LED_G, LOW);
    digitalWrite(LED_B, LOW);
  } else { // 자기장이 감지되면 (맨홀 뚜껑이 있음)
    if (waterLevel > 400) { // 수위가 일정 이상이면
      digitalWrite(LED_B, HIGH); // 파란 LED ON
      digitalWrite(LED_R, LOW);
      digitalWrite(LED_G, LOW);
    } else {
      turnOffAll(); // 모든 LED OFF
    }
  }

  delay(100);
}

void turnOffAll() { // turnOffAll 함수 정의
  digitalWrite(LED_B, LOW);  // 파란 불 끄기
  digitalWrite(LED_G, LOW);  // 초록 불 끄기
  digitalWrite(LED_R, LOW);  // 빨간 불 끄기
}
