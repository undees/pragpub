#define NUM_MOODS 5
#define NEUTRAL ((NUM_MOODS - 1) / 2)

#define UP    '+'
#define DOWN  '-'
#define RESET '!'
#define QUERY '?'
#define NONE  -1

int upPin              = 2;
int downPin            = 3;
int ledPins[NUM_MOODS] = {6, 7, 8, 9, 10};
int heartbeatPin       = 13;

int mood = NEUTRAL;

void setup() {
     int i;
     for (i = 0; i < NUM_MOODS; ++i) {
          pinMode(ledPins[i], OUTPUT);
     }

     pinMode(upPin,   INPUT);
     pinMode(downPin, INPUT);

     Serial.begin(9600);

     setMood(NEUTRAL);
}

void loop() {
     int button = buttonPressed();
     int serial = commandReceived();
     int event = (button != NONE ? button : serial);

     switch (event) {
     case UP:
          setMood(mood + 1);
          break;
     case DOWN:
          setMood(mood - 1);
          break;
     case RESET:
          setMood(NEUTRAL);
          break;
     case QUERY:
          replyWithMood();
          break;
     default:
          setMood(event - '0');
          break;
     }

     flashHeartbeat();
}

int buttonPressed() {
     if (LOW == digitalRead(upPin)) {
          return UP;
     }

     if (LOW == digitalRead(downPin)) {
          return DOWN;
     }

     return NONE;
}

int commandReceived() {
     if (Serial.available() > 0) {
          return Serial.read();
     }

     return NONE;
}

void replyWithMood() {
     Serial.print('0' + mood, BYTE);
}

void setMood(int newMood) {
     if (newMood < 0 || newMood >= NUM_MOODS) {
          return;
     }

     digitalWrite(ledPins[mood], LOW);
     mood = newMood;
     digitalWrite(ledPins[mood], HIGH);
}

void flashHeartbeat() {
     digitalWrite(heartbeatPin, HIGH);
     delay(50);
     digitalWrite(heartbeatPin, LOW);
     delay(50);
}
