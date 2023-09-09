*-----------------------------------------------------------
* Title      :DVME CPU2 Application
* Written by :@kanpapa
* Date       :2023/08/26
* Description:Test Program 1 for DVME CPU2 board
*-----------------------------------------------------------

*--------------------------------------------------------------------
* DVME CPU2 Hardware
*
* CPU: HD68HC000P10 10MHz
* ROM: Intel D27512J-2 x 2	512Kbit x 2 (0F00000-0F1FFFF)
* RAM: Hitach HM62256LP-10	256Kbit x 4 (0000000-001FFFF)
* ACIA: HD63B50P x 2
* PIM: HD63B40P
*--------------------------------------------------------------------

*--------------------------------------------------------------------
* Memory Map
*
* 0000000   RAM 256kbit x 4 
* 000F000   STACK
* 001ffff
*
* 0F00000   ROM
* 0F01000  START ADDRESS
* 0F1FFFF
*
* fe8001   ACIA1 Control Register (Master Reset)
* fe8003   ACIA1 Data Register
* fe8005   ACIA2 Control Register
* fe8007   ACIA2 Data Register
* fe8011-f PIM
* fe8021   Module Control Register (MCR).
* fe8031   Module Status Register (MSR). Read only
* fe805b
* fe805d
*
* ff0000
*
*--------------------------------------------------------------------

* ACIA: HD63B50P x 2 
ACIA1_CREG  equ     $0fe8001        ; ACIA1 Control Register
ACIA1_DREG  equ     $0fe8003        ; ACIA1 Data Register
ACIA2_CREG  equ     $0fe8005        ; ACIA2 Control Register
ACIA2_DREG  equ     $0fe8007        ; ACIA2 Data Register
MCR			equ		$0fe8021		; Module Control Register (MCR).

; System stack
stack    equ    $00F000

; Reset Vector   
         org    $F00000

         dc.l   stack      ;system stack    00
         dc.l   start      ;initial pc
         dc.l   $00000000  ; bus error
         dc.l   $00000000  ; addr error

         dc.l    $00000000  ; bad opcode     10
         dc.l    $00000000  ; div by zero
         dc.l    $00000000   ; chk inst
         dc.l    $00000000   ; trapv inst

         dc.l    $00000000   ; privilegev    20
         dc.l    $00000000   ; trace
         dc.l    $00000000   ;
         dc.l    $00000000   ;

         dc.l    $00000000, $00000000, $00000000, $00000000   ; 30
         dc.l    $00000000, $00000000, $00000000, $00000000   ; 40
         dc.l    $00000000, $00000000, $00000000, $00000000   ; 50
         dc.l    $00000000, $00000000, $00000000, $00000000   ; 60
         dc.l    $00000000, $00000000, $00000000, $00000000   ; 70
         dc.l    $00000000, $00000000, $00000000, $00000000   ; 80
         dc.l    $00000000, $00000000, $00000000, $00000000   ; 90
         dc.l    $00000000, $00000000, $00000000, $00000000   ; A0

         dc.l    $00000000   ; 
         dc.l    $00000000   ;
         dc.l    $00000000   ;
         dc.l    $00000000   ; trap15

         dc.l    $00000000, $00000000, $00000000, $00000000   ; C0
         dc.l    $00000000, $00000000, $00000000, $00000000   ; D0
         dc.l    $00000000, $00000000, $00000000, $00000000   ; E0
         dc.l    $00000000, $00000000, $00000000, $00000000   ; F0
         
         DCB.B    $F00,0  
         

         org    $F01000

start:   move.w #$2700,SR   ; Supervisor mode, Interrupt Mask
         lea    stack,sp  ;Set Stackpointer
         
loop:    lea.l  message.l,a3
loop2:   move.b (a3)+,d0
         cmp.b  #0,d0
         beq    test1
         bra    loop2
         
test1:
         move.b #$5A,d0
         move.b d0,$00E0000
         
         nop
         nop
    
         bra loop

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
