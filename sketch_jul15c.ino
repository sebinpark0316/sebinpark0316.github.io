int potentiometer_Read(int pin)
{
    return analogRead(pin);
}

void motor_forward(int IN1, int IN2, int speed)
{
    analogWrite(IN1, speed);
    analogWrite(IN2, LOW);
}

void motor_backward(int IN1, int IN2, int speed)
{
    analogWrite(IN1, LOW);
    analogWrite(IN2, speed);
}

void motor_hold(int IN1, int IN2)
{
    analogWrite(IN1, LOW);
    analogWrite(IN2, LOW);
}

// For steering handling
const int PotentiOhm = A5;
const int SMotor_In1 = 8;
const int SMotor_In2 = 9;
#define HANDLE_SPEED 150
// For driving
const int LMotor_In1 = 13;
const int LMotor_In2 = 12;
const int RMotor_In1 = 10;
const int RMotor_In2 = 11;

int Front(int Motor_speed) {
    motor_forward(LMotor_In1, LMotor_In2, Motor_speed);
    motor_forward(RMotor_In1, RMotor_In2, Motor_speed);
    return 0;
}

int Handling(int degree) {
    int val = potentiometer_Read(PotentiOhm);

    // 951 => Right
    // 987 => center
    // 1023 => Left
    if (degree <= 1023 && degree >= 1018) {
        motor_backward(SMotor_In1, SMotor_In2, 100);
        delay(150);
    } else if (degree >= 930 && degree <= 935) {
        motor_forward(SMotor_In1, SMotor_In2, 100);
        delay(150);
    } else if (val - degree > 0) {
        motor_forward(SMotor_In1, SMotor_In2, HANDLE_SPEED);
        while (true) {
            val = potentiometer_Read(PotentiOhm);
            if (val <= degree || val <= 930) { // Check if the handle is too far to the left
                break;
            }
        }
    } else {
        motor_backward(SMotor_In1, SMotor_In2, HANDLE_SPEED);
        while (true) {
            val = potentiometer_Read(PotentiOhm);
            if (val >= degree || val >= 1023) { // Check if the handle is too far to the right
                break;
            }
        }
    }

    motor_hold(SMotor_In1, SMotor_In2);

    return 0;
}
int arg;
String py_arg;
int py_arg_int;

void setup() {
  // put your setup code here, to run once:
    Serial.begin(9600);
    pinMode(SMotor_In1, OUTPUT);
    pinMode(SMotor_In2, OUTPUT);
    pinMode(LMotor_In1, OUTPUT);
    pinMode(LMotor_In2, OUTPUT);
    pinMode(RMotor_In1, OUTPUT);
    pinMode(RMotor_In2, OUTPUT);
    Front(150);
    Handling(976.5);
}

void loop() {
  // put your main code here, to run repeatedly:
    if (Serial.available()) {
        py_arg = Serial.readStringUntil('\n');
        py_arg_int = py_arg.toInt();
        Handling(py_arg_int);
        delay(100);
    }
}
