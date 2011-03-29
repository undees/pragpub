/* START:defs */
#include <Bounce.h>

#define NUM_MOODS 5
#define NEUTRAL ((NUM_MOODS - 1) / 2)

#define UP    '+'
#define DOWN  '-'
#define QUERY '?'
#define NONE  -1

int ledPins[NUM_MOODS] = {6, 7, 8, 9, 10};
int heartbeatPin       = 13;
int upPin              = 2;
int downPin            = 3;

Bounce upButton  (upPin,   100);
Bounce downButton(downPin, 100);

int mood = NEUTRAL;
/* END:defs */

/* START:setup */
void setup() {
    for (int i = 0; i < NUM_MOODS; ++i) {
        pinMode(ledPins[i], OUTPUT);
    }

    pinMode(upPin,   INPUT);
    pinMode(downPin, INPUT);

    Serial.begin(9600);

    setMood(NEUTRAL);
}
/* END:setup */

/* START:loop */
void loop() {
    upButton.update();
    downButton.update();

    int button = (upButton.fallingEdge() ? UP :
                  (downButton.fallingEdge() ? DOWN : NONE));

    int serial = (Serial.available() > 0 ? Serial.read() : NONE);

    int event  = (button != NONE ? button : serial);

    switch (event) {
    case UP:
        setMood(mood + 1);
        break;
    case DOWN:
        setMood(mood - 1);
        break;
    case QUERY:
        Serial.print('0' + mood, BYTE);
        break;
    default:
        setMood(event - '0');
        break;
    }

    digitalWrite(heartbeatPin, HIGH);
    delay(50);
    digitalWrite(heartbeatPin, LOW);
    delay(50);
}
/* END:loop */

/* START:mood */
void setMood(int newMood) {
     if (newMood < 0 || newMood >= NUM_MOODS) {
          return;
     }

     digitalWrite(ledPins[mood], LOW);
     mood = newMood;
     digitalWrite(ledPins[mood], HIGH);
}
/* END:mood */
