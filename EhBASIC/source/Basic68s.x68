*************************************************************
*										*
*	Enhanced BASIC for the EASy68k editor/simulator		*
*										*
*	Derived from EhBASIC for the 6502 and adapted by:	*
*	Lee Davison								*
*										*
*	mail : leeedavison@lycos.co.uk				*
*										*
*	This version for the EASy68k editor/simulator.		*
*	Includes new simulator graphics commands			*
*										*
*************************************************************
*	Copyright (C) 2002/3 by Lee Davison. This program	*
*	may be freely distributed for personal use only.	*
*	All commercial rights are reserved.				*
*************************************************************
*										*
*	The choice of memory areas in this code is set to	*
*	reflect the actual memory present on a 68008 SBC	*
*	that I have.							*
*										*
*	Memory map:								*
*										*
*	ROM	$000000 - $00FFFF						*
*	RAM	$040000 - $048000 ($050000 optional)		*
*										*
*************************************************************

* Ver 1.10
* EASy68k extensions Ver 1.01

	OPT	CRE
	ORG	$000400			* past the vectors in a real system


* the following code is simulator specific, change to suit your system

ACIAC    EQU $FE8001
ACIAD    EQU ACIAC+2
RDRF    EQU 0           ; ACIAC Receive Data Register Full
TDRE    EQU 1           ; ACIAC Transmit Data Register Empty


* output character to the console from register d0

VEC_OUT
	MOVEM.l	d0,-(sp)		* save d0, d1
*	MOVE.b	d0,d1			* copy character
*	MOVEQ		#6,d0			* character out
*	TRAP		#15			* do i/o function
COUT
    BTST.B #TDRE,ACIAC.L
    BEQ.S  COUT
	MOVE.B D0,ACIAD.L
    MOVEM.l	(sp)+,d0		* restore d0, d1
	RTS

* input a character from the console into register d0
* else return Cb=0 if there's no character available

VEC_IN
	MOVE.l	d1,-(sp)		* save d1
*	MOVEQ		#7,d0			* get status
*	TRAP		#15			* do i/o function
*	MOVE.b	d1,d0			* copy status
    BTST.B  #RDRF,ACIAC.L
	BNE.s		RETCHR		* branch if character waiting
	MOVE.l	(sp)+,d1		* restore d1
	ORI.b		#$00,d0		* set z flag
*	ANDI.b	#$FE,CCR		* clear carry, flag we not got byte (done by ORI.b)
	RTS

RETCHR
*	MOVEQ		#5,d0			* get byte
*	TRAP		#15			* do i/o function
*	MOVE.b	d1,d0			* copy byte
    MOVE.B  ACIAD.L,D0
	MOVE.l	(sp)+,d1		* restore d1
	ORI.b		#$00,d0		* set z flag on received byte
	ORI.b		#1,CCR		* set carry, flag we got a byte
	RTS

* LOAD routine for the Easy68k simulator

VEC_LD
	RTS                     * Dummy by kanpapa
    SUBQ.w	#1,a5			* decrement execute pointer
	BSR		LAB_GVAL		* get value from line

	BSR		LAB_EVST		* evaluate string, returns d0 = length, a0 = pointer
	BEQ		LAB_FCER		* if null do function call error, then warm start

	MOVEA.l	a0,a1			* copy filename pointer
	ADDA.w	d0,a0			* add length to find end of string
	MOVE.b	(a0),-(sp)		* save byte
	MOVE.l	a0,-(sp)		* save address
	MOVEQ		#0,d0			* set for null
	MOVE.b	d0,(a0)		* null terminate string
	MOVE		#51,d0		* open existing file
	TRAP		#15
	TST.w		d0			* test load result
	BNE		LOAD_exit		* if error clear up and exit

	MOVE.l	d1,file_id		* save file ID
	MOVEA.l	#file_byte,a1	* point to byte buffer
	MOVEQ		#1,d2			* set byte count
	MOVEQ		#53,d0		* read first byte from file
	TRAP		#15

	TST.w		d0			* test status
	BNE		LOAD_close		* if error close files & exit

	MOVEQ		#0,d2			* file position
	MOVEQ		#55,d0		* reset file position
	TRAP		#15

	MOVE.b	(a1),d0		* get first file byte
	BNE		LOAD_ascii		* if first byte not $00 go do ASCII load

						* do binary load
	MOVEA.l	Smeml,a1		* get start of program memory
	MOVE.w	#$7FFF,d2		* set to $7FFF (max read length)
	MOVEQ		#53,d0		* read from file
	TRAP		#15

	ADD.l		a1,d2			* add start of memory to loaded program length
	MOVE.l	d2,Sfncl		* save end of program

LOAD_close
	MOVEQ		#50,d0		* close all files
	TRAP		#15

LOAD_exit
	MOVEA.l	(sp)+,a0		* get string end back
	MOVE.b	(sp)+,(a0)		* put byte back
	BSR		LAB_147A		* go do "CLEAR"
	BRA		LAB_1274		* BASIC warm start entry, go wait for Basic command

* is ASCII file so just change the input vector

LOAD_ascii
	LEA		(LOAD_in,PC),a1	* get byte from file vector
	MOVE.l	a1,V_INPTv		* set input vector
	MOVEA.l	(sp)+,a0		* get string end back
	MOVE.b	(sp)+,(a0)		* put byte back
	BRA		LAB_127D		* now we just wait for Basic command (no "Ready")

* input character to register d0 from file

LOAD_in
	MOVEM.l	d1-d2/a1,-(sp)	* save d1, d2 & a1
	MOVE.l	file_id,d1		* get file ID back
	MOVEA.l	#file_byte,a1	* point to byte buffer
	MOVEQ		#1,d2			* set count for one byte
	MOVEQ		#53,d0		* read from file
	TRAP		#15

	TST.w		d0			* test status
	BNE		LOAD_eof		* branch if byte read failed

	MOVE.b	(a1),d0		* get byte
	MOVEM.l	(sp)+,d1-d2/a1	* restore d1, d2 & a1
	ORI.b		#1,CCR		* set carry, flag we got a byte
	RTS
						* got an error on read so restore vector and tidy up
LOAD_eof
	MOVEQ		#50,d0		* close all files
	TRAP		#15

	LEA		(VEC_IN,PC),a1	* get byte from input device vector
	MOVE.l	a1,V_INPTv		* set input vector
	MOVEQ		#0,d0			* clear byte
	MOVEM.l	(sp)+,d1-d2/a1	* restore d1, d2 & a1
	BSR		LAB_147A		* do CLEAR (erase variables/functions & flush stacks)
	BRA		LAB_1274		* BASIC warm start entry, go wait for Basic command

* SAVE routine for the Easy68k simulator

VEC_SV
    RTS                     * dummy by kanpapa
	SUBQ.w	#1,a5			* decrement execute pointer
	BSR		LAB_GVAL		* get value from line
	BSR		LAB_CTST		* check if source is string, else do type mismatch

	BSR		LAB_GBYT		* get next BASIC byte
	BEQ		SAVE_bas		* branch if no following

	CMP.b		#',',d0		* compare with ","
	BNE		LAB_SNER		* not "," so go do syntax error/warm start

	BSR		LAB_IGBY		* increment & scan memory
	ORI.b		#$20,d0		* ensure lower case
	CMP.b		#'a',d0		* compare with "a"
	BNE		LAB_SNER		* not "a" so go do syntax error/warm start

	BSR		LAB_EVST		* evaluate string, returns d0 = length, a0 = pointer
	BEQ		LAB_FCER		* if null do function call error, then warm start

	MOVEA.l	a0,a1			* copy filename pointer
	ADDA.w	d0,a0			* add length to find end of string
	MOVE.b	(a0),-(sp)		* save byte
	MOVE.l	a0,-(sp)		* save address
	MOVEQ		#0,d0			* set for null
	MOVE.b	d0,(a0)		* null terminate string
	MOVE		#52,d0		* open new file
	TRAP		#15
	TST.w		d0			* test save result
	BNE		SAVE_exit		* if error clear up and exit

	MOVE.l	d1,file_id		* save file ID

	MOVE.l	V_OUTPv,-(sp)	* save the output vector
	LEA		(SAVE_OUT,PC),a1	* send byte to file vector
	MOVE.l	a1,V_OUTPv		* change output vector

	BSR		LAB_IGBY		* increment & scan memory
	BSR		LAB_LIST		* go do list (line numbers applicable)

	MOVE.l	(sp)+,V_OUTPv	* restore the output vector
	BRA		SAVE_close

SAVE_bas
	BSR		LAB_EVST		* evaluate string, returns d0 = length, a0 = pointer
	BEQ		LAB_FCER		* if null do function call error, then warm start

	MOVEA.l	a0,a1			* copy filename pointer
	ADDA.w	d0,a0			* add length to find end of string
	MOVE.b	(a0),-(sp)		* save byte
	MOVE.l	a0,-(sp)		* save address
	MOVEQ		#0,d0			* set for null
	MOVE.b	d0,(a0)		* null terminate string
	MOVE		#52,d0		* open new file
	TRAP		#15
	TST.w		d0			* test save result
	BNE		SAVE_exit		* if error clear up and exit

	MOVEA.l	Smeml,a1		* get start of program
	MOVE.l	Sfncl,d2		* get end of program
	SUB.l		a1,d2			* subtract start of program (= length)

	MOVEQ		#54,d0		* write to file
	TRAP		#15

SAVE_close
	MOVEQ		#50,d0		* close all files
	TRAP		#15

SAVE_exit
	MOVEA.l	(sp)+,a0		* get string end back
	MOVE.b	(sp)+,(a0)		* put byte back
	TST.w		d0			* test save result
	BNE		LAB_FCER		* if error do function call error, then warm start

	RTS

* output character to file from register d0

SAVE_OUT
	MOVEM.l	d0-d2/a1,-(sp)	* save d0, d1, d2 & a1
	MOVE.l	file_id,d1		* get file ID back
	MOVEA.l	#file_byte,a1	* point to byte buffer
	MOVE.b	d0,(a1)		* save byte
	MOVEQ		#1,d2			* set byte count
	MOVEQ		#54,d0		* write to file
	TRAP		#15
	MOVEM.l	(sp)+,d0-d2/a1	* restore d0, d1, d2 & a1
	RTS

****************************************************************************************
****************************************************************************************
****************************************************************************************
****************************************************************************************
*
* Register use :- (must improve this !!)
*
*	a6 -	temp Bpntr			* temporary BASIC execute pointer
*	a5 -	Bpntr				* BASIC execute (get byte) pointer
*	a4 -	des_sk			* descriptor stack pointer
*	a3 -	
*	a2 -	
*	a1 -	
*	a0 -	
*
*	d7 -	FAC1 mantissa		* to do
*	d6 -	FAC1 sign & exponent	* to do
*	d5 -	FAC2 mantissa		* to do
*	d4 -	FAC2 sign & exponent	* to do
*	d3 -	BASIC got byte		* to do
*	d2 -	
*	d1 -	general purpose
*	d0 -	general purpose
*
*

* turn off simulator key echo

code_start
	MOVEQ		#12,d0		* keyboard echo
	MOVEQ		#0,d1			* turn off echo
	TRAP		#15			* do i/o function

* end of simulator specific code

* BASIC cold start entry point

LAB_COLD
	MOVE.l	#ram_base,sp	* set simulator stack for this prog
	MOVE.w	#$4EF9,d0		* JMP opcode
	MOVEA.l	sp,a0			* point to start of vector table

	MOVE.w	d0,(a0)+		* LAB_WARM
	LEA		(LAB_COLD,PC),a1	* initial warm start vector
	MOVE.l	a1,(a0)+		* set vector

	MOVE.w	d0,(a0)+		* Usrjmp
	LEA		(LAB_FCER,PC),a1	* initial user function vector
						* "Function call" error
	MOVE.l	a1,(a0)+		* set vector

	MOVE.w	d0,(a0)+		* V_INPT JMP opcode
	LEA		(VEC_IN,PC),a1	* get byte from input device vector
	MOVE.l	a1,(a0)+		* set vector

	MOVE.w	d0,(a0)+		* V_OUTP JMP opcode
	LEA		(VEC_OUT,PC),a1	* send byte to output device vector
	MOVE.l	a1,(a0)+		* set vector

	MOVE.w	d0,(a0)+		* V_LOAD JMP opcode
	LEA		(VEC_LD,PC),a1	* load BASIC program vector
	MOVE.l	a1,(a0)+		* set vector

	MOVE.w	d0,(a0)+		* V_SAVE JMP opcode
	LEA		(VEC_SV,PC),a1	* save BASIC program vector
	MOVE.l	a1,(a0)+		* set vector

	MOVE.w	d0,(a0)+		* V_CTLC JMP opcode
	LEA		(VEC_CC,PC),a1	* save CTRL-C check vector
	MOVE.l	a1,(a0)+		* set vector

	MOVE.l	sp,(a0)		* save entry stack value

* set-up start values

LAB_GMEM
	MOVEQ		#$00,d0		* clear d0
	MOVE.b	d0,Nullct		* default NULL count
	MOVE.b	d0,TPos		* clear terminal position
	MOVE.b	d0,ccflag		* allow CTRL-C check
	MOVE.w	d0,prg_strt-2	* clear start word
	MOVE.w	d0,BHsend		* clear value to string end word

	MOVE.b	#$50,TWidth		* default terminal width byte for simulator
*	MOVE.b	d0,TWidth		* default terminal width byte

	MOVE.b	#$0E,TabSiz		* save default tab size = 14

	MOVE.b	#$38,Iclim		* default limit for TAB = 14 for simulator
*	MOVE.b	#$F2,Iclim		* default limit for TAB = 14

	MOVEA.l	#des_sk,a4		* set descriptor stack start

	BSR		LAB_CRLF		* print CR/LF
	LEA		(LAB_MSZM,PC),a0	* point to memory size message
	BSR		LAB_18C3		* print null terminated string from memory
	BSR		LAB_INLN		* print "? " and get BASIC input
						* return a0 pointing to the buffer start
	MOVEA.l	a0,a5			* set BASIC execute pointer to buffer
	BSR		LAB_GBYT		* scan memory
	BNE.s		LAB_2DAA		* branch if not null (user typed something)

						* character was null so get memory size the hard way

	MOVEA.l	#prg_strt,a0	* get start of program RAM
	MOVE.l	#ram_top,d2		* remember top of ram+1
	MOVE.w	#$5555,d0		* test pattern 1
	MOVE.w	#$AAAA,d1		* test pattern 2

LAB_2D93
	CMPA.l	d2,a0			* compare with top of RAM+1
	BEQ.s		LAB_2DB6		* branch if match (end of user RAM)

	MOVE.w	d0,(a0)		* set test word
	CMP.w		(a0),d0		* compare it
	BNE.s		LAB_2DB6		* branch if fail

	MOVE.w	d1,(a0)		* set new test word
	CMP.w		(a0)+,d1		* compare it
	BEQ.s		LAB_2D93		* if ok go do next word

	SUBQ.w	#2,a0			* decrement pointer
	BRA.s		LAB_2DB6		* and branch if fail

LAB_2DAA
	BSR		LAB_2887		* get FAC1 from string
	MOVE.b	FAC1_e,d1		* get FAC1 exponent
	CMP.b		#$81,d1		* compare with min
	BCS		LAB_GMEM		* if <1 go get again

	CMP.b		#$A0,d1		* compare maximum integer range exponent
	BNE.s		LAB_2DAB		* if not $A0 go test is less

	TST.b		FAC1_s		* test FAC1 sign
	BPL.s		LAB_2DAD		* branch if FAC1 +ve

						* FAC1 was -ve and exponent is $A0
	CMPI.l	#$80000000,FAC1_m	* compare with max -ve
	BEQ.s		LAB_2DAD		* branch if max -ve

LAB_2DAB
	BCC		LAB_GMEM		* get again if too big

LAB_2DAD
	BSR		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	MOVEA.l	d0,a0			* copy result to address reg

LAB_2DB6
	CMPA.l	#(prg_strt+$100),a0	* compare with start of RAM+$100
	BCS		LAB_GMEM		* if too small go try again

* uncomment these lines if you want to check on the high limit of memory. Note if
* Ram_top is set too low then this will fail. default is ignore it and assume the
* users know what they're doing!
*	
*	CMPA.l	#Ram_top,a0		* compare with end of RAM+1
*	BHI.s		LAB_GMEM		* if too large go try again

	MOVE.l	a0,Ememl		* set end of mem
	MOVE.l	a0,Sstorl		* set bottom of string space

	MOVEQ		#0,d0			* longword clear
	MOVEA.l	#prg_strt,a0	* get start of mem
	MOVE.l	d0,(a0)		* clear first longword
	MOVE.l	a0,Smeml		* save start of mem

	BSR		LAB_1463		* do "NEW" and "CLEAR"
	BSR		LAB_CRLF		* print CR/LF
	MOVE.l	Ememl,d0		* get end of mem
	SUB.l		Smeml,d0		* subtract start of mem

	BSR		LAB_295E		* print d0 as unsigned integer (bytes free)
	LEA		(LAB_SMSG,PC),a0	* point to start message
	BSR		LAB_18C3		* print null terminated string from memory

	MOVEA.l	#LAB_RSED,a0	* point to value
	BSR		LAB_UFAC		* unpack memory (a0) into FAC1

	MOVE.l	#LAB_1274,Wrmjpv	* warm start vector
	BSR		LAB_RND		* initialise
	JMP		LAB_WARM		* go do warm start

* search the stack for FOR, GOSUB or DO activity
* exit with z=1 if FOR, else exit with z=0
* return modified stack in a2

LAB_11A1
	MOVEA.l	sp,a2			* copy stack pointer
	ADDQ.w	#8,a2			* back past two levels of return address
LAB_11A6
	MOVE.w	(a2),d0		* get token
	CMP.w		#TK_FOR,d0		* is FOR token on stack?
	BNE.s		RTS_002		* exit if not

						* was FOR token
	MOVEA.l	2(a2),a0		* get stacked FOR variable pointer
	MOVEA.l	Frnxtl,a1		* get variable pointer for FOR/NEXT
	CMPA.l	#0,a1			* set the flags
	BNE.s		LAB_11BB		* branch if not null

	MOVE.l	a0,Frnxtl		* save var pointer for FOR/NEXT
	CMP.w		d0,d0			* set z for ok exit
RTS_002
	RTS

LAB_11BB
	CMPA.l	a1,a0			* compare var pointer with stacked var pointer
	BEQ.s		RTS_003		* exit if match found

	ADDA.w	#$1A,a2		* add FOR stack use size
	CMPA.l	ram_base,a2		* compare with stack top
	BCS.s		LAB_11A6		* loop if not at start of stack

RTS_003
	RTS

* check room on stack for d0 bytes

*LAB_1212
*	ADD.l		#ram_strt,d0	* add start of ram to value to check
*	CMP.l		sp,d0			* compare new "limit" with stack pointer
*	BCC.s		LAB_OMER		* if sp<limit do "Out of memory" error/warm start

*	RTS

* check available memory, "Out of memory" error if no room
* addr to check is in a0

LAB_121F
	CMPA.l	Sstorl,a0		* compare with bottom of string memory
	BCS.s		RTS_004		* if less then exit (is ok)

	BSR		LAB_GARB		* garbage collection routine
	CMPA.l	Sstorl,a0		* compare with bottom of string memory
	BLS.s		LAB_OMER		* if Sstorl <= a0 do "Out of memory" error/warm start

RTS_004					* ok exit, carry set
	RTS

** do internal error
*
*LAB_ITER
*	MOVEQ		#$58,d0		* error code $58 "Internal" error
*	BRA.s		LAB_XERR		* do error #d0, then warm start

* do address error

LAB_ADER
	MOVEQ		#$54,d0		* error code $54 "Address" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do wrong dimensions error

LAB_WDER
	MOVEQ		#$50,d0		* error code $50 "Wrong dimensions" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do undimensioned array error

LAB_UDER
	MOVEQ		#$4C,d0		* error code $4C "undimensioned array" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do undefined variable error

LAB_UVER
	MOVEQ		#$48,d0		* error code $24*2 "undefined variable" error
	BRA.s		LAB_XERR		* do error #X then warm start

* if you want undefined variables to return 0 (or "") then comment out the above
* two lines and uncomment these two
*
* value returned by this is either numeric zero (exponent byte is $00) or null string
* (string pointer is $00). in fact a pointer to any $00 longword would have done.
*
*	LEA	(LAB_1D96,PC),a0		* else return dummy null pointer
*	RTS

* do loop without do error

LAB_LDER
	MOVEQ		#$44,d0		* error code $22*2 "LOOP without DO" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do undefined function error

LAB_UFER
	MOVEQ		#$40,d0		* error code $20*2 "Undefined function" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do can't continue error

LAB_CCER
	MOVEQ		#$3C,d0		* error code $1E*2 "Can't continue" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do string too complex error

LAB_SCER
	MOVEQ		#$38,d0		* error code $1C*2 "String too complex" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do string too long error

LAB_SLER
	MOVEQ		#$34,d0		* error code $1A*2 "String too long" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do type missmatch error

LAB_TMER
	MOVEQ		#$30,d0		* error code $18*2 "Type mismatch" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do illegal direct error

LAB_IDER
	MOVEQ		#$2C,d0		* error code $16*2 "Illegal direct" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do divide by zero error

LAB_DZER
	MOVEQ		#$28,d0		* error code $14*2 "Divide by zero" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do double dimension error

LAB_DDER
	MOVEQ		#$24,d0		* set error $12*2 "Double dimension" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do array bounds error

LAB_ABER
	MOVEQ		#$20,d0		* error code $10*2 "Array bounds" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do undefine satement error

LAB_USER
	MOVEQ		#$1C,d0		* error code $0E*2 "Undefined statement" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do out of memory error

LAB_OMER
	MOVEQ		#$18,d0		* error code $0C*2 "Out of memory" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do overflow error

LAB_OFER
	MOVEQ		#$14,d0		* error code $0A*2 "Overflow" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do function call error

LAB_FCER
	MOVEQ		#$10,d0		* error code $08*2 "Function call" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do out of data error

LAB_ODER
	MOVEQ		#$0C,d0		* error code $06*2 "Out of DATA" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do return without gosub error

LAB_RGER
	MOVEQ		#$08,d0		* error code $04*2 "RETURN without GOSUB" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do syntax error

LAB_SNER
	MOVEQ		#$04,d0		* error code $02*2 "Syntax" error
	BRA.s		LAB_XERR		* do error #d0, then warm start

* do next without for error

LAB_NFER
	MOVEQ		#$00,d0		* else set error $00 "NEXT without FOR" error

* do error #d0, then warm start

LAB_XERR
	MOVE.w	d0,d7			* copy word
	BSR		LAB_1491		* flush stack & clear continue flag
	BSR		LAB_CRLF		* print CR/LF
	LEA		(LAB_BAER,PC),a1	* start of error message pointer table
	MOVEA.l	(a1,d7.w),a0	* get error message address
	BSR		LAB_18C3		* print null terminated string from memory
	LEA		(LAB_EMSG,PC),a0	* point to " Error" message
LAB_1269
	BSR		LAB_18C3		* print null terminated string from memory
	MOVE.l	Clinel,d0		* get current line
	BMI.s		LAB_1274		* go do warm start if -ve # (was immediate mode)

						* else print line number
	BSR		LAB_2953		* print " in line [LINE #]"

* BASIC warm start entry point, wait for Basic command

LAB_1274
	LEA		(LAB_RMSG,PC),a0	* point to "Ready" message
	BSR		LAB_18C3		* go do print string

* wait for Basic command (no "Ready")

LAB_127D
	MOVEQ		#-1,d1		* set  to -1
	MOVE.l	d1,Clinel		* set current line #
	MOVE.b	d1,Breakf		* set break flag
	MOVE.l	#Ibuffs,a5		* set basic execute pointer ready for new line
LAB_127E
	BSR		LAB_1357		* call for BASIC input
	BSR		LAB_GBYT		* scan memory
	BEQ.s		LAB_127E		* loop while null

* got to interpret input line now ....

	BCS.s		LAB_1295		* branch if numeric character (handle new BASIC line)

						* no line number, immediate mode, a5 is buffer start
	BSR		LAB_13A6		* crunch keywords into Basic tokens
						* crunch from (a5), output to (a0)
						* returns ..
						* d2 is length, d1 trashed, d0 trashed, a1 trashed

	EXG		a0,a5			* set execute pointer to buffer
	BRA		LAB_15F6		* go scan & interpret code

* handle new BASIC line

LAB_1295
	BSR		LAB_GFPN		* get fixed-point number into temp integer
	BSR		LAB_13A6		* crunch keywords into Basic tokens
						* crunch from (a5), output to (a0)
						* returns ..
						* d2 is length, d1 trashed, d0 trashed, a1 trashed
	BSR		LAB_SSLN		* search BASIC for temp integer line number
						* returns pointer in a0
	BCS.s		LAB_12E6		* branch if not found

						* aroooogah! line # already exists! delete it
	MOVEA.l	(a0),a1		* get start of block (next line pointer)
	MOVE.l	Sfncl,d0		* get end of block (start of functions)
	SUB.l		a1,d0			* subtract start of block ( = bytes to move)
	LSR.l		#1,d0			* /2 (word move)
	SUBQ.w	#1,d0			* adjust for DBF loop
	MOVEA.l	a0,a2			* copy destination
LAB_12B0
	MOVE.w	(a1)+,(a2)+		* copy word
	DBF		d0,LAB_12B0		* loop until done

	MOVE.l	a2,Sfncl		* start of functions
	MOVE.l	a2,Svarl		* save start of variables
	MOVE.l	a2,Sstrl		* start of strings
	MOVE.l	a2,Sarryl		* save start of arrays
	MOVE.l	a2,Earryl		* save end of arrays

						* got new line in buffer and no existing same #
LAB_12E6
	MOVE.b	Ibuffs,d0		* get byte from start of input buffer
	BEQ.s		LAB_1325		* if null line go do line chaining

						* got new line and it isn't empty line
	MOVEA.l	Sfncl,a1		* get start of functions (end of block to move)
	MOVE.l	a1,a2			* copy it
	ADDA.w	d2,a2			* add offset to destination (line length)
	ADDQ.w	#8,a2			* add room for pointer and line #

	MOVE.l	a2,Sfncl		* start of functions
	MOVE.l	a2,Svarl		* save start of variables
	MOVE.l	a2,Sstrl		* start of strings
	MOVE.l	a2,Sarryl		* save start of arrays
	MOVE.l	a2,Earryl		* save end of arrays
	MOVE.l	Ememl,Sstorl	* copy end of mem to start of strings (clear strings)

	MOVE.l	a1,d1			* copy end of block to move
	SUB.l		a0,d1			* subtract start of block to move
	LSR.l		#1,d1			* /2 (word copy)
	SUBQ.l	#1,d1			* correct for loop end on -1
LAB_1301
	MOVE.w	-(a1),-(a2)		* decrement pointers and copy word
	DBF		d1,LAB_1301		* decrement & loop

	MOVEA.l	#Ibuffs,a1		* source is input buffer
	MOVEA.l	a0,a2			* copy destination
	MOVEQ		#-1,d1		* set to allow re-chaining
	MOVE.l	d1,(a2)+		* set next line pointer (allow re-chaining)
	MOVE.l	Itemp,(a2)+		* save line number
	LSR.w		#1,d2			* /2 (word copy)
	SUBQ.w	#1,d2			* correct for loop end on -1
LAB_1303
	MOVE.w	(a1)+,(a2)+		* copy word
	DBF		d2,LAB_1303		* decrement & loop

	BRA.s		LAB_1325		* go test for end of prog

* rebuild chaining of Basic lines

LAB_132E
	ADDQ.w	#8,a0			* point to first code byte of line, there is always
						* 1 byte + [EOL] as null entries are deleted
LAB_1330
	TST.b		(a0)+			* test byte	
	BNE.s		LAB_1330		* loop if not [EOL]

						* was [EOL] so get next line start
	MOVE.w	a0,d1			* past pad byte(s)
	ANDI.w	#1,d1			* mask odd bit
	ADD.w		d1,a0			* add back to ensure even
	MOVE.l	a0,(a1)		* save next line pointer to current line
LAB_1325
	MOVEA.l	a0,a1			* copy pointer for this line
	TST.l		(a0)			* test pointer to next line
	BNE.s		LAB_132E		* not end of program yet so we must
						* go and fix the pointers

	BSR		LAB_1477		* reset execution to start, clear vars & flush stack
	BRA		LAB_127D		* now we just wait for Basic command (no "Ready")

* receive line from keyboard
						* $08 as delete key (BACKSPACE on standard keyboard)
LAB_134B
	BSR		LAB_PRNA		* go print the character
	SUBQ.w	#$01,d1		* decrement the buffer index (delete)
	BRA.s		LAB_1359		* re-enter loop

* print "? " and get BASIC input
* return a0 pointing to the buffer start

LAB_INLN
	BSR		LAB_18E3		* print "?" character
	MOVEQ		#' ',d0		* load " "
	BSR		LAB_PRNA		* go print

* call for BASIC input (main entry point)
* return a0 pointing to the buffer start

LAB_1357
	MOVEQ		#$00,d1		* clear buffer index
	MOVEA.l	#Ibuffs,a0		* set buffer base pointer
LAB_1359
	JSR		V_INPT		* call scan input device
	BCC.s		LAB_1359		* loop if no byte

	BEQ.s		LAB_1359		* loop if null byte

	CMP.b		#$07,d0		* compare with [BELL]
	BEQ.s		LAB_1378		* branch if [BELL]

	CMP.b		#$0D,d0		* compare with [CR]
	BEQ		LAB_1866		* do CR/LF exit if [CR]

	TST.w		d1			* set flags on buffer index
	BNE.s		LAB_1374		* branch if not empty

						* next two lines ignore any non print character
						* & [SPACE] if the input buffer is empty
	CMP.b		#' '+1,d0		* compare with [SP]+1
	BCS.s		LAB_1359		* if < ignore character

LAB_1374
	CMP.b		#$08,d0		* compare with [BACKSPACE] (delete last character)
	BEQ.s		LAB_134B		* go delete last character

LAB_1378
	CMP.w	#(Ibuffe-Ibuffs-1),d1	* compare character count with max-1
	BCC.s		LAB_138E		* skip store & do [BELL] if buffer full

	MOVE.b	d0,(a0,d1.w)	* else store in buffer
	ADDQ.w	#$01,d1		* increment index
LAB_137F
	BSR		LAB_PRNA		* go print the character
	BRA.s		LAB_1359		* always loop for next character

* announce buffer full

LAB_138E
	MOVEQ		#$07,d0		* [BELL] character into d0
	BRA.s		LAB_137F		* go print the [BELL] but ignore input character

* crunch keywords into Basic tokens
* crunch from (a5), output to (a0)
* returns ..
* d2 is length
* d1 trashed
* d0 trashed
* a1 trashed

* this is the improved BASIC crunch routine and is 10 to 100 times faster than the
* old list search

LAB_13A6
	MOVEQ		#$00,d1		* set read index
	MOVE.w	d1,d2			* set save index
	MOVE.b	d1,Oquote		* clear open quote/DATA flag
LAB_13AC
	MOVEQ		#0,d0			* clear word
	MOVE.b	(a5,d1.w),d0	* get byte from input buffer
	BEQ.s		LAB_13EC		* if null save byte then continue crunching

	CMP.b		#'_',d0		* compare with "_"
	BCC.s		LAB_13EC		* if >= "_" save byte then continue crunching

	CMP.b		#'<',d0		* compare with "<"
	BCC.s		LAB_13CC		* if >= "<" go crunch

	CMP.b		#'0',d0		* compare with "0"
	BCC.s		LAB_13EC		* if >= "0" save byte then continue crunching

	MOVE.b	d0,Asrch		* save buffer byte as search character
	CMP.b		#$22,d0		* is it quote character?
	BEQ		LAB_1410		* branch if so (copy quoted string)

	CMP.b		#'*',d0		* compare with "*"
	BCS.s		LAB_13EC		* if <= "*" save byte then continue crunching

						* crunch rest
LAB_13CC
	BTST.b	#6,Oquote		* test open quote/DATA token flag
	BNE.s		LAB_13EC		* branch if b6 of Oquote set (was DATA)
						* go save byte then continue crunching

	SUB.b		#$2A,d0		* normalise byte
	ADD.w		d0,d0			* *2 makes word offset (high byte=$00)
	LEA		(TAB_CHRT,PC),a1	* get keyword offset table address
	MOVE.w	(a1,d0.w),d0	* get offset into keyword table
	BMI.s		LAB_141F		* branch if no keywords for character

	LEA		(TAB_STAR,PC),a1	* get keyword table address
	ADDA.w	d0,a1			* add keyword offset
	MOVEQ		#-1,d3		* clear index
	MOVE.w	d1,d4			* copy read index
LAB_13D6
	ADDQ.w	#1,d3			* increment table index
	MOVE.b	(a1,d3.w),d0	* get byte from table
LAB_13D8
	BMI.s		LAB_13EA		* branch if token (save token and continue crunching)

	ADDQ.w	#1,d4			* increment read index
	CMP.b		(a5,d4.w),d0	* compare byte from input buffer
	BEQ.s		LAB_13D6		* loop if character match

	BRA.s		LAB_1417		* branch if no match

LAB_13EA
	MOVE.w	d4,d1			* update read index
LAB_13EC
	MOVE.b	d0,(a0,d2.w)	* save byte to output
	ADDQ.w	#1,d2			* increment buffer save index
	ADDQ.w	#1,d1			* increment buffer read index
	TST.b		d0			* set flags
	BEQ.s		LAB_142A		* branch if was null [EOL]

						* d0 holds token or byte here
	SUB.b		#$3A,d0		* subtract ":"
	BEQ.s		LAB_13FF		* branch if it was ":" (is now $00)

						* d0 now holds token-$3A
	CMP.b		#(TK_DATA-$3A),d0	* compare with DATA token - $3A
	BNE.s		LAB_1401		* branch if not DATA

						* token was : or DATA
LAB_13FF
	MOVE.b	d0,Oquote		* save token-$3A ($00 for ":", TK_DATA-$3A for DATA)
LAB_1401
	SUB.b		#(TK_REM-$3A),d0	* subtract REM token offset
	BNE		LAB_13AC		* If wasn't REM then go crunch rest of line

	MOVE.b	d0,Asrch		* else was REM so set search for [EOL]

						* loop for REM, "..." etc.
LAB_1408
	MOVE.b	(a5,d1.w),d0	* get byte from input buffer
	BEQ.s		LAB_13EC		* branch if null [EOL]

	CMP.b		Asrch,d0		* compare with stored character
	BEQ.s		LAB_13EC		* branch if match (end quote, REM, :, or DATA)

						* entry for copy string in quotes, don't crunch
LAB_1410
	MOVE.b	d0,(a0,d2.w)	* save byte to output
	ADDQ.w	#1,d2			* increment buffer save index
	ADDQ.w	#1,d1			* increment buffer read index
	BRA.s		LAB_1408		* loop

						* not found keyword this go
						* so find the end of this word in the table
LAB_1417
	MOVE.w	d1,d4			* reset read pointer
LAB_141B
	ADDQ.w	#1,d3			* increment keyword table pointer (flag unchanged)
	MOVE.b	(a1,d3.w),d0	* get keyword table byte
	BPL.s		LAB_141B		* if not end of keyword go do next byte

	ADDQ.w	#1,d3			* increment keyword table pointer (flag unchanged)
	MOVE.b	(a1,d3.w),d0	* get keyword table byte
	BNE.s		LAB_13D8		* go test next word if not zero byte (table end)

						* reached end of table with no match
LAB_141F
	MOVE.b	(a5,d1.w),d0	* restore byte from input buffer
	BRA.s		LAB_13EC		* go save byte in output and continue crunching

						* reached [EOL]
LAB_142A
	MOVEQ		#0,d0			* ensure longword clear
	BTST		d0,d2			* test odd bit (fastest)
	BEQ.s		LAB_142C		* branch if no bytes to fill

	MOVE.b	d0,(a0,d2.w)	* clear next byte
	ADDQ.w	#1,d2			* increment buffer save index
LAB_142C
	MOVE.l	d0,(a0,d2.w)	* clear next line pointer (EOT in immediate mode)
	RTS

* search Basic for temp integer line number from start of mem

LAB_SSLN
	MOVEA.l	Smeml,a0		* get start of program mem

* search Basic for temp integer line number from a0
* returns Cb=0 if found
* returns a0 pointer to found or next higher (not found) line

LAB_SHLN
	MOVE.l	Itemp,d1		* get required line #
	BRA.s		LAB_SCLN		* go search for required line from a0

LAB_145F
	MOVEA.l	d0,a0			* copy next line pointer
LAB_SCLN
	MOVE.l	(a0)+,d0		* get next line pointer and point to line #
	BEQ.s		LAB_145E		* is end marker so we're done, do 'no line' exit

	CMP.l		(a0),d1		* compare this line # with required line #
	BGT.s		LAB_145F		* loop if required # > this #

	SUBQ.w	#4,a0			* adjust pointer, flags not changed
	RTS

LAB_145E
	SUBQ.w	#4,a0			* adjust pointer, flags not changed
	SUBQ.l	#1,d0			* make end program found = -1, set carry
	RTS

* perform NEW

LAB_NEW
	BNE.s		RTS_005		* exit if not end of statement (do syntax error)

LAB_1463
	MOVEA.l	Smeml,a0		* point to start of program memory
	MOVEQ		#0,d0			* clear longword
	MOVE.l	d0,(a0)+		* clear first line, next line pointer
	MOVE.l	a0,Sfncl		* set start of functions

* reset execution to start, clear vars & flush stack

LAB_1477
	MOVEA.l	Smeml,a5		* reset BASIC execute pointer
	SUBQ.w	#$01,a5		* -1 (as end of previous line)

* "CLEAR" command gets here

LAB_147A
	MOVE.l	Ememl,Sstorl	* save end of mem as bottom of string space
	MOVE.l	Sfncl,d0		* get start of functions
	MOVE.l	d0,Svarl		* start of variables
	MOVE.l	d0,Sstrl		* start of strings
	MOVE.l	d0,Sarryl		* set start of arrays
	MOVE.l	d0,Earryl		* set end of arrays
	BSR		LAB_161A		* perform RESTORE command

* flush stack & clear continue flag

LAB_1491
	MOVEA.l	#des_sk,a4		* reset descriptor stack pointer

	MOVE.l	(sp)+,d0		* pull return address
	MOVEA.l	entry_sp,sp		* flush stack
	MOVE.l	d0,-(sp)		* restore return address

	MOVEQ		#0,d0			* clear longword
	MOVE.l	d0,Cpntrl		* clear continue pointer
	MOVE.b	d0,Sufnxf		* clear subscript/FNX flag
RTS_005
	RTS

* perform CLEAR

LAB_CLEAR
	BEQ.s		LAB_147A		* if no following byte go do "CLEAR"

	RTS					* was following byte (go do syntax error)

* perform LIST [n][-m]

LAB_LIST
	BLS.s		LAB_14BD		* branch if next character numeric (LIST n...)
						* or if next character [NULL] (LIST)

	CMP.b		#TK_MINUS,d0	* compare with token for -
	BNE.s		RTS_005		* exit if not - (LIST -m)

						* LIST [[n][-m]]
						* this sets the n, if present, as the start & end
LAB_14BD
	BSR		LAB_GFPN		* get fixed-point number into temp integer
	BSR		LAB_SSLN		* search BASIC for temp integer line number
						* (pointer in a0)
	BSR		LAB_GBYT		* scan memory
	BEQ.s		LAB_14D4		* branch if no more characters

						* this bit checks the - is present
	CMP.b		#TK_MINUS,d0	* compare with token for -
	BNE.s		RTS_005		* return if not "-" (will be Syntax error)

						* LIST [n]-m
						* the - was there so set m as the end value
	BSR		LAB_IGBY		* increment & scan memory
	BSR		LAB_GFPN		* get fixed-point number into temp integer
	BNE.s		LAB_14D4		* branch if was not zero

	MOVEQ		#-1,d1		* set end for $FFFFFFFF
	MOVE.l	d1,Itemp		* save Itemp
LAB_14D4
	MOVE.b	#$00,Oquote		* clear open quote flag
	BSR		LAB_CRLF		* print CR/LF
	MOVEA.l	(a0)+,a1		* get next line pointer
	MOVE.l	a1,d0			* copy to set the flags
	BEQ.s		RTS_005		* if null all done so exit

	BSR		LAB_1629		* do CRTL-C check vector

	MOVE.l	(a0)+,d0		* get this line #
	MOVE.l	Itemp,d1		* get end line #
	BEQ.s		LAB_14E2		* if end=0 list whole thing

	CMP.l		d0,d1			* compare this line # with end line #
	BCS.s		RTS_005		* if greater all done so exit

LAB_14E2
	MOVEM.l	a0-a1/d1-d4,-(sp)	* save registers !! work out what's needed here !!
	BSR		LAB_295E		* print d0 as unsigned integer
	MOVEM.l	(sp)+,a0-a1/d1-d4	* restore registers !! and here !!
	MOVEQ		#$20,d0		* space is the next character
LAB_150C
	BSR		LAB_PRNA		* go print the character
	CMP.b		#$22,d0		* was it " character
	BNE.s		LAB_1519		* branch if not

						* we're either entering or leaving quotes
	EOR.b		#$FF,Oquote		* toggle open quote flag
LAB_1519
	MOVE.b	(a0)+,d0		* get byte and increment pointer
	BNE.s		LAB_152E		* branch if not [EOL] (go print)

						* was [EOL]
	MOVEA.l	a1,a0			* copy next line pointer
	MOVE.l	a0,d0			* copy to set flags
	BNE.s		LAB_14D4		* go do next line if not [EOT]

	RTS

LAB_152E
	BPL.s		LAB_150C		* just go print it if not token byte

						* else was token byte so uncrunch it (maybe)
	BTST.b	#7,Oquote		* test the open quote flag
	BNE.s		LAB_150C		* just go print character if open quote set

						* else uncrunch BASIC token
	LEA		(LAB_KEYT,PC),a2	* get keyword table address
	MOVEQ		#$7F,d1		* mask into d1
	AND.b		d0,d1			* copy and mask token
	LSL.w		#2,d1			* *4
	LEA		(a2,d1.w),a2	* get keyword entry address
	MOVE.b	(a2)+,d0		* get byte from keyword table
	BSR		LAB_PRNA		* go print the first character
	MOVEQ		#0,d1			* clear d1
	MOVE.b	(a2)+,d1		* get remaining length byte from keyword table
	BMI.s		LAB_1519		* if -ve done so go get next byte

	MOVE.w	(a2),d0		* get offset to rest
	LEA		(TAB_STAR,PC),a2	* get keyword table address
	LEA		(a2,d0.w),a2	* get address of rest
LAB_1540
	MOVE.b	(a2)+,d0		* get byte from keyword table
	BSR		LAB_PRNA		* go print the character
	DBF		d1,LAB_1540		* decrement and loop if more to do

	BRA.s		LAB_1519		* go get next byte

* perform FOR

LAB_FOR
	BSR		LAB_LET		* go do LET
	BSR		LAB_11A1		* search the stack for FOR or GOSUB activity
						* exit with z=1 if FOR else exit with z=0
						* return modified stack in a2
	BNE.s		LAB_1567		* branch if FOR (this variable) not found

						* FOR (this variable) was found so first
						* we dump the old one
	ADDA.w	#22,sp		* reset stack (dump FOR structure (-4 bytes))
LAB_1567
	ADDQ.w	#4,sp			* dump return address
*	MOVEQ		#28,d0		* we need 28 bytes !
*	BSR.s		LAB_1212		* check room on stack for d0 bytes
	BSR		LAB_SNBS		* scan for next BASIC statement ([:] or [EOL])
						* returns a0 as pointer to [:] or [EOL]
	MOVE.l	a0,-(sp)		* push onto stack
	MOVE.l	Clinel,-(sp)	* push current line onto stack

	MOVEQ		#TK_TO-$100,d0	* set "TO" token
	BSR		LAB_SCCA		* scan for CHR$(d0) , else syntax error/warm start
	BSR		LAB_CTNM		* check if source is numeric, else type mismatch
	MOVE.b	Dtypef,-(sp)	* push FOR variable data type onto stack
	BSR		LAB_EVNM		* evaluate expression & check is numeric, else
						* do type mismatch

	MOVE.l	FAC1_m,-(sp)	* push TO value mantissa
	MOVE.w	FAC1_e,-(sp)	* push TO value exponent and sign

	MOVE.l	#$80000000,FAC1_m	* set default STEP size mantissa
	MOVE.w	#$8100,FAC1_e	* set default STEP size exponent and sign

	BSR		LAB_GBYT		* scan memory
	CMP.b		#TK_STEP,d0		* compare with STEP token
	BNE.s		LAB_15B3		* jump if not "STEP"

						* was step so ....
	BSR		LAB_IGBY		* increment & scan memory
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
LAB_15B3
	MOVE.l	FAC1_m,-(sp)	* push STEP value mantissa
	MOVE.w	FAC1_e,-(sp)	* push STEP value exponent and sign

	MOVE.l	Frnxtl,-(sp)	* push variable pointer for FOR/NEXT
	MOVE.w	#TK_FOR,-(sp)	* push FOR token on stack

	BRA.s		LAB_15C2		* go do interpreter inner loop

LAB_15DC					* have reached [EOL]+1
	MOVE.w	a5,d0			* copy BASIC execute pointer
	AND.w		#1,d0			* and make line start address even
	ADD.w		d0,a5			* add to BASIC execute pointer
	MOVE.l	(a5)+,d0		* get next line pointer
	BEQ		LAB_1274		* if null go to immediate mode, no "BREAK" message
						* (was immediate or [EOT] marker)

	MOVE.l	(a5)+,Clinel	* save (new) current line #
LAB_15F6
	BSR		LAB_GBYT		* get BASIC byte
	BSR.s		LAB_15FF		* go interpret BASIC code from (a5)

* interpreter inner loop entry point

LAB_15C2
	BSR.s		LAB_1629		* do CRTL-C check vector
	TST.w		Clinel		* test current line #, is -ve for immediate mode
	BMI.s		LAB_15D1		* branch if immediate mode

	MOVE.l	a5,Cpntrl		* save BASIC execute pointer as continue pointer
LAB_15D1
	MOVE.b	(a5)+,d0		* get this byte & increment pointer
	BEQ.s		LAB_15DC		* loop if [EOL]

	CMP.b		#$3A,d0		* compare with ":"
	BEQ.s		LAB_15F6		* loop if was statement separator

	BRA		LAB_SNER		* else syntax error, then warm start

* interpret BASIC code from (a5)

LAB_15FF
	BEQ.s		RTS_006		* exit if zero [EOL]

LAB_1602
	EORI.b	#$80,d0		* normalise token
	BMI		LAB_LET		* if not token, go do implied LET

	CMP.b		#(TK_TAB-$80),d0	* compare normalised token with TAB
	BCC		LAB_SNER		* branch if d0>=TAB, syntax error/warm start
						* only tokens before TAB can start a statement

	EXT.w		d0			* byte to word (clear high byte)
	ADD.w		d0,d0			* *2
	ADD.w		d0,d0			* *4 (offset to longword vector)
	LEA		(LAB_CTBL,PC),a0	* get vector table base address
	MOVE.l	(a0,d0.w),-(sp)	* push vector
	BRA		LAB_IGBY		* get following byte & execute vector

* CTRL-C check jump. this is called as a subroutine but exits back via a jump if a
* key press is detected.

LAB_1629
*	CMPA.l	#des_sk,a4		* check discriptor stack is empty
*	BNE		LAB_ITER		* if not do internal error

	JMP		V_CTLC		* ctrl c check vector

* if there was a key press it gets back here .....

LAB_1636
	CMP.b		#$03,d0		* compare with CTRL-C
	BNE.s		RTS_006		* return if wasn't CTRL-C

* perform STOP

LAB_STOP
	BCC.s		LAB_163B		* branch if token follows STOP
						* else just END
* perform END

LAB_END
	MOVE.b	#0,Breakf		* clear break flag, indicate program end
LAB_163B

	CMPA.l	#Ibuffe,a5		* compare execute address with buffer end
	BCS.s		LAB_164F		* branch if BASIC pointer is in buffer
						* (can't continue in immediate mode)

						* else...
	MOVE.l	a5,Cpntrl		* save BASIC execute pointer as continue pointer
LAB_1647
	MOVE.l	Clinel,Blinel	* save break line
LAB_164F
	MOVE.l	(sp)+,d0		* pull return address, don't return to execute loop
	MOVE.b	Breakf,d0		* get break flag
	BEQ		LAB_1274		* go do warm start if was program end

	LEA		(LAB_BMSG,PC),a0	* point to "Break"
	BRA		LAB_1269		* print "Break" and do warm start

* perform RESTORE

LAB_RESTORE
	BNE.s		LAB_RESn		* branch if next character not null (RESTORE n)

LAB_161A
	MOVEA.l	Smeml,a0		* copy start of mem
LAB_1624
	SUBQ.w	#1,a0			* -1
	MOVE.l	a0,Dptrl		* save DATA pointer
RTS_006
	RTS
						* is RESTORE n
LAB_RESn
	BSR		LAB_GFPN		* get fixed-point number into temp integer
	CMP.l		Clinel,d0		* compare current line # with required line #
	BLS.s		LAB_NSCH		* branch if >= (start search from beginning)

	MOVEA.l	a5,a0			* copy BASIC execute pointer
LAB_RESs
	TST.b		(a0)+			* test next byte & increment pointer
	BNE.s		LAB_RESs		* loop if not EOL

	MOVE.w	a0,d1			* copy pointer
	AND.w		#1,d1			* mask odd bit
	ADD.w		d1,a0			* add pointer
	BRA.s		LAB_GSCH		* go find

						* search for line in Itemp from start of memory
LAB_NSCH
	MOVEA.l	Smeml,a0		* get start of mem

						* search for line in Itemp from (a0)
LAB_GSCH
	BSR		LAB_SHLN		* search for temp integer line number from a0
						* returns Cb=0 if found
	BCS		LAB_USER		* go do "Undefined statement" error if not found

	BRA.s		LAB_1624		* else save DATA pointer & return

* perform NULL

LAB_NULL
	BSR		LAB_GTBY		* get byte parameter, result in d0 and Itemp
	MOVE.b	d0,Nullct		* save new NULL count
	RTS

* perform CONT

LAB_CONT
	BNE		LAB_SNER		* if following byte exit to do syntax error

	MOVE.l	Cpntrl,d0		* get continue pointer
	BEQ		LAB_CCER		* go do can't continue error if we can't

						* we can continue so ...
	MOVEA.l	d0,a5			* save continue pointer as BASIC execute pointer
	MOVE.l	Blinel,Clinel	* set break line as current line
	RTS

* get signed word parameter, result in d0 and Itemp

LAB_GTSW
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_EVIR		* evaluate integer expression
						* result in d0 and Itemp

* evaluate signed word parameter, result in d0

LAB_EVSW
	SWAP		d0			* copy high word to low word
	TST.w		d0			* set flags
	BEQ		LAB_ISWD		* branch if -1 < value < 32768

	ADDQ.w	#1,d0			* else check $FFFF
	BNE		LAB_FCER		* if <> 0 do function call error/warm start

LAB_ISWD
	SWAP		d0			* copy high word to low word
	RTS

* perform CLS

LAB_CLS
	BNE		LAB_SNER		* do syntax error if following byte

	MOVE.w	#$FF00,d1		* set for clear screen
	MOVE.b	d1,TPos		* clear terminal position
	MOVEQ		#11,d0		* cursor position
	TRAP		#15			* do i/o function

	RTS

* perform CURSOR X,Y

LAB_CURSOR
	BSR		LAB_GTBY		* get byte parameter, result in d0 and Itemp
	CMP.b		#80,d0		* compare with max+1
	BCC		LAB_FCER		* if >= 80 go do function call error

	MOVE.b	d0,TPos		* set terminal position
	ASL.w		#8,d0			* shift to high byte of word
	MOVE.w	d0,-(sp)		* save d0

	BSR		LAB_SCGB		* scan for "," & get byte param, result in d0 & Itemp

	CMP.b		#32,d0		* compare with max+1
	BCC		LAB_FCER		* if >= 32 go do function call error

	MOVE.w	(sp)+,d1		* restore d1
	OR.w		d0,d1			* OR row into low byte

	MOVEQ		#11,d0		* cursor position
	TRAP		#15			* do i/o function

	MOVEQ		#0,d0			* set d0
	ADD.b		TPos,d0		* get cursor x position
	TST.b		TWidth		* test terminal width
	BNE.s		LAB_CRTS		* branch if not infinite line

LAB_CDLP
	SUB.b		TabSiz,d0		* subtract tab size
	BCC.s		LAB_CDLP		* loop while no borrow
	ADD.b		TabSiz,d0		* add tab size back
LAB_CRTS
	MOVE.b	d0,TPos		* set terminal position
	RTS

* perform LINE [[X1,Y1],X2,Y2][,][LINE_COLOUR]

LAB_LINE
	BEQ		LAB_SNER		* do error if no parameters

	MOVEQ		#0,d1			* clear parameter count
LAB_LPLP
	MOVE.w	d1,-(sp)		* save parameter count
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_EVIR		* evaluate integer expression
						* result in d0 and Itemp
	MOVE.w	(sp)+,d1		* get parameter count
	MOVE.l	d0,-(sp)		* save parameter
	ADDQ.w	#1,d1			* increment parameter count
	BSR		LAB_GBYT		* get BASIC byte
	BEQ		LAB_LEXE		* no more parameters so go evaluate

	CMP.b		#',',d0		* check next byte is ","
	BNE		LAB_SNER		* do error if not

	BSR		LAB_IGBY		* increment & scan memory
	BRA.s		LAB_LPLP		* go get next parameter

LAB_LEXE
	MOVEQ		#1,d0			* for test
	AND.w		d1,d0			* AND parameter count
	BEQ		LAB_LNCO		* branch if no line colour parameter

	MOVE.l	(sp)+,d0		* get line colour
	SUBQ.w	#1,d1			* decrement parameter count
	MOVE.w	d1,-(sp)		* save parameter count
	BSR		LAB_SLCO		* go mask & set line colour
	MOVE.w	(sp)+,d1		* get parameter count back

						* parameter count is always even here
LAB_LNCO
	TST.w		d1			* test remaining parameter count
	BEQ.s		LAB_LRTS		* exit if null

	SUBQ.w	#2,d1			* subtract 2 from count
	BEQ		LAB_L2XY		* go do line to X,Y

	SUBQ.w	#2,d1			* subtract 2 from count
	BNE		LAB_SNER		* do error if there were more than 4 parameters left

	MOVE.l	(sp)+,d0		* get Y2 off stack
	BSR		LAB_EVSW		* evaluate signed word in d0
	MOVE.l	d0,d4			* copy Y2 parameter

	MOVE.l	(sp)+,d0		* get X2 off stack
	BSR		LAB_EVSW		* evaluate signed word in d0
	MOVE.l	d0,d3			* copy X2 parameter

	MOVE.l	(sp)+,d0		* get Y1 off stack
	BSR		LAB_EVSW		* evaluate signed word in d0
	MOVE.l	d0,d2			* copy Y1 parameter

	MOVE.l	(sp)+,d0		* get X1 off stack
	BSR		LAB_EVSW		* evaluate signed word in d0
	MOVE.l	d0,d1			* copy X1 parameter

	MOVEQ		#84,d0		* draw line from X1,Y1 to X2,Y2
	TRAP		#15			* do i/o function
LAB_LRTS
	RTS
						* do line to X,Y
LAB_L2XY
	MOVE.l	(sp)+,d0		* get Y off stack
	BSR		LAB_EVSW		* evaluate signed word in d0
	MOVE.l	d0,d2			* copy Y parameter

	MOVE.l	(sp)+,d0		* get X off stack
	BSR		LAB_EVSW		* evaluate signed word in d0
	MOVE.l	d0,d1			* copy X parameter

	MOVEQ		#85,d0		* draw line to X,Y
	TRAP		#15			* do i/o function

	RTS

* set line colour

LAB_SLCO
	MOVE.l	#$FFFFFF,d1		* set mask
	AND.l		d0,d1			* and line colour
	MOVEQ		#80,d0		* set pen colour
	TRAP		#15			* do i/o function
	RTS

* set fill colour

LAB_SFCO
	MOVE.l	#$FFFFFF,d1		* set mask
	AND.l		d0,d1			* and line colour
	MOVEQ		#81,d0		* set pen colour
	TRAP		#15			* do i/o function
	RTS

* perform FILL [X,Y][,][FILL_COLOUR]

LAB_FILL
	BSR		LAB_GTSW		* get X co-ordinate
	MOVE.l	d0,-(sp)		* save X co-ordinate
	BSR		LAB_1C01		* scan for "," else do syntax error/warm start
	BSR		LAB_GTSW		* get Y co-ordinate
	MOVE.l	d0,-(sp)		* save Y co-ordinate
	BSR		LAB_GBYT		* get BASIC byte
	BEQ		LAB_EFILL		* branch if command end

	CMP.b		#',',d0		* check next byte is ","
	BNE		LAB_SNER		* do error if not ","

	BSR		LAB_IGBY		* increment & scan memory
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_EVIR		* evaluate integer expression
						* result in d0 and Itemp
	BSR		LAB_SFCO		* go mask & set fill colour
LAB_EFILL
	MOVE.l	(sp)+,d2		* restore Y co-ordinate
	MOVE.l	(sp)+,d1		* restore X co-ordinate
	MOVEQ		#89,d0		* flood fill
	TRAP		#15			* do i/o function

	RTS

* perform MOVE X,Y

LAB_MOVE
	BSR		LAB_GTSW		* get X co-ordinate
	MOVE.l	d0,d1			* copy X co-ordinate
	BSR		LAB_1C01		* scan for "," else do syntax error/warm start
	BSR		LAB_GTSW		* get Y co-ordinate
	MOVE.l	d0,d2			* copy Y co-ordinate
	MOVEQ		#86,d0		* move to x,y
	TRAP		#15			* do i/o function

	RTS

* perform POINT X,Y [,LINE_COLOUR]

LAB_POINT
	BSR		LAB_GTSW		* get X co-ordinate
	MOVE.l	d0,-(sp)		* save X co-ordinate
	BSR		LAB_1C01		* scan for "," else do syntax error/warm start
	BSR		LAB_GTSW		* get Y co-ordinate
	MOVE.l	d0,-(sp)		* save Y co-ordinate
	BSR		LAB_GBYT		* get BASIC byte
	BEQ		LAB_EPOINT		* branch if command end

	CMP.b		#',',d0		* check next byte is ","
	BNE		LAB_SNER		* do error if not ","

	BSR		LAB_IGBY		* increment & scan memory
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_EVIR		* evaluate integer expression
						* result in d0 and Itemp
	BSR		LAB_SLCO		* go mask & set line colour
LAB_EPOINT
	MOVE.l	(sp)+,d2		* restore Y co-ordinate
	MOVE.l	(sp)+,d1		* restore X co-ordinate
	MOVEQ		#82,d0		* draw pixel
	TRAP		#15			* do i/o function

	RTS

* perform POINT(X,Y) function

LAB_FPOINT
	ADDQ.w	#1,a5			* increment pointer
	BSR		LAB_1BFE		* scan for "(" , else do syntax error/warm start
	BSR		LAB_GTSW		* get X co-ordinate
	MOVE.l	d0,-(sp)		* save X co-ordinate
	BSR		LAB_1C01		* scan for "," else do syntax error/warm start
	BSR		LAB_GTSW		* get Y co-ordinate
	MOVE.l	d0,-(sp)		* save Y co-ordinate
	BSR		LAB_1BFB		* scan for ")" , else do syntax error/warm start
	MOVE.l	(sp)+,d2		* restore Y co-ordinate
	MOVE.l	(sp)+,d1		* restore X co-ordinate
	MOVEQ		#83,d0		* read pixel colour
	TRAP		#15			* do i/o function
	BRA		LAB_AYFC		* convert d0 to signed longword in FAC1 & RET

* perform RECT [X1,Y1,X2,Y2][,][LINE_COLOUR[,FILL_COLOUR]]

LAB_RECT
	BEQ		LAB_SNER		* do error if no parameters

	MOVEQ		#90,d0		* draw unfilled rectangle
	BRA.s		LAB_shape		* go do shape

* perform RECTF [X1,Y1,X2,Y2][,][LINE_COLOUR[,FILL_COLOUR]]

LAB_FRECT
	BEQ		LAB_SNER		* do error if no parameters

	MOVEQ		#87,d0		* draw filled rectangle
	BRA.s		LAB_shape		* go do shape

* perform ELLIPSE [X1,Y1,X2,Y2][,][LINE_COLOUR[,FILL_COLOUR]]

LAB_ELLIPSE
	BEQ		LAB_SNER		* do error if no parameters

	MOVEQ		#91,d0		* draw unfilled ellipse
	BRA.s		LAB_shape		* go do shape

* perform ELLIPSEF [X1,Y1,X2,Y2][,][LINE_COLOUR[,FILL_COLOUR]]

LAB_FELLIPSE
	BEQ		LAB_SNER		* do error if no parameters

	MOVEQ		#88,d0		* draw filled ellipse
*	BRA		LAB_shape		* go do shape

* do SHAPE [X1,Y1,X2,Y2][,][LINE_COLOUR[,FILL_COLOUR]]

LAB_shape
	MOVE.l	d0,-(sp)		* save shape type
	MOVEQ		#0,d1			* clear parameter count
LAB_SPLP
	MOVE.w	d1,-(sp)		* save parameter count
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_EVIR		* evaluate integer expression
						* result in d0 and Itemp
	MOVE.w	(sp)+,d1		* get parameter count
	MOVE.l	d0,-(sp)		* save parameter
	ADDQ.w	#1,d1			* increment parameter count
	BSR		LAB_GBYT		* get BASIC byte
	BEQ		LAB_SEXE		* no more parameters so go evaluate

	CMP.b		#',',d0		* check next byte is ","
	BNE		LAB_SNER		* do error if not

	BSR		LAB_IGBY		* increment & scan memory
	BRA.s		LAB_SPLP		* go get next parameter

LAB_SEXE
	CMP.b		#4,d1			* compare count with 4
	BEQ		LAB_S2XY		* branch if 4 parameters

	MOVEQ		#1,d0			* for test
	AND.w		d1,d0			* AND parameter count
	BNE		LAB_SNFC		* branch if no fill colour parameter

	MOVE.l	(sp)+,d0		* get fill colour
	SUBQ.w	#1,d1			* decrement parameter count
	MOVE.w	d1,-(sp)		* save parameter count
	BSR		LAB_SFCO		* go mask & set fill colour
	MOVE.w	(sp)+,d1		* get parameter count back
LAB_SNFC
	MOVE.l	(sp)+,d0		* get line colour
	SUBQ.w	#1,d1			* decrement parameter count
	MOVE.w	d1,-(sp)		* save parameter count
	BSR		LAB_SLCO		* go mask & set line colour
	MOVE.w	(sp)+,d1		* get parameter count back
	BEQ		LAB_SRTS		* exit if no more parameters

						* parameter count is always four here
LAB_S2XY
	CMP.b		#4,d1			* compare count with 4
	BNE		LAB_SNER		* do error if not 4 parameters

	MOVE.l	(sp)+,d0		* get Y2 off stack
	BSR		LAB_EVSW		* evaluate signed word in d0
	MOVE.l	d0,d4			* copy Y2 parameter

	MOVE.l	(sp)+,d0		* get X2 off stack
	BSR		LAB_EVSW		* evaluate signed word in d0
	MOVE.l	d0,d3			* copy X2 parameter

	MOVE.l	(sp)+,d0		* get Y1 off stack
	BSR		LAB_EVSW		* evaluate signed word in d0
	MOVE.l	d0,d2			* copy Y1 parameter

	MOVE.l	(sp)+,d0		* get X1 off stack
	BSR		LAB_EVSW		* evaluate signed word in d0
	MOVE.l	d0,d1			* copy X1 parameter

	MOVE.l	(sp)+,d0		* draw shape from X1,Y1 to X2,Y2
	TRAP		#15			* do i/o function
	RTS

LAB_SRTS
	MOVE.l	(sp)+,d0		* dump shape type
	RTS

* perform MODE
* MODE M

LAB_MODE
	BSR		LAB_GTBY		* get byte parameter, result in d0 and Itemp
	CMP.b		#$10,d0		* compare with max+1
	BCC		LAB_FCER		* if >= $10 go do function call error

	MOVE.l	d0,d1			* copy it
	MOVEQ		#92,d0		* set draw mode
	TRAP		#15			* do i/o function

	RTS

* perform SIZE
* SIZE S

LAB_SIZE
	BSR		LAB_GTBY		* get byte parameter, result in d0 and Itemp
	MOVE.l	d0,d1			* copy it
	MOVEQ		#93,d0		* set pen width
	TRAP		#15			* do i/o function

	RTS

* perform RUN

LAB_RUN
	BNE		LAB_RUNn		* if following byte do RUN n

	BSR		LAB_1477		* execution to start, clear vars & flush stack
	MOVE.l	a5,Cpntrl		* save as continue pointer
	BRA		LAB_15C2		* go do interpreter inner loop
						* (can't RTS, we flushed the stack!)

LAB_RUNn
	BSR		LAB_147A		* go do "CLEAR"
	BRA.s		LAB_16B0		* get n and do GOTO n

* perform DO

LAB_DO
*	MOVE.l	#$05,d0		* need 5 bytes for DO ##
*	BSR.s		LAB_1212		* check room on stack for A bytes
	MOVE.l	a5,-(sp)		* push BASIC execute pointer on stack
	MOVE.l	Clinel,-(sp)	* push current line on stack
	MOVE.w	#TK_DO,-(sp)	* push token for DO on stack
DoAgain
	BSR		LAB_GBYT		* scan memory
	BRA		LAB_15C2		* go do interpreter inner loop

* perform GOSUB

LAB_GOSUB
*	MOVE.l	#10,d0		* need 10 bytes for GOSUB ##
*	BSR.s		LAB_1212		* check room on stack for d0 bytes
	MOVE.l	a5,-(sp)		* push BASIC execute pointer
	MOVE.l	Clinel,-(sp)	* push current line
	MOVE.w	#TK_GOSUB,-(sp)	* push token for GOSUB
LAB_16B0
	BSR		LAB_GBYT		* scan memory
	BSR.s		LAB_GOTO		* perform GOTO n
	BRA		LAB_15C2		* go do interpreter inner loop
						* (can't RTS, we used the stack!)

* tail of IF command

LAB_1754
	BSR		LAB_GBYT		* scan memory, Cb=1 if "0"-"9"
	BCC		LAB_15FF		* if not numeric interpret BASIC code from (a5)

**	BRA		LAB_GOTO		* else do GOTO n (was numeric)

* perform GOTO

LAB_GOTO
	BSR		LAB_GFPN		* get fixed-point number into temp integer

	MOVEA.l	a5,a0			* copy BASIC execute pointer
LAB_GOTs
	TST.b		(a0)+			* test next byte & increment pointer
	BNE.s		LAB_GOTs		* loop if not EOL

	MOVE.w	a0,d1			* past pad byte(s)
	AND.w		#1,d1			* mask odd bit
	ADD.w		d1,a0			* add to pointer

	MOVE.l	Clinel,d0		* get current line
	BMI.s		LAB_16D0		* if immediate mode start search from beginning

	CMP.l		Itemp,d0		* compare wanted # with current #
	BCS.s		LAB_16D4		* branch if current # < wanted #
						* (start search from here)

* search for line # in temp (Itemp) from start of mem pointer (Smeml)

LAB_16D0
	MOVEA.l	Smeml,a0		* get start of memory

* search for line # in Itemp from (a0)

LAB_16D4
	BSR		LAB_SHLN		* search for temp integer line number from a0
						* returns Cb=0 if found
	BCS		LAB_USER		* if carry set go do "Undefined statement" error

	MOVEA.l	a0,a5			* copy to basic execute pointer
	SUBQ.w	#1,a5			* decrement pointer
	MOVE.l	a5,Cpntrl		* save as continue pointer
	RTS

* perform LOOP

LAB_LOOP
	MOVEQ		#0,d7			* clear top 24 bits
	MOVE.b	d0,d7			* save following token (byte)
	BSR		LAB_11A1		* search the stack for FOR or GOSUB activity
						* exit with Zb=1 if FOR else exit with Zb=0
						* return modified stack in a2
	
	CMP.w		#TK_DO,d0		* compare with DO token
	BNE		LAB_LDER		* branch if no matching DO

	TST.b		d7			* test saved following token
	BEQ.s		LoopAlways		* if no following token loop forever
						* (stack pointer in a2)

	SUB.b		#TK_UNTIL,d7	* subtract token for UNTIL
	BEQ.s		DoRest		* branch if was UNTIL

	SUBQ.b	#1,d7			* decrement result
	BNE		LAB_SNER		* if not WHILE go do syntax error & warm start
						* only if the token was WHILE will this fail

	SUBQ.b	#1,d7			* set invert result longword
DoRest
	BSR		LAB_IGBY		* increment & scan memory
	MOVE.l	a2,-(sp)		* save modified stack pointer
	BSR		LAB_EVEX		* evaluate expression
	MOVEA.l	(sp)+,a2		* restore modified stack pointer
	TST.b		FAC1_e		* test FAC1 exponent
	BEQ.s		DoCmp			* if =0 go do straight compare

	MOVE.b	#$FF,FAC1_e		* else set all bits
DoCmp
	EOR.b		d7,FAC1_e		* EOR with invert byte
	BNE.s		LoopDone		* if <> 0 clear stack & back to interpreter loop

						* loop condition wasn't met so do it again
LoopAlways
	MOVE.l	2(a2),Clinel	* copy DO current line low byte
	MOVE.l	6(a2),a5		* save BASIC execute pointer low byte
	ADDQ.w	#4,sp			* dump call to this routine
	BRA		DoAgain		* go do DO again

						* clear stack & back to interpreter loop
LoopDone
	ADDA.w	#14,sp		* dump structure and call from stack
	BRA.s		LAB_DATA		* go perform DATA (find : or [EOL])

* perform RETURN

LAB_RETURN
	BNE.s		RTS_007		* exit if following token (to allow syntax error)

	BSR		LAB_11A1		* search the stack for FOR or GOSUB activity
						* exit with z=1 if FOR else exit with z=0
						* return modified stack in a2
	CMP.w		#TK_GOSUB,d0	* compare with GOSUB token
	BNE		LAB_RGER		* branch if no matching GOSUB

	ADDQ.w	#2,a2			* adjust for token
	MOVEA.l	a2,sp			* dump calling addresses & token
	MOVE.l	(sp)+,Clinel	* pull current line
	MOVE.l	(sp)+,a5		* pull BASIC execute pointer
						* now do perform "DATA" statement as we could be
						* returning into the middle of an ON <var> GOSUB
						* n,m,p,q line (the return address used by the
						* DATA statement is the one pushed before the
						* GOSUB was executed!)

* perform DATA

LAB_DATA
	BSR		LAB_SNBS		* scan for next BASIC statement ([:] or [EOL])
						* returns a0 as pointer to [:] or [EOL]
	MOVEA.l	a0,a5			* skip rest of statement
RTS_007
	RTS

* scan for next BASIC statement ([:] or [EOL])
* returns a0 as pointer to [:] or [EOL]

LAB_SNBS
	MOVEA.l	a5,a0			* copy BASIC execute pointer
	MOVEQ		#$22,d1		* set string quote character
	BRA.s		LAB_172D		* go do search

LAB_172C
	CMP.b		#$3A,d0		* compare with ":"
	BEQ.s		RTS_007a		* exit if found

	CMP.b		d1,d0			* compare current character with string quote
	BEQ.s		LAB_1725		* if found go search for [EOL]

LAB_172D
	MOVE.b	(a0)+,d0		* get next byte
	BNE.s		LAB_172C		* loop if not null [EOL]

RTS_007a
	SUBQ.w	#1,a0			* correct pointer
	RTS

LAB_1723
	CMP.b		d1,d0			* compare current character with string quote
	BEQ.s		LAB_172D		* if found go search for ":" or [EOL]

LAB_1725
	MOVE.b	(a0)+,d0		* get next byte
	BNE.s		LAB_1723		* loop if not null [EOL]

	BRA.s		RTS_007a		* correct pointer & return

* perform IF

LAB_IF
	BSR		LAB_EVEX		* evaluate expression
	BSR		LAB_GBYT		* scan memory
	CMP.b		#TK_GOTO,d0		* compare with "GOTO" token
	BEQ.s		LAB_174B		* jump if was "GOTO"

						* wasn't IF ... GOTO so must be IF ... THEN
	MOVEQ		#TK_THEN-$100,d0	* get THEN token
	BSR		LAB_SCCA		* scan for CHR$(d0), else syntax error/warm start
LAB_174B
	MOVE.b	FAC1_e,d0		* get FAC1 exponent
	BNE		LAB_1754		* branch if result was non zero
						* else ....
* perform REM, skip (rest of) line

LAB_REM
	TST.b		(a5)+			* test byte & increment pointer
	BNE.s		LAB_REM		* loop if not EOL

	SUBQ.w	#1,a5			* correct pointer
	RTS

* perform ON

LAB_ON
	BSR		LAB_GTBY		* get byte parameter, result in d0 and Itemp
	MOVE.b	d0,d2			* copy byte
	BSR		LAB_GBYT		* restore BASIC byte
	MOVE.w	d0,-(sp)		* push GOTO/GOSUB token
	CMP.b		#TK_GOSUB,d0	* compare with GOSUB token
	BEQ.s		LAB_176C		* branch if GOSUB

	CMP.b		#TK_GOTO,d0		* compare with GOTO token
	BNE		LAB_SNER		* if not GOTO do syntax error, then warm start

* next character was GOTO or GOSUB

LAB_176C
	SUBQ.b	#1,d2			* decrement index (byte value)
	BNE.s		LAB_1773		* branch if not zero

	MOVE.w	(sp)+,d0		* pull GOTO/GOSUB token
	BRA		LAB_1602		* go execute it

LAB_1773
	BSR		LAB_IGBY		* increment & scan memory
	BSR.s		LAB_GFPN		* get fixed-point number into temp integer
						* (skip this n)
	CMP.b		#$2C,d0		* compare next character with ","
	BEQ.s		LAB_176C		* loop if ","

	MOVE.w	(sp)+,d0		* pull GOTO/GOSUB token (run out of options)
	RTS					* and exit

* get fixed-point number into temp integer
* interpret number from (a5), leave (a5) pointing to byte after #

LAB_GFPN
	MOVEQ		#$00,d1		* clear integer register
	MOVE.l	d1,d0			* clear d0
	BSR		LAB_GBYT		* scan memory, Cb=1 if "0"-"9", & get byte
	BCC.s		LAB_1786		* return if carry clear, chr was not "0"-"9"

	MOVE.l	d2,-(sp)		* save d2
LAB_1785
	MOVE.l	d1,d2			* copy integer register
	ADD.l		d1,d1			* *2
	BCS		LAB_SNER		* if overflow do syntax error, then warm start

	ADD.l		d1,d1			* *4
	BCS		LAB_SNER		* if overflow do syntax error, then warm start

	ADD.l		d2,d1			* *1 + *4
	BCS		LAB_SNER		* if overflow do syntax error, then warm start

	ADD.l		d1,d1			* *10
	BCS		LAB_SNER		* if overflow do syntax error, then warm start

	SUB.b		#$30,d0		* subtract $30 from byte
	ADD.l		d0,d1			* add to integer register (top 24 bits always clear)
	BVS		LAB_SNER		* if overflow do syntax error, then warm start
						* (makes max line # 2147483647)
	BSR		LAB_IGBY		* increment & scan memory
	BCS.s		LAB_1785		* loop for next character if "0"-"9"

	MOVE.l	(sp)+,d2		* restore d2
LAB_1786
	MOVE.l	d1,Itemp		* save Itemp
	RTS

* perform DEC

LAB_DEC
	MOVE.w	#$8180,-(sp)	* set -1 sign/exponent
	BRA.s		LAB_17B7		* go do DEC

* perform INC

LAB_INC
	MOVE.w	#$8100,-(sp)	* set 1 sign/exponent
LAB_17B7
	BSR		LAB_GVAR		* get var address
						* return pointer to variable in Cvaral and a0
	TST.b		Dtypef		* test data type, $80=string, $40=integer, $00=float
	BMI		LAB_TMER		* if string do "Type mismatch" error/warm start

	BNE.s		LAB_INCI		* go do integer INC/DEC

	MOVE.l	a0,Lvarpl		* save var address
	BSR		LAB_UFAC		* unpack memory (a0) into FAC1
	MOVE.l	#$80000000,FAC2_m	* set FAC2 mantissa for 1
	MOVE.w	(sp),d0		* move exponent & sign to d0
	MOVE.w	d0,FAC2_e		* move exponent & sign to FAC2
	MOVE.b	FAC1_s,FAC_sc	* make sign compare = FAC1 sign
	EOR.b		d0,FAC_sc		* make sign compare (FAC1_s EOR FAC2_s)
	BSR		LAB_ADD		* add FAC2 to FAC1
	BSR		LAB_PFAC		* pack FAC1 into variable (Lvarpl)
LAB_INCT
	BSR		LAB_GBYT		* scan memory
	CMPI.b	#$2C,d0		* compare with ","
	BEQ.s		LAB_17B8		* continue if "," (another variable to do)

	ADDQ.w	#2,sp			* else dump sign & exponent
	RTS
						* was "," so another INCR variable to do
LAB_17B8
	BSR		LAB_IGBY		* increment and scan memory
	BRA.s		LAB_17B7		* go do next var

LAB_INCI
	TST.b		1(sp)			* test sign
	BNE.s		LAB_DECI		* branch if DEC

	ADDQ.l	#1,(a0)		* increment variable
	BRA.s		LAB_INCT		* go scan for more

LAB_DECI
	SUBQ.l	#1,(a0)		* decrement variable
	BRA.s		LAB_INCT		* go scan for more


* perform LET

LAB_LET
	BSR		LAB_GVAR		* get variable address
						* return pointer to variable in Cvaral and a0
	MOVE.l	a0,Lvarpl		* save variable address
	MOVE.b	Dtypef,-(sp)	* push var data type, $80=string, $40=int, $00=float
	MOVEQ		#TK_EQUAL-$100,d0	* get = token
	BSR		LAB_SCCA		* scan for CHR$(d0), else syntax error/warm start
	BSR		LAB_EVEX		* evaluate expression
	MOVE.b	Dtypef,d0		* copy expression data type
	MOVE.b	(sp)+,Dtypef	* pop variable data type
	ROL.b		#1,d0			* set carry if expression type = string
	BSR		LAB_CKTM		* type match check, set C for string
	BEQ		LAB_PFAC		* if number pack FAC1 into variable Lvarpl & RET

* string LET

LAB_17D5
	MOVEA.l	Lvarpl,a2		* get pointer to variable
LAB_17D6
	MOVEA.l	FAC1_m,a0		* get descriptor pointer
	MOVEA.l	(a0),a1		* get string pointer
*	CMP.l		Smeml,a1		* compare bottom of memory with string pointer
*	BCS.s		LAB_1810		* if string was in utility memory copy it

	CMP.l		Sstorl,a1		* compare string memory start with string pointer
	BCS.s		LAB_1811		* if it was in program memory assign value & exit

	CMPA.l	Sfncl,a0		* compare functions start with descriptor pointer
	BCS.s		LAB_1811		* branch if >= (string is on stack)

						* string is variable$, make space and copy string
LAB_1810
	MOVEQ		#0,d1			* clear length
	MOVE.w	4(a0),d1		* get string length
	MOVEA.l	(a0),a0		* get string pointer
	BSR		LAB_20C9		* copy string
	MOVEA.l	FAC1_m,a0		* get descriptor pointer back
						* clean stack & assign value to string variable
LAB_1811
	CMPA.l	a0,a4			* is string on the descriptor stack
	BNE.s		LAB_1813		* skip pop if not

	ADDQ.w	#$06,a4		* else update stack pointer
LAB_1813
	MOVE.l	(a0)+,(a2)+		* save pointer to variable
	MOVE.w	(a0),(a2)		* save length to variable
RTS_008
	RTS

* perform GET

LAB_GET
	BSR		LAB_GVAR		* get var address
						* return pointer to variable in Cvaral and a0
	MOVE.l	a0,Lvarpl		* save variable address as GET variable
	TST.b		Dtypef		* test data type, $80=string, $40=integer, $00=float
	BMI.s		LAB_GETS		* go get string character

						* was numeric get
	BSR		INGET			* get input byte
	BSR		LAB_1FD0		* convert d0 to unsigned byte in FAC1
	BRA		LAB_PFAC		* pack FAC1 into variable (Lvarpl) & return

LAB_GETS
	MOVEQ		#$00,d1		* assume no byte
	BSR		INGET			* get input byte
	BCC.s		LAB_NoByte		* branch if no byte received

	MOVEQ		#$01,d1		* string is single byte
LAB_NoByte
	BSR		LAB_2115		* make string space d1 bytes long
						* return a0 = pointer, other registers unchanged
	BEQ.s		LAB_NoSt		* skip store if null string (or will write over $00)

	MOVE.b	d0,(a0)		* save byte in string (byte IS string!)
LAB_NoSt
	BSR		LAB_RTST		* push string on descriptor stack
						* a0 = pointer, d1 = length

	BRA.s		LAB_17D5		* do string LET & return

* PRINT

LAB_1829
	BSR		LAB_18C6		* print string from stack
LAB_182C
	BSR		LAB_GBYT		* scan memory

* perform PRINT

LAB_PRINT
	BEQ.s		LAB_CRLF		* if nothing following just print CR/LF

LAB_1831
	BEQ.s		RTS_008		* exit if nothing more to print

	CMP.b		#TK_TAB,d0		* compare with TAB( token
	BEQ.s		LAB_18A2		* go do TAB/SPC

	CMP.b		#TK_SPC,d0		* compare with SPC( token
	BEQ.s		LAB_18A2		* go do TAB/SPC

	CMP.b		#',',d0		* compare with ","
	BEQ.s		LAB_188B		* go do move to next TAB mark

	CMP.b		#';',d0		* compare with ";"
	BEQ		LAB_18BD		* if ";" continue with PRINT processing

	BSR		LAB_EVEX		* evaluate expression
	TST.b		Dtypef		* test data type, $80=string, $40=integer, $00=float
	BMI.s		LAB_1829		* branch if string

** replace the two lines above with this code

**	MOVE.b	Dtypef,d0		* get data type flag, $80=string, $00=numeric
**	BMI.s		LAB_1829		* branch if string

	BSR		LAB_2970		* convert FAC1 to string
	BSR		LAB_20AE		* print " terminated string to FAC1 stack

* don't check fit if terminal width byte is zero

	MOVEQ		#0,d0			* clear d0
	MOVE.b	TWidth,d0		* get terminal width byte
	BEQ.s		LAB_185E		* skip check if zero

	SUB.b		7(a4),d0		* subtract string length
	SUB.b		TPos,d0		* subtract terminal position
	BCC.s		LAB_185E		* branch if less than terminal width

	BSR.s		LAB_CRLF		* else print CR/LF
LAB_185E
	BSR.s		LAB_18C6		* print string from stack
	BRA.s		LAB_182C		* always go continue processing line

* CR/LF return to BASIC from BASIC input handler
* leaves a0 pointing to the buffer start

LAB_1866
	MOVE.b	#$00,(a0,d1.w)	* null terminate input

* print CR/LF

LAB_CRLF
	MOVEQ		#$0D,d0		* load [CR]
	BSR.s		LAB_PRNA		* go print the character
	MOVEQ		#$0A,d0		* load [LF]
	BRA.s		LAB_PRNA		* go print the character & return (always branch)

LAB_188B
	MOVE.b	TPos,d2		* get terminal position
	CMP.b		Iclim,d2		* compare with input column limit
	BCS.s		LAB_1898		* branch if less than Iclim

	BSR.s		LAB_CRLF		* else print CR/LF (next line)
	BRA.s		LAB_18BD		* continue with PRINT processing (branch always)

LAB_1898
	SUB.b		TabSiz,d2		* subtract TAB size
	BCC.s		LAB_1898		* loop if result was >= 0

	NEG.b		d2			* twos complement it
	BRA.s		LAB_18B7		* print d2 spaces

						* do TAB/SPC
LAB_18A2
	MOVE.w	d0,-(sp)		* save token
	BSR		LAB_SGBY		* increment and get byte, result in d0 and Itemp
	MOVE.w	d0,d2			* copy byte
	BSR		LAB_GBYT		* get basic byte back
	CMP.b		#$29,d0		* is next character ")"
	BNE		LAB_SNER		* if not do syntax error, then warm start

	MOVE.w	(sp)+,d0		* get token back
	CMP.b		#TK_TAB,d0		* was it TAB ?
	BNE.s		LAB_18B7		* branch if not (was SPC)

						* calculate TAB offset
	SUB.b		TPos,d2		* subtract terminal position
	BCS.s		LAB_18BD		* branch if result was < 0 (can't TAB backwards)

	BEQ.s		LAB_18BD		* branch if result was = $0 (already here)

						* print d2 spaces
LAB_18B7
	TST.b		d2			* test count
	BEQ.s		LAB_18BD		* branch if zero

	SUBQ.b	#1,d2			* adjust for DBF loop
	MOVEQ		#$20,d0		* load " "
LAB_18B8
	BSR.s		LAB_PRNA		* go print
	DBF		d2,LAB_18B8		* decrement count and loop if not all done

						* continue with PRINT processing
LAB_18BD
	BSR		LAB_IGBY		* increment & scan memory
	BRA		LAB_1831		* continue executing PRINT

* print null terminated string from a0

LAB_18C3
	BSR		LAB_20AE		* print terminated string to FAC1/stack

* print string from stack

LAB_18C6
	BSR		LAB_22B6		* pop string off descriptor stack or from memory
						* returns with d0 = length, a0 = pointer
	MOVE.w	d0,d1			* copy length & set Z flag
	BEQ.s		RTS_009		* exit (RTS) if null string

	SUBQ.w	#1,d1			* -1 for BF loop
LAB_18CD
	MOVE.b	(a0)+,d0		* get byte from string
	BSR.s		LAB_PRNA		* go print the character
	DBF		d1,LAB_18CD		* decrement count and loop if not done yet

RTS_009
	RTS

* print "?" character

LAB_18E3
	MOVEQ		#$3F,d0		* load "?" character

* print character in d0, includes the null handler and infinite line length code
* changes no registers.

LAB_PRNA
	MOVE.l	d1,-(SP)		* save d1
	CMP.b		#$20,d0		* compare with " "
	BCS.s		LAB_18F9		* branch if less, non printing character

						* don't check fit if terminal width byte is zero
	MOVE.b	TWidth,d1		* get terminal width
	BNE.s		LAB_18F0		* branch if not zero (not infinite length)

						* is "infinite line" so check TAB position
	MOVE.b	TPos,d1		* get position
	SUB.b		TabSiz,d1		* subtract TAB size
	BNE.s		LAB_18F7		* skip reset if different

	MOVE.b	d1,TPos		* else reset position
	BRA.s		LAB_18F7		* go print character

LAB_18F0
	CMP.b		TPos,d1		* compare with terminal character position
	BNE.s		LAB_18F7		* branch if not at end of line

	MOVE.l	d0,-(SP)		* save d0
	BSR		LAB_CRLF		* else print CR/LF
	MOVE.l	(SP)+,d0		* restore d0
LAB_18F7
	ADDQ.b	#$01,TPos		* increment terminal position
LAB_18F9
	JSR		V_OUTP		* output byte via output vector
	CMP.b		#$0D,d0		* compare with [CR]
	BNE.s		LAB_188A		* branch if not [CR]

						* else print nullct nulls after the [CR]
	MOVEQ		#$00,d1		* clear d1
	MOVE.b	Nullct,d1		* get null count
	BEQ.s		LAB_1886		* branch if no nulls

	MOVEQ		#$00,d0		* load [NULL]
LAB_1880
	JSR		V_OUTP		* go print the character
	DBF		d1,LAB_1880		* decrement count and loop if not all done

	MOVEQ		#$0D,d0		* restore the character
LAB_1886
	MOVE.b	d1,TPos		* clear terminal position
LAB_188A
	MOVE.l	(SP)+,d1		* restore d1
	RTS

* handle bad input data

LAB_1904
	TST.b		Imode			* test input mode flag, $00=INPUT, $98=READ
	BPL.s		LAB_1913		* branch if INPUT (go do redo)

	MOVE.l	Dlinel,Clinel	* save DATA line as current line
	BRA		LAB_SNER		* do syntax error, then warm start

						* mode was INPUT
LAB_1913
	LEA		(LAB_REDO,PC),a0	* point to redo message
	BSR		LAB_18C3		* print null terminated string from memory
	MOVEA.l	Cpntrl,a5		* save continue pointer as BASIC execute pointer
	RTS

* perform INPUT

LAB_INPUT
	BSR		LAB_CKRN		* check not Direct (back here if ok)
	CMP.b		#$22,d0		* compare next byte with open quote
	BNE.s		LAB_1934		* branch if no prompt string

	BSR		LAB_1BC1		* print "..." string
	MOVEQ		#$3B,d0		* load d0 with ";"
	BSR		LAB_SCCA		* scan for CHR$(d0), else syntax error/warm start
	BSR		LAB_18C6		* print string from Sutill/Sutilh
						* done with prompt, now get data
LAB_1934
	BSR		LAB_INLN		* print "? " and get BASIC input
						* return a0 pointing to the buffer start
	MOVEQ		#0,d0			* clear d0 (flag INPUT)
	TST.b		(a0)			* test first byte from buffer
	BNE.s		LAB_1953		* branch if not null input

	AND		#$FE,CCR		* was null input so clear carry to exit prog
	BRA		LAB_1647		* go do BREAK exit

* perform READ

LAB_READ
	MOVEA.l	Dptrl,a0		* get DATA pointer
	MOVEQ		#$98-$100,d0	* flag READ
LAB_1953
	MOVE.b	d0,Imode		* set input mode flag, $00=INPUT, $98=READ
	MOVE.l	a0,Rdptrl		* save READ pointer

						* READ or INPUT next variable from list
LAB_195B
	BSR		LAB_GVAR		* get (var) address
						* return pointer to variable in Cvaral and a0
	MOVE.l	a0,Lvarpl		* save variable address as LET variable
	MOVE.l	a5,-(sp)		* save BASIC execute pointer
	MOVEA.l	Rdptrl,a5		* set READ pointer as BASIC execute pointer
	BSR		LAB_GBYT		* scan memory
	BNE.s		LAB_1986		* branch if not null

						* pointer was to null entry
	TST.b		Imode			* test input mode flag, $00=INPUT, $98=READ
	BMI.s		LAB_19DD		* branch if READ (go find next statement)

						* mode was INPUT
	BSR		LAB_18E3		* print "?" character (double ? for extended input)
	BSR		LAB_INLN		* print "? " and get BASIC input
						* return a0 pointing to the buffer start
	TST.b		(a0)			* test first byte from buffer
	BNE.s		LAB_1984		* branch if not null input

	AND		#$FE,CCR		* was null input so clear carry to exit prog
	BRA		LAB_1647		* go do BREAK exit

LAB_1984
	MOVEA.l	a0,a5			* set BASIC execute pointer to buffer start
	SUBQ.w	#1,a5			* decrement pointer
LAB_1985
	BSR		LAB_IGBY		* increment & scan memory
LAB_1986
	TST.b		Dtypef		* test data type, $80=string, $40=integer, $00=float
	BPL.s		LAB_19B0		* branch if numeric

						* else get string
	MOVE.b	d0,d2			* save search character
	CMP.b		#$22,d0		* was it " ?
	BEQ.s		LAB_1999		* branch if so

	MOVEQ		#':',d2		* set new search character
	MOVEQ		#',',d0		* other search character is ","
	SUBQ.w	#1,a5			* decrement BASIC execute pointer
LAB_1999
	ADDQ.w	#1,a5			* increment BASIC execute pointer
	MOVE.b	d0,d3			* set second search character
	MOVEA.l	a5,a0			* BASIC execute pointer is source

	BSR		LAB_20B4		* print d2/d3 terminated string to FAC1 stack
						* d2 = Srchc, d3 = Asrch, a0 is source
	MOVEA.l	a2,a5			* copy end of string to BASIC execute pointer
	BSR		LAB_17D5		* go do string LET
	BRA.s		LAB_19B6		* go check string terminator

						* get numeric INPUT
LAB_19B0
	MOVE.b	Dtypef,-(sp)	* save variable data type
	BSR		LAB_2887		* get FAC1 from string
	MOVE.b	(sp)+,Dtypef	* restore variable data type
	BSR		LAB_PFAC		* pack FAC1 into (Lvarpl)
LAB_19B6
	BSR		LAB_GBYT		* scan memory
	BEQ.s		LAB_19C2		* branch if null (last entry)

	CMP.b		#',',d0		* else compare with ","
	BNE		LAB_1904		* if not "," go handle bad input data

	ADDQ.w	#1,a5			* else was "," so point to next chr
						* got good input data
LAB_19C2
	MOVE.l	a5,Rdptrl		* save read pointer for now
	MOVEA.l	(sp)+,a5		* restore execute pointer
	BSR		LAB_GBYT		* scan memory
	BEQ.s		LAB_1A03		* if null go do extra ignored message

	BSR		LAB_1C01		* scan for "," , else do syntax error/warm start
	BRA		LAB_195B		* go INPUT next variable from list

						* find next DATA statement or do "OD" error
LAB_19DD
	BSR		LAB_SNBS		* scan for next BASIC statement ([:] or [EOL])
						* returns a0 as pointer to [:] or [EOL]
	MOVEA.l	a0,a5			* add index, now = pointer to [EOL]/[EOS]
	ADDQ.w	#1,a5			* pointer to next character
	CMP.b		#':',d0		* was it statement end?
	BEQ.s		LAB_19F6		* branch if [:]

						* was [EOL] so find next line

	MOVE.w	a5,d1			* past pad byte(s)
	AND.w		#1,d1			* mask odd bit
	ADD.w		d1,a5			* add pointer
	MOVE.l	(a5)+,d2		* get next line pointer
	BEQ		LAB_ODER		* branch if end of program

	MOVE.l	(a5)+,Dlinel	* save current DATA line
LAB_19F6
	BSR		LAB_GBYT		* scan memory
	CMP.b		#TK_DATA,d0		* compare with "DATA" token
	BEQ		LAB_1985		* was "DATA" so go do next READ

	BRA.s		LAB_19DD		* go find next statement if not "DATA"

* end of INPUT/READ routine

LAB_1A03
	MOVEA.l	Rdptrl,a0		* get temp READ pointer
	TST.b		Imode			* get input mode flag, $00=INPUT, $98=READ
	BPL.s		LAB_1A0E		* branch if INPUT

	MOVE.l	a0,Dptrl		* else save temp READ pointer as DATA pointer
	RTS

						* we were getting INPUT
LAB_1A0E
	TST.b		(a0)			* test next byte
	BNE.s		LAB_1A1B		* error if not end of INPUT

	RTS
						* user typed too much
LAB_1A1B
	LEA		(LAB_IMSG,PC),a0	* point to extra ignored message
	BRA		LAB_18C3		* print null terminated string from memory & RTS

* perform NEXT

LAB_NEXT
	BNE.s		LAB_1A46		* branch if NEXT var

	MOVEA.w	#0,a0			* else clear a0
	BRA.s		LAB_1A49		* branch always (no variable to search for)

* NEXT var

LAB_1A46
	BSR		LAB_GVAR		* get variable address
						* return pointer to variable in Cvaral and a0
LAB_1A49
	MOVE.l	a0,Frnxtl		* store variable pointer
	BSR		LAB_11A1		* search the stack for FOR or GOSUB activity
						* exit with z=1 if FOR else exit with z=0
						* return modified stack in a2
	BNE		LAB_NFER		* if not found do next without for err/warm start

	MOVEA.l	a2,sp			* set stack pointer (dumps return addresses)
	MOVE.w	6(a2),FAC2_e	* get STEP value exponent and sign
	MOVE.l	8(a2),FAC2_m	* get STEP value mantissa

	MOVEA.l	Frnxtl,a0		* get FOR variable pointer
	MOVE.b	18(a2),Dtypef	* restore FOR variable data type
	BSR		LAB_1C19		* check type and unpack (a0)

	MOVE.b	FAC2_s,FAC_sc	* save FAC2 sign as sign compare
	MOVE.b	FAC1_s,d0		* get FAC1 sign
	EOR.b		d0,FAC_sc		* EOR to create sign compare

	BSR		LAB_ADD		* add STEP value to FOR variable
	MOVE.b	18(a2),Dtypef	* restore FOR variable data type (again)
	BSR		LAB_PFAC		* pack FAC1 into FOR variable

	MOVE.w	12(a2),FAC2_e	* get TO value exponent and sign
	MOVE.l	14(a2),FAC2_m	* get TO value mantissa

	MOVE.b	FAC2_s,FAC_sc	* save FAC2 sign as sign compare
	MOVE.b	FAC1_s,d0		* get FAC1 sign
	EOR.b		d0,FAC_sc		* EOR to create sign compare

	BSR		LAB_27FA		* compare FAC1 with FAC2 (TO value)
						* returns d0=+1 if FAC1 > FAC2
						* returns d0= 0 if FAC1 = FAC2
						* returns d0=-1 if FAC1 < FAC2

	MOVE.w	6(a2),d1		* get STEP value exponent and sign
	EOR.w		d0,d1			* EOR compare result with STEP (exponent and sign)

	TST.b		d0			* test for =
	BEQ.s		LAB_1A90		* branch if = (loop INcomplete)

	TST.b		d1			* test result
	BPL.s		LAB_1A9B		* branch if > (loop complete)

						* loop back and do it all again
LAB_1A90
	MOVE.l	20(a2),Clinel	* reset current line
	MOVE.l	24(a2),a5		* reset BASIC execute pointer
	BRA		LAB_15C2		* go do interpreter inner loop

						* loop complete so carry on
LAB_1A9B
	ADDA.w	#28,a2		* add 28 to dump FOR structure
	MOVEA.l	a2,sp			* copy to stack pointer
	BSR		LAB_GBYT		* scan memory
	CMP.b		#$2C,d0		* compare with ","
	BNE		LAB_15C2		* if not "," go do interpreter inner loop

						* was "," so another NEXT variable to do
	BSR		LAB_IGBY		* else increment & scan memory
	BSR		LAB_1A46		* do NEXT (var)

* evaluate expression & check is numeric, else do type mismatch

LAB_EVNM
	BSR.s		LAB_EVEX		* evaluate expression

* check if source is numeric, else do type mismatch

LAB_CTNM
	CMP.w		d0,d0			* required type is numeric so clear carry
	BRA.s		LAB_CKTM		* go check type match

* check if source is string, else do type mismatch

LAB_CTST
	ORI.b		#1,CCR		* required type is string so set carry

* type match check, set C for string, clear C for numeric

LAB_CKTM
	BTST.b	#7,Dtypef		* test data type flag, don't change carry
	BNE.s		LAB_1ABA		* branch if data type is string

						* else data type was numeric
	BCS		LAB_TMER		* if required type is string do type mismatch err

	RTS
						* data type was string, now check required type
LAB_1ABA
	BCC		LAB_TMER		* if required type is numeric do type mismatch error

	RTS

* evaluate expression

LAB_EVEX
	SUBQ.w	#1,a5			* decrement BASIC execute pointer
	MOVEQ		#0,d1			* clear precedence word
	BRA.s		LAB_1ACD		* enter loop

LAB_1ACC
	MOVE.w	d0,-(sp)		* push compare evaluation byte if branch to here
LAB_1ACD
	MOVE.w	d1,-(sp)		* push precedence word

*	MOVEQ		#$02,d0		* 2 bytes !!
*	BSR.s		LAB_1212		* check room on stack for d0 bytes

	BSR		LAB_GVAL		* get value from line
	MOVE.b	#$00,comp_f		* clear compare function flag
LAB_1ADB
	BSR		LAB_GBYT		* scan memory
LAB_1ADE
	SUB.b		#TK_GT,d0		* subtract token for > (lowest compare function)
	BCS.s		LAB_1AFA		* branch if < TK_GT

	CMP.b		#$03,d0		* compare with ">" to "<" tokens
	BCS.s		LAB_1AE0		* branch if < TK_SGN (is compare function)

	TST.b		comp_f		* test compare function flag
	BNE.s		LAB_1B2A		* branch if compare function

	BRA		LAB_1B78		* go do functions

						* was token for > = or < (d0 = 0, 1 or 2)
LAB_1AE0
	MOVEQ		#1,d1			* set to 0000 0001
	ASL.b		d0,d1			* 1 if >, 2 if =, 4 if <
	MOVE.b	comp_f,d0		* copy old compare function flag
	MOVE.b	d1,comp_f		* save this compare function bit
	EOR.b		d0,comp_f		* EOR in the old compare function flag
	CMP.b		comp_f,d0		* compare old with new compare function flag
	BCC		LAB_SNER		* if <=(new comp_f) do syntax error/warm start
						* was more than one <, = or >)
	BSR		LAB_IGBY		* increment & scan memory
	BRA.s		LAB_1ADE		* go do next character

						* token is < ">" or > "<" tokens
LAB_1AFA
	TST.b		comp_f		* test compare function flag
	BNE.s		LAB_1B2A		* branch if compare function

						* was <  TK_GT so is operator or lower
	ADD.b	#(TK_GT-TK_PLUS),d0	* add # of operators (+ - * / ^ AND OR EOR)
	BCC		LAB_1B78		* branch if < + operator

	BNE.s		LAB_1B0B		* branch if not + token

	TST.b		Dtypef		* test data type, $80=string, $40=integer, $00=float
	BMI		LAB_224D		* type is string & token was +

LAB_1B0B
	MULU		#6,d0			* *6
	MOVEQ		#0,d1			* clear longword
	MOVE.b	d0,d1			* copy to index
LAB_1B13
	MOVE.w	(sp)+,d0		* pull previous precedence
	LEA		(LAB_OPPT,PC),a0	* set pointer to operator table
	CMP.w		(a0,d1.w),d0	* compare with this opperator precedence
	BCC		LAB_1B7D		* branch if previous precedence (d0) >=

	BSR		LAB_CTNM		* check if source is numeric, else type mismatch
LAB_1B1C
	MOVE.w	d0,-(sp)		* save precedence
LAB_1B1D
	BSR.s		LAB_1B43		* get vector, set-up operator, continue evaluation
	MOVE.w	(sp)+,d0		* restore precedence
	MOVE.l	prstk,d1		* get stacked function pointer
	BPL.s		LAB_1B3C		* branch if stacked values

	MOVE.w	d0,d0			* copy precedence (set flags)
	BEQ.s		LAB_1B7B		* exit if done

	BRA		LAB_1B86		* else pop FAC2 & return (do function)

						* was compare function (< = >)
LAB_1B2A
	MOVE.b	Dtypef,d0		* get data type flag
	MOVE.b	comp_f,d1		* get compare function flag
*	LSL.b		#1,d0			* string bit flag into X bit
*	ROXL.b	#1,d1			* shift compare function flag

	ADD.b		d0,d0			* string bit flag into X bit
	ADDX.b	d1,d1			* shift compare function flag

	MOVE.b	#0,Dtypef		* clear data type flag, $00=float
	MOVE.b	d1,comp_f		* save new compare function flag
	SUBQ.w	#1,a5			* decrement BASIC execute pointer
	MOVEQ		#(TK_LT-TK_PLUS)*6,d1	* set offset to last operator entry
	BRA.s		LAB_1B13		* branch always

LAB_1B3C
	LEA		(LAB_OPPT,PC),a0	* point to function vector table
	CMP.w		(a0,d1.w),d0	* compare with this opperator precedence
	BCC.s		LAB_1B86		* branch if d0 >=, pop FAC2 & return

	BRA.s		LAB_1B1C		* branch always

* get vector, set up operator then continue evaluation

LAB_1B43
	LEA		(LAB_OPPT,PC),a0	* point to operator vector table
	MOVE.l	2(a0,d1.w),-(sp)	* put vector on stack
	BSR.s		LAB_1B56		* function set up will return here, then the
						* next RTS will call the function
	MOVE.b	comp_f,d0		* get compare function flag
	BRA		LAB_1ACC		* continue evaluating expression

LAB_1B56
	MOVE.b	FAC1_s,d0		* get FAC1 sign (b7)
	MOVE.w	(a0,d1.w),d1	* get precedence value
	MOVE.l	(sp)+,ut1_pl	* copy return address to utility pointer
	MOVE.b	d0,FAC1_s		* set sign
	MOVE.l	FAC1_m,-(sp)	* push FAC1 mantissa
	MOVE.w	FAC1_e,-(sp)	* push sign and exponent
	MOVE.l	ut1_pl,-(sp)	* push address
	RTS					* return

* do functions

LAB_1B78
	MOVEQ		#-1,d1		* flag all done
	MOVE.w	(sp)+,d0		* pull precedence word
LAB_1B7B
	BEQ.s		LAB_1B9D		* exit if done

LAB_1B7D
	CMP.w		#$64,d0		* compare previous precedence with $64
	BEQ.s		LAB_1B84		* branch if was $64 (< function can be string)

	BSR		LAB_CTNM		* check if source is numeric, else type mismatch
LAB_1B84
	MOVE.l	d1,prstk		* save current operator index

						* pop FAC2 & return
LAB_1B86
	MOVE.w	(sp)+,d0		* pop comparison evaluation
	MOVE.b	d0,d1			* copy comparison evaluation flag
	LSR.b		#1,d0			* shift out comparison evaluation lowest bit
	MOVE.b	d0,Cflag		* save comparison evaluation flag
	MOVE.w	(sp)+,FAC2_e	* pop exponent and sign
	MOVE.l	(sp)+,FAC2_m	* pop mantissa
	MOVE.b	FAC2_s,FAC_sc	* copy FAC2 sign
	MOVE.b	FAC1_s,d0		* get FAC1 sign
	EOR.b		d0,FAC_sc		* EOR FAC1 sign and set sign compare

	LSR.b		#1,d1			* type bit into X and C
	RTS

LAB_1B9D
	MOVE.b	FAC1_e,d0		* get FAC1 exponent
	RTS

* get value from line

LAB_GVAL
	MOVE.b	#$00,Dtypef		* clear data type flag, $00=float
LAB_1BA4
	BSR		LAB_IGBY		* increment & scan memory
	BCS		LAB_2887		* if numeric get FAC1 from string & return

	TST.b		d0			* test byte
	BMI		LAB_1BD0		* if -ve go test token values

						* else is either string, number, variable or (<expr>)
	CMP.b		#'$',d0		* compare with "$"
	BEQ		LAB_2887		* if "$" get hex number from string & return

	CMP.b		#'%',d0		* else compare with "%"
	BEQ		LAB_2887		* if "%" get binary number from string & return

	CMP.b		#$2E,d0		* compare with "."
	BEQ		LAB_2887		* if so get FAC1 from string & return (e.g. .123)

						* wasn't a number so ...
	CMP.b		#$22,d0		* compare with "
	BNE.s		LAB_1BF3		* if not open quote must be variable or open bracket

						* was open quote so get the enclosed string

* print "..." string to string stack

LAB_1BC1
	ADDQ.w	#1,a5			* increment basic execute pointer (past ")
	MOVEA.l	a5,a0			* copy basic execute pointer (string start)
	BSR		LAB_20AE		* print " terminated string to stack
	MOVEA.l	a2,a5			* restore BASIC execute pointer from temp
	RTS

* get value from line .. continued
						* wasn't any sort of number so ...
LAB_1BF3
	CMP.b		#'(',d0		* compare with "("
	BNE.s		LAB_1C18		* if not "(" get (var), return value in FAC1 & $ flag

	ADDQ.w	#1,a5			* increment execute pointer

* evaluate expression within parentheses

LAB_1BF7
	BSR		LAB_EVEX		* evaluate expression

* all the 'scan for' routines return the character after the sought character

* scan for ")" , else do syntax error, then warm start

LAB_1BFB
	MOVEQ		#$29,d0		* load d0 with ")"
	BRA.s		LAB_SCCA

* scan for "(" , else do syntax error, then warm start

LAB_1BFE
	MOVEQ		#$28,d0		* load d0 with "("
	BRA.s		LAB_SCCA

* scan for "," , else do syntax error, then warm start

LAB_1C01
	MOVEQ		#$2C,d0		* load d0 with ","

* scan for CHR$(d0) , else do syntax error, then warm start

LAB_SCCA
	CMP.b		(a5),d0		* check next byte is = d0
	BNE		LAB_SNER		* if not do syntax error/warm start

						* else get next BASIC byte

* BASIC increment and scan memory routine

LAB_IGBY
	ADDQ.w	#1,a5			* increment pointer

* scan memory routine, exit with Cb = 1 if numeric character
* also skips any spaces encountered

LAB_GBYT
	MOVE.b	(a5),d0		* get byte

	CMP.b		#$20,d0		* compare with " "
	BEQ.s		LAB_IGBY		* if " " go do next

* test current BASIC byte, exit with Cb = 1 if numeric character

LAB_TBYT
	CMP.b		#$3A,d0		* compare with ":"
	BCC.s		RTS_001		* exit if >= (not numeric, carry clear)

	SUBI.b	#$30,d0		* subtract "0"
	SUBI.b	#$D0,d0		* subtract -"0"
RTS_001					* carry set if byte = "0"-"9"
	RTS

* set-up for - operator

LAB_1C11
	MOVE.w	#(TK_GT-TK_PLUS)*6,d1	* set offset from base to - operator
LAB_1C13
	ADDQ.w	#4,sp			* dump GVAL return address
	BRA		LAB_1B1D		* continue evaluating expression

* variable name set-up
* get (var), return value in FAC_1 & data type flag

LAB_1C18
	BSR		LAB_GVAR		* get (var) address
						* return pointer to variable in Cvaral and a0
LAB_1C19
	TST.b		Dtypef		* test data type, $80=string, $40=integer, $00=float
	BEQ		LAB_UFAC		* if float unpack memory (a0) into FAC1 & return

	BPL.s		LAB_1C1A		* if integer unpack memory (a0) into FAC1 & return

	MOVE.l	a0,FAC1_m		* save address in FAC1
	RTS

LAB_1C1A
	MOVE.l	(a0),d0		* get integer value
	BRA		LAB_AYFC		* convert d0 to signed longword in FAC1 & return

* get value from line .. continued
* do tokens

LAB_1BD0
	CMP.b		#TK_MINUS,d0	* compare with token for -
	BEQ.s		LAB_1C11		* branch if - token (do set-up for - operator)

						* wasn't -123 so ...
	CMP.b		#TK_PLUS,d0		* compare with token for +
	BEQ		LAB_1BA4		* branch if + token (+n = n so ignore leading +)

	CMP.b		#TK_NOT,d0		* compare with token for NOT
	BNE.s		LAB_1BE7		* branch if not token for NOT

						* was NOT token
	MOVE.w	#(TK_EQUAL-TK_PLUS)*6,d1	* offset to NOT function
	BRA.s		LAB_1C13		* do set-up for function then execute

						* wasn't +, - or NOT so ...
LAB_1BE7
	CMP.b		#TK_FN,d0		* compare with token for FN
	BEQ		LAB_201E		* if FN go evaluate FNx

	CMP.b		#TK_POINT,d0	* compare with token for POINT
	BEQ		LAB_FPOINT		* if POINT go evaluate POINT(x,y)

						* wasn't +, -, NOT or FN so ...
	CMP.b		#TK_SGN,d0		* compare with token for SGN
	BCS		LAB_SNER		* if < SGN token then do syntax error

* get value from line .. 
* only functions left so ...
* set up function references

LAB_1C27
	AND.w		#$7F,d0		* normalise and mask byte
	ASL.w		#2,d0			* *4 (4 bytes per function address)
	MOVE.w	d0,-(sp)		* push offset
	MOVE.w	d0,d1			* copy offset
	BSR		LAB_IGBY		* increment & scan memory
	CMP.w	#(TK_CHRS-$80)*4+1,d1	* compare function offset to CHR$ token offset+1
	BCS.s		LAB_1C51		* branch if <HEX$ (can not be =)

* get value from line .. continued
* was HEX$, BIN$, VARPTR, LEFT$, RIGHT$ or MID$ so..

	CMP.w	#(TK_BINS-$80)*4+1,d1	* compare function offset to BIN$ token offset+1
	BCS.s		LAB_BHSS		* branch if <BITTST (can not be =)

	CMP.w	#(TK_VPTR-$80)*4+1,d1	* compare function offset VARPTR token offset+1
	BCS.s		LAB_1C54		* branch if <LEFT$ (can not be =)

* get value from line .. continued
* was LEFT$, RIGHT$ or MID$ so..

	BSR		LAB_1BFE		* scan for "(" , else do syntax error/warm start
	BSR		LAB_EVEX		* evaluate (should be string) expression
	BSR		LAB_1C01		* scan for "," , else do syntax error/warm start
	BSR		LAB_CTST		* check source is string, else do type mismatch
	MOVE.w	(sp)+,d7		* restore offset
	MOVE.l	FAC1_m,-(sp)	* push descriptor pointer
	MOVE.w	d7,-(sp)		* push function offset
	BSR		LAB_GTWO		* get word parameter, result in d0 and Itemp
	MOVE.w	(sp)+,d7		* restore offset
	MOVE.w	d0,-(sp)		* push word parameter
	MOVE.w	d7,d0			* function offset to d0
	BRA.s		LAB_1C56		* go call function

* get value from line .. continued
* was BIN$ or HEX$ so ..

LAB_BHSS
	BSR		LAB_1BFE		* scan for "(" , else do syntax error/warm start
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	BSR		LAB_GBYT		* get next BASIC byte
	MOVEQ		#0,d1			* set default to no leading "0"s
	CMP.b		#')',d0		* compare with close bracket
	BEQ.s		LAB_1C54		* if ")" go do rest of function

	MOVE.l	Itemp,-(sp)		* copy longword to stack (number)
	BSR		LAB_SCGB		* scan for "," and get byte value
	MOVE.l	d0,d1			* copy leading 0s #
	BSR		LAB_GBYT		* get next BASIC byte
	CMP.b		#')',d0		* is next character )
	BNE		LAB_FCER		* if not ")" do function call error/warm start

	MOVE.l	(sp)+,Itemp		* restore number form stack
	BRA.s		LAB_1C54		* go do rest of function

* get value from line .. continued
* was SGN() to CHR$() so..

LAB_1C51
	BSR		LAB_1BFE		* scan for "(" , else do syntax error/warm start
	BSR		LAB_1BF7		* evaluate expression within parentheses

						* enter here if VARPTR(), MAX() or MIN()
LAB_1C54
	MOVE.w	(sp)+,d0		* get offset back
LAB_1C56
	LEA		(LAB_FTBL,PC),a0	* pointer to functions vector table
	MOVEA.l	(a0,d0.w),a0	* get function vector
	JSR		(a0)			* go do function vector
	BRA		LAB_CTNM		* check if source is numeric & RTS, else do
						* type mismatch
* perform EOR

LAB_EOR
	BSR.s		GetFirst		* get two values for OR, AND or EOR
						* first in d0, and Itemp, second in d2
	EOR.l		d2,Itemp		* EOR with first value
	MOVE.l	Itemp,d0		* get result
	BRA		LAB_AYFC		* convert d0 to signed longword in FAC1 & RET

* perform OR

LAB_OR
	BSR.s		GetFirst		* get two values for OR, AND or EOR
						* first in d0, and Itemp, second in d2
	OR.l		d2,d0			* do OR
	BRA		LAB_AYFC		* convert d0 to signed longword in FAC1 & RET

* perform AND

LAB_AND
	BSR.s		GetFirst		* get two values for OR, AND or EOR
						* first in d0, and Itemp, second in d2
	AND.l		d2,d0			* do AND
	BRA		LAB_AYFC		* convert d0 to signed longword in FAC1 & RET

* get two values for OR, AND, EOR
* first in d0, second in d2

GetFirst
	BSR		LAB_EVIR		* evaluate integer expression (no sign check)
						* result in d0 and Itemp
	MOVE.l	d0,d2			* copy second value
	BSR		LAB_279B		* copy FAC2 to FAC1 (get 1st value in expression)
	BSR		LAB_EVIR		* evaluate integer expression (no sign check)
						* result in d0 and Itemp
	RTS

* perform NOT

LAB_EQUAL
	BSR		LAB_EVIR		* evaluate integer expression (no sign check)
						* result in d0 and Itemp
	NOT.l		d0			* bitwise invert
	BRA		LAB_AYFC		* convert d0 to signed longword in FAC1 & RET

* perform comparisons
* do < compare

LAB_LTHAN
	BSR		LAB_CKTM		* type match check, set C for string
	BCS.s		LAB_1CAE		* branch if string

						* do numeric < compare
	BSR		LAB_27FA		* compare FAC1 with FAC2
						* returns d0=+1 if FAC1 > FAC2
						* returns d0= 0 if FAC1 = FAC2
						* returns d0=-1 if FAC1 < FAC2
	BRA.s		LAB_1CF2		* process result

						* do string < compare
LAB_1CAE
	MOVE.b	#$00,Dtypef		* clear data type, $80=string, $40=integer, $00=float
	BSR		LAB_22B6		* pop string off descriptor stack, or from top of
						* string space returns d0 = length, a0 = pointer
	MOVEA.l	a0,a1			* copy string 2 pointer
	MOVE.l	d0,d1			* copy string 2 length
	MOVEA.l	FAC2_m,a0		* get string 1 descriptor pointer
	BSR		LAB_22BA		* pop (a0) descriptor, returns with ..
						* d0 = length, a0 = pointer
	MOVE.l	d0,d2			* copy length
	BNE.s		LAB_1CB5		* branch if not null string

	TST.l		d1			* test if string 2 is null also
	BEQ.s		LAB_1CF2		* if so do string 1 = string 2

LAB_1CB5
	SUB.l		d1,d2			* subtract string 2 length
	BEQ.s		LAB_1CD5		* branch if strings = length

	BCS.s		LAB_1CD4		* branch if string 1 < string 2

	MOVEQ		#-1,d0		* set for string 1 > string 2
	BRA.s		LAB_1CD6		* go do character comapare

LAB_1CD4
	MOVE.l	d0,d1			* string 1 length is compare length
	MOVEQ		#1,d0			* and set for string 1 < string 2
	BRA.s		LAB_1CD6		* go do character comapare

LAB_1CD5
	MOVE.l	d2,d0			* set for string 1 = string 2
LAB_1CD6
	SUBQ.l	#1,d1			* adjust length for DBcc loop

						* d1 is length to compare, d0 is < = > for length
						* a0 is string 1 pointer, a1 is string 2 pointer
LAB_1CE6
	CMPM.b	(a0)+,(a1)+		* compare string bytes (1 with 2)
	DBNE		d1,LAB_1CE6		* loop if same and not end yet

	BEQ.s		LAB_1CF2		* if = to here, then go use length compare

	BCC.s		LAB_1CDB		* else branch if string 1 > string 2

	MOVEQ		#-1,d0		* else set for string 1 < string 2
	BRA.s		LAB_1CF2		* go set result

LAB_1CDB
	MOVEQ		#1,d0			* and set for string 1 > string 2

LAB_1CF2
	ADDQ.l	#1,d0			* make result 0, 1 or 2
	MOVE.l	d0,d1			* copy to d1
	MOVEQ		#1,d0			* set d0
	ROL.l		d1,d0			* make 1, 2 or 4 (result = flag bit)
	AND.b		Cflag,d0		* AND with comparison evaluation flag
	BEQ		LAB_27DB		* exit if not a wanted result (i.e. false)

	MOVEQ		#-1,d0		* else set -1 (true)
	BRA		LAB_27DB		* save d0 as integer & return


LAB_1CFE
	BSR		LAB_1C01		* scan for "," , else do syntax error/warm start

* perform DIM

LAB_DIM
	MOVEQ		#-1,d1		* set "DIM" flag
	BSR.s		LAB_1D10		* search for variable
	BSR		LAB_GBYT		* scan memory
	BNE.s		LAB_1CFE		* loop and scan for "," if not null

	RTS

* perform << (left shift)

LAB_LSHIFT
	BSR.s		GetPair		* get an integer and byte pair
						* byte is in d2, integer is in d0 and Itemp
	BEQ.s		NoShift		* branch if byte zero

	CMP.b		#$20,d2		* compare bit count with 32d
	BCC.s		TooBig		* branch if >=

	ASL.l		d2,d0			* shift longword
NoShift
	BRA		LAB_AYFC		* convert d0 to signed longword in FAC1 & RET

* perform >> (right shift)

LAB_RSHIFT
	BSR.s		GetPair		* get an integer and byte pair
						* byte is in d2, integer is in d0 and Itemp
	BEQ.s		NoShift		* branch if byte zero

	CMP.b		#$20,d2		* compare bit count with 32d
	BCS.s		Not2Big		* branch if >= (return shift)

	TST.l		d0			* test sign bit
	BPL.s		TooBig		* branch if +ve

	MOVEQ		#-1,d0		* set longword
	BRA		LAB_AYFC		* convert d0 to longword in FAC1 & RET

Not2Big
	ASR.l		d2,d0			* shift longword
	BRA		LAB_AYFC		* convert d0 to longword in FAC1 & RET

TooBig
	MOVEQ		#0,d0			* clear longword
	BRA		LAB_AYFC		* convert d0 to longword in FAC1 & RET

* get an integer and byte pair
* byte is in d2, integer is in d0 and Itemp

GetPair
	BSR		LAB_EVBY		* evaluate byte expression, result in d0 and Itemp
	MOVE.b	d0,d2			* save it
	BSR		LAB_279B		* copy FAC2 to FAC1 (get 1st value in expression)
	BSR		LAB_EVIR		* evaluate integer expression (no sign check)
						* result in d0 and Itemp
	TST.b	d2				* test byte value
	RTS

* check byte, return C=0 if<"A" or >"Z" or <"a" to "z">

LAB_CASC
	CMP.b		#$61,d0		* compare with "a"
	BCC.s		LAB_1D83		* if >="a" go check =<"z"

* check byte, return C=0 if<"A" or >"Z"

LAB_1D82
	CMP.b		#$5B,d0		* compare with "Z"+1
	BCS.s		LAB_1D8A		* if <="Z" go check >="A"

	RTS

LAB_1D8A
	SUB.b		#$41,d0		* subtract "A"
	SUB.b		#$BF,d0		* subtract $BF (restore byte)
						* carry set if byte>$40
	RTS

LAB_1D83
	ADD.b		#$85,d0		* add $85
	ADD.b		#$7B,d0		* add "z"+1 (restore byte)
						* carry set if byte<=$7A
	RTS

* search for variable
* DIM flag is in d1.b
* return pointer to variable in Cvaral and a0
* stet data type to variable type

LAB_GVAR
	MOVEQ		#$00,d1		* set DIM flag = $00
	BSR		LAB_GBYT		* scan memory (1st character)
LAB_1D10
	MOVE.b	d1,Defdim		* save DIM flag

* search for FN name entry point

LAB_1D12
	BSR.s		LAB_CASC		* check byte, return C=0 if<"A" or >"Z"
	BCC		LAB_SNER		* if not syntax error, then warm start

						* is variable name so ...
	MOVEQ		#$0,d1		* set index for name byte
	MOVEA.l	#Varname,a0		* pointer to variable name
	MOVE.l	d1,(a0)		* clear variable name
	MOVE.b	d1,Dtypef		* clear data type, $80=string, $40=integer, $00=float

LAB_1D2D
	CMP.w		#$04,d1		* done all significant characters?
	BCC.s		LAB_1D2E		* if so go ignore any more

	MOVE.b	d0,(a0,d1.w)	* save character
	ADDQ.w	#1,d1			* increment index
LAB_1D2E
	BSR		LAB_IGBY		* increment & scan memory (next character)
	BCS.s		LAB_1D2D		* branch if character = "0"-"9" (ok)

						* character wasn't "0" to "9" so ...
	BSR.s		LAB_CASC		* check byte, return C=0 if<"A" or >"Z"
	BCS.s		LAB_1D2D		* branch if = "A"-"Z" (ok)

						* check if string variable
	CMP.b		#'$',d0		* compare with "$"
	BNE.s		LAB_1D44		* branch if not string

						* type is string
	OR.b		#$80,Varname+1	* set top bit of 2nd character (indicate string)
	BSR		LAB_IGBY		* increment & scan memory
	BRA.s		LAB_1D45		* skip integer check

						* check if integer variable
LAB_1D44
	CMP.b		#'&',d0		* compare with "&"
	BNE.s		LAB_1D45		* branch if not integer

						* type is integer
	OR.b		#$80,Varname+2	* set top bit of 3rd character (indicate integer)
	BSR		LAB_IGBY		* increment & scan memory

* after we have determined the variable type we need to determine
* if it's an array of type

						* gets here with character after var name in d0
LAB_1D45
	TST.b		Sufnxf		* test function name flag
	BEQ.s		LAB_1D48		* branch if not FN or FN variable

	BPL.s		LAB_1D49		* branch if FN variable

						* else was FN name
	MOVE.l	Varname,d0		* get whole function name
	MOVEQ		#8,d1			* set step to next function size -4
	MOVEA.l	#Sfncl,a0		* get pointer to start of functions
	BRA.s		LAB_1D4B		* go find function

LAB_1D48
	SUB.b		#'(',d0		* subtract "("
	BEQ		LAB_1E17		* if "(" go find, or make, array

* either find or create var
* var name (1st four characters only!) is in Varname

						* variable name wasn't var( .. look for plain var
LAB_1D49
	MOVE.l	Varname,d0		* get whole variable name
LAB_1D4A
	MOVEQ		#4,d1			* set step to next variable size -4
	MOVEA.l	#Svarl,a0		* get pointer to start of variables

	BTST.l	#23,d0		* test if string name
	BEQ.s		LAB_1D4B		* branch if not

	ADDQ.w	#2,d1			* 10 bytes per string entry
	ADDQ.w	#(Sstrl-Svarl),a0	* move to string area

LAB_1D4B
	MOVEA.l	4(a0),a1		* get end address
	MOVEA.l	(a0),a0		* get start address
	BRA.s		LAB_1D5E		* enter loop at exit check

LAB_1D5D
	CMP.l		(a0)+,d0		* compare this variable with name
	BEQ.s		LAB_1DD7		* branch if match (found var)

	ADDA.l	d1,a0			* add offset to next variable
LAB_1D5E
	CMPA.l	a1,a0			* compare address with variable space end
	BNE.s		LAB_1D5D		* if not end go check next

						* reached end of variable mem without match
						* ... so create new variable, possibly
	CMPI.l	#LAB_1C19,(sp)	* compare return address with expected
	BEQ		LAB_UVER		* if RHS get (var) go do error or return null

* This will only branch if the call was from LAB_1C18 and is only called from
* there if it is searching for a variable from the RHS of a LET a=b statement

	BTST.b	#0,Sufnxf		* test function search flag
	BNE		LAB_UFER		* if not doing DEF then do undefined function error

						* else create new variable/function
LAB_1D98
	MOVEA.l	Earryl,a2		* get end of block to move
	MOVE.l	a2,d2			* copy end of block to move
	SUB.l		a1,d2			* calculate block to move size

	MOVEA.l	a2,a0			* copy end of block to move
	ADDQ.l	#4,d1			* space for one variable/function + name
	ADDA.l	d1,a2			* add space for one variable/function
	MOVE.l	a2,Earryl		* set new array mem end
	LSR.l		#1,d2			* /2 for word copy
	BEQ.s		LAB_1DAF		* skip move if zero length block

	SUBQ.w	#1,d2			* -1 for DFB loop
LAB_1DAE
	MOVE.w	-(a0),-(a2)		* copy word
	DBF		d2,LAB_1DAE		* loop until done

* get here after creating either a function, variable or string
* if function set variables start, string start, array start
* if variable set string start, array start
* if string set array start

LAB_1DAF
	TST.b		Sufnxf		* was it function
	BMI.s		LAB_1DB0		* branch if was FN

	BTST.l	#23,d0		* was it string
	BNE.s		LAB_1DB2		* branch if string

	BRA.s		LAB_1DB1		* branch if was plain variable

LAB_1DB0
	ADD.l		d1,Svarl		* set new variable memory start
LAB_1DB1
	ADD.l		d1,Sstrl		* set new start of strings
LAB_1DB2
	ADD.l		d1,Sarryl		* set new array memory start
	MOVE.l	d0,(a0)+		* save variable/function name
	MOVE.l	#$00,(a0)		* initialise variable
	BTST.l	#23,d0		* was it string
	BEQ.s		LAB_1DD7		* branch if not string

	MOVE.w	#$00,4(a0)		* else initialise string length

						* found a match for var ((Vrschl) = ptr)
LAB_1DD7
	MOVE.b	#$00,Dtypef		* clear data type
	BTST.l	#23,d0		* was it string
	BEQ.s		LAB_1DD8		* branch if not string

	MOVE.b	#$80,Dtypef		* set data type = string
	BRA.s		LAB_1DD9		* skip intger test

LAB_1DD8
	BTST.l	#15,d0		* was it integer
	BEQ.s		LAB_1DD9		* branch if not integer

	MOVE.b	#$40,Dtypef		* set data type = integer
LAB_1DD9
	MOVE.l	a0,Cvaral		* save current variable/function value address
	MOVE.b	#$00,Sufnxf		* clear FN flag byte
	RTS

* set-up array pointer, Adatal, to first element in array
* set Adatal to Astrtl+2*Dimcnt+#$0A

LAB_1DE6
	MOVEQ		#0,d0			* clear d0
	MOVE.b	Dimcnt,d0		* get # of dimensions (1, 2 or 3)
	ADDQ.l	#5,d0			* +5 (actually 10d but addq is quicker)
	ADD.l		d0,d0			* *2 (bytes per dimension size)
	ADD.l		a0,d0			* add array start pointer
	MOVE.l	d0,Adatal		* save array data pointer
	RTS

* evaluate unsigned integer expression

LAB_EVIN
	BSR		LAB_IGBY		* increment & scan memory
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch

* evaluate positive integer expression, result in d0 and Itemp

LAB_EVPI
	TST.b		FAC1_s		* test FAC1 sign (b7)
	BMI		LAB_FCER		* do function call error if -ve

* evaluate integer expression, no sign check, result in d0 and Itemp

LAB_EVIR
	CMPI.b	#$A0,FAC1_e		* compare exponent with exponent = 2^32 (n>2^31)
	BCS		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	BNE		LAB_FCER		* if > do function call error, then warm start

	TST.b		FAC1_s		* test sign of FAC1
	BPL.s		LAB_EVIX		* if = and +ve then ok

	MOVE.l	FAC1_m,d0		* get mantissa
	CMP.l		#$80000000,d0	* compare -2147483648 with mantissa
	BNE		LAB_FCER		* if <> do function call error, then warm start

LAB_EVIX
	MOVE.l	d0,Itemp		* else just set it
	RTS

* find or make array

LAB_1E17
	MOVE.w	Defdim,-(sp)	* get DIM flag and data type flag (word in mem)
	MOVEQ		#0,d1			* clear dimensions count

* now get the array dimension(s) and stack it (them) before the data type and DIM flag

LAB_1E1F
	MOVE.w	d1,-(sp)		* save dimensions count
	MOVE.l	Varname,-(sp)	* save variable name
	BSR.s		LAB_EVIN		* evaluate integer expression
	MOVE.l	(sp)+,Varname	* restore variable name
	MOVE.w	(sp)+,d1		* restore dimensions count
	MOVE.w	(sp)+,d0		* restore DIM and data type flags
	MOVE.w	Itemp+2,-(sp)	* stack this dimension size
	MOVE.w	d0,-(sp)		* save DIM and data type flags
	ADDQ.w	#1,d1			* increment dimensions count
	BSR		LAB_GBYT		* scan memory
	CMP.b		#$2C,d0		* compare with ","
	BEQ.s		LAB_1E1F		* if found go do next dimension

	MOVE.b	d1,Dimcnt		* store dimensions count
	BSR		LAB_1BFB		* scan for ")" , else do syntax error/warm start
	MOVE.w	(sp)+,Defdim	* restore DIM and data type flags (word in mem)
	MOVEA.l	Sarryl,a0		* get array mem start

* now check to see if we are at the end of array memory (we would be if there were
* no arrays).

LAB_1E5C
	MOVE.l	a0,Astrtl		* save as array start pointer
	CMPA.l	Earryl,a0		* compare with array mem end
	BEQ.s		LAB_1EA1		* go build array if not found

						* search for array
	MOVE.l	(a0),d0		* get this array name
	CMP.l		Varname,d0		* compare with array name
	BEQ.s		LAB_1E8D		* array found so branch

						* no match
	MOVEA.l	4(a0),a0		* get this array size
	ADDA.l	Astrtl,a0		* add to array start pointer
	BRA.s		LAB_1E5C		* go check next array

						* found array, are we trying to dimension it?
LAB_1E8D
	TST.b		Defdim		* are we trying to dimension it?
	BNE		LAB_DDER		* if so do  double dimension error/warm start

* found the array and we're not dimensioning it so we must find an element in it

	BSR		LAB_1DE6		* set data pointer, Adatal, to the first element
						* in the array. Astrtl (and a0) points to the
						* start of the array
	ADDQ.w	#8,a0			* index to dimension count
	MOVE.w	(a0)+,d0		* get no of dimensions
	CMP.b		Dimcnt,d0		* compare with dimensions count
	BEQ		LAB_1F28		* found array so go get element

	BRA		LAB_WDER		* else wrong so do "Wrong dimensions" error

						* array not found, so build it
LAB_1EA1
	BSR		LAB_1DE6		* set data pointer, Adatal, to the first element
						* in the array. Astrtl (and a0) points to the
						* start of the array
	BSR		LAB_121F		* check available memory, "Out of memory" error
						* if no room, addr to check is in a0
	MOVEA.l	Astrtl,a0		* get array start pointer
	MOVE.l	Varname,d0		* get array name
	MOVE.l	d0,(a0)+		* save array name
	MOVEQ		#4,d1			* set 4 bytes per element
	BTST.l	#23,d0		* test if string array
	BEQ.s		LAB_1EDF		* branch if not string

	MOVEQ		#6,d1			* else 6 bytes per element
LAB_1EDF
	MOVE.l	d1,Asptl		* set array data size (bytes per element)
*	MOVEQ		#0,d1			* clear d1 (only byte is used so skip this)
	MOVE.b	Dimcnt,d1		* get dimensions count
	ADDQ.w	#4,a0			* skip the array size now (don't know it yet!)
	MOVE.w	d1,(a0)+		* set array's dimensions count

	TST.b		Defdim		* test default DIM flag
	BEQ		LAB_UDER		* if default flag is clear then we are on the
						* LHS of = with no array so go do "Undimensioned
						* array" error.
						* now calculate the array data space size
LAB_1EC0

* If you want arrays to dimension themselves by default then comment out the test
* above and uncomment the next three code lines and the label LAB_1ED0

*	MOVE.w	#$0B,d1		* set default dimension value (allow 0 to 10)
*	TST.b		Defdim		* test default DIM flag
*	BNE.s		LAB_1ED0		* branch if b6 of Defdim is clear

	MOVE.w	(sp)+,d1		* get dimension size
	ADDQ.w	#1,d1			* +1 to allow 0 to n

*LAB_1ED0
	MOVE.w	d1,(a0)+		* save to array header
	BSR		LAB_1F7C		* do this dimension size (d1) * array size (Asptl)
						* result in d0
	MOVE.l	d0,Asptl		* save array data size
	SUBQ.b	#1,Dimcnt		* decrement dimensions count
	BNE.s		LAB_1EC0		* loop while not = 0

	ADDA.l	Asptl,a0		* add size to first element address
	BCS		LAB_OMER		* if overflow go do "Out of memory" error

	BSR		LAB_121F		* check available memory, "Out of memory" error
						* if no room, addr to check is in a0
	MOVE.l	a0,Earryl		* save array mem end
	MOVEQ		#0,d0			* zero d0
	MOVE.l	asptl,d1		* get size in bytes
	LSR.l		#1,d1			* /2 for word fill (may be odd # words)
	SUBQ.w	#1,d1			* adjust for DBF loop
LAB_1ED8
	MOVE.w	d0,-(a0)		* decrement pointer and clear word
	DBF		d1,LAB_1ED8		* decrement & loop until low word done

	SWAP		d1			* swap words
	TST.w		d1			* test high word
	BEQ.s		LAB_1F07		* exit if done

	SUBQ.w	#1,d1			* decrement low (high) word
	SWAP		d1			* swap back
	BRA.s		LAB_1ED8		* go do a whole block

* now we need to calculate the array size by doing Earryl - Astrtl

LAB_1F07
	MOVEA.l	Astrtl,a0		* get for calculation and as pointer
	MOVE.l	Earryl,d0		* get array memory end
	SUB.l		a0,d0			* calculate array size
	MOVE.l	d0,4(a0)		* save size to array
	TST.b		Defdim		* test default DIM flag
	BNE.s		RTS_011		* exit (RET) if this was a DIM command

						* else, find element
	ADDQ.w	#8,a0			* index to dimension count
	MOVE.w	(a0)+,Dimcnt	* get array's dimension count

* we have found, or built, the array. now we need to find the element

LAB_1F28
	MOVEQ		#0,d0			* clear first result
	MOVE.l	d0,Asptl		* clear array data pointer

* compare nth dimension bound (a0) with nth index (sp)+
* if greater do array bounds error

LAB_1F2C
	MOVE.w	(a0)+,d1		* get nth dimension bound
	CMP.w		(sp),d1		* compare nth index with nth dimension bound
	BLE		LAB_ABER		* if d1 less or = do array bounds error

* now do pointer = pointer * nth dimension + nth index

	TST.l		d0			* test pointer
	BEQ.s		LAB_1F5A		* skip multiply if last result = null

	BSR.s		LAB_1F7C		* do this dimension size (d1) * array size (Asptl)
LAB_1F5A
	MOVEQ		#0,d1			* clear longword
	MOVE.w	(sp)+,d1		* get nth dimension index
	ADD.l		d1,d0			* add index to size
	MOVE.l	d0,Asptl		* save array data pointer

	SUBQ.b	#1,Dimcnt		* decrement dimensions count
	BNE.s		LAB_1F2C		* loop if dimensions still to do

	MOVE.b	#0,Dtypef		* set data type to float
	MOVEQ		#4,d1			* set for numeric array
	TST.b		Varname+1		* test if string array
	BPL.s		LAB_1F6A		* branch if not string

	MOVEQ		#6,d1			* else set for string array
	MOVE.b	#$80,Dtypef		* and set data type to string
	BRA.s		LAB_1F6B		* skip integer test

LAB_1F6A
	TST.b		Varname+2		* test if integer array
	BPL.s		LAB_1F6B		* branch if not integer

	MOVE.b	#$40,Dtypef		* else set data type to integer
LAB_1F6B
	BSR.s		LAB_1F7C		* do element size (d1) * array size (Asptl)
	ADDA.l	d0,a0			* add array data start pointer
	MOVE.l	a0,Cvaral		* save current variable address
RTS_011
	RTS

* does d0 = (Astrtl),Y * (Asptl)
* do this dimension size (d1) * array data size (Asptl)

LAB_1F7C

* do a 16 x 32 bit multiply
* d1 holds the 16 bit multiplier
* Asptl holds the 32 bit multiplicand

* d0	bbbb  bbbb
* d1	0000  aaaa
*	----------
* d0	rrrr  rrrr

	MOVE.l	asptl,d0		* get result
	MOVE.l	d0,d2			* copy it
	CLR.w		d2			* clear low word
	SUB.l		d2,d0			* clear high word
	SWAP		d2			* shift high word to low word
	MULU		d1,d0			* low result
	MULU		d1,d2			* high result
	SWAP		d2			* align words for test
	TST.w		d2			* must be zero
	BNE		LAB_OMER		* if overflow go do "Out of memory" error

	ADD.l		d2,d0			* calculate result
	BCS		LAB_OMER		* if overflow go do "Out of memory" error

	RTS

* perform FRE()

LAB_FRE
	TST.b		Dtypef		* test data type, $80=string, $40=integer, $00=float
	BPL.s		LAB_1FB4		* branch if numeric

	BSR		LAB_22B6		* pop string off descriptor stack, or from top of
						* string space, returns d0 = length, a0 = pointer

						* FRE(n) was numeric so do this
LAB_1FB4
	BSR		LAB_GARB		* go do garbage collection
	MOVE.l	Sstorl,d0		* get bottom of string space
	SUB.l		Earryl,d0		* subtract array mem end

* convert d0 to signed longword in FAC1

LAB_AYFC
	MOVE.b	#$00,Dtypef		* clear data type, $80=string, $40=integer, $00=float
	MOVE.w	#$A000,FAC1_e	* set FAC1 exponent and clear sign (b7)
	MOVE.l	d0,FAC1_m		* save FAC1 mantissa
	BPL		LAB_24D0		* convert if +ve

	ORI.b		#1,CCR		* else set carry
	BRA		LAB_24D0		* do +/- (carry is sign) & normalise FAC1

* remember if the line length is zero (infinite line) then POS(n) will return
* position MOD tabsize

* perform POS()

LAB_POS
	MOVE.b	TPos,d0		* get terminal position

* convert d0 to unsigned byte in FAC1

LAB_1FD0
	AND.l		#$FF,d0		* clear high bits
	BRA.s		LAB_AYFC		* convert d0 to signed longword in FAC1 & RET

* check not Direct (used by DEF and INPUT)

LAB_CKRN
	MOVE.l	Clinel,d1		* get current line #
	ADDQ.l	#1,d1			* increment line #
	BEQ		LAB_IDER		* if 0 go do illegal direct error then warm start

	RTS					* can continue so return

* perform DEF

LAB_DEF
	MOVEQ		#TK_FN-$100,d0	* get FN token
	BSR		LAB_SCCA		* scan for CHR$(d0) , else syntax error/warm start
						* return character after d0
	MOVE.b	#$80,Sufnxf		* set FN flag bit
	BSR		LAB_1D12		* get FN name
	MOVE.l	a0,func_l		* save function pointer

	BSR.s		LAB_CKRN		* check not Direct (back here if ok)
	BSR		LAB_1BFE		* scan for "(" , else do syntax error/warm start
	MOVE.b	#$7E,Sufnxf		* set FN variable flag bits
	BSR		LAB_GVAR		* get/create function variable address
						* return pointer to variable in Cvaral and a0
	MOVEQ		#0,d0			* set zero to clear variable
	MOVE.l	d0,(a0)+		* clear variable
	TST.b		Dtypef		* test data type
	BPL.s		LAB_DEFV		* branch if numeric variable

	MOVE.w	d0,(a0)		* else clear string length
LAB_DEFV
	BSR		LAB_1BFB		* scan for ")" , else do syntax error/warm start
	MOVEQ		#TK_EQUAL-$100,d0	* = token
	BSR		LAB_SCCA		* scan for CHR$(A), else syntax error/warm start
						* return character after d0
	MOVE.l	Varname,-(sp)	* push current variable name
	MOVE.l	a5,-(sp)		* push BASIC execute pointer
	BSR		LAB_DATA		* go perform DATA (find end of DEF FN statement)
	MOVEA.l	func_l,a0		* get pointer
	MOVE.l	(sp)+,(a0)		* save BASIC execute pointer to function
	MOVE.l	(sp)+,4(a0)		* save current variable name to function
	RTS

* evaluate FNx

LAB_201E
	MOVE.b	#$81,Sufnxf		* set FN flag (find not create)
	BSR		LAB_IGBY		* increment & scan memory
	BSR		LAB_1D12		* get FN name
	MOVE.b	Dtypef,-(sp)	* push data type flag (function type)
	MOVE.l	a0,-(sp)		* push function pointer
	BSR		LAB_1BFE		* scan for "(" , else do syntax error/warm start
	BSR		LAB_1BF7		* evaluate expression within parentheses
	MOVEA.l	(sp)+,a0		* pop function pointer
	MOVE.l	a0,func_l		* set function pointer
	MOVE.b	Dtypef,-(sp)	* push data type flag (function expression type)

	MOVE.l	4(a0),d0		* get function variable name
	BSR		LAB_1D4A		* go find function variable (already created)

						* now check type match for variable
	MOVE.b	(sp)+,d0		* pop data type flag (function expression type)
	ROL.b		#1,d0			* set carry if type = string
	BSR		LAB_CKTM		* type match check, set C for string

						* now stack the function variable value before use
	BEQ.s		LAB_2043		* branch if not string

	CMPA.l	#des_sk_e,a4	* compare string stack pointer with max+1
	BEQ		LAB_SCER		* if no space on stack do string too complex error

	MOVE.w	4(a0),-(a4)		* string length on descriptor stack
	MOVE.l	(a0),-(a4)		* string address on stack
	BRA.s		LAB_204S		* skip var push

LAB_2043
	MOVE.l	(a0),-(sp)		* push variable
LAB_204S
	MOVE.l	a0,-(sp)		* push variable address
	MOVE.b	Dtypef,-(sp)	* push variable data type

	BSR.s		LAB_2045		* pack function expression value into (a0)
						* (function variable)
	MOVE.l	a5,-(sp)		* push BASIC execute pointer
	MOVEA.l	func_l,a0		* get function pointer
	MOVEA.l	(a0),a5		* save function execute ptr as BASIC execute ptr
	MOVE.l	Cvaral,-(sp)	* push variable address
	BSR		LAB_EVEX		* evaluate expression
	MOVE.l	(sp)+,Cvaral	* pull variable address
	BSR		LAB_GBYT		* scan memory
	BNE		LAB_SNER		* if not [EOL] or [EOS] do syntax error/warm start

	MOVE.l	(sp)+,a5		* restore BASIC execute pointer

* restore variable from stack and test data type

	MOVE.b	(sp)+,d0		* pull variable data type
	MOVEA.l	(sp)+,a0		* pull variable address
	TST.b		d0			* test variable data type
	BPL.s		LAB_204T		* branch if not string

	MOVE.l	(a4)+,(a0)		* string address from descriptor stack
	MOVE.w	(a4)+,4(a0)		* string length from descriptor stack
	BRA.s		LAB_2044		* skip variable pull

LAB_204T
	MOVE.l	(sp)+,(a0)		* restore variable from stack
LAB_2044
	MOVE.b	(sp)+,d0		* pop data type flag (function type)
	ROL.b		#1,d0			* set carry if type = string
	BSR		LAB_CKTM		* type match check, set C for string
	RTS

LAB_2045
	TST.b		Dtypef		* test data type
	BPL		LAB_2778		* if numeric pack FAC1 into variable (a0) & return

	MOVEA.l	a0,a2			* copy variable pointer
	BRA		LAB_17D6		* go do string LET & return


* perform STR$()

LAB_STRS
	BSR		LAB_CTNM		* check if source is numeric, else type mismatch
	BSR		LAB_2970		* convert FAC1 to string
	ADDQ.w	#4,sp			* skip return type check

* Scan, set up string
* print " terminated string to FAC1 stack

LAB_20AE
	MOVEQ		#$22,d2		* set Srchc character (terminator 1)
	MOVE.w	d2,d3			* set Asrch character (terminator 2)

* print d2/d3 terminated string to FAC1 stack
* d2 = Srchc, d3 = Asrch, a0 is source
* a6 is temp

LAB_20B4
	MOVEQ		#0,d1			* clear longword
	SUBQ.w	#1,d1			* set length to -1
	MOVEA.l	a0,a2			* copy start to calculate end
LAB_20BE
	ADDQ.w	#1,d1			* increment length
	MOVE.b	(a0,d1.w),d0	* get byte from string
	BEQ.s		LAB_20D0		* exit loop if null byte [EOS]

	CMP.b		d2,d0			* compare with search character (terminator 1)
	BEQ.s		LAB_20CB		* branch if terminator

	CMP.b		d3,d0			* compare with terminator 2
	BNE.s		LAB_20BE		* loop if not terminator 2 (or null string)

LAB_20CB
	CMP.b		#$22,d0		* compare with "
	BNE.s		LAB_20D0		* branch if not "

	ADDQ.w	#1,a2			* else increment string start (skip " at end)
LAB_20D0
	ADDA.l	d1,a2			* add longowrd length to make string end+1

	CMPA.l	#ram_strt,a0	* is string in ram
	BCS.s		LAB_RTST		* if not go push descriptor on stack & exit
						* (could be message string from ROM)

	CMPA.l	Smeml,a0		* is string in utility ram
	BCC.s		LAB_RTST		* if not go push descriptor on stack & exit
						* (is in string or program space)

						* (else) copy string to string memory
LAB_20C9
	MOVEA.l	a0,a1			* copy descriptor pointer
	MOVE.l	d1,d0			* copy longword length
	BNE.s		LAB_20D8		* branch if not null string

	MOVEA.l	d1,a0			* make null pointer
	BRA.s		LAB_RTST		* go push descriptor on stack & exit

LAB_20D8
	BSR.s		LAB_2115		* make string space d1 bytes long
	MOVE.l	d1,d0			* copy length again
	ADDA.l	d1,a0			* new string end
	ADDA.l	d1,a1			* old string end
	SUBQ.w	#1,d0			* -1 for DBF loop
LAB_20E0
	MOVE.b	-(a1),-(a0)		* copy byte (source can be odd aligned)
	DBF		d0,LAB_20E0		* loop until done


* check for space on descriptor stack then ...
* put string address and length on descriptor stack & update stack pointers
* start is in a0, length is in d1

LAB_RTST
	CMPA.l	#des_sk_e,a4	* compare string stack pointer with max+1
	BEQ		LAB_SCER		* if no space on string stack ..
						* .. go do 'string too complex' error

						* push string & update pointers
	MOVE.w	d1,-(a4)		* string length on descriptor stack
	MOVE.l	a0,-(a4)		* string address on stack
	MOVE.l	a4,FAC1_m		* string descriptor pointer in FAC1
	MOVE.b	#$80,Dtypef		* save data type flag, $80=string
	RTS

* Build descriptor a0/d1
* make space in string memory for string d1.w long
* return pointer in a0/Sutill

LAB_2115
	TST.w		d1			* test length
	BEQ.s		LAB_2128		* branch if user wants null string

						* make space for string d1 long
	MOVE.w	d0,-(sp)		* save d0
	MOVEQ		#0,d0			* clear longword
	MOVE.b	d0,Gclctd		* clear garbage collected flag (b7)
	MOVEQ		#1,d0			* +1 to possibly round up
	AND.w		d1,d0			* mask odd bit
	ADD.w		d1,d0			* ensure d0 is even length
	BCC.s		LAB_2117		* branch if no overflow

	MOVEQ		#1,d0			* set to allocate 65536 bytes
	SWAP		d0			* makes $00010000
LAB_2117
	MOVEA.l	Sstorl,a0		* get bottom of string space
	SUBA.l	d0,a0			* subtract string length
	CMPA.l	Earryl,a0		* compare with top of array space
	BCS.s		LAB_2137		* possibly do out of memory error if less

	MOVE.l	a0,Sstorl		* save bottom of string space low byte
	MOVE.l	a0,Sutill		* save string utility ptr low byte
	MOVE.w	(sp)+,d0		* restore d0
	TST.w		d1			* set flags on length
	RTS

LAB_2128
	MOVEA.w	d1,a0			* make null pointer
	RTS

LAB_2137
	TST.b		Gclctd		* get garbage collected flag
	BMI		LAB_OMER		* do "Out of memory" error, then warm start

	BSR.s		LAB_GARB		* else go do garbage collection
	MOVE.b	#$80,Gclctd		* set garbage collected flag
	BRA.s		LAB_2117		* go try again

* garbage collection routine

LAB_GARB
	MOVEM.l	d0-d2/a0-a2,-(sp)	* save registers
	MOVE.l	Ememl,Sstorl	* start with no strings

						* re-run routine from last ending
LAB_214B
	MOVE.l	Earryl,d1		* set highest uncollected string so far
	MOVEQ		#0,d0			* clear longword
	MOVEA.l	d0,a1			* clear string to move pointer
	MOVEA.l	Sstrl,a0		* set pointer to start of strings
	MOVEA.l	Sarryl,a2		* set end pointer to start of arrays (end of strings)
	BRA.s		LAB_2176		* branch into loop at end loop test

LAB_2161
	BSR		LAB_2206		* test and set if this is the highest string
	ADD.l		#10,a0		* increment to next string
LAB_2176
	CMPA.l	a0,a2			* compare pointer with with end of area
	BNE.s		LAB_2161		* go do next if not at end

* done strings, now do arrays.

**	MOVEA.l	Sarryl,a0		* set pointer to start of arrays (should be there)
	MOVEA.l	Earryl,a2		* set end pointer to end of arrays
	BRA.s		LAB_218F		* branch into loop at end loop test

LAB_217E
	MOVE.l	4(a0),d2		* get array size
	ADD.l		a0,d2			* makes start of next array

	MOVE.l	(a0),d0		* get array name
	BTST		#23,d0		* test string flag
	BEQ.s		LAB_218B		* branch if not string

	MOVE.w	8(a0),d0		* get # of dimensions
	ADD.w		d0,d0			* *2
	ADDA.w	d0,a0			* add to skip dimension size(s)
	ADDA.w	#$0A,a0		* increment to first element
LAB_2183
	BSR.s		LAB_2206		* test and set if this is the highest string
	ADDQ.w	#6,a0			* increment to next element
	CMPA.l	d2,a0			* compare with start of next array
	BNE.s		LAB_2183		* go do next if not at end of array

LAB_218B
	MOVEA.l	d2,a0			* pointer to next array
LAB_218F
	CMPA.l	a0,a2			* compare pointer with array end
	BNE.s		LAB_217E		* go do next if not at end

* done arrays and variables, now just the descriptor stack to do

	MOVEA.l	a4,a0			* get descriptor stack pointer
	MOVEA.l	#des_sk,a2		* set end pointer to end of stack
	BRA.s		LAB_21C4		* branch into loop at end loop test

LAB_21C2
	BSR.s		LAB_2206		* test and set if this is the highest string
	ADDQ.w	#06,a0		* increment to next string
LAB_21C4
	CMPA.l	a0,a2			* compare pointer with stack end
	BNE.s		LAB_21C2		* go do next if not at end

* descriptor search complete, now either exit or set-up and move string

	MOVE.l	a1,d0			* set the flags (a1 is move string)
	BEQ.s		LAB_21D1		* go tidy up and exit if no move

	MOVEA.l	(a1),a0		* a0 is now string start
	MOVEQ		#0,d1			* clear d1
	MOVE.w	4(a1),d1		* d1 is string length
	ADDQ.l	#1,d1			* +1
	AND.b		#$FE,d1		* make even length
	ADDA.l	d1,a0			* pointer is now to string end+1
	MOVEA.l	Sstorl,a2		* is destination end+1
	CMPA.l	a2,a0			* does the string need moving
	BEQ.s		LAB_2240		* branch if not

	LSR.l		#1,d1			* word move so do /2
	SUBQ.w	#1,d1			* -1 for DBF loop
LAB_2216
	MOVE.w	-(a0),-(a2)		* copy word
	DBF		d1,LAB_2216		* loop until done

	MOVE.l	a0,(a1)		* save new string start
LAB_2240
	MOVE.l	(a1),Sstorl		* string start is new string mem start
	BRA		LAB_214B		* re-run routine from last ending
						* (but don't collect this string)

LAB_21D1
	MOVEM.l	(sp)+,d0-d2/a0-a2	* restore registers
RTS_012
	RTS

*  test and set if this is the highest string

LAB_2206
	MOVE.l	(a0),d0		* get this string pointer
	BEQ.s		RTS_012		* exit if null string

	CMP.l		d0,d1			* compare with highest uncollected string so far
	BCC.s		RTS_012		* exit if <= with highest so far

	CMP.l		Sstorl,d0		* compare with bottom of string space
	BCC.s		RTS_012		* exit if >= bottom of string space

	MOVEQ		#0,d0			* clear d0
	MOVE.w	4(a1),d0		* d0 is string length
	NEG.l		d0			* make -ve
	AND.b		#$FE,d0		* make -ve even length
	ADD.l		Sstorl,d0		* add string store to -ve length
	CMP.l		(a0),d0		* compare with string address
	BEQ.s		LAB_2212		* if = go move string store pointer down

	MOVE.l	(a0),d1		* highest = current
	MOVEA.l	a0,a1			* string to move = current
	RTS

LAB_2212
	MOVE.l	d0,Sstorl		* set new string store start
	RTS

* concatenate
* add strings, string descriptor 1 is in FAC1_m, string 2 is in line

LAB_224D
	MOVE.l	FAC1_m,-(sp)	* stack descriptor pointer for string 1

	BSR		LAB_GVAL		* get value from line
	BSR		LAB_CTST		* check if source is string, else do type mismatch

	MOVEA.l	FAC1_m,a1		* copy descriptor pointer 2
	MOVEA.l	(sp),a0		* copy descriptor pointer 1
	MOVEQ		#0,d1			* clear longword length
	MOVE.w	4(a0),d1		* get length 1
	ADD.w		4(a1),d1		* add length 2
	BCS		LAB_SLER		* if overflow go do 'string too long' error

	BSR		LAB_2115		* make space d1 bytes long
	MOVE.l	a0,FAC2_m		* save new string start pointer
	MOVEA.l	(sp),a0		* copy descriptor pointer 1 from stack
	BSR.s		LAB_229C		* copy string from descriptor a0 to Sutill
						* return with a0 = pointer, d1 = length

	MOVEA.l	FAC1_m,a0		* get descriptor pointer for string 2
	BSR.s		LAB_22BA		* pop (a0) descriptor, returns with ..
						* a0 = pointer, d0 = length
	BSR.s		LAB_229E		* copy string d0 bytes long from a0 to Sutill
						* return with a0 = pointer, d1 = length

	MOVEA.l	(sp)+,a0		* get descriptor pointer for string 1
	BSR.s		LAB_22BA		* pop (a0) descriptor, returns with ..
						* d0 = length, a0 = pointer

	MOVEA.l	FAC2_m,a0		* retreive result string pointer
	MOVE.l	Sutill,d1		* copy end
	SUB.l		a0,d1			* subtract start = length
	BSR		LAB_RTST		* push string on descriptor stack
						* a0 = pointer, d1 = length
	BRA		LAB_1ADB		* continue evaluation

* copy string from descriptor (a0) to Sutill
* return with a0 = pointer, d1 = length

LAB_229C
	MOVE.w	4(a0),d0		* get length
	MOVEA.l	(a0),a0		* get string pointer
LAB_229E
	MOVEA.l	Sutill,a1		* get destination pointer
	MOVE.w	d0,d1			* copy and check length
	BEQ.s		RTS_013		* skip copy if null

	MOVE.l	a1,-(sp)		* save destination string pointer
	SUBQ.w	#1,d0			* subtract for DBF loop
LAB_22A0
	MOVE.b	(a0)+,(a1)+		* copy byte
	DBF		d0,LAB_22A0		* loop if not done

	MOVE.l	a1,Sutill		* update Sutill to end of copied string
	MOVEA.l	(sp)+,a0		* restore destination string pointer
RTS_013
	RTS

* evaluate string, returns d0 = length, a0 = pointer

LAB_EVST
	BSR		LAB_CTST		* check if source is string, else do type mismatch

* pop string off descriptor stack, or from top of string space
* returns with d0 = length, a0 = pointer

LAB_22B6
	MOVEA.l	FAC1_m,a0		* get descriptor pointer

* pop (a0) descriptor off stack or from string space
* returns with d0 = length, a0 = pointer

LAB_22BA
	MOVEM.l	a1/d1,-(sp)		* save other regs
	CMPA.l	a0,a4			* is string on the descriptor stack
	BNE.s		LAB_22BD		* skip pop if not

	ADDQ.w	#$06,a4		* else update stack pointer
LAB_22BD
	MOVEQ		#0,d0			* clear string length longword
	MOVEA.l	(a0)+,a1		* get string address
	MOVE.w	(a0)+,d0		* get string length

	CMPA.l	a0,a4			* was it on the descriptor stack
	BNE.s		LAB_22E6		* branch if it wasn't

	CMPA.l	Sstorl,a1		* compare string address with bottom of string space
	BNE.s		LAB_22E6		* branch if <>

	MOVEQ		#1,d1			* mask for odd bit
	AND.w		d0,d1			* AND length
	ADD.l		d0,d1			* make it fit word aligned length

	ADD.l		d1,Sstorl		* add to bottom of string space
LAB_22E6
	MOVEA.l	a1,a0			* copy to a0
	MOVEM.l	(sp)+,a1/d1		* restore other regs
	RTS

* perform CHR$()

LAB_CHRS
	BSR		LAB_EVBY		* evaluate byte expression, result in d0 and Itemp
	MOVEQ		#1,d1			* string is single byte
	BSR		LAB_2115		* make string space d1 bytes long
						* return a0/Sutill = pointer, others unchanged
	MOVE.b	d0,(a0)		* save byte in string (byte IS string!)
	ADDQ.w	#4,sp			* skip return type check
	BRA		LAB_RTST		* push string on descriptor stack
						* a0 = pointer, d1 = length

* perform LEFT$()

LAB_LEFT
	BSR.s		LAB_236F		* pull string data & word parameter from stack
						* return pointer in a0, word in d0. destroys d1
	EXG		d0,d1			* offset in d0, word in d1
	TST.l		d1			* test returned length
	BEQ.s		LAB_231C		* branch if null return

	MOVEQ		#0,d0			* clear start offset
	CMP.w		4(a0),d1		* compare word parameter with string length
	BCS.s		LAB_231C		* branch if string length > word parameter

	BRA.s		LAB_2316		* go copy whole string

* perform RIGHT$()

LAB_RIGHT
	BSR.s		LAB_236F		* pull string data & word parameter from stack
						* return pointer in a0, word in d0. destroys d1
	MOVE.l	d0,d1			* copy word (and clear high word)
	BEQ.s		LAB_231C		* branch if null return

	MOVE.w	4(a0),d0		* get string length
	SUB.l		d1,d0			* subtract word
	BCC.s		LAB_231C		* branch if string length > word parameter

						* else copy whole string
LAB_2316
	MOVEQ		#0,d0			* clear start offset
	MOVE.w	4(a0),d1		* else make parameter = length

* get here with ...
*   a0  - points to descriptor
* 4(a0) - is string length
*   d0  - is offset from string start
*   d1  - is required string length

LAB_231C
	MOVE.l	a0,-(sp)		* save string descriptor pointer
	BSR		LAB_2115		* make string space d1 bytes long
						* return a0/Sutill = pointer, others unchanged
	MOVEA.l	(sp)+,a0		* restore string descriptor pointer
	MOVE.l	d0,-(sp)		* save start offset (longword)
	BSR.s		LAB_22BA		* pop (a0) descriptor, returns with ..
						* d0 = length, a0 = pointer
	ADDA.l	(sp)+,a0		* adjust pointer to start of wanted string
	MOVE.w	d1,d0			* length to d0
	BSR		LAB_229E		* store string d0 bytes long from (a0) to (Sutill)
						* return with a0 = pointer, d1 = length
	BRA		LAB_RTST		* push string on descriptor stack
						* a0 = pointer, d1 = length

* perform MID$()

LAB_MIDS
	MOVEQ		#0,d7			* clear longword
	SUBQ.w	#1,d7			* set default length = 65535
	BSR		LAB_GBYT		* scan memory
	CMP.b		#$29,d0		* compare with ")"
	BEQ.s		LAB_2358		* branch if = ")" (skip second byte get)

	BSR		LAB_1C01		* find "," - else do syntax error/warm start
	BSR		LAB_GTWO		* get word parameter, result in d0 and Itemp
	MOVE.l	d0,d7			* copy length
LAB_2358
	BSR.s		LAB_236F		* pull string data & byte parameter from stack
						* return pointer in a0, word in d0. destroys d1
	MOVEQ		#0,d1			* null length
	SUBQ.l	#1,d0			* decrement start index
	BMI		LAB_FCER		* if was null do function call error, then warm start

	CMP.w		4(a0),d0		* compare string length with start index
	BCC.s		LAB_231C		* if start not in string do null string (d1=0)

	MOVE.l	d7,d1			* get length back
	ADD.w		d0,d7			* d7 now = MID$() end
	BCS.s		LAB_2368		* already too long so do RIGHT$ equivalent

	CMP.w		4(a0),d7		* compare string length with start index + length
	BCS.s		LAB_231C		* if end in string go do string

LAB_2368
	MOVE.w	4(a0),d1		* get string length
	SUB.w		d0,d1			* subtract start offset
	BRA.s		LAB_231C		* go do string (effectively RIGHT$)

* pull string data & word parameter from stack
* return pointer in a0, word in d0. destroys d1

LAB_236F
	BSR		LAB_1BFB		* scan for ")" , else do syntax error/warm start
	MOVE.l	(sp)+,d1		* pull return address
	ADDQ		#4,sp			* skip type check on exit
	MOVEQ		#0,d0			* clear longword
	MOVE.w	(sp)+,d0		* pull word parameter
	MOVE.l	(sp)+,a0		* pull string pointer
	MOVE.l	d1,-(sp)		* push return address
	RTS

* perform LCASE$()

LAB_LCASE
	BSR		LAB_EVST		* evaluate string, returns d0 = length, a0 = pointer
	MOVE.l	d0,d1			* copy length and set flags
	BEQ.s		NoString		* branch if null string

	MOVE.l	d0,d2			* copy for counter
	SUBQ.l	#1,d2			* subtract for DBF loop
LC_loop
	MOVE.b	(a0,d2.w),d0	* get byte from string
	BSR		LAB_1D82		* is character "A" to "Z"
	BCC.s		NoUcase		* branch if not upper case alpha

	ORI.b		#$20,d0		* convert upper to lower case
	MOVE.b	d0,(a0,d2.w)	* save byte back to string
NoUcase
	DBF		d2,LC_loop		* decrement and loop if not all done

	BRA.s		NoString		* tidy up & exit (branch always)

* perform UCASE$()

LAB_UCASE
	BSR		LAB_EVST		* evaluate string, returns d0 = length, a0 = pointer
	MOVE.l	d0,d1			* copy length and set flags
	BEQ.s		NoString		* branch if null string

	MOVE.l	d0,d2			* copy for counter
	SUBQ.l	#1,d2			* subtract for DBF loop
UC_loop
	MOVE.b	(a0,d2.w),d0	* get byte from string
	BSR		LAB_CASC		* is character "a" to "z" (or "A" to "Z")
	BCC.s		NoLcase		* branch if not alpha

	ANDI.b	#$DF,d0		* convert lower to upper case
	MOVE.b	d0,(a0,d2.w)	* save byte back to string
NoLcase
	DBF		d2,UC_loop		* decrement and loop if not all done

NoString
	ADDQ.w	#4,sp			* dump RTS address (skip numeric type check)
	BRA		LAB_RTST		* push string on descriptor stack
						* a0 = pointer, d1 = length

* perform SADD()

LAB_SADD
	BSR		LAB_EVST		* evaluate string, returns d0 = length, a0 = pointer
	MOVE.l	a0,d0			* copy string address
	BRA		LAB_AYFC		* convert d0 to signed longword in FAC1 & return

* perform LEN()

LAB_LENS
	BSR		LAB_EVST		* evaluate string, returns d0 = length, a0 = pointer
	BRA		LAB_1FD0		* convert d0 to unsigned byte in FAC1 & return

* perform ASC()

LAB_ASC
	BSR		LAB_EVST		* evaluate string, returns d0 = length, a0 = pointer
	BEQ		LAB_FCER		* if null do function call error, then warm start

	MOVE.b	(a0),d0		* get first character byte
	BRA		LAB_1FD0		* convert d0 to unsigned byte in FAC1 & return

* scan for "," and get byte, else do Syntax error then warm start

LAB_SCGB
	BSR		LAB_1C01		* scan for "," , else do syntax error/warm start
	BRA.s		LAB_GTBY		* get byte parameter, result in d0 and Itemp & RET

* increment and get byte, result in d0 and Itemp

LAB_SGBY
	BSR		LAB_IGBY		* increment & scan memory

* get byte parameter, result in d0 and Itemp

LAB_GTBY
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch

* evaluate byte expression, result in d0 and Itemp

LAB_EVBY
	BSR		LAB_EVPI		* evaluate positive integer expression
						* result in d0 and Itemp
	MOVE.l	d0,d1			* copy result
	AND.l		#$FFFFFF00,d1	* check top 24 bits
	BNE		LAB_FCER		* if <> 0 do function call error/warm start

	RTS

* get word parameter, result in d0 and Itemp

LAB_GTWO
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_EVPI		* evaluate positive integer expression
						* result in d0 and Itemp
	SWAP		d0			* copy high word to low word
	TST.w		d0			* set flags
	BNE		LAB_FCER		* if <> 0 do function call error/warm start

	SWAP		d0			* copy high word to low word
	RTS

* perform VAL()

LAB_VAL
	BSR		LAB_EVST		* evaluate string, returns d0 = length, a0 = pointer
	TST.w		d0			* check length
	BEQ.s		LAB_VALZ		* string was null so set result = $00
						* clear FAC1 exponent & sign & return

	MOVEA.l	a5,a6			* save BASIC execute pointer
	MOVEA.l	a0,a5			* copy string pointer to execute pointer
	ADDA.l	d0,a0			* string end+1
	MOVE.b	(a0),d0		* get byte from string+1
	MOVE.w	d0,-(sp)		* save it
	MOVE.l	a0,-(sp)		* save address
	MOVE.b	#0,(a0)		* null terminate string
	BSR		LAB_GBYT		* scan memory
	BSR		LAB_2887		* get FAC1 from string
	MOVEA.l	(sp)+,a0		* restore pointer
	MOVE.w	(sp)+,d0		* pop byte
	MOVE.b	d0,(a0)		* restore to memory
	MOVEA.l	a6,a5			* restore BASIC execute pointer
	RTS

LAB_VALZ
	MOVE.w	d0,FAC1_e		* clear FAC1 exponent & sign
	RTS

* get two parameters for POKE or WAIT, first parameter in a0, second in d0

LAB_GADB
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	MOVE.l	d0,-(sp)		* copy to stack
	BSR		LAB_1C01		* scan for "," , else do syntax error/warm start
	BSR.s		LAB_GTBY		* get byte parameter, result in d0 and Itemp
	MOVEA.l	(sp)+,a0		* pull address
	RTS

* get two parameters for DOKE or WAITW, first parameter in a0, second in d0

LAB_GADW
	BSR.s		LAB_GEAD		* get even address (for word/long memory actions)
						* address returned in d0 and on the stack
	BSR		LAB_1C01		* scan for "," , else do syntax error/warm start
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_EVPI		* evaluate positive integer expression
						* result in d0 and Itemp
	MOVE.l	d0,d1			* copy result
	AND.l		#$FFFF0000,d1	* check top 16 bits
	BNE		LAB_FCER		* if <> 0 do function call error/warm start

	MOVEA.l	(sp)+,a0		* pull address
	RTS

* get even address (for word or longword memory actions)
* address returned in d0 and on the stack
* does address error if the address is odd

LAB_GEAD
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	BTST		#0,d0			* test low bit of longword
	BNE		LAB_ADER		* if address is odd do address error/warm start

	MOVEA.l	(sp)+,a0		* copy return address
	MOVE.l	d0,-(sp)		* address on stack
	MOVE.l	a0,-(sp)		* put return address back
	RTS

* perform PEEK()

LAB_PEEK
	BSR		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	MOVEA.l	d0,a0			* copy to address register
	MOVE.b	(a0),d0		* get byte
	BRA		LAB_1FD0		* convert d0 to unsigned byte in FAC1 & return

* perform POKE

LAB_POKE
	BSR.s		LAB_GADB		* get two parameters for POKE or WAIT
						* first parameter in a0, second in d0
	MOVE.b	d0,(a0)		* put byte in memory
	RTS

* perform DEEK()

LAB_DEEK
	BSR		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	BTST		#0,d0			* test low bit of longword
	BNE		LAB_ADER		* if address is odd do address error/warm start

	EXG		d0,a0			* copy to address register
	MOVEQ		#0,d0			* clear top bits
	MOVE.w	(a0),d0		* get word
	BRA		LAB_AYFC		* convert d0 to signed longword in FAC1 & return

* perform LEEK()

LAB_LEEK
	BSR		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	BTST		#0,d0			* test low bit of longword
	BNE		LAB_ADER		* if address is odd do address error/warm start

	EXG		d0,a0			* copy to address register
	MOVE.l	(a0),d0		* get word
	BRA		LAB_AYFC		* convert d0 to signed longword in FAC1 & return

* perform DOKE

LAB_DOKE
	BSR.s		LAB_GADW		* get two parameters for DOKE or WAIT
						* first parameter in a0, second in d0
	MOVE.w	d0,(a0)		* put word in memory
	RTS

* perform LOKE

LAB_LOKE
	BSR.s		LAB_GEAD		* get even address (for word/long memory actions)
						* address returned in d0 and on the stack
	BSR		LAB_1C01		* scan for "," , else do syntax error/warm start
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_EVIR		* evaluate integer value (no sign check)
	MOVEA.l	(sp)+,a0		* pull address
	MOVE.l	d0,(a0)		* put longword in memory
RTS_015
	RTS

* perform SWAP

LAB_SWAP
	BSR		LAB_GVAR		* get var1 address
						* return pointer to variable in Cvaral and a0
	MOVEA.l	a0,a3			* copy address
	MOVE.b	Dtypef,d3		* get data type, $80=string, $40=inetger $00=float

	BSR		LAB_1C01		* scan for "," , else do syntax error/warm start
	BSR		LAB_GVAR		* get var2 address (pointer in Cvaral/h)
						* return pointer to variable in Cvaral and a0
	CMP.b		Dtypef,d3		* compare with var2 data type
	BNE		LAB_TMER		* if not both the same type do "Type mismatch"
						* error then warm start

	MOVE.l	(a0),d0		* get var2
	MOVE.l	(a3),(a0)		* copy var1 to var2
	MOVE.l	d0,(a3)		* save var2 to var1

	TST.b		d3			* check data type
	BPL.s		RTS_015		* exit if not string

	MOVE.w	4(a0),d0		* get string 2 length
	MOVE.w	4(a3),4(a0)		* copy string 1 length to string 2 length
	MOVE.w	d0,4(a3)		* save string 2 length to string 1 length
	RTS

* perform CALL

LAB_CALL
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
	BSR		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	PEA		(LAB_GBYT,PC)	* put return address on stack
	MOVEA.l	d0,a0			* address into address register
	JMP		(a0)			* do indirect jump to user routine

* if the called routine exits correctly then it will return via the get byte routine.
* this will then get the next byte for the interpreter and return

* perform WAIT

LAB_WAIT
	BSR		LAB_GADB		* get two parameters for POKE or WAIT
						* first parameter in a0, second in d0
	MOVE.l	a0,-(sp)		* save address
	MOVE.w	d0,-(sp)		* save byte
	MOVEQ		#0,d2			* clear mask
	BSR		LAB_GBYT		* scan memory
	BEQ.s		LAB_2441		* skip if no third argument

	BSR		LAB_SCGB		* scan for "," & get byte,
						* else do syntax error/warm start
	MOVE.l	d0,d2			* copy mask
LAB_2441
	MOVE.w	(sp)+,d1		* get byte
	MOVEA.l	(sp)+,a0		* get address
LAB_2445
	MOVE.b	(a0),d0		* read memory byte
	EOR.b		d2,d0			* EOR with second argument (mask)
	AND.b		d1,d0			* AND with first argument (byte)
	BEQ.s		LAB_2445		* loop if result is zero

	RTS

* perform subtraction, FAC1 from FAC2

LAB_SUBTRACT
	EORI.b	#$80,FAC1_s		* complement FAC1 sign
	MOVE.b	FAC2_s,FAC_sc	* copy FAC2 sign byte

	MOVE.b	FAC1_s,d0		* get FAC1 sign byte
	EOR.b		d0,FAC_sc		* EOR with FAC2 sign

	BRA.s		LAB_ADD		* go add FAC2 to FAC1

* add 0.5 to FAC1

LAB_244E
	LEA		(LAB_2A96,PC),a0	* set 0.5 pointer

* perform addition, add (a0) to FAC1

LAB_246C
	BSR		LAB_264D		* unpack memory (a0) into FAC2

* add FAC2 to FAC1

LAB_ADD
	MOVE.b	FAC1_e,d0		* get exponent
	BEQ		LAB_279B		* FAC1 was zero so copy FAC2 to FAC1 & return

						* FAC1 is non zero
	MOVEA.l	#FAC2_m,a0		* set pointer1 to FAC2 mantissa
	MOVE.b	FAC2_e,d0		* get FAC2 exponent
	BEQ.s		RTS_016		* exit if zero

	SUB.b		FAC1_e,d0		* subtract FAC1 exponent
	BEQ.s		LAB_24A8		* branch if = (go add mantissa)

	BCS.s		LAB_249C		* branch if FAC2 < FAC1

						* FAC2 > FAC1
	MOVE.w	FAC2_e,FAC1_e	* copy sign and exponent of FAC2
	NEG.b		d0			* negate exponent difference (make diff -ve)
	SUBQ.w	#8,a0			* pointer1 to FAC1

LAB_249C
	NEG.b		d0			* negate exponent difference (make diff +ve)
	MOVE.l	d1,-(sp)		* save d1
	CMP.b		#32,d0		* compare exponent diff with 32
	BLT.s		LAB_2467		* branch if range >= 32

	MOVEQ		#0,d1			* clear d1
	BRA.s		LAB_2468		* go clear smaller mantissa

LAB_2467
	MOVE.l	(a0),d1		* get FACx mantissa
	LSR.l		d0,d1			* shift d0 times right
LAB_2468
	MOVE.l	d1,(a0)		* save it back
	MOVE.l	(sp)+,d1		* restore d1

						* exponents are equal now do mantissa add/subtract
LAB_24A8
	TST.b		FAC_sc		* test sign compare (FAC1 EOR FAC2)
	BMI.s		LAB_24F8		* if <> go do subtract

	MOVE.l	FAC2_m,d0		* get FAC2 mantissa
	ADD.l		FAC1_m,d0		* add FAC1 mantissa
	BCC.s		LAB_24F7		* save and exit if no carry (FAC1 is normal)

	ROXR.l	#1,d0			* else shift carry back into mantissa
	ADDQ.b	#1,FAC1_e		* increment FAC1 exponent
	BCS		LAB_OFER		* if carry do overflow error & warm start

LAB_24F7
	MOVE.l	d0,FAC1_m		* save mantissa
RTS_016
	RTS
						* signs are different
LAB_24F8
	MOVEA.l	#FAC1_m,a1		* pointer 2 to FAC1
	CMPA.l	a0,a1			* compare pointers
	BNE.s		LAB_24B4		* branch if <>

	ADDQ.w	#8,a1			* else pointer2 to FAC2

						* take smaller from bigger (take sign of bigger)
LAB_24B4
	MOVE.l	(a1),d0		* get larger mantissa
	MOVE.l	(a0),d1		* get smaller mantissa
	MOVE.l	d0,FAC1_m		* save larger mantissa
	SUB.l		d1,FAC1_m		* subtract smaller

* do +/- (carry is sign) & normalise FAC1

LAB_24D0
	BCC.s		LAB_24D5		* branch if result is +ve

						* erk! subtract wrong way round, negate everything
	EORI.b	#$FF,FAC1_s		* complement FAC1 sign
	NEG.l		FAC1_m		* negate FAC1 mantissa

* normalise FAC1

LAB_24D5
	MOVE.l	FAC1_m,d0		* get mantissa
	BMI.s		LAB_24DA		* mantissa is normal so just exit

	BNE.s		LAB_24D9		* mantissa is not zero so go normalise FAC1

	MOVE.w	d0,FAC1_e		* else make FAC1 = +zero
	RTS

LAB_24D9
	MOVE.l	d1,-(sp)		* save d1
	MOVE.l	d0,d1			* mantissa to d1
	MOVEQ		#0,d0			* clear d0
	MOVE.b	FAC1_e,d0		* get exponent byte
	BEQ.s		LAB_24D8		* if exponent is zero then clean up and exit
LAB_24D6
	ADD.l		d1,d1			* shift mantissa (ADD is quicker for single shift)
	DBMI		d0,LAB_24D6		* decrement exponent and loop if mantissa and
						* exponent +ve

	TST.w		d0			* test exponent
	BEQ.s		LAB_24D8		* if exponent is zero make FAC1 zero

	BPL.s		LAB_24D7		* if exponent is >zero go save FAC1

	MOVEQ		#1,d0			* else set for zero after correction
LAB_24D7
	SUBQ.b	#1,d0			* adjust exponent for loop
	MOVE.l	d1,FAC1_m		* save normalised mantissa
LAB_24D8
	MOVE.l	(sp)+,d1		* restore d1
	MOVE.b	d0,FAC1_e		* save corrected exponent
LAB_24DA
	RTS

* perform LOG()

LAB_LOG
	TST.b		FAC1_s		* test sign
	BMI		LAB_FCER		* if -ve do function call error/warm start

	MOVEQ		#0,d7			* clear d7
	MOVE.b	d7,FAC_sc		* clear sign compare
	MOVE.b	FAC1_e,d7		* get exponent
	BEQ		LAB_FCER		* if 0 do function call error/warm start

	SUB.l		#$81,d7		* normalise exponent
	MOVE.b	#$81,FAC1_e		* force a value between 1 and 2
	MOVE.l	FAC1_m,d6		* copy mantissa

	MOVE.l	#$80000000,FAC2_m	* set mantissa for 1
	MOVE.w	#$8100,FAC2_e	* set exponent for 1
	BSR		LAB_ADD		* find arg+1
	MOVEQ		#0,d0			* setup for calc skip
	MOVE.w	d0,FAC2_e		* set FAC1 for zero result
	ADD.l		d6,d6			* shift 1 bit out
	MOVE.l	d6,FAC2_m		* put back FAC2
	BEQ.s		LAB_LONN		* if 0 skip calculation

	MOVE.w	#$8000,FAC2_e	* set exponent for .5
	BSR		LAB_DIVIDE		* do (arg-1)/(arg+1)
	TST.b		FAC1_e		* test exponent
	BEQ.s		LAB_LONN		* if 0 skip calculation

	MOVE.b	FAC1_e,d1		* get exponent
	SUB.b		#$82,d1		* normalise and two integer bits
	NEG.b		d1			* negate for shift
**	CMP.b		#$1F,d1		* will mantissa vanish?
**	BGT.s		LAB_dunno		* if so do ???

	MOVE.l	FAC1_m,d0		* get mantissa
	LSR.l		d1,d0			* shift in two integer bits

* d0 = arg
* d0 = x, d1 = y
* d2 = x1, d3 = y1
* d4 = shift count
* d5 = loop count
* d6 = z
* a0 = table pointer

	MOVEQ		#0,d6			* z = 0
	MOVE.l	#1<<30,d1		* y = 1
	MOVEA.l	#TAB_HTHET,a0	* pointer to hyperbolic tangent table
	MOVEQ		#30,d5		* loop 31 times
	MOVEQ		#1,d4			* set shift count
	BRA.s		LAB_LOCC		* entry point for loop

LAB_LAAD
	ASR.l		d4,d2			* x1 >> i
	SUB.l		d2,d1			* y = y - x1
	ADD.l		(a0),d6		* z = z + tanh(i)
LAB_LOCC
	MOVE.l	d0,d2			* x1 = x
	MOVE.l	d1,d3			* y1 = Y
	ASR.l		d4,d3			* y1 >> i
	BCC.s		LAB_LOLP

	ADDQ.l	#1,d3
LAB_LOLP
	SUB.l		d3,d0			* x = x - y1
	BPL.s		LAB_LAAD		* branch if > 0

	MOVE.l	d2,d0			* get x back
	ADDQ.w	#4,a0			* next entry
	ADDQ.l	#1,d4			* next i
	LSR.l		#1,d3			* /2
	BEQ.s		LAB_LOCX		* branch y1 = 0

	DBF		d5,LAB_LOLP		* decrement and loop if not done

						* now sort out the result
LAB_LOCX
	ADD.l		d6,d6			* *2
	MOVE.l	d6,d0			* setup for d7 = 0
LAB_LONN
	MOVE.l	d0,d4			* save cordic result
	MOVEQ		#0,d5			* set default exponent sign
	TST.l		d7			* check original exponent sign
	BEQ.s		LAB_LOXO		* branch if original was 0

	BPL.s		LAB_LOXP		* branch if was +ve

	NEG.l		d7			* make original exponent +ve
	MOVEQ		#$80-$100,d5	* make sign -ve
LAB_LOXP
	MOVE.b	d5,FAC1_s		* save original exponent sign
	SWAP		d7			* 16 bit shift
	LSL.l		#8,d7			* easy first part
	MOVEQ		#$88-$100,d5	* start with byte
LAB_LONE
	SUBQ.l	#1,d5			* decrement exponent
	ADD.l		d7,d7			* shift mantissa
	BPL.s		LAB_LONE		* loop if not normal

LAB_LOXO
	MOVE.l	d7,FAC1_m		* save original exponent as mantissa
	MOVE.b	d5,FAC1_e		* save exponent for this
	MOVE.l	#$B17217F8,FAC2_m	* LOG(2) mantissa
	MOVE.w	#$8000,FAC2_e	* LOG(2) exponent & sign
	MOVE.b	FAC1_s,FAC_sc	* make sign compare = FAC1 sign
	BSR.s		LAB_MULTIPLY	* do multiply
	MOVE.l	d4,FAC2_m		* save cordic result
	BEQ.s		LAB_LOWZ		* branch if zero

	MOVE.w	#$8200,FAC2_e	* set exponent & sign
	MOVE.b	FAC1_s,FAC_sc	* clear sign compare
	BSR		LAB_ADD		* and add for final result

LAB_LOWZ
	RTS

* multiply FAC1 by FAC2

LAB_MULTIPLY
	MOVEM.l	d0-d4,-(sp)		* save registers
	TST.b		FAC1_e		* test FAC1 exponent
	BEQ		LAB_MUUF		* if exponent zero go make result zero

	MOVE.b	FAC2_e,d0		* get FAC2 exponent
	BEQ		LAB_MUUF		* if exponent zero go make result zero

	MOVE.b	FAC_sc,FAC1_s	* sign compare becomes sign

	ADD.b		FAC1_e,d0		* multiply exponents by adding
	BCC.s		LAB_MNOC		* branch if no carry

	SUB.b		#$80,d0		* normalise result
	BCC		LAB_OFER		* if no carry do overflow

	BRA.s		LAB_MADD		* branch

						* no carry for exponent add
LAB_MNOC
	SUB.b		#$80,d0		* normalise result
	BCS		LAB_MUUF		* return zero if underflow

LAB_MADD
	MOVE.b	d0,FAC1_e		* save exponent

						* d1 (FAC1) x d2 (FAC2)
	MOVE.l	FAC1_m,d1		* get FAC1 mantissa
	MOVE.l	FAC2_m,d2		* get FAC2 mantissa

	MOVE.w	d1,d4			* copy low word FAC1
	MOVE.l	d1,d0			* copy long word FAC1
	SWAP		d0			* high word FAC1 to low word FAC1
	MOVE.w	d0,d3			* copy high word FAC1

	MULU		d2,d1			* low word FAC2 x low word FAC1
	MULU		d2,d0			* low word FAC2 x high word FAC1
	SWAP		d2			* high word FAC2 to low word FAC2
	MULU		d2,d4			* high word FAC2 x low word FAC1
	MULU		d2,d3			* high word FAC2 x high word FAC1

* done multiply, now add partial products

*			d1 =					aaaa  ----	FAC2_L x FAC1_L
*			d0 =				bbbb  aaaa		FAC2_L x FAC1_H
*			d4 =				bbbb  aaaa		FAC2_H x FAC1_L
*			d3 =			cccc  bbbb			FAC2_H x FAC1_H
*			product =		mmmm  mmmm

	ADD.l		#$8000,d1		* round up lowest word
	CLR.w		d1			* clear low word, don't need it
	SWAP		d1			* align high word
	ADD.l		d0,d1			* add FAC2_L x FAC1_H (can't be carry)
LAB_MUF1
	ADD.l		d4,d1			* now add intermediate (FAC2_H x FAC1_L)
	BCC.s		LAB_MUF2		* branch if no carry

	ADD.l		#$10000,d3		* else correct result
LAB_MUF2
	ADD.l		#$8000,d1		* round up low word *##
	CLR.w		d1			* clear low word
	SWAP		d1			* align for final add
	ADD.l		d3,d1			* add FAC2_H x FAC1_H, result
	BMI.s		LAB_MUF3		* branch if normalisation not needed

	ADD.l		d1,d1			* shift mantissa
	SUBQ.b	#1,FAC1_e		* adjust exponent
	BEQ.s		LAB_MUUF		* branch if underflow

LAB_MUF3
	MOVE.l	d1,FAC1_m		* save mantissa
LAB_MUEX
	MOVEM.l	(sp)+,d0-d4		* restore registers
	RTS
						* either zero or underflow result
LAB_MUUF
	MOVEQ		#0,d0			* quick clear
	MOVE.l	d0,FAC1_m		* clear mantissa
	MOVE.w	d0,FAC1_e		* clear sign and exponent
	BRA.s		LAB_MUEX		* restore regs & exit

* unpack memory (a0) into FAC2, trashes d0

LAB_264D
	MOVE.l	(a0),d0		* get value
	SWAP		d0			* exponent and sign to bits 0-15
	MOVE.w	d0,FAC2_e		* save FAC2 exponent & sign
	MOVE.b	d0,FAC_sc		* save sign as sign compare
	OR.b		#$80,d0		* restore MSb
	SWAP		d0			* swap words back

	ASL.l		#8,d0			* shift exponent & clear guard byte
	MOVE.l	d0,FAC2_m		* move into FAC2

	MOVE.b	FAC1_s,d0		* get FAC1 sign
	EOR.b		d0,FAC_sc		* make sign compare (FAC1_s EOR FAC2_s)

	RTS

* multiply by 10

LAB_269E
	TST.b		FAC1_e		* test exponent byte
	BEQ.s		x10exit		* exit if zero

	MOVE.l	d0,-(sp)		* save d0	
	MOVE.l	FAC1_m,d0		* get FAC1
	LSR.l		#2,d0			* /4
	BCC.s		x10nornd		* if no carry don't round up

	ADDQ.l	#1,d0			* round up least bit, there won't be any carry
x10nornd
	ADD.l		FAC1_m,d0		* add FAC1 (x1.125)
	BCC.s		x10exp		* branch if no carry

	ROXR.l	#1,d0			* shift carry back in
	ADDQ.b	#1,FAC1_e		* increment exponent
	BCS		LAB_OFER		* branch if overflow

x10exp
	MOVE.l	d0,FAC1_m		* save new mantissa
	ADDQ.b	#3,FAC1_e		* correct exponent ( 8 x 1.125 = 10 )
	BCS		LAB_OFER		* branch if overflow

	MOVE.l	(sp)+,d0		* restore d0	
x10exit
	RTS

* convert a0 and do (a0)/FAC1

LAB_26CA
	BSR		LAB_264D		* unpack memory (a0) into FAC2, trashes d0

* do FAC2/FAC1, result in FAC1
* fast hardware version

LAB_DIVIDE
	MOVE.l	d7,-(sp)		* save d7
	MOVEQ		#0,d0			* clear FAC2 exponent
	MOVE.l	d0,d2			* clear FAC1 exponent

	MOVE.b	FAC1_e,d2		* get FAC1 exponent
	BEQ		LAB_DZER		* if zero go do /0 error

	MOVE.b	FAC2_e,d0		* get FAC2 exponent
	BEQ.s		LAB_DIV0		* if zero return zero

	SUB.w		d2,d0			* get result exponent by subtracting
	ADD.w		#$80,d0		* correct 16 bit exponent result

	MOVE.b	FAC_sc,FAC1_s	* sign compare is result sign

* now to do 32/32 bit mantissa divide

	CLR.b		flag			* clear 'flag' byte
	MOVE.l	FAC1_m,d3		* get FAC1 mantissa
	MOVE.l	FAC2_m,d4		* get FAC2 mantissa
	CMP.l		d3,d4			* compare FAC2 with FAC1 mantissa
	BEQ.s		LAB_MAN1		* set mantissa result = 1 if equal

	BCS.s		AC1gtAC2		* branch if FAC1 > FAC2

	SUB.l		d3,d4			* subtract FAC1 from FAC2 (result now must be <1)
	ADDQ.b	#3,flag		* FAC2>FAC1 so set 'flag' byte
AC1gtAC2
	BSR.s		LAB_32_16		* do 32/16 divide
	SWAP		d1			* move 16 bit result to high word
	MOVE.l	d2,d4			* copy remainder longword
	BSR.s		LAB_3216		* do 32/16 divide again (skip copy d4 to d2)
	DIVU		d5,d2			* now divide remainder to make guard word
	MOVE.b	flag,d7		* now normalise, get flag byte back
	BEQ.s		LAB_DIVX		* skip add if null

* else result was >1 so we need to add 1 to result mantissa and adjust exponent

	LSR.b		#1,d7			* shift 1 into eXtend
	ROXR.l	#1,d1			* shift extend result >>
	ROXR.w	#1,d2			* shift extend guard word >>
	ADDQ.b	#1,d0			* adjust exponent

* now round result to 32 bits

LAB_DIVX
	ADD.w		d2,d2			* guard bit into eXtend bit
	BCC.s		L_DIVRND		* branch if guard=0

	ADDQ.l	#1,d1			* add guard to mantissa
	BCC.s		L_DIVRND		* branch if no overflow

LAB_SET1
	ROXR.l	#1,d1			* shift extend result >>
	ADDQ.w	#1,d0			* adjust exponent

						* test for over/under flow
L_DIVRND
	MOVE.w	d0,d3			* copy exponent
	BMI		LAB_DIV0		* if -ve return zero

	ANDI.w	#$FF00,d3		* mask low byte
	BNE		LAB_OFER		* branch if overflow

						* move result into FAC1
LAB_XDIV
	MOVE.l	(sp)+,d7		* restore d7
	MOVE.b	d0,FAC1_e		* save result exponent
	MOVE.l	d1,FAC1_m		* save result mantissa
	RTS

* FAC1 mantissa = FAC2 mantissa so set result mantissa

LAB_MAN1
	MOVEQ		#1,d1			* set bit
	LSR.l		d1,d1			* bit into eXtend
	BRA.s		LAB_SET1		* set mantissa, adjust exponent and exit

* result is zero

LAB_DIV0
	MOVEQ		#0,d0			* zero exponent & sign
	MOVE.l	d0,d1			* zero mantissa
	BRA		LAB_XDIV		* exit divide

* divide 16 bits into 32, AB/Ex
*
* d4			AAAA	BBBB		* 32 bit numerator
* d3			EEEE	xxxx		* 16 bit denominator
*
* returns -
*
* d1			xxxx	DDDD		* 16 bit result
* d2				HHHH	IIII	* 32 bit remainder

LAB_32_16
	MOVE.l	d4,d2			* copy FAC2 mantissa		(AB)
LAB_3216
	MOVE.l	d3,d5			* copy FAC1 mantissa		(EF)
	CLR.w		d5			* clear low word d1		(Ex)
	SWAP		d5			* swap high word to low word	(xE)
	DIVU		d5,d4			* do FAC2/FAC1 high word	(AB/E)
	BVC.s		LAB_LT_1		* if no overflow DIV was ok

	MOVEQ		#-1,d4		* else set default value

; done the divide, now check the result, we have ...

* d3			EEEE	FFFF		* denominator copy
* d5		0000	EEEE			* denominator high word
* d2			AAAA	BBBB		* numerator copy
* d4			MMMM	DDDD		* result MOD and DIV

LAB_LT_1
	MOVE.w	d4,d6			* copy 16 bit result
	MOVE.w	d4,d1			* copy 16 bit result again

* we now have ..
* d3			EEEE	FFFF		* denominator copy
* d5		0000	EEEE			* denominator high word
* d6			xxxx  DDDD		* result DIV copy
* d1			xxxx  DDDD		* result DIV copy
* d2			AAAA	BBBB		* numerator copy
* d4			MMMM	DDDD		* result MOD and DIV

* now multiply out 32 bit denominator by 16 bit result
* QRS = AB*D

	MULU		d3,d6			* FFFF * DDDD =       rrrr  SSSS
	MULU		d5,d4			* EEEE * DDDD = QQQQ  rrrr

* we now have ..
* d3			EEEE	FFFF		* denominator copy
* d5		0000	EEEE			* denominator high word
* d6				rrrr  SSSS	* 48 bit result partial low
* d1			xxxx  DDDD		* result DIV copy
* d2			AAAA	BBBB		* numerator copy
* d4			QQQQ	rrrr		* 48 bit result partial

	MOVE.w	d6,d7			* copy low word of low multiply

* d7				xxxx	SSSS	* 48 bit result partial low

	CLR.w		d6			* clear low word of low multiply
	SWAP		d6			* high word of low multiply to low word

* d6			0000	rrrr		* high word of 48 bit result partial low

	ADD.l		d6,d4

* d4			QQQQ	RRRR		* 48 bit result partial high longword

	MOVEQ		#0,d6			* clear to extend numerator to 48 bits

* now do GHI = AB0 - QRS (which is the remainder)

	SUB.w		d7,d6			* low word subtract

* d6				xxxx	IIII	* remainder low word

	SUBX.l	d4,d2			* high longword subtract

* d2			GGGG	HHHH		* remainder high longword

* now if we got the divide correct then the remainder high longword will be +ve

	BPL.s		L_DDIV		* branch if result is ok (<needed)

* remainder was -ve so DDDD is too big

LAB_REMM
	SUBQ.w	#1,d1			* adjust DDDD

* d3				xxxx	FFFF	* denominator copy
* d6				xxxx	IIII	* remainder low word

	ADD.w		d3,d6			* add EF*1 low remainder low word

* d5			0000	EEEE		* denominator high word
* d2			GGGG	HHHH		* remainder high longword

	ADDX.l	d5,d2			* add extend EF*1 to remainder high longword
	BMI.s		LAB_REMM		* loop if result still too big

* all done and result correct or <

L_DDIV
	SWAP		d2			* remainder mid word to high word

* d2			HHHH	GGGG		* (high word /should/ be $0000)

	MOVE.w	d6,d2			* remainder in high word

* d2				HHHH	IIII	* now is 32 bit remainder
* d1			xxxx	DDDD		* 16 bit result

	RTS

* unpack memory (a0) into FAC1

LAB_UFAC
	MOVE.l	(a0),d0		* get packed value
	SWAP		d0			* exponent and sign into least significant word
	MOVE.w	d0,FAC1_e		* save exponent and sign
	OR.w		#$80,d0		* set MSb
	SWAP		d0			* byte order back to normal

	ASL.l		#8,d0			* shift exponent & clear guard byte
	MOVE.l	d0,FAC1_m		* move into FAC1

	MOVE.b	FAC1_e,d0		* get FAC1 exponent
	RTS

* set numeric variable, pack FAC1 into Lvarpl

LAB_PFAC
	MOVE.l	a0,-(sp)		* save pointer
	MOVEA.l	Lvarpl,a0		* get destination pointer
	BTST		#6,Dtypef		* test data type
	BEQ.s		LAB_277C		* branch if floating

	BSR		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	MOVE.l	d0,(a0)		* save in var
	MOVE.l	(sp)+,a0		* restore pointer
	RTS

* normalise round and pack FAC1 into (a0)

LAB_2778
	MOVE.l	a0,-(sp)		* save pointer
LAB_277C
	BSR		LAB_24D5		* normalise FAC1
	BSR.s		LAB_27BA		* round FAC1
	MOVE.l	FAC1_m,d0		* get FAC1 mantissa
	ROR.l		#8,d0			* align 24/32 bit mantissa
	SWAP		d0			* exponent/sign into 0-15
	AND.w		#$7F,d0		* clear exponent and sign bit
	ANDI.b	#$80,FAC1_s		* clear non sign bits in sign
	OR.w		FAC1_e,d0		* OR in exponent and sign
	SWAP		d0			* move exponent and sign  back to 16-31
	MOVE.l	d0,(a0)		* store in destination
	MOVE.l	(sp)+,a0		* restore pointer
	RTS

* copy FAC2 to FAC1

LAB_279B
	MOVE.w	FAC2_e,FAC1_e	* copy exponent & sign
	MOVE.l	FAC2_m,FAC1_m	* copy mantissa
	RTS

* round FAC1

LAB_27BA
	MOVE.b	FAC1_e,d0		* get FAC1 exponent
	BEQ.s		LAB_27C4		* branch if zero

	MOVE.l	FAC1_m,d0		* get FAC1
	ADD.l		#$80,d0		* round to 24 bit
	BCC.s		LAB_27C3		* branch if no overflow

	ROXR.l	#1,d0			* shift FAC1 mantissa
	ADDQ.b	#1,FAC1_e		* correct exponent
	BCS		LAB_OFER		* if carry do overflow error & warm start

LAB_27C3
	AND.b		#$00,d0		* clear guard byte
	MOVE.l	d0,FAC1_m		* save back to FAC1
	RTS

LAB_27C4
	MOVE.b	d0,FAC1_s		* make zero always +ve
RTS_017
	RTS

* get FAC1 sign
* return d0=-1,C=1/-ve d0=+1,C=0/+ve

LAB_27CA
	MOVEQ		#0,d0			* clear d0
	MOVE.b	FAC1_e,d0		* get FAC1 exponent
	BEQ.s		RTS_017		* exit if zero (already correct SGN(0)=0)

* return d0=-1,C=1/-ve d0=+1,C=0/+ve
* no = 0 check

LAB_27CE
	MOVE.b	FAC1_s,d0		* else get FAC1 sign (b7)

* return d0=-1,C=1/-ve d0=+1,C=0/+ve
* no = 0 check, sign in d0

LAB_27D0
	EXT.w		d0			* make word
	EXT.l		d0			* make longword
	ASR.l		#8,d0			* move sign bit through byte to carry
	BCS.s		RTS_017		* exit if carry set

	MOVEQ		#1,d0			* set result for +ve sign
	RTS

* perform SGN()

LAB_SGN
	BSR.s		LAB_27CA		* get FAC1 sign
						* return d0=-1/-ve d0=+1/+ve

* save d0 as integer longword

LAB_27DB
	MOVE.l	d0,FAC1_m		* save FAC1 mantissa
	MOVE.w	#$A000,FAC1_e	* set FAC1 exponent & sign
	ADD.l		d0,d0			* top bit into carry
	BRA		LAB_24D0		* do +/- (carry is sign) & normalise FAC1

* perform ABS()

LAB_ABS
	MOVE.b	#0,FAC1_s		* clear FAC1 sign
	RTS

* compare FAC1 with (a0)
* returns d0=+1 if FAC1 > FAC2
* returns d0= 0 if FAC1 = FAC2
* returns d0=-1 if FAC1 < FAC2

LAB_27F8
	BSR		LAB_264D		* unpack memory (a0) into FAC2, trashes d0

* compare FAC1 with FAC2
* returns d0=+1 if FAC1 > FAC2
* returns d0= 0 if FAC1 = FAC2
* returns d0=-1 if FAC1 < FAC2

LAB_27FA
	MOVE.b	FAC2_e,d1		* get FAC2 exponent
	BEQ.s		LAB_27CA		* branch if FAC2 exponent=0 & get FAC1 sign
						* d0=-1,C=1/-ve d0=+1,C=0/+ve

	MOVE.b	FAC_sc,d0		* get FAC sign compare
	BMI.s		LAB_27CE		* if signs <> do return d0=-1,C=1/-ve
						* d0=+1,C=0/+ve & return

	MOVE.b	FAC1_s,d0		* get FAC1 sign
	CMP.b		FAC1_e,d1		* compare FAC1 exponent with FAC2 exponent
	BNE.s		LAB_2828		* branch if different

	MOVE.l	FAC2_m,d1		* get FAC2 mantissa
	CMP.l		FAC1_m,d1		* compare mantissas
	BEQ.s		LAB_282F		* exit if mantissas equal

* gets here if number <> FAC1

LAB_2828
	BCS.s		LAB_282E		* branch if FAC1 > FAC2

	EORI.b	#$80,d0		* else toggle FAC1 sign
LAB_282E
	BRA.s		LAB_27D0		* return d0=-1,C=1/-ve d0=+1,C=0/+ve

LAB_282F
	MOVEQ		#0,d0			* clear result
RTS_018
	RTS

* convert FAC1 floating-to-fixed
* result in d0 and Itemp

LAB_2831
	MOVE.l	d1,-(sp)		* save d1
	MOVE.l	FAC1_m,d0		* copy mantissa
	MOVE.b	FAC1_e,d1		* get FAC1 exponent
	CMP.b		#$81,d1		* compare with min
	BCS.s		LAB_287F		* if <1 go clear FAC1 & return

	SUB.b		#$A0,d1		* compare maximum integer range exponent
	BNE.s		LAB_2844		* if not $A0, go test is less

	TST.b		FAC1_s		* test FAC1 sign
	BPL.s		LAB_2845		* branch if FAC1 +ve

						* FAC1 was -ve and exponent is $A0
	CMP.l		#$80000000,d0	* compare with max -ve
	BEQ.s		LAB_2845		* branch if max -ve

LAB_2844
	BCC		LAB_OFER		* do overflow if too big

LAB_2845
	NEG.b		d1			* convert -ve to +ve
	LSR.l		d1,d0			* shift integer

	TST.b		FAC1_s		* test FAC1 sign (b7)
	BPL.s		LAB_2846		* branch if FAC1 +ve

	NEG.l		d0			* negate integer value
LAB_2846
	MOVE.l	d0,Itemp
	MOVE.l	(sp)+,d1		* restore d1
	RTS
						* set zero result
LAB_287F
	MOVEQ		#0,d0			* clear result
	BRA.s		LAB_2846		* go save & exit

* perform INT()

LAB_INT
	CMP.b		#$A0,FAC1_e		* compare FAC1 exponent with max int
	BCC.s		RTS_018		* exit if >= (too big for fractional part!)

	MOVE.w	#$A000,d3		* set exponent for result
	MOVE.b	FAC1_s,d3		* get FAC1 sign
	MOVE.b	#0,FAC1_s		* make +ve
	BSR.s		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	MOVE.w	d3,FAC1_e		* set sign and exponent
	MOVE.l	d0,FAC1_m		* set mantissa
	BRA		LAB_24D5		* normalise FAC1 & return

* print " in line [LINE #]"

LAB_2953
	LEA		(LAB_LMSG,PC),a0	* point to " in line " message
	BSR		LAB_18C3		* print null terminated string

						* Print Basic line #
	MOVE.l	Clinel,d0		* get current line

* print d0 as unsigned integer

LAB_295E
	BSR.s		LAB_2966		* convert 32 bit d0 to unsigned string (a0)
	BRA		LAB_18C3		* print null terminated string from memory & RET

* convert d0 to unsigned ASCII string result in (a0)

LAB_2966
	MOVEA.l	#Bin2dec,a1		* get table address
	MOVEQ		#0,d1			* table index
	MOVEA.l	#Usdss,a0		* output string start
	MOVE.l	d1,d2			* output string index
LAB_2967
	MOVE.l	(a1,d1.w),d3	* get table value
	BEQ.s		LAB_2969		* exit if end marker

	MOVEQ		#'0'-1,d4		* set character to "0"-1
LAB_2968
	ADDQ.w	#1,d4			* next numeric character
	SUB.l		d3,d0			* subtract table value
	BPL.s		LAB_2968		* not overdone so loop

	ADD.l		d3,d0			* correct value
	MOVE.b	d4,(a0,d2.w)	* character out to string
	ADDQ.w	#4,d1			* increment table pointer
	ADDQ.w	#1,d2			* increment output string pointer
	BRA.s		LAB_2967		* loop

LAB_2969
	ADD.b		#'0',d0		* make last character
	MOVE.b	d0,(a0,d2.w)	* character out to string
	SUBQ.w	#1,a0			* decrement a0 (allow simple loop)

						* now find non zero start of string
LAB_296A
	ADDQ.w	#1,a0			* increment a0 (we know this will never carry to b16)
	CMPA.l	#(BHsend-1),a0	* are we at end
	BEQ.s		RTS_019		* branch if so

	CMPI.b	#'0',(a0)		* is character "0" ?
	BEQ.s		LAB_296A		* loop if so

RTS_019
	RTS

**LAB_xxxx	##
**	BSR.s		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
** now check not 0 and go print it ...

* convert FAC1 to ASCII string result in (a0)
* STR$() function enters here

* d0 is character out
* d1 is save index
* d2 is gash

* a0 is output pointer

LAB_2970
	BSR		LAB_27BA		* round FAC1
	MOVEA.l	#Decss,a1		* set output string start

** insert code here to test the numeric type and do integer if needed ##
**	BTST		#6,d0			* test the integer bit
**	BNE.s		LAB_xxxx		* branch if integer

	MOVE.b	#' ',(a1)		* character = " " (assume +ve)
	BCLR.b	#7,FAC1_s		* test and clear FAC1 sign (b7)
	BEQ.s		LAB_2978		* branch if +ve

	MOVE.b	#$2D,(a1)		* else character = "-"
LAB_2978
	MOVE.b	FAC1_e,d2		* get FAC1 exponent
	BNE.s		LAB_2989		* branch if FAC1<>0

						* exponent was $00 so FAC1 is 0
	MOVEQ		#'0',d0		* set character = "0"
	MOVEQ		#1,d1			* set output string index
	BRA		LAB_2A89		* save last character, [EOT] & exit

						* FAC1 is some non zero value
LAB_2989
	MOVE.b	#0,numexp		* clear number exponent count
	CMP.b		#$81,d2		* compare FAC1 exponent with $81 (>1.00000)

	BCC.s		LAB_299C		* branch if FAC1=>1

	MOVE.l	#$F4240000,FAC2_m	* 1000000 mantissa
	MOVE.w	#$9400,FAC2_e	* 1000000 exponent & sign
	MOVE.b	FAC1_s,FAC_sc	* make FAC1 sign sign compare
	BSR		LAB_MULTIPLY	* do FAC2*FAC1

	MOVE.b	#$FA,numexp		* set number exponent count (-6)
LAB_299C
	LEA		(LAB_294B,PC),a0	* set pointer to 999999.4375
						* (max before scientific notation)
	BSR		LAB_27F8		* compare FAC1 with (a0)
						* returns d0=+1 if FAC1 > FAC2
						* returns d0= 0 if FAC1 = FAC2
						* returns d0=-1 if FAC1 < FAC2
	BEQ.s		LAB_29C3		* exit if FAC1 = (a0)

	BPL.s		LAB_29B9		* go do /10 if FAC1 > (a0)

						* FAC1 < (a0)
LAB_29A7
	LEA		(LAB_2947,PC),a0	* set pointer to 99999.9375
	BSR		LAB_27F8		* compare FAC1 with (a0)
						* returns d0=+1 if FAC1 > FAC2
						* returns d0= 0 if FAC1 = FAC2
						* returns d0=-1 if FAC1 < FAC2
	BEQ.s		LAB_29B2		* branch if FAC1 = (a0) (allow decimal places)

	BPL.s		LAB_29C0		* branch if FAC1 > (a0) (no decimal places)

						* FAC1 <= (a0)
LAB_29B2
	BSR		LAB_269E		* multiply FAC1 by 10
	SUBQ.b	#1,numexp		* decrement number exponent count
	BRA.s		LAB_29A7		* go test again

LAB_29B9
	MOVE.w	FAC1_e,FAC2_e	* copy exponent & sign from FAC1 to FAC2
	MOVE.l	FAC1_m,FAC2_m	* copy FAC1 mantissa to FAC2 mantissa
	MOVE.b	FAC1_s,FAC_sc	* save FAC1_s as sign compare

	MOVE.l	#$CCCCCCCD,FAC1_m	* 1/10 mantissa
	MOVE.w	#$7D00,FAC1_e	* 1/10 exponent & sign
	BSR		LAB_MULTIPLY	* do FAC2*FAC1, effectively divide by 10 but faster

	ADDQ.b	#1,numexp		* increment number exponent count
	BRA.s		LAB_299C		* go test again (branch always)

						* now we have just the digits to do
LAB_29C0
	BSR		LAB_244E		* add 0.5 to FAC1 (round FAC1)
LAB_29C3
	BSR		LAB_2831		* convert FAC1 floating-to-fixed
						* result in d0 and Itemp
	MOVEQ		#$01,d2		* set default digits before dp = 1
	MOVE.b	numexp,d0		* get number exponent count
	ADD.b		#7,d0			* allow 6 digits before point
	BMI.s		LAB_29D9		* if -ve then 1 digit before dp

	CMP.b		#$08,d0		* d0>=8 if n>=1E6
	BCC.s		LAB_29D9		* branch if >= $08

						* < $08
	SUBQ.b	#1,d0			* take 1 from digit count
	MOVE.b	d0,d2			* copy byte
	MOVEQ		#$02,d0		* set exponent adjust
LAB_29D9
	MOVEQ		#0,d1			* set output string index
	SUBQ.b	#2,d0			* -2
	MOVE.b	d0,expcnt		* save exponent adjust
	MOVE.b	d2,numexp		* save digits before dp count
	MOVE.b	d2,d0			* copy digits before dp count
	BEQ.s		LAB_29E4		* branch if no digits before dp

	BPL.s		LAB_29F7		* branch if digits before dp

LAB_29E4
	ADDQ.l	#1,d1			* increment index
	MOVE.b	#'.',(a1,d1.w)	* save to output string

	TST.b		d2			* test digits before dp count
	BEQ.s		LAB_29F7		* branch if no digits before dp

	ADDQ.l	#1,d1			* increment index
	MOVE.b	#'0',(a1,d1.w)	* save to output string
LAB_29F7
	MOVEQ		#0,d2			* clear index (point to 100,000)
	MOVEQ		#$80-$100,d0	* set output character
LAB_29FB
	LEA		(LAB_2A9A,PC),a0	* get base of table
	MOVE.l	(a0,d2.w),d3	* get table value
LAB_29FD
	ADDQ.b	#1,d0			* increment output character
	ADD.l		d3,Itemp		* add to (now fixed) mantissa
	BTST		#7,d0			* set test sense (z flag only)
	BCS.s		LAB_2A18		* did carry so has wrapped past zero

	BEQ.s		LAB_29FD		* no wrap and +ve test so try again

	BRA.s		LAB_2A1A		* found this digit

LAB_2A18
	BNE.s		LAB_29FD		* wrap and -ve test so try again

LAB_2A1A
	BCC.s		LAB_2A21		* branch if +ve test result

	NEG.b		d0			* negate number
	ADD.b		#$0B,d0		* and effectively subtract from 11d
LAB_2A21
	ADD.b		#$2F,d0		* add "0"-1 to result
	ADDQ.w	#4,d2			* increment index to next less power of ten
	ADDQ.w	#1,d1			* increment output string index
	MOVE.b	d0,d3			* copy character to d3
	AND.b		#$7F,d3		* mask out top bit
	MOVE.b	d3,(a1,d1.w)	* save to output string
	SUB.b		#1,numexp		* decrement # of characters before the dp
	BNE.s		LAB_2A3B		* branch if still characters to do

						* else output the point
	ADDQ.l	#1,d1			* increment index
	MOVE.b	#'.',(a1,d1.w)	* save to output string
LAB_2A3B
	AND.b		#$80,d0		* mask test sense bit
	EORI.b	#$80,d0		* invert it
	CMP.b		#$18,d2		* compare table index with max+4
	BNE.s		LAB_29FB		* loop if not max

						* now remove trailing zeroes
LAB_2A4B
	MOVE.b	(a1,d1.w),d0	* get character from output string
	SUBQ.l	#1,d1			* decrement output string index
	CMP.b		#'0',d0		* compare with "0"
	BEQ.s		LAB_2A4B		* loop until non "0" character found

	CMP.b		#'.',d0		* compare with "."
	BEQ.s		LAB_2A58		* branch if was dp

						* else restore last character
	ADDQ.l	#1,d1			* increment output string index
LAB_2A58
	MOVE.b	#'+',2(a1,d1.w)	* save character "+" to output string
	TST.b		expcnt		* test exponent count
	BEQ.s		LAB_2A8C		* if zero go set null terminator & exit

						* exponent isn't zero so write exponent
	BPL.s		LAB_2A68		* branch if exponent count +ve

	MOVE.b	#'-',2(a1,d1.w)	* save character "-" to output string
	NEG.b		expcnt		* convert -ve to +ve
LAB_2A68
	MOVE.b	#'E',1(a1,d1.w)	* save character "E" to output string
	MOVE.b	expcnt,d2		* get exponent count
	MOVEQ		#$2F,d0		* one less than "0" character
LAB_2A74
	ADDQ.b	#1,d0			* increment 10's character
	SUB.b		#$0A,d2		* subtract 10 from exponent count
	BCC.s		LAB_2A74		* loop while still >= 0

	ADD.b		#$3A,d2		* add character ":" ($30+$0A, result is 10-value)
	MOVE.b	d0,3(a1,d1.w)	* save 10's character to output string
	MOVE.b	d2,4(a1,d1.w)	* save 1's character to output string
	MOVE.b	#0,5(a1,d1.w)	* save null terminator after last character
	BRA.s		LAB_2A91		* go set string pointer (a0) and exit

LAB_2A89
	MOVE.b	d0,(a1,d1.w)	* save last character to output string
LAB_2A8C
	MOVE.b	#0,1(a1,d1.w)	* save null terminator after last character
LAB_2A91
	MOVEA.l	a1,a0			* set result string pointer (a0)
	RTS

LAB_POON
	MOVE.l	#$80000000,FAC1_m	* 1 mantissa
	MOVE.w	#$8100,FAC1_e	* 1 exonent & sign
	RTS

LAB_POZE
	MOVEQ		#0,d0			* clear longword
	MOVE.l	d0,FAC1_m		* 0 mantissa
	MOVE.w	d0,FAC1_e		* 0 exonent & sign
	RTS

* Perform power function
* The number is in FAC2, the power is in FAC1
* no longer trashes Itemp

LAB_POWER
	TST.b		FAC1_e		* test power
	BEQ.s		LAB_POON		* if zero go return 1

	TST.b		FAC2_e		* test number
	BEQ.s		LAB_POZE		* if zero go return 0

	MOVE.b	FAC2_s,-(sp)	* save number sign
	BPL.s		LAB_POWP		* power of positive number

	MOVEQ		#0,d1			* clear d1
	MOVE.b	d1,FAC2_s		* make sign +ve

						* number sign was -ve, must have integer power
						* or do 'function call' error
	MOVE.b	FAC1_e,d1		* get power exponent
	SUB.w		#$80,d1		* normalise to .5
	BLS		LAB_FCER		* if 0<power<1 then do 'function call' error

						* now shift all the integer bits out
	MOVE.l	FAC1_m,d0		* get power mantissa
	ASL.l		d1,d0			* shift mantissa
	BNE		LAB_FCER		* if power<>INT(power) then do 'function call' error

	BCS.s		LAB_POWP		* if integer value odd then leave result -ve

	MOVE.b	d0,(sp)		* save result sign +ve
LAB_POWP
	MOVE.l	FAC1_m,-(sp)	* save power mantissa
	MOVE.w	FAC1_e,-(SP)	* save power sign & exponent

	BSR		LAB_279B		* copy number to FAC1
	BSR		LAB_LOG		* find log of number

	MOVE.w	(sp)+,d0		* get power sign & exponent
	MOVE.l	(sp)+,FAC2_m	* get power mantissa
	MOVE.w	d0,FAC2_e		* save sign & exponent to FAC2
	MOVE.b	d0,FAC_sc		* save sign as sign compare
	MOVE.b	FAC1_s,d0		* get FAC1 sign
	EOR.b		d0,FAC_sc		* make sign compare (FAC1_s EOR FAC2_s)

	BSR		LAB_MULTIPLY	* multiply by power
	BSR.s		LAB_EXP		* find exponential
	MOVE.b	(sp)+,FAC1_s	* restore number sign
	RTS

* Ffp ABS/NEG - make absolute or -ve equivalent of FAC1

	TST.b		FAC1_s		* test sign byte
	BEQ.s		RTS_020		* exit if +ve

* do - FAC1

LAB_GTHAN
	TST.b		FAC1_e		* test for non zero FAC1
	BEQ.s		RTS_020		* branch if null

	EORI.b	#$80,FAC1_s		* (else) toggle FAC1 sign bit
RTS_020
	RTS

						* return +1
LAB_EX1
	MOVE.l	#$80000000,FAC1_m	* +1 mantissa
	MOVE.w	#$8100,FAC1_e	* +1 sign & exponent
	RTS
						* do over/under flow
LAB_EXOU
	TST.b		FAC1_s		* test sign
	BPL		LAB_OFER		* was +ve so do overflow error

						* else underflow so return zero
	MOVEQ		#0,d0			* clear longword
	MOVE.l	d0,FAC1_m		* 0 mantissa
	MOVE.w	d0,FAC1_e		* 0 sign & exponent
	RTS
						* fraction was zero so do 2^n
LAB_EXOF
	MOVE.l	#$80000000,FAC1_m	* +n mantissa
	MOVE.b	#0,FAC1_s		* clear sign
	ADD.b		#$80,d1		* adjust exponent
	MOVE.b	d1,FAC1_e		* save exponent
	RTS

* perform EXP()	(x^e)
* valid input range is -88 to +88

LAB_EXP
	MOVE.b	FAC1_e,d0		* get exponent
	BEQ.s		LAB_EX1		* return 1 for zero in

	CMP.b		#$64,d0		* compare exponent with min
	BCS.s		LAB_EX1		* if smaller just return 1

**	MOVEM.l	d1-d6/a0,-(sp)	* save the registers
	MOVE.b	#0,cosout		* flag +ve number
	MOVE.l	FAC1_m,d1		* get mantissa
	CMP.b		#$87,d0		* compare exponent with max
	BHI.s		LAB_EXOU		* go do over/under flow if greater

	BNE.s		LAB_EXCM		* branch if less

						* else is 2^7
	CMP.l		#$B00F33C7,d1	* compare mantissa with n*2^7 max
	BCC.s		LAB_EXOU		* if => go over/underflow

LAB_EXCM
	TST.b		FAC1_s		* test sign
	BPL.s		LAB_EXPS		* branch if arg +ve

	MOVE.b	#$FF,cosout		* flag +ve number
	MOVE.b	#0,FAC1_s		* take absolute value
LAB_EXPS
						* now do n/LOG(2)
	MOVE.l	#$B8AA3B29,FAC2_m	* 1/LOG(2) mantissa
	MOVE.w	#$8100,FAC2_e	* 1/LOG(2) exponent & sign
	MOVE.b	#0,FAC_sc		* we know they're both +ve
	BSR		LAB_MULTIPLY	* effectively divide by log(2)

						* max here is +/- 127
						* now separate integer and fraction
	MOVE.b	#0,tpower		* clear exponent add byte
	MOVE.b	FAC1_e,d5		* get exponent
	SUB.b		#$80,d5		* normalise
	BLS.s		LAB_ESML		* branch if < 1 (d5 is 0 or -ve)

						* result is > 1
	MOVE.l	FAC1_m,d0		* get mantissa
	MOVE.l	d0,d1			* copy it
	MOVE.l	d5,d6			* copy normalised exponent

	NEG.w		d6			* make -ve
	ADD.w		#32,d6		* is now 32-d6
	LSR.l		d6,d1			* just integer bits
	MOVE.b	d1,tpower		* set exponent add byte

	LSL.l		d5,d0			* shift out integer bits
	BEQ		LAB_EXOF		* fraction is zero so do 2^n

	MOVE.l	d0,FAC1_m		* fraction to FAC1
	MOVE.w	#$8000,FAC1_e	* set exponent & sign

						* multiple was < 1
LAB_ESML
	MOVE.l	#$B17217F8,FAC2_m	* LOG(2) mantissa
	MOVE.w	#$8000,FAC2_e	* LOG(2) exponent & sign
	MOVE.b	#0,FAC_sc		* clear sign compare
	BSR		LAB_MULTIPLY	* multiply by log(2)

	MOVE.l	FAC1_m,d0		* get mantissa
	MOVE.b	FAC1_e,d5		* get exponent
	SUB.w		#$82,d5		* normalise and -2 (result is -1 to -30)
	NEG.w		d5			* make +ve
	LSR.l		d5,d0			* shift for 2 integer bits

* d0 = arg
* d6 = x, d1 = y
* d2 = x1, d3 = y1
* d4 = shift count
* d5 = loop count
						* now do cordic set-up
	MOVEQ		#0,d1			* y = 0
	MOVE.l	#KFCTSEED,d6	* x = 1 with jkh inverse factored out
	MOVEA.l	#TAB_HTHET,a0	* pointer to hyperbolic arctan table
	MOVEQ		#0,d4			* clear shift count
 
						* cordic loop, shifts 4 and 13 (and 39
						* if it went that far) need to be repeated
	MOVEQ		#3,d5			* 4 loops
	BSR.s		LAB_EXCC		* do loops 1 through 4
	SUBQ.w	#4,a0			* do table entry again
	SUBQ.l	#1,d4			* do shift count again
	MOVEQ		#9,d5			* 10 loops
	BSR.s		LAB_EXCC		* do loops 4 (again) through 13
	SUBQ.w	#4,a0			* do table entry again
	SUBQ.l	#1,d4			* do shift count again
	MOVEQ		#18,d5		* 19 loops
	BSR.s		LAB_EXCC		* do loops 13 (again) through 31
 
						* now get the result
	TST.b		cosout		* test sign flag
	BPL.s		LAB_EXPL		* branch if +ve

	NEG.l		d1			* do -y
	NEG.b		tpower		* do -exp
LAB_EXPL
	MOVEQ		#$83-$100,d0	* set exponent
	ADD.l		d1,d6			* y = y +/- x
	BMI.s		LAB_EXRN		* branch if result normal

LAB_EXNN
	SUBQ.l	#1,d0			* decrement exponent
	ADD.l		d6,d6			* shift mantissa
	BPL.s		LAB_EXNN		* loop if not normal

LAB_EXRN
	MOVE.l	d6,FAC1_m		* save exponent result
	ADD.b		tpower,d0		* add integer part
	MOVE.b	d0,FAC1_e		* save exponent
**	MOVEM.l	(sp)+,d1-d6/a0	* restore registers
	RTS
 
						* cordic loop
LAB_EXCC
	ADDQ.l	#1,d4			* increment shift count
	MOVE.l	d6,d2			* x1 = x
	ASR.l		d4,d2			* x1 >> n
	MOVE.l	d1,d3			* y1 = y
	ASR.l		d4,d3			* y1 >> n
	TST.l		d0			* test arg
	BMI.s		LAB_EXAD		* branch if -ve

	ADD.l		d2,d1			* y = y + x1
	ADD.l		d3,d6			* x = x + y1
	SUB.l		(a0)+,d0		* arg = arg - atnh(a0)
	DBF		d5,LAB_EXCC		* decrement and loop if not done

	RTS

LAB_EXAD
	SUB.l		d2,d1			* y = y - x1
	SUB.l		d3,d6			* x = x + y1
	ADD.l		(a0)+,d0		* arg = arg + atnh(a0)
	DBF		d5,LAB_EXCC		* decrement and loop if not done

	RTS

* RND(n), 31 bit version. make n=0 for 5th next number in sequence or n<>0 to get
* 5th next number in sequence after seed n. Taking the 5th next number is slower
* but helps hide the shift & add nature of this generator.

LAB_RND
	MOVE.b	FAC1_e,d0		* get FAC1 exponent
	BEQ.s		NextPRN		* do next random # if zero

						* else get seed into random number store
	MOVEA.l	#PRNlword,a0	* set PRNG pointer
	BSR		LAB_2778		* pack FAC1 into (a0)

NextPRN
	MOVEQ		#4,d2			* do this 5 times
	MOVE.l	PRNlword,d0		* get current
Ninc0
	MOVEQ		#0,d1			* clear bit count
	ROR.l		#2,d0			* bit 31 -> carry
	BCC.s		Ninc1			* skip increment if =0

	ADDQ.b	#1,d1			* else increment bit count
Ninc1
	ROR.l		#3,d0			* bit 28 -> carry
	BCC.s		Ninc2			* skip increment if =0

	ADDQ.b	#1,d1			* else increment bit count
Ninc2
	ROL.l		#5,d0			* restore PRNG longword
	ROXR.b	#1,d1			* EOR bit into Xb
	ROXR.l	#1,d0			* shift bit to most significant
	DBF		d2,Ninc0		* loop 5 times

	MOVE.l	d0,PRNlword		* save back to seed word
	MOVE.l	d0,FAC1_m		* save to FAC1

	MOVE.w	#$8000,FAC1_e	* set the exponent and clear the sign
	BRA		LAB_24D5		* normalise FAC1 & return

* cordic TAN(x) routine, TAN(x) = SIN(x)/COS(x)
* x = angle in radians

LAB_TAN
	BSR.s		LAB_SCCC		* go do SIN/COS cordic compute
	BSR		LAB_24D5		* normalise FAC1
	MOVE.w	FAC1_e,FAC2_e	* copy exponent & sign from FAC1 to FAC2
	MOVE.l	FAC1_m,FAC2_m	* copy FAC1 mantissa to FAC2 mantissa
	MOVE.l	d1,FAC1_m		* get COS(x) mantissa
	MOVE.b	d3,FAC1_e		* get COS(x) exponent
	BEQ		LAB_OFER		* do overflow if COS = 0

	BSR		LAB_24D5		* normalise FAC1
	BRA		LAB_DIVIDE		* do FAC2/FAC1 & return (FAC_sc set by SIN COS calc)

* cordic SIN(x), COS(x) routine
* x = angle in radians

LAB_COS
	MOVE.l	#$C90FDAA3,FAC2_m	* pi/2 mantissa (b2 is set so COS(PI/2)=0)
	MOVE.w	#$8100,FAC2_e	* pi/2 exponent and sign
	MOVE.b	FAC1_s,FAC_sc	* sign = FAC1 sign (b7)
	BSR		LAB_ADD		* add FAC2 to FAC1, adjust for COS(x)
LAB_SIN
	BSR.s		LAB_SCCC		* go do SIN/COS cordic compute
	BRA		LAB_24D5		* normalise FAC1 & return

* SIN/COS cordic calculator

LAB_SCCC
	MOVE.b	#0,cosout		* set needed result

	MOVE.l	#$A2F9836F,FAC2_m	* 1/pi mantissa (LSB is rounded up so SIN(PI)=0)
	MOVE.w	#$7F00,FAC2_e	* 1/pi exponent & sign
	MOVE.b	FAC1_s,FAC_sc	* sign = FAC1 sign (b7)
	BSR		LAB_MULTIPLY	* multiply by 1/pi

	MOVE.b	FAC1_e,d0		* get FAC1 exponent
	BEQ		LAB_SCZE		* branch if zero

	MOVEA.l	#TAB_SNCO,a0	* point to constants table
	MOVE.l	FAC1_m,d6		* get FAC1 mantissa
	SUBQ.b	#1,d0			* 2 radians in 360 degrees so /2
	BEQ		LAB_SCZE		* branch if zero

	SUB.b		#$80,d0		* normalise exponent
	BMI.s		LAB_SCL0		* branch if < 1

						* X is > 1
	CMP.b		#$20,d0		* is it >= 2^32
	BCC		LAB_SCZE		* may as well do zero

	LSL.l		d0,d6			* shift out integer part bits
	BEQ		LAB_SCZE		* no fraction so go do zero

	BRA.s		LAB_CORD		* go test quadrant and adjust

						* x is < 1
LAB_SCL0
	NEG.b		d0			* make +ve
	CMP.b		#$1E,d0		* is it <= 2^-30
	BCC.s		LAB_SCZE		* may as well do zero

	LSR.l		d0,d6			* shift out <= 2^-32 bits

* cordic calculator, arguament in d6
* table pointer in a0, returns in d0-d3

LAB_CORD
	MOVE.b	FAC1_s,FAC_sc	* copy as sign compare for TAN
	ADD.l		d6,d6			* shift 0.5 bit into carry
	BCC.s		LAB_LTPF		* branch if less than 0.5

	EORI.b	#$FF,FAC1_s		* toggle result sign
LAB_LTPF
	ADD.l		d6,d6			* shift 0.25 bit into carry
	BCC.s		LAB_LTPT		* branch if less than 0.25

	EORI.b	#$FF,cosout		* toggle needed result
	EORI.b	#$FF,FAC_sc		* toggle sign compare for TAN

LAB_LTPT
	LSR.l		#2,d6			* shift the bits back (clear integer bits)
	BEQ.s		LAB_SCZE		* no fraction so go do zero

						* set start values
	MOVEQ		#1,d5			* set bit count
	MOVE.l	-4(a0),d0		* get multiply constant (1st itteration d0)
	MOVE.l	d0,d1			* 1st itteration d1
	SUB.l		(a0)+,d6		* 1st always +ve so do 1st step
	BRA.s		mainloop		* jump into routine

subloop
	SUB.l		(a0)+,d6		* z = z - arctan(i)/2pi
	SUB.l		d3,d0			* x = x - y1
	ADD.l		d2,d1			* y = y + x1
	BRA.s		nexta			* back to main loop

mainloop
	MOVE.l	d0,d2			* x1 = x
	ASR.l		d5,d2			* / (2 ^ i)
	MOVE.l	d1,d3			* y1 = y
	ASR.l		d5,d3			* / (2 ^ i)
	TST.l		d6			* test sign (is 2^0 bit)
	BPL.s		subloop		* go do subtract if > 1

	ADD.l		(a0)+,d6		* z = z + arctan(i)/2pi
	ADD.l		d3,d0			* x = x + y1
	SUB.l		d2,d1			* y = y + x1
nexta
	ADDQ.l	#1,d5			* i = i + 1
	CMP.l		#$1E,d5		* check end condition
	BNE.s		mainloop		* loop if not all done

						* now untangle output value
	MOVEQ		#$81-$100,d2	* set exponent for 0 to .99 rec.
	MOVE.l	d2,d3			* copy it for cos output
outloop
	TST.b		cosout		* did we want cos output?
	BMI.s		subexit		* if so skip

	EXG		d0,d1			* swap SIN and COS mantissas
	EXG		d2,d3			* swap SIN and COS exponents
subexit
	MOVE.l	d0,FAC1_m		* set result mantissa
	MOVE.b	d2,FAC1_e		* set result exponent
RTS_021
	RTS

						* set values for 0/1
LAB_SCZE
	MOVEQ		#$81-$100,d2	* set exponent for 1.0
	MOVEQ		#0,d3			* set exponent for 0.0
	MOVE.l	#$80000000,d0	* mantissa for 1.0
	MOVE.l	d3,d1			* mantissa for 0.0
	BRA.s		outloop		* go output it

* perform ATN()

LAB_ATN
	MOVE.b	#0,cosout		* set needed result
	MOVE.b	FAC1_e,d0		* get FAC1 exponent
	CMP.b		#$81,d0		* compare exponent with 1
	BCS.s		LAB_ATLO		* branch if FAC1<1

	LEA		(LAB_259C,PC),a0	* set 1 pointer
	BSR		LAB_26CA		* convert a0 and do (a0)/FAC1
	MOVE.b	#$FF,cosout		* set needed result
LAB_ATLO
	MOVE.l	FAC1_m,d0		* get FAC1 mantissa
	ADD.b		FAC1_e,d1		* get FAC1 exponent (always <= 1)
	EXT.w		d1			* make word
	EXT.l		d1			* make word
	NEG.l		d1			* change to +ve
	ADDQ.l	#2,d1			* +2
	CMP.b		#11,d1		* compare with 2^-11
	BCC.s		RTS_021		* x = ATN(x) so skip calc

	LSR.l		d1,d0			* shift in two integer part bits
	BEQ.s		LAB_SCZE		* zero so go do zero

	MOVEA.l	#TAB_ATNC,a0	* pointer to arctan table
	MOVEQ		#0,d6			* Z = 0
	MOVE.l	#1<<30,d1		* y = 1
	MOVEQ		#29,d5		* loop 30 times
	MOVEQ		#1,d4			* shift counter
	BRA.s		LAB_ATCD		* enter loop

LAB_ATNP
	ASR.l		d4,d2			* x1 / 2^i
	ADD.l		d2,d1			* y = y + x1
	ADD.l		(A0),d6		* z = z + atn(i)
LAB_ATCD
	MOVE.l	d0,d2			* x1 = x
	MOVE.l	d1,d3			* y1 = y
	ASR.l		d4,d3			* y1 / 2^i
LAB_CATN
	SUB.l		d3,d0			* x = x - y1
	BPL.s		LAB_ATNP		* branch if x >= 0

	MOVE.l	d2,d0			* else get x back
	ADDQ.w	#4,a0			* increment pointer
	ADDQ.l	#1,d4			* increment i
	ASR.l		#1,d3			* y1 / 2^i
	DBF		d5,LAB_CATN		* decrement and loop if not done

	MOVE.b	#$82,FAC1_e		* set new exponent
	MOVE.l	d6,FAC1_m		* save mantissa
	BSR		LAB_24D5		* normalise FAC1

	TST.b		cosout		* was it > 1 ?
	BPL		RTS_021		* branch if not

	MOVE.b	FAC1_s,d7		* get sign
	MOVE.b	#0,FAC1_s		* clear sign
	MOVE.l	#$C90FDAA2,FAC2_m	* set -(pi/2)
	MOVE.w	#$8180,FAC2_E	* set exponent and sign
	MOVE.b	#$FF,FAC_sc		* set sign compare
	BSR		LAB_ADD		* perform addition, FAC2 to FAC1
	MOVE.b	d7,FAC1_s		* restore sign
	RTS

* perform BITSET

LAB_BITSET
	BSR		LAB_GADB		* get two parameters for POKE or WAIT
						* first parameter in a0, second in d0
	CMP.b		#$08,d0		* only 0 to 7 are allowed
	BCC		LAB_FCER		* branch if > 7

	MOVEQ		#$02,d1		* set value
	ASR.b		#1,d1			* set Xb and value
	ROXL.b	d0,d1			* move set bit
	OR.b		(a0),d1		* OR with byte
	MOVE.b	d1,(a0)		* save byte
	RTS

* perform BITCLR

LAB_BITCLR
	BSR		LAB_GADB		* get two parameters for POKE or WAIT
						* first parameter in a0, second in d0
	CMP.b		#$08,d0		* only 0 to 7 are allowed
	BCC		LAB_FCER		* branch if > 7

	MOVEQ		#$FF-$100,d1	* set value
	ASL.b		#1,d1			* set Xb and value
	ROXL.b	d0,d1			* move cleared bit
	AND.b		(a0),d1		* AND with byte
	MOVE.b	d1,(a0)		* save byte
	RTS

* perform BITTST()

LAB_BTST
	BSR		LAB_1BFE		* scan for "(" , else do syntax error/warm start
	BSR		LAB_GADB		* get two parameters for POKE or WAIT
						* first parameter in a0, second in d0
	CMP.b		#$08,d0		* only 0 to 7 are allowed
	BCC		LAB_FCER		* branch if > 7

	MOVE.l	d0,d1			* copy bit # to test
	BSR		LAB_GBYT		* get next BASIC byte
	CMP.b		#')',d0		* is next character ")"
	BNE		LAB_SNER		* if not ")" go do syntax error, then warm start

	BSR		LAB_IGBY		* update execute pointer (to character past ")")
	MOVEQ		#0,d0			* set the result as zero
	BTST		d1,(a0)		* test bit
	BEQ		LAB_27DB		* branch if zero (already correct)

	MOVEQ		#-1,d0		* set for -1 result
	BRA		LAB_27DB		* go do SGN tail

* perform BIN$()
* # of leading 0s is in d1, the number is in Itemp

LAB_BINS
	CMP.b		#$21,d1		* max + 1
	BCC		LAB_FCER		* exit if too big ( > or = )

	MOVE.l	Itemp,d0		* get number back
	MOVEQ		#$1F,d2		* bit count-1
	MOVEA.l	#Binss,a0		* point to string
	MOVEQ		#$30,d4		* "0" character for ADDX
NextB1
	MOVEQ		#0,d3			* clear byte
	LSR.l		#1,d0			* shift bit into Xb
	ADDX.b	d4,d3			* add carry and character to zero
	MOVE.b	d3,(a0,d2.w)	* save character to string
	DBF		d2,NextB1		* decrement and loop if not done

* this is the exit code and is also used by HEX$()

EndBHS
	MOVE.b	#0,BHsend		* null terminate the string
	TST.b		d1			* test # of characters
	BEQ.s		NextB2		* go truncate string

	NEG.l		d1			* make -ve
	ADD.l		#BHsend,d1		* effectively (end-length)
	MOVEA.l	d1,a0			* move to pointer
	BRA.s		BinPr			* go print string

* truncate string to remove leading "0"s

NextB2
	MOVE.b	(a0),d0		* get byte
	BEQ.s		BinPr			* if null then end of string so add 1 and print it

	CMP.b		#'0',d0		* compare with "0"
	BNE.s		GoPr			* if not "0" then go print string from here

	ADDQ.w	#1,a0			* else increment pointer
	BRA.s		NextB2		* loop always

* make fixed length output string - ignore overflows!

BinPr
	CMPA.l	#BHsend,a0		* are we at the string end
	BNE.s		GoPr			* branch if not

	SUBQ.w	#1,a0			* else need at least one zero
GoPr
	BSR		LAB_IGBY		* update execute pointer (to character past ")")
	ADDQ.w	#4,sp			* bypass type check on exit
	BRA		LAB_20AE		* print " terminated string to FAC1, stack & RET

* perform HEX$()

LAB_HEXS
	CMP.b		#$09,d1		* max + 1
	BCC		LAB_FCER		* exit if too big ( > or = )

	MOVE.l	Itemp,d0		* get number back
	MOVEQ		#$07,d2		* nibble count-1
	MOVEA.l	#Hexss,a0		* point to string
	MOVEQ		#$30,d4		* "0" character for ABCD
NextH1
	MOVE.b	d0,d3			* copy lowest byte
	ROR.l		#4,d0			* shift nibble into 0-3
	AND.b		#$0F,d3		* just this nibble
	MOVE.b	d3,d5			* copy it
	ADD.b		#$F6,d5		* set extend bit
	ABCD		d4,d3			* decimal add extend and character to zero
	MOVE.b	d3,(a0,d2.w)	* save character to string
	DBF		d2,NextH1		* decrement and loop if not done

	BRA.s		EndBHS		* go process string

* ctrl-c check routine. includes limited "life" byte save for INGET routine
* now also the code that checks to see if an interrupt has occurred

VEC_CC
	TST.b		ccflag		* check [CTRL-C] check flag
	BNE.s		RTS_022		* exit if inhibited

	JSR		V_INPT		* scan input device
	BCC.s		LAB_FBA0		* exit if buffer empty

	MOVE.b	d0,ccbyte		* save received byte
	MOVE.b	#$20,ccnull		* set "life" timer for bytes countdown
	BRA		LAB_1636		* return to BASIC

LAB_FBA0
	TST.b		ccnull		* get countdown byte
	BEQ.s		RTS_022		* exit if finished

	SUBQ.b	#1,ccnull		* else decrement countdown
RTS_022
	RTS

* get byte from input device, no waiting
* returns with carry set if byte in A

INGET
	JSR		V_INPT		* call scan input device
	BCS.s		LAB_FB95		* if byte go reset timer

	MOVE.b	ccnull,d0		* get countdown
	BEQ.s		RTS_022		* exit if empty

	MOVE.b	ccbyte,d0		* get last received byte
LAB_FB95
	MOVE.b	#$00,ccnull		* clear timer because we got a byte
	ORI.b		#1,CCR		* set carry, flag we got a byte
	RTS

* perform MAX()

LAB_MAX
	BSR		LAB_1BFE		* scan for "(" , else do syntax error/warm start
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch error/warm start
LAB_MAXN
	BSR.s		LAB_PHFA		* push FAC1, evaluate expression,
						* pull FAC2 & compare with FAC1
	BPL.s		LAB_MAXN		* branch if no swap to do

	BSR		LAB_279B		* copy FAC2 to FAC1
	BRA.s		LAB_MAXN		* go do next

* perform MIN()

LAB_MIN
	BSR		LAB_1BFE		* scan for "(" , else do syntax error/warm start
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch
LAB_MINN
	BSR.s		LAB_PHFA		* push FAC1, evaluate expression,
						* pull FAC2 & compare with FAC1
	BMI.s		LAB_MINN		* branch if no swap to do

	BEQ.s		LAB_MINN		* branch if no swap to do

	BSR		LAB_279B		* copy FAC2 to FAC1
	BRA.s		LAB_MINN		* go do next (branch always)

* exit routine. don't bother returning to the loop code
* check for correct exit, else so syntax error

LAB_MMEC
	CMP.b		#')',d0		* is it end of function?
	BNE		LAB_SNER		* if not do MAX MIN syntax error

	ADDQ.w	#4,sp			* dump return address
	BSR		LAB_IGBY		* update BASIC execute pointer (to chr past ")")
	RTS

* check for next, evaluate & return or exit
* this is the routine that does most of the work

LAB_PHFA
	BSR		LAB_GBYT		* get next BASIC byte
	CMP.b		#',',d0		* is there more ?
	BNE.s		LAB_MMEC		* if not go do end check

	MOVE.w	FAC1_e,-(sp)	* push exponent and sign
	MOVE.l	FAC1_m,-(sp)	* push mantissa

	BSR		LAB_IGBY		* scan & get next BASIC byte (after ",")
	BSR		LAB_EVNM		* evaluate expression & check is numeric,
						* else do type mismatch

						* pop FAC2 (MAX/MIN expression so far)
	MOVE.l	(sp)+,FAC2_m	* pop mantissa
	MOVE.w	(sp)+,FAC2_e	* pop exponent and sign

	MOVE.b	FAC2_s,FAC_sc	* save FAC2 sign as sign compare
	MOVE.b	FAC1_s,d0		* get FAC1 sign
	EOR.b		d0,FAC_sc		* EOR to create sign compare

	BRA		LAB_27FA		* compare FAC1 with FAC2 & return
						* returns d0=+1 if FAC1 > FAC2
						* returns d0= 0 if FAC1 = FAC2
						* returns d0=-1 if FAC1 < FAC2

* perform WIDTH

LAB_WDTH
	CMP.b		#',',d0		* is next byte ","
	BEQ.s		LAB_TBSZ		* if so do tab size

	BSR		LAB_GTBY		* get byte parameter, result in d0 and Itemp
	TST.b		d0			* test result
	BEQ.s		LAB_NSTT		* branch if set for infinite line

	CMP.b		#$10,d0		* else make min width = 16d
	BCS		LAB_FCER		* if less do function call error & exit

* this next compare ensures that we can't exit WIDTH via an error leaving the
* tab size greater than the line length.

	CMP.b		TabSiz,d0		* compare with tab size
	BCC.s		LAB_NSTT		* branch if >= tab size

	MOVE.b	d0,TabSiz		* else make tab size = terminal width
LAB_NSTT
	MOVE.b	d0,TWidth		* set the terminal width
	BSR		LAB_GBYT		* get BASIC byte back
	BEQ.s		WExit			* exit if no following

	CMP.b		#',',d0		* else is it ","
	BNE		LAB_SNER		* if not do syntax error

LAB_TBSZ
	BSR		LAB_SGBY		* increment and get byte, result in d0 and Itemp
	TST.b		d0			* test TAB size
	BMI		LAB_FCER		* if >127 do function call error & exit

	CMP.b		#1,d0			* compare with min-1
	BCS		LAB_FCER		* if <=1 do function call error & exit

	MOVE.b	TWidth,d1		* set flags for width
	BEQ.s		LAB_SVTB		* skip check if infinite line

	CMP.b		TWidth,d0		* compare TAB with width
	BGT		LAB_FCER		* branch if too big

LAB_SVTB
	MOVE.b	d0,TabSiz		* save TAB size

* calculate tab column limit from TAB size. The Iclim is set to the last tab
* position on a line that still has at least one whole tab width between it
* and the end of the line.

WExit
	MOVE.b	TWidth,d0		* get width
	BEQ.s		LAB_WDLP		* branch if infinite line

	CMP.b		TabSiz,d0		* compare with tab size
	BCC.s		LAB_WDLP		* branch if >= tab size

	MOVE.b	d0,TabSiz		* else make tab size = terminal width
LAB_WDLP
	SUB.b		TabSiz,d0		* subtract tab size
	BCC.s		LAB_WDLP		* loop while no borrow

	ADD.b		TabSiz,d0		* add tab size back
	ADD.b		TabSiz,d0		* add tab size back again

	NEG.b		d0			* make -ve
	ADD.b		TWidth,d0		* subtract remainder from width
	MOVE.b	d0,Iclim		* save tab column limit
RTS_023
	RTS

* perform SQR()

* d0 is number to find the root of
* d1 is the root result
* d2 is the remainder
* d3 is a counter
* d4 is temp

LAB_SQR
	TST.b		FAC1_s		* test FAC1 sign
	BMI		LAB_FCER		* if -ve do function call error

	TST.b		FAC1_e		* test exponent
	BEQ.s		RTS_023		* exit if zero

	MOVEM.l	d1-d4,-(sp)		* save registers
	MOVE.l	FAC1_m,d0		* copy FAC1
	MOVEQ		#0,d2			* clear remainder
	MOVE.l	d2,d1			* clear root

	MOVEQ		#$1F,d3		* $1F for DBF, 64 pairs of bits to
						* do for a 32 bit result
	BTST		#0,FAC1_e		* test exponent odd/even
	BNE.s		LAB_SQE2		* if odd only 1 shift first time

LAB_SQE1
	ADD.l		d0,d0			* shift highest bit of number ..
	ADDX.l	d2,d2			* .. into remainder .. never overflows
	ADD.l		d1,d1			* root = root * 2 .. never overflows
LAB_SQE2
	ADD.l		d0,d0			* shift highest bit of number ..
	ADDX.l	d2,d2			* .. into remainder .. never overflows

	MOVE.l	d1,d4			* copy root
	ADD.l		d4,d4			* 2n
	ADDQ.l	#1,d4			* 2n+1

	CMP.l		d4,d2			* compare 2n+1 to remainder
	BCS.s		LAB_SQNS		* skip sub if remainder smaller

	SUB.l		d4,d2			* subtract temp from remainder
	ADDQ.l	#1,d1			* increment root
LAB_SQNS
	DBF		d3,LAB_SQE1		* loop if not all done

	MOVE.l	d1,FAC1_m		* save result mantissa
	MOVE.b	FAC1_e,d0		* get exponent (d0 is clear here)
	SUB.w		#$80,d0		* normalise
	LSR.w		#1,d0			* /2
	BCC.s		LAB_SQNA		* skip increment if carry clear

	ADDQ.w	#1,d0			* add bit zero back in (allow for half shift)
LAB_SQNA
	ADD.w		#$80,d0		* re-bias to $80
	MOVE.b	d0,FAC1_e		* save it
	MOVEM.l	(sp)+,d1-d4		* restore registers
	BRA		LAB_24D5		* normalise FAC1 & return

* perform VARPTR()

LAB_VARPTR
	BSR		LAB_1BFE		* scan for "(" , else do syntax error/warm start
	BSR		LAB_GVAR		* get var address
						* return pointer to variable in Cvaral and a0
	BSR		LAB_1BFB		* scan for ")" , else do syntax error/warm start
	MOVE.l	Cvaral,d0		* get var address
	BRA		LAB_AYFC		* convert d0 to signed longword in FAC1 & return

* perform TI

LAB_TI
	MOVEQ		#8,d0			* get time
	TRAP		#15
	MOVE.l	d1,FAC1_m		* time (in 100ths seconds) into FAC1
	MOVE.w	#$A000,FAC1_e	* time exponent and sign
	MOVE.b	#$00,Dtypef		* clear data type flag, $00=float
	BRA		LAB_24D5		* normalise FAC1 & return

* perform PI

LAB_PI
	MOVE.b	#$00,Dtypef		* clear data type flag, $00=float
	MOVE.l	#$C90FDAA2,FAC1_m	* pi mantissa (32 bit)
	MOVE.w	#$8200,FAC1_e	* pi exponent and sign
	RTS

* perform TWOPI

LAB_TWOPI
	MOVE.b	#$00,Dtypef		* clear data type flag, $00=float
	MOVE.l	#$C90FDAA2,FAC1_m	* 2pi mantissa (32 bit)
	MOVE.w	#$8300,FAC1_e	* 2pi exponent and sign
	RTS

* get ASCII string equivalent into FAC1 as integer32 or float

* entry is with a5 pointing to the first character of the string
* exit with a5 pointing to the first character after the string

* d0 is character
* d1 is mantissa
* d2 is partial and table mantissa
* d3 is mantissa exponent (decimal & binary)
* d4 is decimal exponent

* get FAC1 from string
* this routine now handles hex and binary values from strings
* starting with "$" and "%" respectively

LAB_2887
	MOVEM.l	d1-d5,-(sp)		* save registers
	MOVEQ		#$00,d1		* clear temp accumulator
	MOVE.l	d1,d3			* set mantissa decimal exponent count
	MOVE.l	d1,d4			* clear decimal exponent
	MOVE.b	d1,FAC1_s		* clear sign byte
	MOVE.b	d1,Dtypef		* set float data type
	MOVE.b	d1,expneg		* clear exponent sign
	BSR		LAB_GBYT		* get first byte back
	BCS.s		LAB_28FE		* go get floating if 1st character numeric

	CMP.b		#'-',d0		* or is it -ve number
	BNE.s		LAB_289A		* branch if not

	MOVE.b	#$FF,FAC1_s		* set sign byte
	BRA.s		LAB_289C		* now go scan & check for hex/bin/int

LAB_289A
						* first character wasn't numeric or -
	CMP.b		#'+',d0		* compare with '+'
	BNE.s		LAB_289D		* branch if not '+' (go check for '.'/hex/bin/int)
	
LAB_289C
						* was "+" or "-" to start, so get next character
	BSR		LAB_IGBY		* increment & scan memory
	BCS.s		LAB_28FE		* branch if numeric character

LAB_289D
	CMP.b		#'.',d0		* else compare with '.'
	BEQ		LAB_2904		* branch if '.'

						* code here for hex/binary/integer numbers
	CMP.b		#'$',d0		* compare with '$'
	BEQ		LAB_CHEX		* branch if '$'

	CMP.b		#'%',d0		* else compare with '%'
	BEQ		LAB_CBIN		* branch if '%'

**	CMP.b		#'&',d0		* else compare with '&'
**	BEQ.s		LAB_CINT		* branch if '&' go do integer get ##

* ##	BRA		LAB_SNER		* not #.$%& so do error
	BRA		LAB_2Y01		* not #.$%& so return 0

LAB_28FD
	BSR		LAB_IGBY		* get next character
	BCC.s		LAB_2902		* exit loop if not a digit

LAB_28FE
	BSR		d1x10			* multiply d1 by 10 and add character
	BCC.s		LAB_28FD		* loop for more if no overflow

LAB_28FF
						* overflowed mantissa, count 10s exponent
	ADDQ.l	#1,d3			* increment mantissa decimal exponent count
	BSR		LAB_IGBY		* get next character
	BCS.s		LAB_28FF		* loop while numeric character

						* done overflow, now flush fraction or do E
	CMP.b		#'.',d0		* else compare with '.'
	BNE.s		LAB_2901		* branch if not '.'

LAB_2900
						* flush remaining fractional digits
	BSR		LAB_IGBY		* get next character
	BCS		LAB_2900		* loop while numeric character

LAB_2901
						* done number, only (possible) exponent remains
	CMP.b		#'E',d0		* else compare with 'E'
	BNE.s		LAB_2Y01		* if not 'E' all done, go evaluate

						* process exponent
	BSR		LAB_IGBY		* get next character
	BCS.s		LAB_2X04		* branch if digit

	CMP.b		#'-',d0		* or is it -ve number
	BEQ.s		LAB_2X01		* branch if so

	CMP.b		#TK_MINUS,d0	* or is it -ve number
	BNE.s		LAB_2X02		* branch if not

LAB_2X01
	MOVE.b	#$FF,expneg		* set exponent sign
	BRA.s		LAB_2X03		* now go scan & check exponent

LAB_2X02
	CMP.b		#'+',d0		* or is it +ve number
	BEQ.s		LAB_2X03		* branch if so

	CMP.b		#TK_PLUS,d0		* or is it +ve number
	BNE		LAB_SNER		* wasn't - + TK_MINUS TK_PLUS or # so do error

LAB_2X03
	BSR		LAB_IGBY		* get next character
	BCC.s		LAB_2Y01		* if not digit all done, go evaluate
LAB_2X04
	MULU		#10,d4		* multiply decimal exponent by 10
	AND.l		#$FF,d0		* mask character
	SUB.b		#'0',d0		* convert to value
	ADD.l		d0,d4			* add to decimal exponent
	CMP.b		#48,d4		* compare with decimal exponent limit+10
	BLE.s		LAB_2X03		* loop if no overflow/underflow

LAB_2X05
						* exponent value has overflowed
	BSR		LAB_IGBY		* get next character
	BCS.s		LAB_2X05		* loop while numeric digit

	BRA.s		LAB_2Y01		* all done, go evaluate

LAB_2902
	CMP.b		#'.',d0		* else compare with '.'
	BEQ.s		LAB_2904		* branch if was '.'

	BRA.s		LAB_2901		* branch if not '.' (go check/do 'E')

LAB_2903
	SUBQ.l	#1,d3			* decrement mantissa decimal exponent
LAB_2904
						* was dp so get fractional part
	BSR		LAB_IGBY		* get next character
	BCC.s		LAB_2901		* exit loop if not a digit (go check/do 'E')

	BSR		d1x10			* multiply d1 by 10 and add character
	BCC.s		LAB_2903		* loop for more if no overflow

	BRA.s		LAB_2900		* else go flush remaining fractional part

LAB_2Y01
						* now evaluate result
	TST.b		expneg		* test exponent sign
	BPL.s		LAB_2Y02		* branch if sign positive

	NEG.l		d4			* negate decimal exponent
LAB_2Y02
	ADD.l		d3,d4			* add mantissa decimal exponent
	MOVEQ		#32,d3		* set up max binary exponent
	TST.l		d1			* test mantissa
	BEQ.s		LAB_rtn0		* if mantissa=0 return 0

	BMI.s		LAB_2Y04		* branch if already mormalised

	SUBQ.l	#1,d3			* decrement bianry exponent for DBMI loop
LAB_2Y03
	ADD.l		d1,d1			* shift mantissa
	DBMI		d3,LAB_2Y03		* decrement & loop if not normalised

						* ensure not too big or small
LAB_2Y04
	CMP.l		#38,d4		* compare decimal exponent with max exponent
	BGT		LAB_OFER		* if greater do overflow error and warm start

	CMP.l		#-38,d4		* compare decimal exponent with min exponent
	BLT.s		LAB_ret0		* if less just return zero

	NEG.l		d4			* negate decimal exponent to go right way
	MULS		#6,d4			* 6 bytes per entry
	MOVE.l	a0,-(sp)		* save register
	LEA		(LAB_P_10,PC),a0	* point to table
	MOVE.b	1(a0,d4.w),FAC2_e	* copy exponent for multiply
	MOVE.l	2(a0,d4.w),FAC2_m	* copy table mantissa
	MOVE.l	(sp)+,a0		* restore register

	EORI.b	#$80,d3		* normalise input exponent
	MOVE.l	d1,FAC1_m		* save input mantissa
	MOVE.b	d3,FAC1_e		* save input exponent
	MOVE.b	FAC1_s,FAC_sc	* set sign as sign compare

	MOVEM.l	(sp)+,d1-d5		* restore registers
	BRA		LAB_MULTIPLY	* go multiply input by table

LAB_ret0
	MOVEQ		#0,d1			* clear mantissa
LAB_rtn0
	MOVE.l	d1,d3			* clear exponent
	MOVE.b	d3,FAC1_e		* save exponent
	MOVE.l	d1,FAC1_m		* save mantissa
	MOVEM.l	(sp)+,d1-d5		* restore registers
	RTS

* $ for hex add-on

* gets here if the first character was "$" for hex
* get hex number

LAB_CHEX
	MOVE.b	#$40,Dtypef		* set integer numeric data type
	MOVEQ		#32,d3		* set up max binary exponent
LAB_CHXX
	BSR		LAB_IGBY		* increment & scan memory
	BCS.s		LAB_ISHN		* branch if numeric character

	OR.b		#$20,d0		* case convert, allow "A" to "F" and "a" to "f"
	SUB.b		#'a',d0		* subtract "a"
	BCS.s		LAB_CHX3		* exit if <"a"

	CMP.b		#$06,d0		* compare normalised with $06 (max+1)
	BCC.s		LAB_CHX3		* exit if >"f"

	ADD.b		#$3A,d0		* convert to nibble+"0"
LAB_ISHN
	BSR.s		d1x16			* multiply d1 by 16 and add character
	BCC.s		LAB_CHXX		* loop for more if no overflow

						* overflowed mantissa, count 16s exponent
LAB_CHX1
	ADDQ.l	#4,d3			* increment mantissa exponent count
	BVS		LAB_OFER		* do overflow error if overflowed

	BSR		LAB_IGBY		* get next character
	BCS.s		LAB_CHX1		* loop while numeric character

	OR.b		#$20,d0		* case convert, allow "A" to "F" and "a" to "f"
	SUB.b		#'a',d0		* subtract "a"
	BCS.s		LAB_CHX3		* exit if <"a"

	CMP.b		#$06,d0		* compare normalised with $06 (max+1)
	BCS.s		LAB_CHX1		* loop if <="f"

						* now return value
LAB_CHX3
	TST.l		d1			* test mantissa
	BEQ.s		LAB_rtn0		* if mantissa=0 return 0

	BMI.s		LAB_exxf		* branch if already mormalised

	SUBQ.l	#1,d3			* decrement bianry exponent for DBMI loop
LAB_CHX2
	ADD.l		d1,d1			* shift mantissa
	DBMI		d3,LAB_CHX2		* decrement & loop if not normalised

LAB_exxf
	EORI.b	#$80,d3		* normalise exponent
	MOVE.b	d3,FAC1_e		* save exponent
	MOVE.l	d1,FAC1_m		* save mantissa
	MOVEM.l	(sp)+,d1-d5		* restore registers
RTS_024
	RTS

* % for binary add-on

* gets here if the first character was  "%" for binary
* get binary number

LAB_CBIN
	MOVE.b	#$40,Dtypef		* set integer numeric data type
	MOVEQ		#32,d3		* set up max binary exponent
LAB_CBXN
	BSR		LAB_IGBY		* increment & scan memory
	BCC.s		LAB_CHX3		* if not numeric character go return value

	CMP.b		#'2',d0		* compare with "2" (max+1)
	BCC.s		LAB_CHX3		* if >="2" go return value

	MOVE.l	d1,d2			* copy value
	BSR.s		d1x02			* multiply d1 by 2 and add character
	BCC.s		LAB_CBXN		* loop for more if no overflow

						* overflowed mantissa, count 2s exponent
LAB_CBX1
	ADDQ.l	#1,d3			* increment mantissa exponent count
	BVS		LAB_OFER		* do overflow error if overflowed

	BSR		LAB_IGBY		* get next character
	BCC.s		LAB_CHX3		* if not numeric character go return value

	CMP.b		#'2',d0		* compare with "2" (max+1)
	BCS.s		LAB_CBX1		* loop if <"2"

	BRA.s		LAB_CHX3		* if not numeric character go return value

* half way decent times 16 and times 2 with overflow checks

d1x16
	MOVE.l	d1,d2			* copy value
	ADD.l		d2,d2			* times two
	BCS.s		RTS_024		* return if overflow

	ADD.l		d2,d2			* times four
	BCS.s		RTS_024		* return if overflow

	ADD.l		d2,d2			* times eight
	BCS.s		RTS_024		* return if overflow

d1x02
	ADD.l		d2,d2			* times sixteen (ten/two)
	BCS.s		RTS_024		* return if overflow

* now add in new digit

	AND.l		#$FF,d0		* mask character
	SUB.b		#'0',d0		* convert to value
	ADD.l		d0,d2			* add to result
	BCS.s		RTS_024		* return if overflow (should never ever do this ##)

	MOVE.l	d2,d1			* copy result
	RTS

* half way decent times 10 with overflow checks

d1x10
	MOVE.l	d1,d2			* copy value
	ADD.l		d2,d2			* times two
	BCS.s		RTS_025		* return if overflow

	ADD.l		d2,d2			* times four
	BCS.s		RTS_025		* return if overflow

	ADD.l		d1,d2			* times five
	BCC.s		d1x02			* times two if ok

RTS_025
	RTS

*************************************************************************************

* token values needed for BASIC

TK_END		EQU $80		* $80
TK_FOR		EQU TK_END+1	* $81	* FOR token
TK_NEXT		EQU TK_FOR+1	* $82
TK_DATA		EQU TK_NEXT+1	* $83	* DATA token
TK_INPUT		EQU TK_DATA+1	* $84
TK_DIM		EQU TK_INPUT+1	* $85
TK_READ		EQU TK_DIM+1	* $86
TK_LET		EQU TK_READ+1	* $87
TK_DEC		EQU TK_LET+1	* $88
TK_GOTO		EQU TK_DEC+1	* $89	* GOTO token
TK_RUN		EQU TK_GOTO+1	* $8A
TK_IF			EQU TK_RUN+1	* $8B
TK_RESTORE		EQU TK_IF+1		* $8C
TK_GOSUB		EQU TK_RESTORE+1	* $8D	* GOSUB token
TK_RETURN		EQU TK_GOSUB+1	* $8E
TK_REM		EQU TK_RETURN+1	* $8F	* REM token
TK_STOP		EQU TK_REM+1	* $90
TK_ON			EQU TK_STOP+1	* $91	* ON token
TK_NULL		EQU TK_ON+1		* $92
TK_INC		EQU TK_NULL+1	* $93
TK_WAIT		EQU TK_INC+1	* $94
TK_LOAD		EQU TK_WAIT+1	* $95
TK_SAVE		EQU TK_LOAD+1	* $96
TK_DEF		EQU TK_SAVE+1	* $97
TK_POKE		EQU TK_DEF+1	* $98
TK_DOKE		EQU TK_POKE+1	* $99
TK_LOKE		EQU TK_DOKE+1	* $9A
TK_CALL		EQU TK_LOKE+1	* $9B
TK_DO			EQU TK_CALL+1	* $9C	* DO token
TK_LOOP		EQU TK_DO+1		* $9D
TK_PRINT		EQU TK_LOOP+1	* $9E	* PRINT token
TK_CONT		EQU TK_PRINT+1	* $9F

TK_CLS		EQU TK_CONT+1	* $A0 * EASy68k graphics
TK_CURSOR		EQU TK_CLS+1	* $A1 * EASy68k graphics
TK_LINE		EQU TK_CURSOR+1	* $A2 * EASy68k graphics
TK_FILL		EQU TK_LINE+1	* $A3 * EASy68k graphics
TK_MOVE		EQU TK_FILL+1	* $A4 * EASy68k graphics
TK_POINT		EQU TK_MOVE+1	* $A5 * EASy68k graphics
TK_RECT		EQU TK_POINT+1	* $A6 * EASy68k graphics
TK_FRECT		EQU TK_RECT+1	* $A7 * EASy68k graphics
TK_ELLIPSE		EQU TK_FRECT+1	* $A8 * EASy68k graphics
TK_FELLIPSE		EQU TK_ELLIPSE+1	* $A9 * EASy68k graphics
TK_MODE		EQU TK_FELLIPSE+1	* $AA * EASy68k graphics
TK_SIZE		EQU TK_MODE+1	* $AB * EASy68k graphics

TK_LIST		EQU TK_SIZE+1	* $AC
TK_CLEAR		EQU TK_LIST+1	* $AD	* CLEAR token
TK_NEW		EQU TK_CLEAR+1	* $AE
TK_WIDTH		EQU TK_NEW+1	* $AF
TK_GET		EQU TK_WIDTH+1	* $B0
TK_SWAP		EQU TK_GET+1	* $B1
TK_BITSET		EQU TK_SWAP+1	* $B2
TK_BITCLR		EQU TK_BITSET+1	* $B3
TK_TAB		EQU TK_BITCLR+1	* $B4	* TAB token
TK_TO			EQU TK_TAB+1	* $B5	* TO token
TK_FN			EQU TK_TO+1		* $B6	* FN token
TK_SPC		EQU TK_FN+1		* $B7	* SPC token
TK_THEN		EQU TK_SPC+1	* $B8	* THEN token
TK_NOT		EQU TK_THEN+1	* $B9	* NOT token
TK_STEP		EQU TK_NOT+1	* $BA	* STEP token
TK_UNTIL		EQU TK_STEP+1	* $BB	* UNTIL token
TK_WHILE		EQU TK_UNTIL+1	* $BC
TK_PLUS		EQU TK_WHILE+1	* $BD	* + token
TK_MINUS		EQU TK_PLUS+1	* $BE	* - token
TK_MULT		EQU TK_MINUS+1	* $BF
TK_DIV		EQU TK_MULT+1	* $C0
TK_POWER		EQU TK_DIV+1	* $C1
TK_AND		EQU TK_POWER+1	* $C2
TK_EOR		EQU TK_AND+1	* $C3
TK_OR			EQU TK_EOR+1	* $C4
TK_RSHIFT		EQU TK_OR+1		* $C5
TK_LSHIFT		EQU TK_RSHIFT+1	* $C6
TK_GT			EQU TK_LSHIFT+1	* $C7	* > token
TK_EQUAL		EQU TK_GT+1		* $C8	* = token
TK_LT			EQU TK_EQUAL+1	* $C9	* < token
TK_SGN		EQU TK_LT+1		* $CA	* SGN token
TK_INT		EQU TK_SGN+1	* $CB
TK_ABS		EQU TK_INT+1	* $CC
TK_USR		EQU TK_ABS+1	* $CD
TK_FRE		EQU TK_USR+1	* $CE
TK_POS		EQU TK_FRE+1	* $CF
TK_SQR		EQU TK_POS+1	* $D0
TK_RND		EQU TK_SQR+1	* $D1
TK_LOG		EQU TK_RND+1	* $D2
TK_EXP		EQU TK_LOG+1	* $D3
TK_COS		EQU TK_EXP+1	* $D4
TK_SIN		EQU TK_COS+1	* $D5
TK_TAN		EQU TK_SIN+1	* $D6
TK_ATN		EQU TK_TAN+1	* $D7
TK_PEEK		EQU TK_ATN+1	* $D8
TK_DEEK		EQU TK_PEEK+1	* $D9
TK_LEEK		EQU TK_DEEK+1	* $DA
TK_SADD		EQU TK_LEEK+1	* $DB
TK_LEN		EQU TK_SADD+1	* $DC
TK_STRS		EQU TK_LEN+1	* $DD
TK_VAL		EQU TK_STRS+1	* $DE
TK_ASC		EQU TK_VAL+1	* $DF
TK_UCASES		EQU TK_ASC+1	* $E0
TK_LCASES		EQU TK_UCASES+1	* $E1
TK_CHRS		EQU TK_LCASES+1	* $E2	* CHR$ token
TK_HEXS		EQU TK_CHRS+1	* $E3
TK_BINS		EQU TK_HEXS+1	* $E4	* BIN$ token
TK_BITTST		EQU TK_BINS+1	* $E5
TK_MAX		EQU TK_BITTST+1	* $E6
TK_MIN		EQU TK_MAX+1	* $E7
TK_TI			EQU TK_MIN+1	* $E8
TK_PI			EQU TK_TI+1		* $E9
TK_TWOPI		EQU TK_PI+1		* $EA
TK_VPTR		EQU TK_TWOPI+1	* $EB	* VARPTR token
TK_LEFTS		EQU TK_VPTR+1	* $EC
TK_RIGHTS		EQU TK_LEFTS+1	* $ED
TK_MIDS		EQU TK_RIGHTS+1	* $EE

************************************************************************************

* binary to unsigned decimal table

Bin2dec
	dc.l	$3B9ACA00			* 1000000000
	dc.l	$05F5E100			* 100000000
	dc.l	$00989680			* 10000000
	dc.l	$000F4240			* 1000000
	dc.l	$000186A0			* 100000
	dc.l	$00002710			* 10000
	dc.l	$000003E8			* 1000
	dc.l	$00000064			* 100
	dc.l	$0000000A			* 10
LAB_1D96
	dc.l	$00000000			* 0 end marker

LAB_RSED
	dc.l	$312E3130			* 825110832

 	dc.w	255				* 10**38
	dc.l	$96769951
 	dc.w	251				* 10**37
	dc.l	$F0BDC21B
 	dc.w	248				* 10**36
	dc.l	$C097CE7C
 	dc.w	245				* 10**35
	dc.l	$9A130B96
 	dc.w	241				* 10**34
	dc.l	$F684DF57
 	dc.w	238				* 10**33
	dc.l	$C5371912
 	dc.w	235				* 10**32
	dc.l	$9DC5ADA8
 	dc.w	231				* 10**31
	dc.l	$FC6F7C40
 	dc.w	228				* 10**30
	dc.l	$C9F2C9CD
 	dc.w	225				* 10**29
	dc.l	$A18F07D7
 	dc.w	222				* 10**28
	dc.l	$813F3979
 	dc.w	218				* 10**27
	dc.l	$CECB8F28
 	dc.w	215				* 10**26
	dc.l	$A56FA5BA
 	dc.w	212				* 10**25
	dc.l	$84595161
 	dc.w	208				* 10**24
	dc.l	$D3C21BCF
 	dc.w	205				* 10**23
	dc.l	$A968163F
 	dc.w	202				* 10**22
	dc.l	$87867832
 	dc.w	198				* 10**21
	dc.l	$D8D726B7
 	dc.w	195				* 10**20
	dc.l	$AD78EBC6
 	dc.w	192				* 10**19
	dc.l	$8AC72305
 	dc.w	188				* 10**18
	dc.l	$DE0B6B3A
 	dc.w	185				* 10**17
	dc.l	$B1A2BC2F
 	dc.w	182				* 10**16
	dc.l	$8E1BC9BF
 	dc.w	178				* 10**15
	dc.l	$E35FA932
 	dc.w	175				* 10**14
	dc.l	$B5E620F5
 	dc.w	172				* 10**13
	dc.l	$9184E72A
 	dc.w	168				* 10**12
	dc.l	$E8D4A510
 	dc.w	165				* 10**11
	dc.l	$BA43B740
 	dc.w	162				* 10**10
	dc.l	$9502F900
 	dc.w	158				* 10**9
	dc.l	$EE6B2800
 	dc.w	155				* 10**8
	dc.l	$BEBC2000
 	dc.w	152				* 10**7
	dc.l	$98968000
 	dc.w	148				* 10**6
	dc.l	$F4240000
 	dc.w	145				* 10**5
	dc.l	$C3500000
 	dc.w	142				* 10**4
	dc.l	$9C400000
 	dc.w	138				* 10**3
	dc.l	$FA000000
 	dc.w	135 				* 10**2
	dc.l	$C8000000
 	dc.w	132 				* 10**1
	dc.l	$A0000000
LAB_P_10
	dc.w	129 				* 10**0
	dc.l	$80000000
 	dc.w	125				* 10**-1
	dc.l	$CCCCCCCD
 	dc.w	122				* 10**-2
	dc.l	$A3D70A3D
 	dc.w	119				* 10**-3
	dc.l	$83126E98
 	dc.w	115				* 10**-4
	dc.l	$D1B71759
 	dc.w	112				* 10**-5
	dc.l	$A7C5AC47
 	dc.w	109				* 10**-6
	dc.l	$8637BD06
 	dc.w	105				* 10**-7
	dc.l	$D6BF94D6
 	dc.w	102				* 10**-8
	dc.l	$ABCC7712
 	dc.w	99				* 10**-9
	dc.l	$89705F41
 	dc.w	95				* 10**-10
	dc.l	$DBE6FECF
 	dc.w	92				* 10**-11
	dc.l	$AFEBFF0C
 	dc.w	89				* 10**-12
	dc.l	$8CBCCC09
 	dc.w	85				* 10**-13
	dc.l	$E12E1342
 	dc.w	82				* 10**-14
	dc.l	$B424DC35
 	dc.w	79				* 10**-15
	dc.l	$901D7CF7
 	dc.w	75				* 10**-16
	dc.l	$E69594BF
 	dc.w	72				* 10**-17
	dc.l	$B877AA32
 	dc.w	69				* 10**-18
	dc.l	$9392EE8F
 	dc.w	65				* 10**-19
	dc.l	$EC1E4A7E
 	dc.w	62				* 10**-20
	dc.l	$BCE50865
 	dc.w	59				* 10**-21
	dc.l	$971DA050
 	dc.w	55				* 10**-22
	dc.l	$F1C90081
 	dc.w	52				* 10**-23
	dc.l	$C16D9A01
 	dc.w	49				* 10**-24
	dc.l	$9ABE14CD
 	dc.w	45				* 10**-25
	dc.l	$F79687AE
 	dc.w	42				* 10**-26
	dc.l	$C6120625
 	dc.w	39				* 10**-27
	dc.l	$9E74D1B8
 	dc.w	35				* 10**-28
	dc.l	$FD87B5F3
  	dc.w	32				* 10**-29
	dc.l	$CAD2F7F5
 	dc.w	29				* 10**-30
	dc.l	$A2425FF7
 	dc.w	26				* 10**-31
	dc.l	$81CEB32C
 	dc.w	22				* 10**-32
	dc.l	$CFB11EAD
 	dc.w	19				* 10**-33
	dc.l	$A6274BBE
 	dc.w	16				* 10**-34
	dc.l	$84EC3C98
 	dc.w	12				* 10**-35
	dc.l	$D4AD2DC0
 	dc.w	9				* 10**-36
	dc.l	$AA242499
 	dc.w	6				* 10**-37
	dc.l	$881CEA14
 	dc.w	2				* 10**-38
	dc.l	$D9C7DCED

* table of constants for cordic SIN/COS/TAN calculations
* constants are un normalised fractions and are atn(2^-i)/2pi

	dc.l	$4DBA76D4			* SIN/COS multiply constant
TAB_SNCO
	dc.l	$20000000			* atn(2^0)/2pi
	dc.l	$12E4051E			* atn(2^1)/2pi
	dc.l	$09FB385C			* atn(2^2)/2pi
	dc.l	$051111D5			* atn(2^3)/2pi
	dc.l	$028B0D44			* atn(2^4)/2pi
	dc.l	$0145D7E2			* atn(2^5)/2pi
	dc.l	$00A2F61F			* atn(2^6)/2pi
	dc.l	$00517C56			* atn(2^7)/2pi
	dc.l	$0028BE54			* atn(2^8)/2pi
	dc.l	$00145F2F			* atn(2^9)/2pi
	dc.l	$000A2F99			* atn(2^10)/2pi
	dc.l	$000517CD			* atn(2^11)/2pi
	dc.l	$00028BE7			* atn(2^12)/2pi
	dc.l	$000145F4			* atn(2^13)/2pi
	dc.l	$0000A2FA			* atn(2^14)/2pi
	dc.l	$0000517D			* atn(2^15)/2pi
	dc.l	$000028BF			* atn(2^16)/2pi
	dc.l	$00001460			* atn(2^17)/2pi
	dc.l	$00000A30			* atn(2^18)/2pi
	dc.l	$00000518			* atn(2^19)/2pi
	dc.l	$0000028C			* atn(2^20)/2pi
	dc.l	$00000146			* atn(2^21)/2pi
	dc.l	$000000A3			* atn(2^22)/2pi
	dc.l	$00000052			* atn(2^23)/2pi
	dc.l	$00000029			* atn(2^24)/2pi
	dc.l	$00000015			* atn(2^25)/2pi
	dc.l	$0000000B			* atn(2^26)/2pi
	dc.l	$00000006			* atn(2^27)/2pi
	dc.l	$00000003			* atn(2^28)/2pi
	dc.l	$00000002			* atn(2^29)/2pi
	dc.l	$00000001			* atn(2^30)/2pi
	dc.l	$00000001			* atn(2^31)/2pi

* table of constants for cordic ATN calculation
* constants are normalised to two integer bits and are atn(2^-i)

*	dc.l	$3243F6A9			* atn(2^0) (not used)
TAB_ATNC
	dc.l	$1DAC6705			* atn(2^-1)
	dc.l	$0FADBAFD			* atn(2^-2)
	dc.l	$07F56EA7			* atn(2^-3)
	dc.l	$03FEAB77			* atn(2^-4)
	dc.l	$01FFD55C			* atn(2^-5)
	dc.l	$00FFFAAB			* atn(2^-6)
	dc.l	$007FFF55			* atn(2^-7)
	dc.l	$003FFFEB			* atn(2^-8)
	dc.l	$001FFFFD			* atn(2^-9)
	dc.l	$00100000			* atn(2^-10)
	dc.l	$00080000			* atn(2^-11)
	dc.l	$00040000			* atn(2^-12)
	dc.l	$00020000			* atn(2^-13)
	dc.l	$00010000			* atn(2^-14)
	dc.l	$00008000			* atn(2^-15)
	dc.l	$00004000			* atn(2^-16)
	dc.l	$00002000			* atn(2^-17)
	dc.l	$00001000			* atn(2^-18)
	dc.l	$00000800			* atn(2^-19)
	dc.l	$00000400			* atn(2^-20)
	dc.l	$00000200			* atn(2^-21)
	dc.l	$00000100			* atn(2^-22)
	dc.l	$00000080			* atn(2^-23)
	dc.l	$00000040			* atn(2^-24)
	dc.l	$00000020			* atn(2^-25)
	dc.l	$00000010			* atn(2^-26)
	dc.l	$00000008			* atn(2^-27)
	dc.l	$00000004			* atn(2^-28)
	dc.l	$00000002			* atn(2^-29)
	dc.l	$00000001			* atn(2^-30)
	dc.l	$00000000			* atn(2^-31)
	dc.l	$00000000			* atn(2^-32)

* constants are normalised to n integer bits and are tanh(2^-i)
n	equ	2
TAB_HTHET
	dc.l	$8C9F53D0>>n		* atnh(2^-1)   .549306144
	dc.l	$4162BBE8>>n		* atnh(2^-2)   .255412812
	dc.l	$202B1238>>n		* atnh(2^-3)
	dc.l	$10055888>>n		* atnh(2^-4)
	dc.l	$0800AAC0>>n		* atnh(2^-5)
	dc.l	$04001550>>n		* atnh(2^-6)
	dc.l	$020002A8>>n		* atnh(2^-7)
	dc.l	$01000050>>n		* atnh(2^-8)
	dc.l	$00800008>>n		* atnh(2^-9)
	dc.l	$00400000>>n		* atnh(2^-10)
	dc.l	$00200000>>n		* atnh(2^-11)
	dc.l	$00100000>>n		* atnh(2^-12)
	dc.l	$00080000>>n		* atnh(2^-13)
	dc.l	$00040000>>n		* atnh(2^-14)
	dc.l	$00020000>>n		* atnh(2^-15)
	dc.l	$00010000>>n		* atnh(2^-16)
	dc.l	$00008000>>n		* atnh(2^-17)
	dc.l	$00004000>>n		* atnh(2^-18)
	dc.l	$00002000>>n		* atnh(2^-19)
	dc.l	$00001000>>n		* atnh(2^-20)
	dc.l	$00000800>>n		* atnh(2^-21)
	dc.l	$00000400>>n		* atnh(2^-22)
	dc.l	$00000200>>n		* atnh(2^-23)
	dc.l	$00000100>>n		* atnh(2^-24)
	dc.l	$00000080>>n		* atnh(2^-25)
	dc.l	$00000040>>n		* atnh(2^-26)
	dc.l	$00000020>>n		* atnh(2^-27)
	dc.l	$00000010>>n		* atnh(2^-28)
	dc.l	$00000008>>n		* atnh(2^-29)
	dc.l	$00000004>>n		* atnh(2^-30)
	dc.l	$00000002>>n		* atnh(2^-31)
	dc.l	$00000001>>n		* atnh(2^-32)

KFCTSEED	equ	$9A8F4441>>n	* $26A3D110

* command vector table

LAB_CTBL
	dc.l	LAB_END			* END
	dc.l	LAB_FOR			* FOR
	dc.l	LAB_NEXT			* NEXT
	dc.l	LAB_DATA			* DATA
	dc.l	LAB_INPUT			* INPUT
	dc.l	LAB_DIM			* DIM
	dc.l	LAB_READ			* READ
	dc.l	LAB_LET			* LET
	dc.l	LAB_DEC			* DEC	
	dc.l	LAB_GOTO			* GOTO
	dc.l	LAB_RUN			* RUN
	dc.l	LAB_IF			* IF
	dc.l	LAB_RESTORE			* RESTORE
	dc.l	LAB_GOSUB			* GOSUB
	dc.l	LAB_RETURN			* RETURN
	dc.l	LAB_REM			* REM
	dc.l	LAB_STOP			* STOP
	dc.l	LAB_ON			* ON
	dc.l	LAB_NULL			* NULL
	dc.l	LAB_INC			* INC	
	dc.l	LAB_WAIT			* WAIT
	dc.l	V_LOAD			* LOAD
	dc.l	V_SAVE			* SAVE
	dc.l	LAB_DEF			* DEF
	dc.l	LAB_POKE			* POKE
	dc.l	LAB_DOKE			* DOKE
	dc.l	LAB_LOKE			* LOKE
	dc.l	LAB_CALL			* CALL
	dc.l	LAB_DO			* DO	
	dc.l	LAB_LOOP			* LOOP
	dc.l	LAB_PRINT			* PRINT
	dc.l	LAB_CONT			* CONT

	dc.l	LAB_CLS			* CLS
	dc.l	LAB_CURSOR			* CURSOR
	dc.l	LAB_LINE			* LINE
	dc.l	LAB_FILL			* FILL
	dc.l	LAB_MOVE			* MOVE
	dc.l	LAB_POINT			* POINT
	dc.l	LAB_RECT			* RECT
	dc.l	LAB_FRECT			* FRECT
	dc.l	LAB_ELLIPSE			* ELLIPSE
	dc.l	LAB_FELLIPSE		* FELLIPSE
	dc.l	LAB_MODE			* MODE
	dc.l	LAB_SIZE			* SIZE

	dc.l	LAB_LIST			* LIST
	dc.l	LAB_CLEAR			* CLEAR
	dc.l	LAB_NEW			* NEW
	dc.l	LAB_WDTH			* WIDTH
	dc.l	LAB_GET			* GET
	dc.l	LAB_SWAP			* SWAP
	dc.l	LAB_BITSET			* BITSET
	dc.l	LAB_BITCLR			* BITCLR

* action addresses for functions

LAB_FTxx
LAB_FTBL EQU LAB_FTxx-(TK_SGN-$80)*4	* offset for table start

	dc.l	LAB_SGN			* SGN()
	dc.l	LAB_INT			* INT()
	dc.l	LAB_ABS			* ABS()
	dc.l	UsrJMP			* USR()
	dc.l	LAB_FRE			* FRE()
	dc.l	LAB_POS			* POS()
	dc.l	LAB_SQR			* SQR()
	dc.l	LAB_RND			* RND()
	dc.l	LAB_LOG			* LOG()
	dc.l	LAB_EXP			* EXP()
	dc.l	LAB_COS			* COS()
	dc.l	LAB_SIN			* SIN()
	dc.l	LAB_TAN			* TAN()
	dc.l	LAB_ATN			* ATN()
	dc.l	LAB_PEEK			* PEEK()
	dc.l	LAB_DEEK			* DEEK()
	dc.l	LAB_LEEK			* LEEK()
	dc.l	LAB_SADD			* SADD()
	dc.l	LAB_LENS			* LEN()
	dc.l	LAB_STRS			* STR$()
	dc.l	LAB_VAL			* VAL()
	dc.l	LAB_ASC			* ASC()
	dc.l	LAB_UCASE			* UCASE$()
	dc.l	LAB_LCASE			* LCASE$()
	dc.l	LAB_CHRS			* CHR$()
	dc.l	LAB_HEXS			* HEX$()
	dc.l	LAB_BINS			* BIN$()
	dc.l	LAB_BTST			* BITTST()
	dc.l	LAB_MAX			* MAX()
	dc.l	LAB_MIN			* MIN()
	dc.l	LAB_TI			* PI
	dc.l	LAB_PI			* PI
	dc.l	LAB_TWOPI			* TWOPI
	dc.l	LAB_VARPTR			* VARPTR()
	dc.l	LAB_LEFT			* LEFT$()
	dc.l	LAB_RIGHT			* RIGHT$()
	dc.l	LAB_MIDS			* MID$()

* hierarchy and action addresses for operator

LAB_OPPT
	dc.w	$0079				* +
	dc.l	LAB_ADD
	dc.w	$0079				* -
	dc.l	LAB_SUBTRACT
	dc.w	$007B				* *
	dc.l	LAB_MULTIPLY
	dc.w	$007B				* /
	dc.l	LAB_DIVIDE
	dc.w	$007F				* ^
	dc.l	LAB_POWER
	dc.w	$0050				* AND
	dc.l	LAB_AND
	dc.w	$0046				* EOR
	dc.l	LAB_EOR
	dc.w	$0046				* OR
	dc.l	LAB_OR
	dc.w	$0056				* >>
	dc.l	LAB_RSHIFT
	dc.w	$0056				* <<
	dc.l	LAB_LSHIFT
	dc.w	$007D				* >
	dc.l	LAB_GTHAN			* used to evaluate -n
	dc.w	$005A				* =
	dc.l	LAB_EQUAL			* used to evaluate NOT
	dc.w	$0064				* <
	dc.l	LAB_LTHAN

						* numeric PRINT constants
LAB_2947
	dc.l	$91434FF8			* 99999.9375 (max value with at least one decimal)
LAB_294B
	dc.l	$947423F7			* 999999.4375 (max value before sci notation)
						* misc constants

LAB_259C
	dc.l	$81000000			* 1.000000, used for ATN
LAB_2A96
	dc.l	$80000000			* 0.5, used for float rounding

* This table is used in converting numbers to ASCII.
* first four entries for expansion to 9.25 digits

*	dc.l	$C4653600			* -1000000000
*	dc.l	$05F5E100			* 100000000
*	dc.l	$FF676980			* -10000000
*	dc.l	$000F4240			* 1000000
LAB_2A9A
	dc.l	$FFFE7960			* -100000
	dc.l	$00002710			* 10000
	dc.l	$FFFFFC18			* -1000
	dc.l	$00000064			* 100
	dc.l	$FFFFFFF6			* -10
	dc.l	$00000001			* 1

* new keyword tables

* offsets to keyword tables

TAB_CHRT
	dc.w	TAB_STAR-TAB_STAR		* "*"	$2A
	dc.w	TAB_PLUS-TAB_STAR		* "+"	$2B
	dc.w	-1				* "," $2C no keywords
	dc.w	TAB_MNUS-TAB_STAR		* "-"	$2D
	dc.w	-1				* "." $2E no keywords
	dc.w	TAB_SLAS-TAB_STAR		* "/"	$2F
	dc.w	-1				* "0" $30 no keywords
	dc.w	-1				* "1" $31 no keywords
	dc.w	-1				* "2" $32 no keywords
	dc.w	-1				* "3" $33 no keywords
	dc.w	-1				* "4" $34 no keywords
	dc.w	-1				* "5" $35 no keywords
	dc.w	-1				* "6" $36 no keywords
	dc.w	-1				* "7" $37 no keywords
	dc.w	-1				* "8" $38 no keywords
	dc.w	-1				* "9" $39 no keywords
	dc.w	-1				* ";" $3A no keywords
	dc.w	-1				* ":" $3B no keywords
	dc.w	TAB_LESS-TAB_STAR		* "<"	$3C
	dc.w	TAB_EQUL-TAB_STAR		* "="	$3D
	dc.w	TAB_MORE-TAB_STAR		* ">"	$3E
	dc.w	TAB_QEST-TAB_STAR		* "?"	$3F
	dc.w	-1				* "@" $40 no keywords
	dc.w	TAB_ASCA-TAB_STAR		* "A"	$41
	dc.w	TAB_ASCB-TAB_STAR		* "B"	$42
	dc.w	TAB_ASCC-TAB_STAR		* "C"	$43
	dc.w	TAB_ASCD-TAB_STAR		* "D"	$44
	dc.w	TAB_ASCE-TAB_STAR		* "E"	$45
	dc.w	TAB_ASCF-TAB_STAR		* "F"	$46
	dc.w	TAB_ASCG-TAB_STAR		* "G"	$47
	dc.w	TAB_ASCH-TAB_STAR		* "H"	$48
	dc.w	TAB_ASCI-TAB_STAR		* "I"	$49
	dc.w	-1				* "J" $4A no keywords
	dc.w	-1				* "K" $4B no keywords
	dc.w	TAB_ASCL-TAB_STAR		* "L"	$4C
	dc.w	TAB_ASCM-TAB_STAR		* "M"	$4D
	dc.w	TAB_ASCN-TAB_STAR		* "N"	$4E
	dc.w	TAB_ASCO-TAB_STAR		* "O"	$4F
	dc.w	TAB_ASCP-TAB_STAR		* "P"	$50
	dc.w	-1				* "Q" $51 no keywords
	dc.w	TAB_ASCR-TAB_STAR		* "R"	$52
	dc.w	TAB_ASCS-TAB_STAR		* "S"	$53
	dc.w	TAB_ASCT-TAB_STAR		* "T"	$54
	dc.w	TAB_ASCU-TAB_STAR		* "U"	$55
	dc.w	TAB_ASCV-TAB_STAR		* "V"	$56
	dc.w	TAB_ASCW-TAB_STAR		* "W"	$57
	dc.w	-1				* "X" $58 no keywords
	dc.w	-1				* "Y" $59 no keywords
	dc.w	-1				* "Z" $5A no keywords
	dc.w	-1				* "[" $5B no keywords
	dc.w	-1				* "\" $5C no keywords
	dc.w	-1				* "]" $5D no keywords
	dc.w	TAB_POWR-TAB_STAR		* "^"	$5E

* Table of Basic keywords.

LAB_KEYT
	dc.b	'E',1
	dc.w	KEY_END-TAB_STAR		* END
	dc.b	'F',1
	dc.w	KEY_FOR-TAB_STAR		* FOR
	dc.b	'N',2
	dc.w	KEY_NEXT-TAB_STAR		* NEXT
	dc.b	'D',2
	dc.w	KEY_DATA-TAB_STAR		* DATA
	dc.b	'I',3
	dc.w	KEY_INPUT-TAB_STAR	* INPUT
	dc.b	'D',1
	dc.w	KEY_DIM-TAB_STAR		* DIM
	dc.b	'R',2
	dc.w	KEY_READ-TAB_STAR		* READ
	dc.b	'L',1
	dc.w	KEY_LET-TAB_STAR		* LET
	dc.b	'D',1
	dc.w	KEY_DEC-TAB_STAR		* DEC
	dc.b	'G',2
	dc.w	KEY_GOTO-TAB_STAR		* GOTO
	dc.b	'R',1
	dc.w	KEY_RUN-TAB_STAR		* RUN
	dc.b	'I',0
	dc.w	KEY_IF-TAB_STAR		* IF
	dc.b	'R',5
	dc.w	KEY_RESTORE-TAB_STAR	* RESTORE
	dc.b	'G',3
	dc.w	KEY_GOSUB-TAB_STAR	* GOSUB
	dc.b	'R',4
	dc.w	KEY_RETURN-TAB_STAR	* RETURN
	dc.b	'R',1
	dc.w	KEY_REM-TAB_STAR		* REM
	dc.b	'S',2
	dc.w	KEY_STOP-TAB_STAR		* STOP
	dc.b	'O',0
	dc.w	KEY_ON-TAB_STAR		* ON
	dc.b	'N',2
	dc.w	KEY_NULL-TAB_STAR		* NULL
	dc.b	'I',1
	dc.w	KEY_INC-TAB_STAR		* INC
	dc.b	'W',2
	dc.w	KEY_WAIT-TAB_STAR		* WAIT
	dc.b	'L',2
	dc.w	KEY_LOAD-TAB_STAR		* LOAD
	dc.b	'S',2
	dc.w	KEY_SAVE-TAB_STAR		* SAVE
	dc.b	'D',1
	dc.w	KEY_DEF-TAB_STAR		* DEF
	dc.b	'P',2
	dc.w	KEY_POKE-TAB_STAR		* POKE
	dc.b	'D',2
	dc.w	KEY_DOKE-TAB_STAR		* DOKE
	dc.b	'L',2
	dc.w	KEY_LOKE-TAB_STAR		* LOKE
	dc.b	'C',2
	dc.w	KEY_CALL-TAB_STAR		* CALL
	dc.b	'D',0
	dc.w	KEY_DO-TAB_STAR		* DO
	dc.b	'L',2
	dc.w	KEY_LOOP-TAB_STAR		* LOOP
	dc.b	'P',3
	dc.w	KEY_PRINT-TAB_STAR	* PRINT
	dc.b	'C',2
	dc.w	KEY_CONT-TAB_STAR		* CONT

	dc.b	'C',1
	dc.w	KEY_CLS-TAB_STAR		* CLS
	dc.b	'C',4
	dc.w	KEY_CURSOR-TAB_STAR	* CURSOR
	dc.b	'L',2
	dc.w	KEY_LINE-TAB_STAR		* LINE
	dc.b	'F',2
	dc.w	KEY_FILL-TAB_STAR		* FILL
	dc.b	'M',2
	dc.w	KEY_MOVE-TAB_STAR		* MOVE
	dc.b	'P',3
	dc.w	KEY_POINT-TAB_STAR	* POINT
	dc.b	'R',2
	dc.w	KEY_RECT-TAB_STAR		* RECT
	dc.b	'R',3
	dc.w	KEY_FRECT-TAB_STAR	* RECTF
	dc.b	'E',5
	dc.w	KEY_ELLIPSE-TAB_STAR	* ELLIPSE
	dc.b	'E',6
	dc.w	KEY_FELLIPSE-TAB_STAR	* ELLIPSEF
	dc.b	'M',2
	dc.w	KEY_MODE-TAB_STAR		* MODE
	dc.b	'S',2
	dc.w	KEY_SIZE-TAB_STAR		* SIZE

	dc.b	'L',2
	dc.w	KEY_LIST-TAB_STAR		* LIST
	dc.b	'C',3
	dc.w	KEY_CLEAR-TAB_STAR	* CLEAR
	dc.b	'N',1
	dc.w	KEY_NEW-TAB_STAR		* NEW
	dc.b	'W',3
	dc.w	KEY_WIDTH-TAB_STAR	* WIDTH
	dc.b	'G',1
	dc.w	KEY_GET-TAB_STAR		* GET
	dc.b	'S',3
	dc.w	KEY_SWAP-TAB_STAR		* SWAP
	dc.b	'B',4
	dc.w	KEY_BITSET-TAB_STAR	* BITSET
	dc.b	'B',4
	dc.w	KEY_BITCLR-TAB_STAR	* BITCLR
	dc.b	'T',2
	dc.w	KEY_TAB-TAB_STAR		* TAB(

	dc.b	'T',0
	dc.w	KEY_TO-TAB_STAR		* TO
	dc.b	'F',0
	dc.w	KEY_FN-TAB_STAR		* FN
	dc.b	'S',2
	dc.w	KEY_SPC-TAB_STAR		* SPC(
	dc.b	'T',2
	dc.w	KEY_THEN-TAB_STAR		* THEN
	dc.b	'N',1
	dc.w	KEY_NOT-TAB_STAR		* NOT
	dc.b	'S',2
	dc.w	KEY_STEP-TAB_STAR		* STEP
	dc.b	'U',3
	dc.w	KEY_UNTIL-TAB_STAR	* UNTIL
	dc.b	'W',3
	dc.w	KEY_WHILE-TAB_STAR	* WHILE

	dc.b	'+',-1
	dc.w	KEY_PLUS-TAB_STAR		* +
	dc.b	'-',-1
	dc.w	KEY_MINUS-TAB_STAR	* -
	dc.b	'*',-1
	dc.w	KEY_MULT-TAB_STAR		* *
	dc.b	'/',-1
	dc.w	KEY_DIV-TAB_STAR		* /
	dc.b	'^',-1
	dc.w	KEY_POWER-TAB_STAR	* ^
	dc.b	'A',1
	dc.w	KEY_AND-TAB_STAR		* AND
	dc.b	'E',1
	dc.w	KEY_EOR-TAB_STAR		* EOR
	dc.b	'O',0
	dc.w	KEY_OR-TAB_STAR		* OR
	dc.b	'>',0
	dc.w	KEY_RSHIFT-TAB_STAR	* >>
	dc.b	'<',0
	dc.w	KEY_LSHIFT-TAB_STAR	* <<
	dc.b	'>',-1
	dc.w	KEY_GT-TAB_STAR		* >
	dc.b	'=',-1
	dc.w	KEY_EQUAL-TAB_STAR	* =
	dc.b	'<',-1
	dc.w	KEY_LT-TAB_STAR		* <

	dc.b	'S',1
	dc.w	KEY_SGN-TAB_STAR		* SGN
	dc.b	'I',1
	dc.w	KEY_INT-TAB_STAR		* INT
	dc.b	'A',1
	dc.w	KEY_ABS-TAB_STAR		* ABS
	dc.b	'U',1
	dc.w	KEY_USR-TAB_STAR		* USR
	dc.b	'F',1
	dc.w	KEY_FRE-TAB_STAR		* FRE
	dc.b	'P',1
	dc.w	KEY_POS-TAB_STAR		* POS
	dc.b	'S',1
	dc.w	KEY_SQR-TAB_STAR		* SQR
	dc.b	'R',1
	dc.w	KEY_RND-TAB_STAR		* RND
	dc.b	'L',1
	dc.w	KEY_LOG-TAB_STAR		* LOG
	dc.b	'E',1
	dc.w	KEY_EXP-TAB_STAR		* EXP
	dc.b	'C',1
	dc.w	KEY_COS-TAB_STAR		* COS
	dc.b	'S',1
	dc.w	KEY_SIN-TAB_STAR		* SIN
	dc.b	'T',1
	dc.w	KEY_TAN-TAB_STAR		* TAN
	dc.b	'A',1
	dc.w	KEY_ATN-TAB_STAR		* ATN
	dc.b	'P',2
	dc.w	KEY_PEEK-TAB_STAR		* PEEK
	dc.b	'D',2
	dc.w	KEY_DEEK-TAB_STAR		* DEEK
	dc.b	'L',2
	dc.w	KEY_LEEK-TAB_STAR		* LEEK
	dc.b	'S',2
	dc.w	KEY_SADD-TAB_STAR		* SADD
	dc.b	'L',1
	dc.w	KEY_LEN-TAB_STAR		* LEN
	dc.b	'S',2
	dc.w	KEY_STRS-TAB_STAR		* STR$
	dc.b	'V',1
	dc.w	KEY_VAL-TAB_STAR		* VAL
	dc.b	'A',1
	dc.w	KEY_ASC-TAB_STAR		* ASC
	dc.b	'U',4
	dc.w	KEY_UCASES-TAB_STAR	* UCASE$
	dc.b	'L',4
	dc.w	KEY_LCASES-TAB_STAR	* LCASE$
	dc.b	'C',2
	dc.w	KEY_CHRS-TAB_STAR		* CHR$
	dc.b	'H',2
	dc.w	KEY_HEXS-TAB_STAR		* HEX$
	dc.b	'B',2
	dc.w	KEY_BINS-TAB_STAR		* BIN$
	dc.b	'B',4
	dc.w	KEY_BITTST-TAB_STAR	* BITTST
	dc.b	'M',1
	dc.w	KEY_MAX-TAB_STAR		* MAX
	dc.b	'M',1
	dc.w	KEY_MIN-TAB_STAR		* MIN
	dc.b	'T',0
	dc.w	KEY_PI-TAB_STAR		* TI
	dc.b	'P',0
	dc.w	KEY_PI-TAB_STAR		* PI
	dc.b	'T',3
	dc.w	KEY_TWOPI-TAB_STAR	* TWOPI
	dc.b	'V',4
	dc.w	KEY_VPTR-TAB_STAR		* VARPTR
	dc.b	'L',3
	dc.w	KEY_LEFTS-TAB_STAR	* LEFT$
	dc.b	'R',4
	dc.w	KEY_RIGHTS-TAB_STAR	* RIGHT$
	dc.b	'M',2
	dc.w	KEY_MIDS-TAB_STAR		* MID$

* BASIC error messages

LAB_BAER
	dc.l	LAB_NF			* $00 NEXT without FOR
	dc.l	LAB_SN			* $04 syntax
	dc.l	LAB_RG			* $08 RETURN without GOSUB
	dc.l	LAB_OD			* $0C out of data
	dc.l	LAB_FC			* $10 function call
	dc.l	LAB_OV			* $14 overflow
	dc.l	LAB_OM			* $18 out of memory
	dc.l	LAB_US			* $1C undefined statement
	dc.l	LAB_BS			* $20 array bounds
	dc.l	LAB_DD			* $24 double dimension array
	dc.l	LAB_D0			* $28 divide by 0
	dc.l	LAB_ID			* $2C illegal direct
	dc.l	LAB_TM			* $30 type mismatch
	dc.l	LAB_LS			* $34 long string
	dc.l	LAB_ST			* $38 string too complex
	dc.l	LAB_CN			* $3C continue error
	dc.l	LAB_UF			* $40 undefined function
	dc.l	LAB_LD			* $44 LOOP without DO
	dc.l	LAB_UV			* $48 undefined variable
	dc.l	LAB_UA			* $4C undimensioned array
	dc.l	LAB_WD			* $50 wrong dimensions
	dc.l	LAB_AD			* $54 address
*	dc.l	LAB_IT			* $58 internal

LAB_NF	dc.b	'NEXT without FOR',$00
LAB_SN	dc.b	'Syntax',$00
LAB_RG	dc.b	'RETURN without GOSUB',$00
LAB_OD	dc.b	'Out of DATA',$00
LAB_FC	dc.b	'Function call',$00
LAB_OV	dc.b	'Overflow',$00
LAB_OM	dc.b	'Out of memory',$00
LAB_US	dc.b	'Undefined statement',$00
LAB_BS	dc.b	'Array bounds',$00
LAB_DD	dc.b	'Double dimension',$00
LAB_D0	dc.b	'Divide by zero',$00
LAB_ID	dc.b	'Illegal direct',$00
LAB_TM	dc.b	'Type mismatch',$00
LAB_LS	dc.b	'String too long',$00
LAB_ST	dc.b	'String too complex',$00
LAB_CN	dc.b	'Can''t continue',$00
LAB_UF	dc.b	'Undefined function',$00
LAB_LD	dc.b	'LOOP without DO',$00
LAB_UV	dc.b	'Undefined variable',$00
LAB_UA	dc.b	'Undimensioned array',$00
LAB_WD	dc.b	'Wrong dimensions',$00
LAB_AD	dc.b	'Address',$00
*LAB_IT	dc.b	'Internal',$00

* keyword table for line (un)crunching

* [keyword,token
* [keyword,token]]
* end marker (#$00)

TAB_STAR
KEY_MULT
	dc.b TK_MULT,$00
TAB_PLUS
KEY_PLUS
	dc.b TK_PLUS,$00			* +
TAB_MNUS
KEY_MINUS
	dc.b TK_MINUS,$00			* -
TAB_SLAS
KEY_DIV
	dc.b TK_DIV,$00			* /
TAB_LESS
KEY_LSHIFT
	dc.b	'<',TK_LSHIFT		* <<
KEY_LT
	dc.b TK_LT				* <
	dc.b	$00
TAB_EQUL
KEY_EQUAL
	dc.b TK_EQUAL,$00			* =
TAB_MORE
KEY_RSHIFT
	dc.b	'>',TK_RSHIFT		* >>
KEY_GT
	dc.b TK_GT				* >
	dc.b	$00
TAB_QEST
	dc.b TK_PRINT,$00
TAB_ASCA
KEY_ABS
	dc.b	'BS',TK_ABS			* ABS
KEY_AND
	dc.b	'ND',TK_AND			* AND
KEY_ASC
	dc.b	'SC',TK_ASC			* ASC
KEY_ATN
	dc.b	'TN',TK_ATN			* ATN
	dc.b	$00
TAB_ASCB
KEY_BINS
	dc.b	'IN$',TK_BINS		* BIN$IN$
KEY_BITCLR
	dc.b	'ITCLR',TK_BITCLR		* BITCLR
KEY_BITSET
	dc.b	'ITSET',TK_BITSET		* BITSET
KEY_BITTST
	dc.b	'ITTST',TK_BITTST		* BITTST
	dc.b	$00
TAB_ASCC
KEY_CALL
	dc.b	'ALL',TK_CALL		* CALL
KEY_CHRS
	dc.b	'HR$',TK_CHRS		* CHR$
KEY_CLEAR
	dc.b	'LEAR',TK_CLEAR		* CLEAR
KEY_CLS
	dc.b	'LS',TK_CLS			* CLS
KEY_CONT
	dc.b	'ONT',TK_CONT		* CONT
KEY_COS
	dc.b	'OS',TK_COS			* COS
KEY_CURSOR
	dc.b	'URSOR',TK_CURSOR		* CURSOR
	dc.b	$00
TAB_ASCD
KEY_DATA
	dc.b	'ATA',TK_DATA		* DATA
KEY_DEC
	dc.b	'EC',TK_DEC			* DEC
KEY_DEEK
	dc.b	'EEK',TK_DEEK		* DEEK
KEY_DEF
	dc.b	'EF',TK_DEF			* DEF
KEY_DIM
	dc.b	'IM',TK_DIM			* DIM
KEY_DOKE
	dc.b	'OKE',TK_DOKE		* DOKE
KEY_DO
	dc.b	'O',TK_DO			* DO
	dc.b	$00
TAB_ASCE
KEY_FELLIPSE
	dc.b	'LLIPSEF',TK_FELLIPSE	* ELLIPSEF
KEY_ELLIPSE
	dc.b	'LLIPSE',TK_ELLIPSE	* ELLIPSE
KEY_END
	dc.b	'ND',TK_END			* END
KEY_EOR
	dc.b	'OR',TK_EOR			* EOR
KEY_EXP
	dc.b	'XP',TK_EXP			* EXP
	dc.b	$00
TAB_ASCF
KEY_FILL
	dc.b	'ILL',TK_FILL		* FILL
KEY_FOR
	dc.b	'OR',TK_FOR			* FOR
KEY_FN
	dc.b	'N',TK_FN			* FN
KEY_FRE
	dc.b	'RE',TK_FRE			* FRE
	dc.b	$00
TAB_ASCG
KEY_GET
	dc.b	'ET',TK_GET			* GET
KEY_GOTO
	dc.b	'OTO',TK_GOTO		* GOTO
KEY_GOSUB
	dc.b	'OSUB',TK_GOSUB		* GOSUB
	dc.b	$00
TAB_ASCH
KEY_HEXS
	dc.b	'EX$',TK_HEXS,$00		* HEX$
TAB_ASCI
KEY_IF
	dc.b	'F',TK_IF			* IF
KEY_INC
	dc.b	'NC',TK_INC			* INC
KEY_INPUT
	dc.b	'NPUT',TK_INPUT		* INPUT
KEY_INT
	dc.b	'NT',TK_INT			* INT
	dc.b	$00
TAB_ASCL
KEY_LCASES
	dc.b	'CASE$',TK_LCASES		* LCASE$
KEY_LEEK
	dc.b	'EEK',TK_LEEK		* LEEK
KEY_LEFTS
	dc.b	'EFT$',TK_LEFTS		* LEFT$
KEY_LEN
	dc.b	'EN',TK_LEN			* LEN
KEY_LET
	dc.b	'ET',TK_LET			* LET
KEY_LINE
	dc.b	'INE',TK_LINE		* LINE
KEY_LIST
	dc.b	'IST',TK_LIST		* LIST
KEY_LOAD
	dc.b	'OAD',TK_LOAD		* LOAD
KEY_LOG
	dc.b	'OG',TK_LOG			* LOG
KEY_LOKE
	dc.b	'OKE',TK_LOKE		* LOKE
KEY_LOOP
	dc.b	'OOP',TK_LOOP		* LOOP
	dc.b	$00
TAB_ASCM
KEY_MAX
	dc.b	'AX',TK_MAX			* MAX
KEY_MIDS
	dc.b	'ID$',TK_MIDS		* MID$
KEY_MIN
	dc.b	'IN',TK_MIN			* MIN
KEY_MODE
	dc.b	'ODE',TK_MODE		* MODE
KEY_MOVE
	dc.b	'OVE',TK_MOVE		* MOVE
	dc.b	$00
TAB_ASCN
KEY_NEW
	dc.b	'EW',TK_NEW			* NEW
KEY_NEXT
	dc.b	'EXT',TK_NEXT		* NEXT
KEY_NOT
	dc.b	'OT',TK_NOT			* NUT
KEY_NULL
	dc.b	'ULL',TK_NULL		* NULL
	dc.b	$00
TAB_ASCO
KEY_ON
	dc.b	'N',TK_ON			* ON
KEY_OR
	dc.b	'R',TK_OR			* OR
	dc.b	$00
TAB_ASCP
KEY_PEEK
	dc.b	'EEK',TK_PEEK		* PEEK
KEY_PI
	dc.b	'I',TK_PI			* PI
KEY_POINT
	dc.b	'OINT',TK_POINT		* POINT
KEY_POKE
	dc.b	'OKE',TK_POKE		* POKE
KEY_POS
	dc.b	'OS',TK_POS			* POS
KEY_PRINT
	dc.b	'RINT',TK_PRINT		* PRINT
	dc.b	$00
TAB_ASCR
KEY_READ
	dc.b	'EAD',TK_READ		* READ
KEY_FRECT
	dc.b	'ECTF',TK_FRECT		* RECTF
KEY_RECT
	dc.b	'ECT',TK_RECT		* RECT
KEY_REM
	dc.b	'EM',TK_REM			* REM
KEY_RESTORE
	dc.b	'ESTORE',TK_RESTORE	* RESTORE
KEY_RETURN
	dc.b	'ETURN',TK_RETURN		* RETURN
KEY_RIGHTS
	dc.b	'IGHT$',TK_RIGHTS		* RIGHT$
KEY_RND
	dc.b	'ND',TK_RND			* RND
KEY_RUN
	dc.b	'UN',TK_RUN			* RUN
	dc.b	$00
TAB_ASCS
KEY_SADD
	dc.b	'ADD',TK_SADD		* SADD
KEY_SAVE
	dc.b	'AVE',TK_SAVE		* SAVE
KEY_SGN
	dc.b	'GN',TK_SGN			* SGN
KEY_SIN
	dc.b	'IN',TK_SIN			* SIN
KEY_SIZE
	dc.b	'IZE',TK_SIZE		* SIZE
KEY_SPC
	dc.b	'PC(',TK_SPC		* SPC(
KEY_SQR
	dc.b	'QR',TK_SQR			* SQR
KEY_STEP
	dc.b	'TEP',TK_STEP		* STEP
KEY_STOP
	dc.b	'TOP',TK_STOP		* STOP
KEY_STRS
	dc.b	'TR$',TK_STRS		* STR$
KEY_SWAP
	dc.b	'WAP',TK_SWAP		* SWAP
	dc.b	$00
TAB_ASCT
KEY_TAB
	dc.b	'AB(',TK_TAB		* TAB(
KEY_TAN
	dc.b	'AN',TK_TAN			* TAN
KEY_THEN
	dc.b	'HEN',TK_THEN		* THEN
KEY_TI
	dc.b	'I',TK_TI			* TI
KEY_TO
	dc.b	'O',TK_TO			* TO
KEY_TWOPI
	dc.b	'WOPI',TK_TWOPI		* TWOPI
	dc.b	$00
TAB_ASCU
KEY_UCASES
	dc.b	'CASE$',TK_UCASES		* UCASE$
KEY_UNTIL
	dc.b	'NTIL',TK_UNTIL		* UNTIL
KEY_USR
	dc.b	'SR',TK_USR			* USR
	dc.b	$00
TAB_ASCV
KEY_VAL
	dc.b	'AL',TK_VAL			* VAL
KEY_VPTR
	dc.b	'ARPTR',TK_VPTR		* VARPTR
	dc.b	$00
TAB_ASCW
KEY_WAIT
	dc.b	'AIT',TK_WAIT		* WAIT
KEY_WHILE
	dc.b	'HILE',TK_WHILE		* WHILE
KEY_WIDTH
	dc.b	'IDTH',TK_WIDTH		* WIDTH
	dc.b	$00
TAB_POWR
KEY_POWER
	dc.b	TK_POWER,$00		* ^

* just messages

LAB_BMSG
	dc.b	$0D,$0A,'Break',$00
LAB_EMSG
	dc.b	' Error',$00
LAB_LMSG
	dc.b	' in line ',$00
LAB_IMSG
	dc.b	'Extra ignored',$0D,$0A,$00
LAB_REDO
	dc.b	'Redo from start',$0D,$0A,$00
LAB_RMSG
	dc.b	$0D,$0A,'Ready',$0D,$0A,$00

LAB_MSZM
	dc.b	$0D,$0A,'Memory size ',$00

LAB_SMSG
	dc.b	' Bytes free',$0D,$0A,$0A
	dc.b	'Enhanced 68k BASIC Version 1.10',$0D,$0A
	dc.b	'for the Sim68k 68000 simulator',$0D,$0A
	dc.b	'Extension commands Version 1.01',$0D,$0A,$00

*************************************************************************************
* EhBASIC keywords quick reference list								*
*************************************************************************************

* glossary

	* <.>		  required
	* {.|.}	  one of required
	* [.]		  optional
	* ...		  may repeat as last

	* any		= anything
	* num		= number
	* state	= statement
	* pint	= positive integer
	* str		= string
	* var		= variable
	* nvar	= numeric variable
	* svar	= string variable
	* expr	= expression
	* nexpr	= numeric expression
	* sexpr	= string expression

* statement separator

* :		. [state] : [state]						* done

* number bases

* %		. %<binary num>							* done
* $		. $<hex num>							* done

* commands

* END		. END									* done
* FOR		. FOR <nvar>=<nexpr> TO <nexpr> [STEP <nexpr>]		* done
* NEXT	. NEXT [<nvar>[,<nvar>]...]					* done
* DATA	. DATA [{num|["]str["]}[,{num|["]str["]}]...]		* done
* INPUT	. INPUT [<">str<">;] <var>[,<var>[,<var>]...]		* done
* DIM		. DIM <var>(<nexpr>[,<nexpr>[,<nexpr>]])			* done
* READ	. READ <var>[,<var>[,<var>]...]				* done
* LET		. [LET] <var>=<expr>						* done
* DEC		. DEC <nvar>[,<nvar>[,<nvar>]...]				* done
* GOTO	. GOTO <pint>							* done
* RUN		. RUN [pint]							* done
* IF		. IF <nexpr> {THEN {pint|state}|GOTO <pint>}		* done
* RESTORE	. RESTORE [pint]							* done
* GOSUB	. GOSUB <pint>							* done
* REM		. REM [any]								* done
* STOP	. STOP								* done
* ON		. ON <nexpr> {GOTO|GOSUB} <pint>[,<pint>[,<pint>]...]	* done
* NULL	. NULL <nexpr>							* done
* INC		. INC <nvar>[,<nvar>[,<nvar>]...]				* done
* WAIT	. WAIT <nexpr>,<nexpr>[,<nexpr>]				* done
* LOAD	. LOAD <sexpr>							* done
* SAVE	. SAVE <sexpr>							* done
* DEF		. DEF FN<var>(<var>)=<expr>					* done
* POKE	. POKE <nexpr>,<nexpr>						* done
* DOKE	. DOKE <nexpr>,<nexpr>					 	* done
* LOKE	. LOKE <nexpr>,<nexpr>					 	* done
* CALL	. CALL <nexpr>							* done
* DO		. DO									* done
* LOOP	. LOOP [{WHILE|UNTIL}<nexpr>]					* done
* PRINT	. PRINT [{;|,}][expr][{;|,}[expr][{;|,}[expr]]...]	* done

* new graphics commands for EASy68k

* CLS		. CLS									* done
* CURSOR	. CURSOR <nexpr>,<nexpr>					* done
* LINE	. LINE <nexpr>,<nexpr>[,<nexpr>,<nexpr>][,][<nexpr>]	* done
* FILL	. FILL <nexpr>,<nexpr>[,][<nexpr>]				* done
* MOVE	. MOVE <nexpr>,<nexpr>						* done
* POINT	. POINT <nexpr>,<nexpr>[,][<nexpr>]				* done
* RECT	. RECT <nexpr>,<nexpr>[,<nexpr>,<nexpr>][,][<nexpr>[,<nexpr>]]	* done
* RECTF	. RECTF <nexpr>,<nexpr>[,<nexpr>,<nexpr>][,][<nexpr>[,<nexpr>]]	* done
* ELLIPSE	. ELLIPSE <nexpr>,<nexpr>[,<nexpr>,<nexpr>][,][<nexpr>[,<nexpr>]]	* done
* ELLIPSEF	. ELLIPSEF <nexpr>,<nexpr>[,<nexpr>,<nexpr>][,][<nexpr>[,<nexpr>]]* done
* MODE	. MODE <pint>							* done
* SIZE	. SIZE <pint>							* done

* CONT	. CONT								* done
* LIST	. LIST [pint][-pint]						* done
* CLEAR	. CLEAR								* done
* NEW		. NEW									* done
* WIDTH	. WIDTH [<pint>][,<pint>]					* done
* GET		. GET <var>								* done
* SWAP	. SWAP <var>,<var>						* done
* BITSET	. BITSET <nexpr>,<nexpr>					* done
* BITCLR	. BITCLR <nexpr>,<nexpr>					* done

* sub commands (may not start a statement)

* TAB		. TAB(<nexpr>)							* done
* TO		. FOR <nvar>=<nexpr> TO <nexpr> [STEP <nexpr>]		* done
* FN		. FN<var>(<expr>)							* done
* SPC		. SPC(<nexpr>)							* done
* THEN	. IF <nexpr> {THEN {pint|comm}|GOTO <pint>}		* done
* NOT		. NOT <nexpr>							* done
* STEP	. FOR <nvar>=<nexpr> TO <nexpr> [STEP <nexpr>]		* done
* UNTIL	. LOOP [{WHILE|UNTIL}<nexpr>]					* done
* WHILE	. LOOP [{WHILE|UNTIL}<nexpr>]					* done

* operators

* +		. [expr] + <expr>							* done
* -		. [nexpr] - <nexpr>						* done
* *		. <nexpr> * <nexpr>						* done fast hardware
* /		. <nexpr> / <nexpr>						* done fast hardware
* ^		. <nexpr> ^ <nexpr>						* done
* AND		. <nexpr> AND <nexpr>						* done
* EOR		. <nexpr> EOR <nexpr>						* done
* OR		. <nexpr> OR <nexpr>						* done
* >>		. <nexpr> >> <nexpr>						* done
* <<		. <nexpr> << <nexpr>						* done

* compare functions

* <		. <expr> < <expr>							* done
* =		. <expr> = <expr>							* done
* >		. <expr> > <expr>							* done

* new graphics function for EASy68k

* POINT	. POINT(<nexpr>,<nexpr>)					* done

* functions

* SGN		. SGN(<nexpr>)							* done
* INT		. INT(<nexpr>)							* done
* ABS		. ABS(<nexpr>)							* done
* USR		. USR(<expr>)							* done
* FRE		. FRE(<expr>)							* done
* POS		. POS(<expr>)							* done
* SQR		. SQR(<nexpr>)							* done fast shift/sub
* RND		. RND(<nexpr>)							* done 31 bit PRNG
* LOG		. LOG(<nexpr>)							* done fast cordic
* EXP		. EXP(<nexpr>)							* done fast cordic
* COS		. COS(<nexpr>)							* done fast cordic
* SIN		. SIN(<nexpr>)							* done fast cordic
* TAN		. TAN(<nexpr>)							* done fast cordic
* ATN		. ATN(<nexpr>)							* done fast cordic
* PEEK	. PEEK(<nexpr>)							* done
* DEEK	. DEEK(<nexpr>)							* done
* LEEK	. LEEK(<nexpr>)							* done
* SADD	. SADD(<sexpr>)							* done
* LEN		. LEN(<sexpr>)							* done
* STR$	. STR$(<nexpr>)							* done
* VAL		. VAL(<sexpr>)							* done
* ASC		. ASC(<sexpr>)							* done
* UCASE$	. UCASE$(<sexpr>)							* done
* LCASE$	. LCASE$(<sexpr>)							* done
* CHR$	. CHR$(<nexpr>)							* done
* HEX$	. HEX$(<nexpr>)							* done
* BIN$	. BIN$(<nexpr>)							* done
* BTST	. BTST(<nexpr>,<nexpr>)						* done
* MAX		. MAX(<nexpr>[,<nexpr>[,<nexpr>]...])			* done
* MIN		. MIN(<nexpr>[,<nexpr>[,<nexpr>]...])			* done
* TI		. TI									* done
* PI		. PI									* done
* TWOPI	. TWOPI								* done
* VARPTR	. VARPTR(<var>)							* done
* LEFT$	. LEFT$(<sexpr>,<nexpr>)					* done
* RIGHT$	. RIGHT$(<sexpr>,<nexpr>)					* done
* MID$	. MID$(<sexpr>,<nexpr>[,<nexpr>])				* done

* This lot is in RAM

*	ORG	$40000
	ORG	$10000
ram_strt
						* I'll allow 1K for the stack

	ORG	$10400
ram_base
LAB_WARM	ds.w	1			* BASIC warm start entry point
Wrmjpv	ds.l	1			* BASIC warm start jump vector

Usrjmp	ds.w	1			* USR function JMP address
Usrjpv	ds.l	1			* USR function JMP vector

* system dependant i/o vectors
* these are in RAM and are set at start-up

V_INPT	ds.w	1			* non halting scan input device entry point
V_INPTv	ds.l	1			* non halting scan input device jump vector

V_OUTP	ds.w	1			* send byte to output device entry point
V_OUTPv	ds.l	1			* send byte to output device jump vector

V_LOAD	ds.w	1			* load BASIC program entry point
V_LOADv	ds.l	1			* load BASIC program jump vector

V_SAVE	ds.w	1			* save BASIC program entry point
V_SAVEv	ds.l	1			* save BASIC program jump vector

V_CTLC	ds.w	1			* save CTRL-C check entry point
V_CTLCv	ds.l	1			* save CTRL-C check jump vector

entry_sp	ds.l	1			* stack value on entry to basic

Itemp		ds.l	1			* temporary integer (for GOTO etc)

Smeml		ds.l	1			* start of memory	(start of program)
Sfncl		ds.l	1			* start of functions	(end of Program)
Svarl		ds.l	1			* start of variables	(end of functions)
Sstrl		ds.l	1			* start of strings	(end of variables)
Sarryl	ds.l	1			* start of arrays		(end of strings)
Earryl	ds.l	1			* end of arrays		(start of free mem)
Sstorl	ds.l	1			* string storage		(moving down)
Ememl		ds.l	1			* end of memory		(upper bound of RAM)
Sutill	ds.l	1			* string utility ptr
Clinel	ds.l	1			* current line		(Basic line number)
Blinel	ds.l	1			* break line		(Basic line number)

Cpntrl	ds.l	1			* continue pointer
Dlinel	ds.l	1			* current DATA line
Dptrl		ds.l	1			* DATA pointer
Rdptrl	ds.l	1			* read pointer
Varname	ds.l	1			* current var name
Cvaral	ds.l	1			* current var address
Frnxtl	ds.l	1			* var pointer for FOR/NEXT
Lvarpl	EQU	Frnxtl		* let var pointer low byte

des_sk_e	ds.l	6			* descriptor stack end
des_sk
						* descriptor stack start address
						* use a4 for the descriptor pointer

* Ibuffs can now be anywhere in RAM just make sure the byte before it is <> $00

		ds.w	1			
Ibuffs	ds.l	$40			* start of input buffer
Ibuffe
						* end of input buffer

FAC1_m	ds.l	1			* FAC1 mantissa1
FAC1_e	ds.w	1			* FAC1 exponent
FAC1_s	EQU	FAC1_e+1		* FAC1 sign (b7)
		ds.w	1			

FAC2_m	ds.l	1			* FAC2 mantissa1
FAC2_e	ds.l	1			* FAC2 exponent
FAC2_s	EQU	FAC2_e+1		* FAC2 sign (b7)
FAC_sc	EQU	FAC2_e+2		* FAC sign comparison, Acc#1 vs #2
flag		EQU	FAC2_e+3		* flag byte for divide routine

PRNlword	ds.l	1			* PRNG seed long word

ut1_pl	ds.l	1			* utility pointer 1

Asptl		ds.l	1			* array size/pointer
Adatal	ds.l	1			* array data pointer

Astrtl	ds.l	1			* array start pointer low byte

numexp	EQU	Astrtl		* string to float number exponent count
expcnt	EQU	Astrtl+1		* string to float exponent count

expneg	EQU	Astrtl+3		* string to float eval exponent -ve flag

func_l	ds.l	1			* function pointer


						* these two need to be a word aligned pair !
Defdim	ds.w	1			* default DIM flag
cosout	EQU	Defdim		* flag which CORDIC output (re-use byte)
Dtypef	EQU	Defdim+1		* data type flag, $80=string, $40=integer, $00=float


Binss		ds.l	4			* number to bin string start (32 chrs)

Decss		ds.l	1			* number to decimal string start (16 chrs)
		ds.w	1			*
Usdss		ds.w	1			* unsigned decimal string start (10 chrs)

Hexss		ds.l	2			* number to hex string start (8 chrs)

BHsend	ds.w	1			* bin/decimal/hex string end


prstk		ds.b	1			* stacked function index

Srchc		ds.b	1			* search character
tpower	EQU	Srchc			* remember CORDIC power (re-use byte)

Asrch		ds.b	1			* scan-between-quotes flag, alt search character

Dimcnt	ds.b	1			* # of dimensions

Breakf	ds.b	1			* break flag, $00=END else=break
Oquote	ds.b	1			* open quote flag (Flag: DATA; LIST; memory)
Gclctd	ds.b	1			* garbage collected flag
Sufnxf	ds.b	1			* subscript/FNX flag, 1xxx xxx = FN(0xxx xxx)
Imode		ds.b	1			* input mode flag, $00=INPUT, $98=READ

Cflag		ds.b	1			* comparison evaluation flag

TabSiz	ds.b	1			* TAB step size

TempB		ds.b	1			* temp byte

comp_f	ds.b	1			* compare function flag, bits 0,1 and 2 used
						* bit 2 set if >
						* bit 1 set if =
						* bit 0 set if <

Nullct	ds.b	1			* nulls output after each line
TPos		ds.b	1			* BASIC terminal position byte
TWidth	ds.b	1			* BASIC terminal width byte
Iclim		ds.b	1			* input column limit
ccflag	ds.b	1			* CTRL-C check flag
ccbyte	ds.b	1			* CTRL-C last received byte
ccnull	ds.b	1			* CTRL-C last received byte 'life' timer

* these variables for simulator load/save routines

file_byte	ds.b	1			* load/save data byte
file_id	ds.l	1			* load/save file ID

		dc.w	0			* dummy even value and zero pad byte

prg_strt
ram_top	EQU	$18000		* last RAM byte + 1

	END	code_start

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
