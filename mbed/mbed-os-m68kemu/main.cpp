//
// Generate address signals for 68k cpu in mbed.
// 2023.9.3 @kanpapa
//
#include "mbed.h"

// Blinking rate in milliseconds
#define BLINKING_RATE     500ms

// Initialise the digital pin LED1 as an output
DigitalOut led1(LED1);

// How to connect mbed to 68kcpu socket
//
// mbed            68k CPU Socket
// p20  ---------- 6  AS*    
// p19  ---------- 7  UDS*
// p18  ---------- 8  LDS*
// p17  ---------- 9  R/W*
// p29  ---------- 43 A15
// p28  ---------- 44 A16
// p27  ---------- 45 A17
// p26  ---------- 46 A18
// p25  ---------- 47 A19
// p24  ---------- 48 A20
// p23  ---------- 50 A21
// p22  ---------- 51 A22
// p21  ---------- 52 A23
// GND  ---------- 16 Vss  
//         GND --- 28 FC0

DigitalOut as(p20);     // AS*
DigitalOut uds(p19);    // UDS*
DigitalOut lds(p18);    // LDS*
DigitalOut rw(p17);     // R/W*
BusOut adrsbus(p29,p28,p27,p26,p25,p24,p23,p22,p21); // A15-A23

void SetAdrsBus(unsigned addr){
    // 1)SET R/W TO READ
    // 2)PLASE FUNCTIUON CODE ON FC2-FC0

    // 3)PLACE ADDRESS ON A23-A15
    adrsbus = addr;
    ThisThread::sleep_for(1ms); //Address Valid to AS, DS Asserted (Read) 10ns
    
    // 4)ASSERT ADDRESS STROBE
    as = 0;

    // 5)ASSERT UPPER DATA STROBE AND LOWER DATA STROBE
    //uds = 0;
    //lds = 0;
    //rw = 1;

    ThisThread::sleep_for(1ms); // ASand DS Read) Width Asserted 195ns
    // 1)DECODE ADDRESS
    // 2)PLASE DATA ON D15-D0
    // 3)ASSERT DATA TRANSFER ACKNOWLEDGE (DTACK)

    // 1)LATCH DATA
    // 2)NEGATE UDS AND LDS
    //uds = 1;
    //lds = 1;
    //rw = 1;

    // 3)NEGATE AS
    as = 1;    

    ThisThread::sleep_for(1ms);
}

int main()
{
    // Setup signals
    as = 1;     // NEGATE AS
    uds = 0;    // ASSERT UDS
    lds = 0;    // ASSERT LDS
    rw = 1;     // ASSERT READ
    adrsbus = 0; // PLASE ADDRESS OFF A23-A15

    // reset vector
    SetAdrsBus(0);      // Cycle 1
    SetAdrsBus(0);      // Cycle 2
    SetAdrsBus(0);      // Cycle 3
    SetAdrsBus(0);      // Cycle 4

    // Dummy access 
    SetAdrsBus(0);
    SetAdrsBus(0);
    
    // Increment address signal
    for (unsigned addr = 0x00; addr < 0x200 ; addr++){
        SetAdrsBus(addr); 
    }

    // Indicates end of process
    while (true) {
        ThisThread::sleep_for(BLINKING_RATE);
        led1 = !led1;
    }
}
