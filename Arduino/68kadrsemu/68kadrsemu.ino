//
// Search Address bus for 68k
//
// 2023.08.19 @kanpapa
//

//                  // 68KCPU
unsigned AD16=2;    // A16
unsigned AD17=3;    // A17
unsigned AD18=4;    // A18
unsigned AD19=5;    // A19
unsigned AD20=6;    // A20
unsigned AD21=7;    // A21
unsigned AD22=8;    // A22
unsigned AD23=9;    // A23

unsigned AS=A0;     // AS
unsigned UDS=A1;    // UDS
unsigned LDS=A2;    // LDS

unsigned ADDR[]={AD16,AD17,AD18,AD19,AD20,AD21,AD22,AD23};

void SetAdrsBus(unsigned addr){
    // Reset Address strobe
    digitalWrite(AS, HIGH);
    digitalWrite(UDS, HIGH);
    digitalWrite(LDS, HIGH);

    delay(1); // 1ms

    // Set address bus
    if (addr & 0x80) digitalWrite(AD23, HIGH); else digitalWrite(AD23, LOW);
    if (addr & 0x40) digitalWrite(AD22, HIGH); else digitalWrite(AD22, LOW);
    if (addr & 0x20) digitalWrite(AD21, HIGH); else digitalWrite(AD21, LOW);
    if (addr & 0x10) digitalWrite(AD20, HIGH); else digitalWrite(AD20, LOW);
    if (addr & 0x08) digitalWrite(AD19, HIGH); else digitalWrite(AD19, LOW);
    if (addr & 0x04) digitalWrite(AD18, HIGH); else digitalWrite(AD18, LOW);
    if (addr & 0x02) digitalWrite(AD17, HIGH); else digitalWrite(AD17, LOW);
    if (addr & 0x01) digitalWrite(AD16, HIGH); else digitalWrite(AD16, LOW);

    delay(1); // 1ms
    
    // Set Address Strobe
    digitalWrite(AS, LOW);
    digitalWrite(UDS, LOW);
    digitalWrite(LDS, LOW);
 
    delay(1); // 1ms

    // Resety Address strobe
    digitalWrite(AS, HIGH);
    digitalWrite(UDS, HIGH);
    digitalWrite(LDS, HIGH);
}

void setup() {
  // Reset Address strobe
  digitalWrite(AS, HIGH); // Init AS
  digitalWrite(UDS, HIGH); // Init UDS
  digitalWrite(LDS, HIGH); // Init LDS
  for (int i=0; i<8; i++) digitalWrite(ADDR[i], LOW); // Address bus

  // set PINMMODE
  for (int i=0; i<8; i++) pinMode(ADDR[i], OUTPUT); // Address bus
  pinMode(AS, OUTPUT);
  pinMode(UDS, OUTPUT);
  pinMode(LDS, OUTPUT);
  
  delay(2);   // 2msec

  // Reset vector
  SetAdrsBus(0);  // SP
  SetAdrsBus(0);
  SetAdrsBus(0);  // PC
  SetAdrsBus(0);

  // Dummy
  SetAdrsBus(0);
  
  for (unsigned addr = 0x0; addr < 0x100 ; addr++){
    // display address
    //Serial.println(addr, HEX);
    SetAdrsBus(addr);    
  }
}

void loop() {
}