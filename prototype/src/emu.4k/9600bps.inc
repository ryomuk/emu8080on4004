;;;---------------------------------------------------------------------------
;;; getchar and putchar functions
;;; baud rate = 9600bps
;;; 8bit, no parity, stop 1
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; GETCHAR_P1
;;; receive a character from serial port (TEST) and put into P1(R2, R3)
;;;
;;; Input: none
;;; Output: P1(R2,R3), ACC=0(OK), ACC=1(error)
;;; Working: P6, P7
;;; This subroutine destroys P6, P7.
;;; 
;;; baud rate: 9600bps (104.17us/bit, 9.645cycle/bit)
;;; 
;;;          |--12--|-9--|-9-|-9--|-12--|-9--|-9-|-9--|-10--|
;;; ~~~~~~~~|____|~~~~|____|~~~~|____|~~~~|____|~~~~|____|~~~~~ 9.645cycle/bit
;;;          ^      ^    ^   ^    ^     ^    ^   ^    ^     ^
;;;        start    0    1   2    3     4    5   6    7    stop
;;;               |->phase delay
;;; - In order to check data bits in the middle of the signal,
;;;   a "phase delay" should be added between the start bit and data bits.
;;;   (1 to 4 cycles may be moderate for 9.645cycle/bit)
;;; - Detection of the start bit may cause delay of 2 cycles due to polling.
;;;---------------------------------------------------------------------------

GETCHAR_P1:
        FIM R12R13, loop(4)     ; loop for first(lower) 4 bit
                                ; 
        JCN TN, $               ;(2) wait for start bit (TEST="0")
	FIM P7, loop(4)         ;(2)
	ISZ R15,$               ;(8) 12 cycles between startbit and bit0
                                ;    phase(bit0)= 12 -9.645 = 2.355cycle
GETCHAR_L1:
	JCN TN, GETCHAR_L2      ;(2) check a bit
        CLC                     ;<1> TEST="0" then CY=0
        JUN GETCHAR_L3          ;<2>
GETCHAR_L2:
	STC                     ;[1] TEST="1" then CY=1
        NOP                     ;[1]
        NOP                     ;[1]
GETCHAR_L3:
	RAR                     ;(1) load CY->ACC
	NOP                     ;(1) 9cycle/bit (error=-0.645 cycle/bit)
        ISZ R13, GETCHAR_L1     ;(2) repeat until 4 bit received
                                ;    phase(here)= 2.355 -0.645*3 = 0.42cycle
	XCH R3                  ;(1)
	FIM R12R13, loop(4)     ;(2) loop for second(upper) 4 bit
		                ;    12 cycles between bit3 and bit4
                                ;    phase(bit4)= 2.42 +12 -9.645 = 2.775cycle
GETCHAR_L4:
	JCN TN, GETCHAR_L5      ;(2) check a bit
        CLC                     ;<1> TEST="0" then CY=0
        JUN GETCHAR_L6          ;<2>
GETCHAR_L5:
	STC                     ;[1] TEST="1" then CY=1
        NOP                     ;[1]
        NOP                     ;[1]
GETCHAR_L6:
	RAR                     ;(1) load CY->ACC
	NOP                     ;(1) 9cycle/bit (error=-0.645 cycle/bit)
        ISZ R13, GETCHAR_L4     ;(2) repeat until 4 bit received
                                ;    phase(here)= 4.755 -0.645*3 = 0.84 cycle
	XCH R2                  ;(1)
                                ;    10 cycles/between bit7 and stopbit
                                ;    phase(stop)= 2.84 +10 -9.645 = 1.195cycle
	;; check stop bit
        JCN TN, GETCHAR_OK      ; stop bit == "1"
        BBL 1                   ; stop bit != "1"
GETCHAR_OK:
	BBL 0
                
;;;---------------------------------------------------------------------------
;;; PUTCHAR_P1
;;; send the character in P1(R2, R3) to OUTPORT
;;; 
;;; Input: P1(R2,R3)
;;; Output: ACC=0
;;; Working: P6(R12R13), P7
;;; This subroutine destroys P6, P7.
;;; P1 is not affected
;;; 
;;; baud rate: 9600bps (104.17us/bit, 9.645cycle/bit)
;;; 
;;; Input: P1(R2,R3)
;;; Output: ACC=0
;;; Working: P6(R12R13), P7
;;; This subroutine destroys P6, P7.
;;;---------------------------------------------------------------------------
;;; 
;;;         |--9-|-9--|-9-|-9--|-10--|-10-|-10-|-10-|-10--|(ave.9.56cycle/bit)
;;; ~~~~~~~~|____|~~~~|____|~~~~|____|~~~~|____|~~~~|____|~~~~~ 9.645cycle/bit
;;;         ^    ^    ^   ^    ^     ^    ^    ^    ^     ^
;;;       start  0    1   2    3     4    5    6    7     stop
;;;---------------------------------------------------------------------------

PUTCHAR_P1:
	if (BANK_SERIAL != BANK_DEFAULT)
	LDM BANK_SERIAL     ; set bank to serial output port RAM
        DCL                 ; this may be omitted if BANK_SERIAL==BANK_DEFAULT
	endif
	
        FIM P7, CHIP_SERIAL ; chip# of output port
	SRC P7              ; set port address

        FIM R12R13, loop(5) ; start bit and lower 4bit(R3)
        LD R3
        CLC                 ; start bit is 0
        RAL
                
PUTCHAR_L1:
	NOP                 ;(1) 9cycle/bit
        NOP                 ;(1)
        NOP                 ;(1)
        NOP                 ;(1)
        NOP                 ;(1)
        WMP                 ;(1)
        RAR                 ;(1)
        ISZ R13, PUTCHAR_L1 ;(2)
	
        FIM R12R13, loop(5) ;(2) upper 4bit(R2) and stop bit
        LD R2               ;(1)
        STC                 ;(1) stop bit is 1
	NOP                 ;(1) timing adjustment
        NOP                 ;(1) 10cycle between bit3 and bit4
PUTCHAR_L2:
	WMP                 ;(1) 10cycle/bit
        FIM R14R15, loop(2) ;(2)
        ISZ R15, $          ;(4)
        RAR                 ;(1)
        ISZ R13, PUTCHAR_L2 ;(2)
	
	if (BANK_SERIAL != BANK_DEFAULT)
	LDM BANK_DEFAULT    ; restore bank to default
        DCL                 ; this may be omitted if BANK_SERIAL==BANK_DEFAULT
	endif
	
        BBL 0

