*-----------------------------------------------------------
* Title      :DVME CPU2 Application (no ram)
* Written by :@kanpapa
* Date       :2023/08/27
* Description:Test Program 1 for DVME CPU2 board
*-----------------------------------------------------------

*--------------------------------------------------------------------
* DVME CPU2 Hardware
*
* CPU: HD68HC000P10 10MHz
* ROM: Intel D27512J-2 x 2	512Kbit x 2 (0F00000-0F1FFFF)
* RAM: Hitach HM62256LP-10	256Kbit x 4 (??00000-??1FFFF)
* ACIA: HD63B50P x 2
* PIM: HD63B40P
*--------------------------------------------------------------------

*--------------------------------------------------------------------
* Memory Map
*
* ?00000   RAM 256kbit x 4 
* ?1FFFF
*
* 0F0000   STACK?, RAM END?
*
* F00000   ROM1
* F01000   START ADDRESS
* F1FFFF
*
* FE8001   ACIA1 Control Register (Master Reset)
* FE8003   ACIA1 Data Register
* FE8005   ACIA2 Control Register
* FE8007   ACIA2 Data Register
* FE8011-F PIM
* FE8021   Module Control Register (MCR).
* FE8031   Module Status Register (MSR). Read only
* FE805B
* FE805D
*
* FF0000
*
*--------------------------------------------------------------------

* ACIA: HD63B50P x 2 
ACIA1_CREG  equ     $0fe8001        ; ACIA1 Control Register
ACIA1_DREG  equ     $0fe8003        ; ACIA1 Data Register
ACIA2_CREG  equ     $0fe8005        ; ACIA2 Control Register
ACIA2_DREG  equ     $0fe8007        ; ACIA2 Data Register
MCR			equ		$0fe8021		; Module Control Register (MCR).

; System stack
stack    equ    $FF0000

; Reset Vector   
         org    $F00000

         dc.l   stack      ; system stack    00
         dc.l   start      ; initial pc
         dc.l   $00000000  ; bus error
         dc.l   $00000000  ; addr error

         dc.l   $00000000  ; bad opcode     10
         dc.l   $00000000  ; div by zero
         dc.l   $00000000  ; chk inst
         dc.l   $00000000  ; trapv inst

         dc.l   $00000000  ; privilegev    20
         dc.l   $00000000  ; trace
         dc.l   $00000000  ;
         dc.l   $00000000  ;

         dc.l   $00000000, $00000000, $00000000, $00000000   ; 30
         dc.l   $00000000, $00000000, $00000000, $00000000   ; 40
         dc.l   $00000000, $00000000, $00000000, $00000000   ; 50
         dc.l   $00000000, $00000000, $00000000, $00000000   ; 60
         dc.l   $00000000, $00000000, $00000000, $00000000   ; 70
         dc.l   $00000000, $00000000, $00000000, $00000000   ; 80
         dc.l   $00000000, $00000000, $00000000, $00000000   ; 90
         dc.l   $00000000, $00000000, $00000000, $00000000   ; A0

         dc.l   $00000000   ; 
         dc.l   $00000000   ;
         dc.l   $00000000   ;
         dc.l   $00000000   ; trap15

         dc.l   $00000000, $00000000, $00000000, $00000000   ; C0
         dc.l   $00000000, $00000000, $00000000, $00000000   ; D0
         dc.l   $00000000, $00000000, $00000000, $00000000   ; E0
         dc.l   $00000000, $00000000, $00000000, $00000000   ; F0

         DCB.B  $F00,0         

         org    $F01000

start:   move.w #$2700,SR   ; Supervisor mode, Interrupt Mask
         lea stack,sp            ;Set Stackpointer
         
         ;; FAIL LED OFF
         movea.l #MCR,A0      ; MODULE CONTROL REGISTER
         move.b #$00,(A0)

         ;; SETUP ACIA1,2
         move.b #$03,ACIA1_CREG ; setup ports (Master Reset)
         move.b #$03,ACIA2_CREG ; setup ports (Master Reset)
         move.b #$15,ACIA1_CREG ; 8Bits + 1Stop Bits, div 16
         move.b #$15,ACIA2_CREG ; 8Bits + 1Stop Bits, div 16

loop:    lea.l  message.l,a3

wstr:    move.b (a3)+,d0
         cmp.b  #0,d0
         beq    loop

writ:    btst   #1,ACIA1_CREG  ;sample control register till done
         beq    writ
         move.b d0,ACIA1_DREG    ;write the character to port
         bra    wstr

;
; Messages data
;
cr       equ    $0d        ;ASCII code for Carriage Return
lf       equ    $0a        ;ASCII code for Line Feed
message  dc.b   'HELLO WORLD',cr,lf,0

         end    start

* Put program code here

    SIMHALT             ; halt simulator

* Put variables and constants here

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
