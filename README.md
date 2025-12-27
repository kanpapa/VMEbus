# VMEbus

This repository contains documentation and sources for running digital's 68000 VME board DVME CPU2. 

![DVME CPU2](/images/DVME_CPU2_board1.jpg)

Please refer to my blog for more information.  
https://kanpapa.com/2023/08/68000-vme-board1.html

* DVMECPU2
  * Memory map
  * Parts list

* Hardware test
  * This program sends a Hello world string to the serial port.

* VME_power
  * Kicad data for the printed circuit board to supply power to the VME board.

* mbed
  * CPU simulator for investigating address decoders using mbed LPC1768.

* zBug
  * zbug monitor source program and ROM image data.

* EhBASIC for DVMECPU2
  * Modified [EhBASIC](https://philpem.me.uk/leeedavison/68k/simbasic/index.html) source code for DVMECPU2.
  * Free for personal use only (see readme.txt).

* images
  * Photos data

## Photos

![DVME CPU2](/images/DVME_CPU2_board_front1.jpg)

![VME Power board1](/images/vme_board_3_power_pcb_product2.jpg)

![VME Power board2](/images/vme_board_3_power_pcb_product3.jpg)

## Caution
The contents of this repository are the result of personal research and are non-guaranteed.
