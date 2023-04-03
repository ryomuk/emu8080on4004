;;;---------------------------------------------------------------------------
;;; Tiny Monitor with 8080 emulator on 4004 (emu8080)
;;; for Intel 4004 evaluation board
;;;
;;; by Ryo Mukai
;;; 2023/03/21
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; This source can be assembled with the Macroassembler AS
;;; (http://john.ccac.rwth-aachen.de:8000/as/)
;;;---------------------------------------------------------------------------

	cpu 4004	; AS's command to specify CPU

	include "macros.inc"	; aliases and macros

;;;---------------------------------------------------------------------------
;;; Software Configuration
;;;---------------------------------------------------------------------------


;;;---------------------------------------------------------------------------
;;; Emulator compile configuration
;;;---------------------------------------------------------------------------
;; FLAG_P is not implemented because it takes much cost
EMU_USE_FLAG_P = 0	; don't use P FLAG
;;; EMU_USE_FLAG_P = 1	; use P FLAG

;;;---------------------------------------------------------------------------
;;; Emulator port configuration
;;;---------------------------------------------------------------------------
EMU_UARTRC	equ	00H	; for tinybasic-1.0
EMU_UARTRD	equ	01H	; for tynybasic-1.0
;;;	EMU_IN_UARTRC_VALUE	equ 22H	; for tynybasic-1.0
EMU_IN_UARTRC_VALUE	equ 0FFH	;

;;;---------------------------------------------------------------------------
;;; Hardware Configuration
;;;---------------------------------------------------------------------------

;;; RAM0 and RAM1 must be 4002-1 and located in the BANK#0 (CM-RAM0).
;;; For RAM2 and RAM3, 4002-2 is preferred, because it can be located
;;; in the BANK#0 same as RAM0 and RAM1.
;;; However -2 is more expensive and difficult to get than -1,
;;; so the chip type of RAM2 and RAM3 is configurable.
;;; If you use -1 for RAM2 and RAM3, they are located in
;;; the BANK#1 (CM-RAM1), and DCL must be executed before SRC.

;;; Chip type of RAM2 and RAM3
RAM23TYPE	equ "4002-2"	; or "4002-1"

;;; BANK# for DCL, and CHIP#=(D7.D6.000000) for SRC
BANK_RAM0	equ 0
CHIP_RAM0	equ 00H
BANK_RAM1	equ 0
CHIP_RAM1	equ 40H
	if (RAM23TYPE == "4002-2")
BANK_RAM2	equ 0
CHIP_RAM2	equ 80H
BANK_RAM3	equ 0
CHIP_RAM3	equ 0C0H
	elseif (RAM23TYPE == "4002-1")
BANK_RAM2	equ 1
CHIP_RAM2	equ 00H
BANK_RAM3	equ 1
CHIP_RAM3	equ 40H
	endif

;;; Default Bank
;;; The CM-RAM line should be always set to BANK_DEFAULT
;;; to omit DCL as much as possible.
;;; (This is for when RAM23TYPE=="4002-1".)
BANK_DEFAULT	equ BANK_RAM0
		
;;; Output port for serial interface
BANK_SERIAL	equ BANK_RAM3
CHIP_SERIAL	equ CHIP_RAM3

;;; Output port for program memory bank selection
BANK_PMSELECT0	equ BANK_RAM0
BANK_PMSELECT1	equ BANK_RAM1
CHIP_PMSELECT0	equ CHIP_RAM0
CHIP_PMSELECT1	equ CHIP_RAM1

	
;;; Program Memory RAM area
PM_RAM_START	equ 0F00H	; Start address of program memory RAM
PM_READ_P0_P1	equ 0FFEH	; Entry of the subroutine to read RAM
				; "FIN P1 and BBL 0"
	
;;; Address labels in the 16 bit address space logical program memory PM16
PM16_MEMSTART	equ 0000H
PM16_LINEBUF	equ 0D00H

;;; for 256 x 16 x16 PM space
;;; PM_READ_P0_P1   equ 0F7EH	; Entry of the subroutine to read RAM
;;; PM16_LINEBUF	equ 7D00H

;;;---------------------------------------------------------------------------
;;; Data RAM Register Configuration
;;;---------------------------------------------------------------------------
;;; RAM0
;;; 
;;; 8080 register code DDD or SSS
;;; 0 1 2 3 4 5 6 7
;;; B C D E H L M A
;;; 
;;;  ADDRESS=~(xxx)<<1
	
REG8_A		equ 00H	;
REG8_M		equ 02H	; REG8_M is only used as a label.
REG8_L		equ 04H	;
REG8_H		equ 06H	;
REG8_E		equ 08H	;
REG8_D		equ 0AH	;
REG8_C		equ 0CH	;
REG8_B		equ 0EH	;

REG8_FLAG	equ 10H ;
REG8_SRC	equ 12H	; temporary register to save SRC reg value
REG16_PC	equ 14H	; Program Counter of 8080
REG16_SP	equ 18H	; Stack Pointer of 8080
REG16_ADDR	equ 1CH ; 16 bit temporary register

		;; lower byte is the first
REG16_BC	equ REG8_C
REG16_DE	equ REG8_E
REG16_HL	equ REG8_L

REG8_PCL	equ REG16_PC
REG8_PCH	equ REG16_PC+2
REG8_SPL	equ REG16_SP
REG8_SPH	equ REG16_SP+2
REG8_ADDRL	equ REG16_ADDR
REG8_ADDRH	equ REG16_ADDR+2
	
REG4_FLAG_1P1C	equ REG8_FLAG
REG4_FLAG_SZBH	equ REG8_FLAG+1

REG4_EMU_STEP	equ 20H	; Execution mode (0:continuous, 1:step)
	
REG16_MON_INDEX	equ 28H	;
REG16_MON_ADDR	equ 2CH	;
REG16_MON_TMP	equ 30H	;
REG16_MON_PMBANK	equ 34H	;
REG8_MON_MEMSPACE	equ 38H	; 'D', 'P', 'L' = (Data, Physical, Logical)
REG8_MON_RESERVED	equ 3AH	; (reserved)
	

;;; RAM1
REG16_STACK_40H	equ 40H		;; stack area
REG16_STACK_7CH	equ 7CH	

STACK_INIT	equ 80H

;;; RAM2
;;; RAM3
	
;;;---------------------------------------------------------------------------
;;; Program Start
;;;---------------------------------------------------------------------------
	org 0000H		; beginning of Program Memory

;;;---------------------------------------------------------------------------
;;; Mail Loop for Monitor Program
;;;---------------------------------------------------------------------------
MAIN:
	NOP
	CLB

	if ( BANK_DEFAULT != 0 )
	LDM BANK_DEFAULT
	endif
	;; DL is assumed to be set back to BANK_DEFAULT (normally 0)
	;; except when in use for another banks.
	DCL

	FIM SP, STACK_INIT	; initialize stack pointer
	JMS INIT_SERIAL		; Initialize Serial Port


	;; write "PM_READ_P0_P1" routine on all memory banks
	LDM loop(16)
	XCH P1_HI
PM_INIT_HLOOP:
	LDM loop(16)
	XCH P1_LO
PM_INIT_LLOOP:
	JMS PM_SELECTPMB_P1
	JMS PM_INIT_BANK ; write PM_READ code on program memory
	ISZ P1_LO, PM_INIT_LLOOP
	ISZ P1_HI, PM_INIT_HLOOP

	FIM P1, 00H
	JMS PM_SELECTPMB_P1	 ; set PMB to 0
	
;	JCN TN, $		;wait for TEST="0" (button pressed)
	FIM P0, lo(STR_VFD_INIT) ; init VFD
	JMS PRINTSTR_P0
	FIM P0, lo(STR_OMSG) ; opening message in the Page 7
	JMS PRINTSTR_P0

	FIM P0, REG8_MON_MEMSPACE
	FIM P1, 'D'
	JMS LD_REG8P0_P1	; set memspace 'D'
	
	;; init emulator PC
	FIM P0, REG16_PC
	FIM P2, 00H
	FIM P3, 00H
	JMS LD_REG16P0_P2P3	; PC=0000H

CMD_LOOP:
	FIM P1, ']'		; prompt
	JMS PUTCHAR_P1

	FIM P0, REG16_MON_INDEX
	FIM P2, up(PM16_LINEBUF)
	FIM P3, lo(PM16_LINEBUF)
	JMS LD_REG16P0_P2P3
	JMS GETLINE_PM16REG16P0

	JMS LD_P1_PM16REG16P0_INCREMENT	; P1=PM16(REG(P0)++)
	JMS TOUPPER_P1
L0:
	FIM P7, 'H'		; Select Memory Space (D/P/L)
	JMS CMP_P1P7
	JCN ZN, L1
	JUN COMMAND_H
L1:
	FIM P7, 'D'		; Dump Memory
	JMS CMP_P1P7
	JCN ZN, L2
	JUN COMMAND_D
L2:
;;;	FIM P7, 'S'		; Set to Memory
;;;	JMS CMP_P1P7
;;;	JCN ZN, L3
;;;	JUN COMMAND_S
L3:
	FIM P7, 'L'		; Load to Logical Memory
	JMS CMP_P1P7
	JCN ZN, L4
	JUN COMMAND_L
L4:
	FIM P7, 'C'		; Clear program memory
	JMS CMP_P1P7
	JCN ZN, L5
	JUN COMMAND_C
L5:
	FIM P7, 'G'		; Go to PM_RAM_START (0F00H)
	JMS CMP_P1P7
	JCN ZN, L6
	JUN COMMAND_G
L6:
	FIM P7, 'E'		; jump to 8080 Emulator
	JMS CMP_P1P7 		;
	JCN ZN, L10		;

	JMS LD_P1_PM16REG16P0_INCREMENT ; check next letter
	JMS TOUPPER_P1
	FIM P7, 'S'		; 'E' continuous mode, 'ES' step mode
	JMS CMP_P1P7 		; 
	JCN ZN, L6_CONTINUOUS	;
	LDM 1H			; step mode
	JUN L6_SETMODE
L6_CONTINUOUS			; continuous mode
	JMS DEC_REG16P0
	LDM 0H
L6_SETMODE:
	FIM P7, REG4_EMU_STEP
	LD_REG4P7_ACC
	FIM P1, REG16_PC	; set start PC if designated
	JMS GETHEX_REG16P1_PM16REG16P0_INCREMENT
	JUN COMMAND_E


L10:
	FIM P0, lo(STR_CMDERR)
	JMS PRINTSTR_P0

	JUN CMD_LOOP


;;;---------------------------------------------------------------------------
;;; COMMAND_DP
;;; Dump Physical Memory
;;;	BANK=ADDR.FEDCBA98
;;;  PM_ADDR=ADDR.76543210 + 0F00H
;;;---------------------------------------------------------------------------
COMMAND_DP:
	FIM P1, REG16_MON_ADDR
	JMS LD_P2P3_REG16P1

	LD_P1_P2
	JMS PM_SELECTPMB_P1
	
	LDM loop(8)
	XCH CNT_I
CMDDP_L0:
	LD_P1_P2
	JMS PRINTHEX_P1
	FIM P1, ':'
	JMS PUTCHAR_P1
	FIM P1, 'F'
	JMS PUTCHAR_P1
	LD_P1_P3
	JMS PRINTHEX_P1
	FIM P1, ':'
	JMS PUTCHAR_P1

CMDDP_L1:	
	LD_P0_P3
	JMS PM_READ_P0_P1	; Read program memory
	JMS PRINTHEX_P1

	ISZ P3_LO, CMDDP_L1
	JMS PRINT_CRLF
	INC P3_HI
	LD P3_HI
	JCN Z, CMDDP_EXIT
	ISZ CNT_I, CMDDP_L0
CMDDP_EXIT:	
	FIM P0, REG16_MON_ADDR
	JMS LD_REG16P0_P2P3

	JUN CMD_LOOP		; return to command loop

;;;---------------------------------------------------------------------------
;;; COMMAND_DL
;;; Dump Logical Memory
;;;---------------------------------------------------------------------------
COMMAND_DL:
	FIM P0, REG16_MON_ADDR
	JMS LD_P1_REG8P0
	LD_CNT_P1
	LDM loop(8)
	XCH CNT_I
CMDDL_L0:
	FIM P1, REG16_MON_ADDR
	JMS PRINTHEX_REG16P1
	FIM P1, ':'
	JMS PUTCHAR_P1
CMDDL_L1:	
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS PRINTHEX_P1

	ISZ CNT_J, CMDDL_L1
	JMS PRINT_CRLF
	ISZ CNT_I, CMDDL_L0
CMDDL_NEXT:
	JUN CMD_LOOP		; return to command loop

	
;;;---------------------------------------------------------------------------
;;; COMMAND_D
;;; Dump Memory
;;;---------------------------------------------------------------------------
COMMAND_D:
	FIM P1, REG16_MON_ADDR
	JMS GETHEX_REG16P1_PM16REG16P0_INCREMENT
	
	FIM P7, REG8_MON_MEMSPACE
	JMS LD_P1_REG8P7
	
	FIM P7, 'D'
	JMS CMP_P1P7
	JCN ZN, CMDD_L1
	JUN COMMAND_DD
CMDD_L1:
	FIM P7, 'P'
	JMS CMP_P1P7
	JCN ZN, CMDD_L2
	JUN COMMAND_DP
CMDD_L2:
	FIM P7, 'L'
	JMS CMP_P1P7
	JCN ZN, CMDD_L3
	JUN COMMAND_DL
CMDD_L3:
	FIM P0, lo(STR_ERROR_UNKNOWN_MEMSPACE)
	JMS PRINTSTR_P0
	JUN CMD_LOOP

;;;---------------------------------------------------------------------------
;;; COMMAND_DD
;;; Dump Data RAM
;;; input:
;;; REG16_MON_ADDR
;;; RAM0=00H-3FH
;;; RAM1=40H-7FH
;;; RAM2=80H-BFH
;;; RAM3=C0H-FFH
;;; CHIP#=ADDR.bit(76), REG#=ADDR.bit(54), CHAR#=ADDR.bit(3210)
;;;---------------------------------------------------------------------------
COMMAND_DD:
	FIM P7, REG16_MON_ADDR
	JMS LD_P1_REG8P7	; P1=lower 8bit of ADDR
	LD_P0_P1		; P0=ADDR for SCR

	;; PRINT 4 registers
	LDM loop(4)		; PRINT 4 regs
	XCH CNT_I		; I=loop(4)
	;; PRINT 16 characters
CMDDD_L1:
	JMS PRINT_DATARAM_P0
	INC P0_HI
	ISZ CNT_I, CMDDD_L1

	LD_P1_P0
	FIM P0, REG16_MON_ADDR
	JMS LD_REG8P0_P1

	JUN CMD_LOOP		; return to command loop
	
;;;---------------------------------------------------------------------------
;;; COMMAND_G
;;; Go to Top of Program memory PM_RAM_START(0x0F00)
;;;---------------------------------------------------------------------------
COMMAND_G:
	JUN PM_RAM_START

;;;---------------------------------------------------------------------------
;;; COMMAND_H
;;; Select Memory Space and address
;;; 'D' = Data Memory
;;; 'P' = Physical Program Memory
;;; 'L' = Logical Program Memory
;;;---------------------------------------------------------------------------
COMMAND_H:
	JMS LD_P1_PM16REG16P0_INCREMENT	; P1=PM16(REG(P0)++)
	JMS ISZEROORNOT_P1
	JCN ZN, CMDH_SET
	JUN CMDH_EXIT
CMDH_SET:
	JMS TOUPPER_P1
	FIM P2, REG8_MON_MEMSPACE
	JMS LD_REG8P2_P1
	FIM P1, REG16_MON_ADDR
	JMS GETHEX_REG16P1_PM16REG16P0_INCREMENT
CMDH_EXIT:
	FIM P7, REG8_MON_MEMSPACE
	JMS LD_P1_REG8P7
	JMS PUTCHAR_P1
	FIM P1, REG16_MON_ADDR
	JMS PRINTHEX_REG16P1
	JMS PRINT_CRLF
	JUN CMD_LOOP

;;;---------------------------------------------------------------------------
;;; COMMAND_L
;;; Load to Logical Memory
;;; Intel Hex format, no checksum check
;;; data lengh must be 0to10H/line
;;;---------------------------------------------------------------------------
COMMAND_L:
CMDL_START:
	FIM P0, REG16_MON_INDEX
	FIM P2, up(PM16_LINEBUF)
	FIM P3, lo(PM16_LINEBUF)
	JMS LD_REG16P0_P2P3
	JMS GETLINE_PM16REG16P0

	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS ISZEROORNOT_P1
	JCN ZN, CMDL_L0
	JUN CMDL_EXIT
CMDL_L0:
	FIM P7, ':'
	JMS CMP_P1P7
	JCN Z, CMDL_L1
	JUN CMDL_ERROR
CMDL_L1:
	JMS GETHEXBYTE_P1_PM16REG16P0_INCREMENT
	LD_CNT_P1				; count

	JMS GETHEXBYTE_P1_PM16REG16P0_INCREMENT ; address (upper byte)
	LD_P2_P1
	JMS GETHEXBYTE_P1_PM16REG16P0_INCREMENT ; address (lower byte)
	LD_P3_P1
	FIM P1, REG16_MON_ADDR
	JMS LD_REG16P1_P2P3
	JMS GETHEXBYTE_P1_PM16REG16P0_INCREMENT ; recode type
	JMS ISZEROORNOT_P1
	JCN ZN, CMDL_L2
	JUN CMDL_READLOOP
CMDL_L2:
	FIM P7, 01H
	JMS CMP_P1P7
	JCN ZN, CMDL_ERROR
	JUN CMDL_EXIT
CMDL_ERROR:
	JMS DEC_REG16P0
	JMS PRINTSTR_PM16REG16P0
	FIM P0, lo(STR_ERROR_LOADCOMMAND)
	JMS PRINTSTR_P0
	JUN CMD_LOOP
CMDL_READLOOP:
	LD CNT_LO
	JCN ZN, CMDL_CONTINUE
	LD CNT_HI
	JCN ZN, CMDL_CONTINUE
	JUN  CMDL_START		; continue to read next line
CMDL_CONTINUE:
	FIM P0, REG16_MON_INDEX
	JMS GETHEXBYTE_P1_PM16REG16P0_INCREMENT
	JCN Z, CMDL_L3
	JUN CMDL_START		; continue to read next line
CMDL_L3:
	FIM P0, REG16_MON_ADDR
	JMS LD_PM16REG16P0_P1
	JMS INC_REG16P0
	LD CNT_LO
	DAC
	XCH CNT_LO
	JCN C, CMDL_L5		; no borrow then skip
	LD CNT_HI
	DAC
	XCH CNT_HI
CMDL_L5:
	JUN CMDL_READLOOP
CMDL_EXIT:
	;; set memory space to logical
	FIM P0, REG8_MON_MEMSPACE
	FIM P1, 'L'
	JMS LD_REG8P0_P1
	JUN CMD_LOOP
	
;;;---------------------------------------------------------------------------
;;; COMMAND_C
;;; Clear Program Memory
;;;---------------------------------------------------------------------------
COMMAND_C:
	FIM CNT, loops(1, 16)
;;;	FIM CNT, loops(16, 16)
CMDPMC_BANKLOOP:
	LD_P1_CNT
	JMS PM_SELECTPMB_P1
	FIM R0R1, loops(16, 16)	; loop counter
	FIM P1, 00H		; data to fill
CMDPMC_L1:
	JMS PM_WRITE_P0_P1
	ISZ R1, CMDPMC_L1
	ISZ R0, CMDPMC_L1

	JMS PM_INIT_BANK	; write PM_READ code on program memory
	ISZ CNT_J, CMDPMC_BANKLOOP
	ISZ CNT_I, CMDPMC_BANKLOOP

;;;	JMS PM_SELECTPMB_P1	; set PMB to 0
	
	JUN CMD_LOOP		; return to command loop

;;;	org 0200H
;;;---------------------------------------------------------------------------
;;; 8080 emulator main loop
;;;---------------------------------------------------------------------------
COMMAND_E:
EMU_START:
	FIM P0, lo(STR_EMU_MESSAGE)
	JMS PRINTSTR_P0

EMU_LOOP:
	FIM P7, REG4_EMU_STEP
	LD_ACC_REG4P7
	JCN Z, EMU_EXEC
	JMS EMU_PRINT_REGISTERS
	JMS GETCHAR_P1
	FIM P7, '.'
	JMS CMP_P1P7
	JCN Z, EMU_EXIT
EMU_EXEC:
	
	JMS EXEC_CODE	; call by subroutine consumes precious PC stack 
			; but it can return here by BBL from various routines
			; in contrast JUN consumes 2 bytes
	JUN EMU_LOOP

EMU_EXIT:
	JUN CMD_LOOP	; go back to monitor loop

;;;---------------------------------------------------------------------------
;;; EXEC_CODE
;;;---------------------------------------------------------------------------
EXEC_CODE:
	FIM P0, REG16_PC
	JMS LD_P1_PM16REG16P0_INCREMENT

	LD P1_HI		;
	RAL			; ACC=bit(654x), CY=bit(7)
	JCN CN, CODE_007F	; 00H<=CODE<=7FH
	JUN CODE_80FF		; 80H<=CODE<=FFH

;;;---------------------------------------------------------------------------
CODE_007F:			; 00H<=CODE<=7FH
	RAL			; ACC=bit(54xx), CY=bit(6)
	JCN CN, CODE_003F	; 00H<=CODE<=3FH
	JUN CODE_407F		; 40H<=CODE<=7FH
;;;---------------------------------------------------------------------------
	NOP
	NOP
CODE_003F:			; 00H<=CODE<=3FH
	LD P1_LO
	JCN NZ,CODE_NOT_NOP
	LD P1_HI
	JCN NZ,CODE_NOT_NOP
	JUN CODE_00H		; NOP
CODE_NOT_NOP:
CODE_C0FF:
	; merge 01H<=CODE<=3FH and C0H<=CODE<=FFH here,
	; prepare for jump table
	; P1=P1<<1 and jump to dispatch table
	LD P1_LO
	CLC
	RAL
	XCH P1_LO			; P1_LO=bit(210).0, CY=bit(3)
	LD P1_HI
	RAL
	XCH P1_HI			; P1_HI=bit(6543)
	JUN JIN_P1_CODE_013F_C0FF	; jump to branch table
;;;---------------------------------------------------------------------------
CODE_80FF:			; 80H<=P1<=FFH
	RAL			; ACC=bit(54xx), CY=bit(6)
	JCN CN, CODE_80BF
	JUN CODE_C0FF		; C0H<=P1<=FFH

;;;---------------------------------------------------------------------------
CODE_407F:			; 40H<=P1<=7FH
CODE_80BF:			; 80H<=P1<=BFH
;;;---------------------------------------------------------------------------
;;; Common procedure for 40H<=CODE<=BFH
;;; save source value to REG(SRC)
;;; REG(SRC) = REG((~P1.bit(210))<<1)
;;; 8080 register code SSS
;;; 0 1 2 3 4 5 6 7
;;; B C D E H L M A
;;; ADDRESS=~(xxx)<<1
;;;---------------------------------------------------------------------------
	JMS PUSH_P1
	;; set source register address to P1
	CLB
	XCH P1_HI		; P1_HI=0000
	LD P1_LO
	CMA
	CLC
	RAL
	XCH P1_LO		; P1_LO=~bit(210)<<1, P1_HI=0000

	LD P1_LO

 	LDM REG8_M		; check if SRCREG==M or not
	CLC
	SUB P1_LO
	JCN Z, GETSRC_LOAD_M

	JMS LD_P1_REG8P1	; if SRCREG!=M then P1=REG(SRCREG)
        JUN GETSRC_SAVE_SRCVALUE

GETSRC_LOAD_M:			; if SRCREG==M then P1=PM(HL)
	FIM P0, REG16_HL
	JMS LD_P1_PM16REG16P0_INCREMENT ; P1=PM(ADDR(=HL)++)
	JMS DEC_REG16P0

GETSRC_SAVE_SRCVALUE:
	;; set source register value to P1
	FIM P0, REG8_SRC
	JMS LD_REG8P0_P1	; REG(SRC) = P1

	JMS POP_P1
	LD P1_HI
	RAL
	JCN CN, CODE_407F_MOV	; execute MOV
	JUN CODE_80BF_ARITH_LOGIC

;;;---------------------------------------------------------------------------
;;; Execute MOV code
;;; source value is already stored to REG8(SRC)
;;;---------------------------------------------------------------------------
CODE_407F_MOV:
	FIM P7, 76H		; check HLT
	JMS CMP_P1P7
	JCN ZN, CODE_MOV_L1
	JUN CODE_76H		; HLT

CODE_MOV_L1:
	;; set destination REGISTER address to P2
	FIM P2, 00H
	LD P1_HI
	RAL
	RAL
	CLC
	RAR
	RAR
	XCH P2_LO		; P2_LO=00.bit(54)
	LD P1_LO
	RAL			; CY=bit(3)
	LD P2_LO
	RAL
	CMA
	RAL
	XCH P2_LO		; P2_LO=~(bit(543)).0

	FIM P1, REG8_SRC
	JMS LD_P1_REG8P1	; P1=REG(SRC)

				; write SRC value to DST
	LDM REG8_M		; if DST=M, write M to (HL)
	CLC
	SUB P2_LO		; check DST(P2) is M or not
	JCN Z, CODE_MOV_WRITE_M_TO_PM

	JMS LD_REG8P2_P1	; mov REG(DST) = REG(SRC)
	BBL 0

CODE_MOV_WRITE_M_TO_PM:		; PM(HL)=REG(SRC)
	FIM P0, REG16_HL
	JUN LD_PM16REG16P0_P1
;;; 	BBL 0


;;;---------------------------------------------------------------------------
CODE_80BF_ARITH_LOGIC:
	; prepare P2 for jump table
	; P2=0F0H + CODE.bit(543)0
	FIM P2, 0F0H		; P2=0F0H
	LD P1_LO		; ACC=CODE(3210)
	RAL			; CY=CODE.bit(3)
	LD P1_HI		; ACC=CODE.bit(7654), CY=bit(3)
	RAL			; ACC=CODE.bit(6543)
	CLC			; CY=0
	RAL			; ACC=CODE.bit(543).0
	XCH P2_LO		; P2=0F0H + CODE.bit(543)0

	FIM P7, REG8_SRC
	JMS LD_P1_REG8P7	; P1 = REG(SRC)

	JUN JIN_P2_CODE_80BF

;;;---------------------------------------------------------------------------
;;; Emulate individual codes
;;;---------------------------------------------------------------------------
CODE_76H:			; HLT
	FIM P0, lo(STR_EMU_HLT)
	JMS PRINTSTR_P0
	FIM P7, REG4_EMU_STEP
	LD_ACC_REG4P7
	JCN ZN, CODE_76H_EXIT
	JMS EMU_PRINT_REGISTERS	; print registers if continuous mode
CODE_76H_EXIT:
	JUN CMD_LOOP		; go back to monitor by HLT

CODE_00H:			; NOP
	BBL 0

CODE_01H:			; LXI B,B3B2
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_C
	JMS LD_REG8P2_P1
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_B
	JUN LD_REG8P2_P1

CODE_02H:			; STAX B
	FIM P7, REG8_A
	JMS LD_P1_REG8P7
	FIM P0, REG16_BC
	JUN LD_PM16REG16P0_P1

CODE_03H:			; INX B
	FIM P0, REG16_BC
	JUN INC_REG16P0

CODE_04H:			; INR B
	FIM P1, REG8_B
	JUN CODE_INR
	
CODE_05H:			; DCR B
	FIM P1, REG8_B
	JUN CODE_DCR

CODE_06H:			; MVI B,B2
	FIM P2, REG8_B
	JUN CODE_MVI
;;; 	BBL 0

CODE_07H:			; RLC
	FIM P0, REG8_A
	JMS LD_P1_REG8P0
	LD P1_HI
	RAL			; CY=bit(7)
	LD P1_LO
	RAL
	XCH P1_LO		; P1_LO=bit(2107), CY=bit(3)
	LD P1_HI
	RAL
	XCH P1_HI		; P1_HI=bit(6543), CY=bit(7)
	JMS SETFLAG_C_CY
	JUN LD_REG8P0_P1
;;;	BBL 0

CODE_08H:			; ...
	BBL 0
	
CODE_09H:			; DAD B
	FIM P0, REG16_HL
	FIM P1, REG16_BC
	JMS ADD_REG16P0_REG16P1
	JUN SETFLAG_C_CY
;;; 	BBL 0

CODE_0AH:			; LDAX B
	FIM P0, REG16_BC
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS DEC_REG16P0
	
	FIM P2, REG8_A
	JUN LD_REG8P2_P1
;;; 	BBL 0

CODE_0BH:			; DCX B
	FIM P0, REG16_BC
	JUN DEC_REG16P0
;;; 	BBL 0
	
CODE_0CH:			; INR C
	FIM P1, REG8_C
	JUN CODE_INR
;;; 	BBL 0

CODE_0DH:			; DCR C
	FIM P1, REG8_C
	JUN CODE_DCR
;;; 	BBL 0

CODE_0EH:			; MVI C,B2
	FIM P2, REG8_C
	JUN CODE_MVI
;;; 	BBL 0

CODE_0FH:			; RRC
	FIM P0, REG8_A
	JMS LD_P1_REG8P0
	LD P1_LO
	RAR			; CY=bit(0)
	LD P1_HI
	RAR
	XCH P1_HI		; P1_HI=bit(0765), CY=bit(4)
	LD P1_LO
	RAR
	XCH P1_LO		; P1_LO=bit(4321), CY=bit(0)
	JMS SETFLAG_C_CY
	JUN LD_REG8P0_P1
;;; 	BBL 0

CODE_10H:			; ...
	BBL 0

CODE_11H:			; LXI D,B3B2
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_E
	JMS LD_REG8P2_P1
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_D
	JUN LD_REG8P2_P1

CODE_12H:			; STAX D
	FIM P7, REG8_A
	JMS LD_P1_REG8P7
	FIM P0, REG16_DE
	JUN LD_PM16REG16P0_P1
	
CODE_13H:			; INX D
	FIM P0, REG16_DE
	JUN INC_REG16P0

CODE_14H:			; INR D
	FIM P1, REG8_D
	JUN CODE_INR

CODE_15H:			; DCR D
	FIM P1, REG8_D
	JUN CODE_DCR
;;; 	BBL 0

CODE_16H:			; MVI D,B2
	FIM P2, REG8_D
	JUN CODE_MVI
;;; 	BBL 0

CODE_17H:			; RAL
	FIM P0, REG8_A
	JMS LD_P1_REG8P0	; P1=ACC
	JMS GETFLAG_C		; CY=FLAG_C
;;; 	RAR			; can be omitted because CY is already C
	LD P1_LO
	RAL
	XCH P1_LO		; P1_LO=bit(2107), CY=bit(3)
	LD P1_HI
	RAL
	XCH P1_HI		; P1_HI=bit(6543), CY=bit(7)
	JMS SETFLAG_C_CY
	JUN LD_REG8P0_P1
;;;	BBL 0
	
CODE_18H:			; ...
	BBL 0

CODE_19H:			; DAD D
	FIM P0, REG16_HL
	FIM P1, REG16_DE
	JMS ADD_REG16P0_REG16P1
	JUN SETFLAG_C_CY
;;;	BBL 0
	
CODE_1AH:			; LDAX D
	FIM P0, REG16_DE
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS DEC_REG16P0
	
	FIM P2, REG8_A
	JUN LD_REG8P2_P1
;;;	BBL 0

CODE_1BH:			; DCX D
	FIM P0, REG16_DE
	JUN DEC_REG16P0
;;;	BBL 0

CODE_1CH:			; INR E
	FIM P1, REG8_E
	JUN CODE_INR
;;;	BBL 0

CODE_1DH:			; DCR E
	FIM P1, REG8_E
	JUN CODE_DCR
;;;	BBL 0

CODE_1EH:			; MVI E,B2
	FIM P2, REG8_E
	JUN CODE_MVI
;;;	BBL 0

CODE_1FH:			; RAR
	FIM P0, REG8_A
	JMS LD_P1_REG8P0	; P1=ACC
	JMS GETFLAG_C		; CY=FLAG_C
;;; 	RAR			; can be omitted because CY is already C
	LD P1_HI
	RAR
	XCH P1_HI		; P1_HI=bit(C765), CY=bit(4)
	LD P1_LO
	RAR
	XCH P1_LO		; P1_LO=bit(4321), CY=bit(0)
	JMS SETFLAG_C_CY
	JUN LD_REG8P0_P1
;;;	BBL 0

CODE_20H:			; ...
	BBL 0

CODE_21H:			; LXI H,B3B2
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_L
	JMS LD_REG8P2_P1
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_H
	JUN LD_REG8P2_P1
;;;	BBL 0

CODE_22H:			; SHLD,B3B2
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_ADDRL
	JMS LD_REG8P2_P1
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_ADDRH
	JMS LD_REG8P2_P1	; REG(ADDR)=B3B2

	FIM P7, REG8_L
	JMS LD_P1_REG8P7
	FIM P0, REG16_ADDR
	JMS LD_PM16REG16P0_P1	; PM(REG(ADDR))=L
	JMS INC_REG16P0		; REG(ADDR)++
	
	FIM P7, REG8_H
	JMS LD_P1_REG8P7
	JMS LD_PM16REG16P0_P1	; PM(REG(ADDR))=H
	JUN INC_REG16P0		; REG(ADDR)++ and return
;;;	BBL 0

	
CODE_23H:			; INX H
	FIM P0, REG16_HL
	JUN INC_REG16P0
;;;	BBL 0

CODE_24H:			; INR H
	FIM P1, REG8_H
	JUN CODE_INR
;;;	BBL 0

CODE_25H:			; DCR H
	FIM P1, REG8_H
	JUN CODE_DCR
;;;	BBL 0

CODE_26H:			; MVI H,B2
	FIM P2, REG8_H
	JUN CODE_MVI
;;;	BBL 0

CODE_27H:			; DAA
				; This is not properly implemeted
				; due to the lack of AC(CY4) flag
	FIM P0, REG8_A
	JMS LD_P1_REG8P0
	LD P1_LO
	DAA
	XCH P1_LO
	LDM 0
	ADD P1_HI
	DAA
	XCH P1_HI
	
	JUN LD_REG8P0_P1
;;;	BBL 0

CODE_28H:			; ...
	BBL 0

CODE_29H:			; DAD H
	FIM P0, REG16_HL
	FIM P1, REG16_HL
	JMS ADD_REG16P0_REG16P1
	JUN SETFLAG_C_CY
;;;	BBL 0

CODE_2AH:			; LHLD,B3B2
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_ADDRL
	JMS LD_REG8P2_P1
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_ADDRH
	JMS LD_REG8P2_P1		; REG(ADDR)=B3B2

	FIM P0, REG16_ADDR
	FIM P2, REG8_L
	JMS LD_P1_PM16REG16P0_INCREMENT ; L=PM(REG(ADDR)++)
	JMS LD_REG8P2_P1

	FIM P2, REG8_H
	JMS LD_P1_PM16REG16P0_INCREMENT
	JUN LD_REG8P2_P1		; H=PM(REG(ADDR)++) and return
;;;	BBL 0

CODE_2BH:			; DCX H
	FIM P0, REG16_HL
	JUN DEC_REG16P0
;;;	BBL 0

CODE_2CH:			; INR L
	FIM P1, REG8_L
	JUN CODE_INR
;;;	BBL 0

CODE_2DH:			; DCR L
	FIM P1, REG8_L
	JUN CODE_DCR
;;;	BBL 0

CODE_2EH:			; MVI L,B2
	FIM P2, REG8_L
	JUN CODE_MVI
;;;	BBL 0

CODE_2FH:			; CMA
	FIM P0, REG8_A		; A=~A
	JMS LD_P1_REG8P0
	LD P1_LO
	CMA
	XCH P1_LO

	LD P1_HI
	CMA
	XCH P1_HI
	JUN LD_REG8P0_P1
;;;	BBL 0
	
CODE_30H:			; ...
	BBL 0

CODE_31H:			; LXI SP, B3B2
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_SPL
	JMS LD_REG8P2_P1
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_SPH
	JUN LD_REG8P2_P1
;;;	BBL 0

CODE_32H:			; STA B3B2
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_ADDRL
	JMS LD_REG8P2_P1
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_ADDRH
	JMS LD_REG8P2_P1	; REG(ADDR)=B3B2

	FIM P7, REG8_A
	JMS LD_P1_REG8P7	; P1=A
	FIM P0, REG16_ADDR
	JUN LD_PM16REG16P0_P1	; PM(REG(ADDR)) = A and return
;;;	BBL 0
	
CODE_33H:			; INX SP
	FIM P0, REG16_SP
	JUN INC_REG16P0
;;;	BBL 0

CODE_34H:			; INR M
	FIM P0, REG16_HL
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS DEC_REG16P0
	
	JMS INC_P1
	JMS LD_PM16REG16P0_P1

	JUN SETFLAG_ZSP_P1
;;;	BBL 0

CODE_35H:			; DCR M
	FIM P0, REG16_HL
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS DEC_REG16P0
	
	JMS DEC_P1
	JMS LD_PM16REG16P0_P1

	JUN SETFLAG_ZSP_P1
;;;	BBL 0
	
CODE_36H:			; MVI M, B2
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P0, REG16_HL
	JUN LD_PM16REG16P0_P1
;;;	BBL 0
	
CODE_37H:			; STC
	JUN SETFLAG_C_1
;;;	BBL 0

CODE_38H:			; ...
	BBL 0

CODE_39H:			; DAD SP
	FIM P0, REG16_HL
	FIM P1, REG16_SP
	JMS ADD_REG16P0_REG16P1
	JUN SETFLAG_C_CY
;;;	BBL 0

CODE_3AH:			; LDA B2B3
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_ADDRL
	JMS LD_REG8P2_P1
	JMS LD_P1_PM16REG16P0_INCREMENT
	FIM P2, REG8_ADDRH
	JMS LD_REG8P2_P1	; REG(ADDR)=B3B2

	FIM P0, REG16_ADDR
	JMS LD_P1_PM16REG16P0_INCREMENT	; P1=PM(REG(ADDR)++)
	FIM P2, REG8_A
	JUN LD_REG8P2_P1	; P1=A and return
;;;	BBL 0

CODE_3BH:			; DCX SP
	FIM P0, REG16_SP
	JUN DEC_REG16P0
;;;	BBL 0

CODE_3CH:			; INR A
	FIM P1, REG8_A
CODE_INR:
	JMS INC_REG8P1
	JUN SETFLAG_ZSP_REG8P1
;;;	BBL 0

CODE_3DH:			; DCR A
	FIM P1, REG8_A
CODE_DCR:
	JMS DEC_REG8P1
	JUN SETFLAG_ZSP_REG8P1
;;;	BBL 0

CODE_3EH:			; MVI A,B2
	FIM P2, REG8_A
CODE_MVI:
	JMS LD_P1_PM16REG16P0_INCREMENT
	JUN LD_REG8P2_P1
;;;	BBL 0

CODE_3FH:			; CMC
	JMS GETFLAG_C
;;; 	RAR			; can be omitted because CY is already C
	CMC
	JUN SETFLAG_C_CY
;;;	BBL 0

CODE_C0H:			; RNZ
	JMS GETFLAG_Z		; *** Z-flag =1 if zero, =0 if not zero ***
	JUN RET_IF0		; return if Z flag == 0
	;;;	BBL 0

CODE_C1H:			; POP B
	FIM P2, REG8_B
	FIM P3, REG8_C
	JUN CODE_POP_REG8P2P3
;;;	BBL 0

CODE_C2H:			; JNZ
	JMS GETFLAG_Z		; *** Z==1 if zero, ==0 if not zero ***
;;;	JUN JMP_IF0		; jump if Z==0
;;; this jump can be omitted
JMP_IF0:
	JCN Z, CODE_JMP
	JMS INC_REG16P0		; PC+=2
	JMS INC_REG16P0
	BBL 0
JMP_IF1:
	JCN ZN, CODE_JMP
	JMS INC_REG16P0		; PC+=2
	JMS INC_REG16P0
	BBL 0

CODE_C3H:			; JMP B3B2
CODE_JMP:
	JMS LD_P1_PM16REG16P0_INCREMENT ; P2=PM(REG(PC)++)
	LD_P3_P1
	JMS LD_P1_PM16REG16P0_INCREMENT ; P3=PM(REG(PC)++)
	LD_P2_P1
;;;	FIM P0, REG16_PC	; this can be omitted
	JUN LD_REG16P0_P2P3
;;;	BBL 0

CODE_C4H:			; CNZ
	JMS GETFLAG_Z		; *** Z==1 if zero, ==0 if not zero ***
	JUN CALL_IF0		; call if Z==0
;;;	BBL 0

CODE_C5H:			; PUSH B
	FIM P2, REG8_B
	FIM P3, REG8_C
	JUN CODE_PUSH_REG8P2P3
;;;	BBL 0

CODE_C6H:			; ADI B2
	JMS LD_P1_PM16REG16P0_INCREMENT ; P1=PM(REG(PC)++)
ADI_P1:
	FIM P0, REG8_A
	JMS ADD_REG8P0_P1
	JMS SETFLAG_C_CY
	JUN SETFLAG_ZSP_REG8P0
;;;	BBL 0
	
CODE_C7H:			; RST 0
	FIM P2, up(0<<3)
	FIM P3, lo(0<<3)
	JUN CALL_P2P3
;;;	BBL 0
	
CODE_C8H:			; RZ
	JMS GETFLAG_Z		; *** Z-flag =1 if zero, =0 if not zero ***
;;;	JUN RET_IF1		; return if Z flag == 1
;;; this jump can be omitted
RET_IF1:
	JCN ZN, CODE_RET
	BBL 0
RET_IF0:
	JCN Z, CODE_RET
	BBL 0
CODE_C9H:			; RET
CODE_RET:	
	FIM P2, REG8_PCH
	FIM P3, REG8_PCL
	JUN CODE_POP_REG8P2P3
;;;	BBL 0
	
CODE_CAH:			; JZ
	JMS GETFLAG_Z		; *** Z==1 if zero, ==0 if not zero ***
	JUN JMP_IF1		; jump if Z==1
;;;	BBL 0

CODE_CBH:			; ...
	BBL 0

CODE_CCH:			; CZ
	JMS GETFLAG_Z
CALL_IF1:
	JCN ZN, CODE_CALL
	JMS INC_REG16P0		; PC+=2
	JMS INC_REG16P0
	BBL 0
CALL_IF0:	
	JCN Z, CODE_CALL
	JMS INC_REG16P0		; PC+=2
	JMS INC_REG16P0
	BBL 0

CODE_CDH:			; CALL B3B2
CODE_CALL:
	JMS LD_P1_PM16REG16P0_INCREMENT ; P2=PM(REG(PC)++)
	LD_P3_P1
	JMS LD_P1_PM16REG16P0_INCREMENT ; P3=PM(REG(PC)++)
	LD_P2_P1			; P2P3=B3B2 (Target address to jump)

CALL_P2P3:
	FIM P1, REG16_ADDR
	JMS LD_REG16P1_REG16P0	; ADDR=PC (return address to PUSH)
;;; 	FIM P0, REG16_PC	; this can be omitted
	JMS LD_REG16P0_P2P3	; PC=B3B2
	
	;; PUSH PC
	FIM P2, REG8_ADDRH
	FIM P3, REG8_ADDRL
	JUN CODE_PUSH_REG8P2P3
;;; 	BBL 0

CODE_CEH:			; ACI B2
	JMS LD_P1_PM16REG16P0_INCREMENT ; P1=PM(REG(PC)++)
ACI_P1:
	JMS GETFLAG_C
	JCN Z, ACI_P1_NOCARRY
	JMS INC_P1
ACI_P1_NOCARRY:	
	FIM P0, REG8_A
	JMS ADD_REG8P0_P1
	JMS SETFLAG_C_CY
	JUN SETFLAG_ZSP_REG8P0
;;;	BBL 0
	
CODE_CFH:			; RST 1
	FIM P2, up(1<<3)
	FIM P3, lo(1<<3)
	JUN CALL_P2P3
	
CODE_D0H:			; RNC
	JMS GETFLAG_C		;
	JUN RET_IF0		;
;;;	BBL 0

CODE_D1H:			; POP D
	FIM P2, REG8_D
	FIM P3, REG8_E
	JUN CODE_POP_REG8P2P3
;;;	BBL 0

CODE_D2H:			; JNC
	JMS GETFLAG_C
	JUN JMP_IF0
;;;	BBL 0

CODE_D3H:			; OUT B2
	JMS LD_P1_PM16REG16P0_INCREMENT ; P1=PM(REG(PC)++)
	JUN EMULATE_OUT_P1
;;;	BBL 0
	
CODE_D4H:			; CNC
	JMS GETFLAG_C
	JUN CALL_IF0
;;;	BBL 0

CODE_D5H:			; PUSH D
	FIM P2, REG8_D
	FIM P3, REG8_E
	JUN CODE_PUSH_REG8P2P3
;;;	BBL 0

CODE_D6H:			; SUI B2
	JMS LD_P1_PM16REG16P0_INCREMENT ; P1=PM(REG(PC)++)
SUI_P1:
	FIM P0, REG8_A
	JMS SUB_REG8P0_P1
	JMS SETFLAG_C_CY
	JUN SETFLAG_ZSP_REG8P0
;;;	BBL 0
	
CODE_D7H:			; RST 2
	FIM P2, up(2<<3)
	FIM P3, lo(2<<3)
	JUN CALL_P2P3
;;;	BBL 0
	
CODE_D8H:			; RC
	JMS GETFLAG_C
	JUN RET_IF1
;;;	BBL 0

CODE_D9H:			; ...
	BBL 0

CODE_DAH:			; JC
	JMS GETFLAG_C
	JUN JMP_IF1
;;;	BBL 0

CODE_DBH:			; IN
	JMS LD_P1_PM16REG16P0_INCREMENT ; P1=PM(REG(PC)++)
	JUN EMULATE_IN_P1
;;;	BBL 0

CODE_DCH:			; CC
	JMS GETFLAG_C
	JUN CALL_IF1

CODE_DDH:			; ...
	BBL 0
CODE_DEH:			; SBI B2
	JMS LD_P1_PM16REG16P0_INCREMENT ; P1=PM(REG(PC)++)
SBI_P1:
	JMS GETFLAG_C
	JCN Z, SBI_P1_NOCARRY
	JMS INC_P1
SBI_P1_NOCARRY:
	FIM P0, REG8_A
	JMS SUB_REG8P0_P1
	JMS SETFLAG_C_CY
	JUN SETFLAG_ZSP_REG8P0
;;; 	BBL 0

CODE_DFH:			; RST 3
	FIM P2, up(3<<3)
	FIM P3, lo(3<<3)
	JUN CALL_P2P3

CODE_E0H:			; RPO
	JMS GETFLAG_P
	JUN RET_IF0
	
CODE_E1H:			; POP H
	FIM P2, REG8_H
	FIM P3, REG8_L
	JUN CODE_POP_REG8P2P3

CODE_E2H:			; JPO
	JMS GETFLAG_P
	JUN JMP_IF0

CODE_E3H:			; XTHL L<->(SP) H<->(SP+1)
	;; POP to ADDR
	FIM P2, REG8_ADDRH
	FIM P3, REG8_ADDRL
	FIM P0, REG16_SP
	JMS LD_P1_PM16REG16P0_INCREMENT ; lower byte is first
	JMS LD_REG8P3_P1		; REG(ADDRL)=(SP++)
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS LD_REG8P2_P1		; REG(ADDRH)=(SP++)

	;; PUSH HL
	FIM P2, REG8_H
	FIM P3, REG8_L
	JMS LD_P1_REG8P2	; P1=REG(H)
	JMS DEC_REG16P0		; REG(SP)--
	JMS LD_PM16REG16P0_P1	; PM(REG(SP)) = H

	JMS LD_P1_REG8P3	; P1=REG(L)
	JMS DEC_REG16P0		; REG(SP)--
	JMS LD_PM16REG16P0_P1	; PM(REG(SP)) = L

	;; HL = ADDR
	FIM P6, REG16_HL
	FIM P7, REG16_ADDR
	JUN LD_REG16P6_REG16P7 ; REG(HL)=REG(ADDR)
	
CODE_E4H:			; CPO
	JMS GETFLAG_P
	JUN CALL_IF0

CODE_E5H:			; PUSH H
	FIM P2, REG8_H
	FIM P3, REG8_L
	JUN CODE_PUSH_REG8P2P3

CODE_E6H:			; ANI B2
	JMS LD_P1_PM16REG16P0_INCREMENT ; P1=PM(REG(PC)++)
ANI_P1:
	LD_P2_P1		; P2=B2
	FIM P0, REG8_A
	JMS LD_P1_REG8P0	; P1=A
	JMS AND_P1_P2		; P1=A&P2
	JMS LD_REG8P0_P1	; A= P1
	JMS SETFLAG_C_0
	JUN SETFLAG_ZSP_REG8P0
	
CODE_E7H:			; RST 4
	FIM P2, up(4<<3)
	FIM P3, lo(4<<3)
	JUN CALL_P2P3

CODE_E8H:			; RPE
	JMS GETFLAG_P
	JUN RET_IF1

CODE_E9H:			; PCHL
	FIM P1, REG16_HL
	JUN LD_REG16P0_REG16P1
	
CODE_EAH:			; JPE
	JMS GETFLAG_P
	JUN JMP_IF1

CODE_EBH:			; XCHG
	FIM P0, REG16_ADDR
	FIM P1, REG16_HL
	JMS LD_REG16P0_REG16P1	; ADDR=HL
	FIM P0, REG16_DE
	JMS LD_REG16P1_REG16P0	; HL=DE
	FIM P1, REG16_ADDR
	JUN LD_REG16P0_REG16P1	; DE=ADDR
	
CODE_ECH:			; CPE
	JMS GETFLAG_P
	JUN CALL_IF1

CODE_EDH:			; ...
	BBL 0

CODE_EEH:			; XRI B2
	JMS LD_P1_PM16REG16P0_INCREMENT ; P1=PM(REG(PC)++)
XRI_P1:
	LD_P2_P1		; P2=B2
	FIM P0, REG8_A
	JMS LD_P1_REG8P0	; P1=A
	JMS XOR_P1_P2
	JMS LD_REG8P0_P1	; A= A ^ P2
	JMS SETFLAG_C_0
	JUN SETFLAG_ZSP_REG8P0
	
CODE_EFH:			; RST 5
	FIM P2, up(5<<3)
	FIM P3, lo(5<<3)
	JUN CALL_P2P3

CODE_F0H:			; RP
	JMS GETFLAG_S
	JUN RET_IF0
	
CODE_F1H:			; POP PSW
	FIM P2, REG8_A
	FIM P3, REG8_FLAG
CODE_POP_REG8P2P3:
	FIM P0, REG16_SP
	JMS LD_P1_PM16REG16P0_INCREMENT ; lower byte is first
	JMS LD_REG8P3_P1		; REG(P3)=(SP++)
	JMS LD_P1_PM16REG16P0_INCREMENT
	JUN LD_REG8P2_P1		; REG(P2)=(SP++)
	
CODE_F2H:			; JP
	JMS GETFLAG_S
	JUN JMP_IF0

CODE_F3H:			; DI
				; Interrupt is not implemented
	BBL 0

CODE_F4H:			; CP
	JMS GETFLAG_S
	JUN CALL_IF0

CODE_F5H:			; PUSH PSW
	FIM P2, REG8_A
	FIM P3, REG8_FLAG
CODE_PUSH_REG8P2P3:
	FIM P0, REG16_SP
				; higher byte is the first
	JMS LD_P1_REG8P2	; P1=REG(P2)
	JMS DEC_REG16P0		; REG(SP)--
	JMS LD_PM16REG16P0_P1	; PM(REG(SP)) = P2

	JMS LD_P1_REG8P3	; P1=REG(P3)
	JMS DEC_REG16P0		; REG(SP)--
	JUN LD_PM16REG16P0_P1	; PM(REG(SP)) = P3 and return

CODE_F6H:			; ORI
	JMS LD_P1_PM16REG16P0_INCREMENT ; P1=PM(REG(PC)++)
ORI_P1:
	LD_P2_P1		; P2=B2
	FIM P0, REG8_A
	JMS LD_P1_REG8P0	; P1=A
	JMS OR_P1_P2
	JMS LD_REG8P0_P1	; P1= A | P2
	JMS SETFLAG_C_0
	JUN SETFLAG_ZSP_REG8P0
	
CODE_F7H:			; RST 6
	FIM P2, up(6<<3)
	FIM P3, lo(6<<3)
	JUN CALL_P2P3

CODE_F8H:			; RM
	JMS GETFLAG_S
	JUN RET_IF1

CODE_F9H:			; SPHL
	FIM P6, REG16_SP
	FIM P7, REG16_HL
	JUN LD_REG16P6_REG16P7

CODE_FAH:			; JM
	JMS GETFLAG_S
	JUN JMP_IF1

CODE_FBH:			; EI
				; Interrupt is not implemented
	BBL 0

CODE_FCH:			; CM
	JMS GETFLAG_S
	JUN CALL_IF1

CODE_FDH:			; ...
	BBL 0

CODE_FEH:			; CPI
	JMS LD_P1_PM16REG16P0_INCREMENT ; P1=PM(REG(PC)++)
CPI_P1:
	FIM P6, REG8_SRC
	FIM P7, REG8_A
	JMS LD_REG8P6_REG8P7
	FIM P0, REG8_SRC
	JMS SUB_REG8P0_P1
	JMS SETFLAG_C_CY
	JUN SETFLAG_ZSP_REG8P0
;;; 	BBL 0
CODE_FFH:			; RST 7
	FIM P2, up(7<<3)
	FIM P3, lo(7<<3)
	JUN CALL_P2P3

;;;---------------------------------------------------------------------------
;;; FLAG routines
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; GETFLAG_Z
;;; ACC = FLAG_Z, CY=FLAG_Z
;;;---------------------------------------------------------------------------
GETFLAG_Z:
	FIM P7, REG4_FLAG_SZBH
	SRC P7
	RDM
	RAL
	RAL
	JCN C, GETFLAG_Z_EXIT1
	BBL 0
GETFLAG_Z_EXIT1:
	BBL 1

;;;---------------------------------------------------------------------------
;;; GETFLAG_S
;;; ACC = FLAG_S, CY=FLAG_S
;;;---------------------------------------------------------------------------
GETFLAG_S:
	FIM P7, REG4_FLAG_SZBH
	SRC P7
	RDM
	RAL
	JCN C, GETFLAG_S_EXIT1
	BBL 0
GETFLAG_S_EXIT1:
	BBL 1

;;;---------------------------------------------------------------------------
;;; GETFLAG_C
;;; ACC=FLAG_C, CY=FLAG_C
;;;---------------------------------------------------------------------------
GETFLAG_C:
	FIM P7, REG4_FLAG_1P1C
	SRC P7
	RDM
	RAR
	JCN C, GETFLAG_C_1
	BBL 0
GETFLAG_C_1:	
	BBL 1

;;;---------------------------------------------------------------------------
;;; GETFLAG_P
;;; Flag P is loded to ACC
;;; ACC=FLAG_P
;;; This routine is compiled if EMU_USE_FLAG_P, 
;;; otherwise FLAG_P is always 0.
;;;---------------------------------------------------------------------------
GETFLAG_P:
	if EMU_USE_FLAG_P
	FIM P7, REG4_FLAG_1P1C
	SRC P7
	RDM
	RAL
	RAL
	JCN CN, GETFLAG_P_0
	BBL 1
GETFLAG_P_0:
	endif 			; EMU_USE_FLAG_P
	BBL 0
	
;;;---------------------------------------------------------------------------
;;; SETFLAG_C_{CY, 0, 1}
;;; 	Set FLAG_C = {CY, 0, 1}
;;;---------------------------------------------------------------------------
SETFLAG_C_CY:
	JCN C, SETFLAG_C_1
SETFLAG_C_0:
	FIM P7, REG4_FLAG_1P1C
	SRC P7
	RDM
	RAR
	CLC
	RAL
	WRM
	BBL 0
SETFLAG_C_1:
	FIM P7, REG4_FLAG_1P1C
	SRC P7
	RDM
	RAR
	STC
	RAL
	WRM
	BBL 0

;;;---------------------------------------------------------------------------
;;; SETFLAG_ZSP_{REG8P0, REG8P1, P1}
;;; 
;;; Set flag Z and S according to the value of {REG8P0, REG8P1, P1}.
;;; P flag is compiled if EMU_USE_FLAG_P (not implemented yet).
;;;---------------------------------------------------------------------------
SETFLAG_ZSP_REG8P0:
	JMS LD_P1_REG8P0
	JUN SETFLAG_ZSP_P1

SETFLAG_ZSP_REG8P1:
	JMS LD_P1_REG8P1

SETFLAG_ZSP_P1:
	LD P1_HI		; ACC=Sxxx
	RAL			; CY=S
	TCC			; ACC=000S, (CY=Z), (BH=00)
	
	XCH CNT_I		; I=BHxS, (CY=Z to be set), (BH=00)

	;; set Z FLAG
	JMS ISZEROORNOT_P1
	RAR			; CY= (P1==0) ? 0 : 1
	CMC			; CY= (P1==0) ? 1 : 0
	LD CNT_I		; ACC=BHxS (CY=Z)
	RAR			; ACC=ZBHx (CY=S)
	RAR			; ACC=SZBH (BH=00)

	FIM P7, REG4_FLAG_SZBH
	SRC P7
	WRM			; write back to REG16_FLAG_SZBH

	if EMU_USE_FLAG_P
	;; Set P flag
;;; table implementation may be faster
;;;              0123456789ABCDEF
;;; 4bit table =(0110100110010110)
;;; org 09D0H
;;; PARITY4TABLE: (1 when EVEN)
;;; data 1,0,0,1,0,1,1,0,0,1,1,0,1,0,0,1
;;; GETPARITY_R1:
;;; FIN P2
;;; LD P2_LO
;;; XCH_R1
;;; BBL 0
;;; 
;;; FIM P0, lo(PARITY4TABLE)
;;; LD P1_H
;;; XCH R1
;;; JMS GETPARITY_R1
;;; LD R1
;;; XCH P1_H
;;; LD P1_L
;;; XCH R1
;;; JMS GETPARITY_R1
;;; LD R1
;;; ADD P1_H
;;; RAR       ; here CY=PARITY (1 when EVEN)
	
	CLB
	XCH CNT_I		; I=0
	LD_P1_P2		; restore P1
	LD P1_HI
	RAL
	JCN CN,PFLAG_CNT1
	INC CNT_I
PFLAG_CNT1:
	RAL
	JCN CN,PFLAG_CNT2
	INC CNT_I
PFLAG_CNT2:
	RAL
	JCN CN,PFLAG_CNT3
	INC CNT_I
PFLAG_CNT3:
	RAL
	JCN CN,PFLAG_CNT4
	INC CNT_I
PFLAG_CNT4:
	LD P1_LO
	RAL
	JCN CN,PFLAG_CNT5
	INC CNT_I
PFLAG_CNT5:
	RAL
	JCN CN,PFLAG_CNT6
	INC CNT_I
PFLAG_CNT6:
	RAL
	JCN CN,PFLAG_CNT7
	INC CNT_I
PFLAG_CNT7:
	RAL
	JCN CN,PFLAG_CNT8
	INC CNT_I
PFLAG_CNT8:
	FIM P7, REG4_FLAG_1P1C
	SRC P7
	RDM
	RAL
	RAL
	WRM			; FLAG=xCxx (CY=P)

	LD CNT_I
	RAR
	CMC			; CY=~(LSB of I) (P=1 when EVEN )

	RDM
	RAR
	RAR
	WRM			; FLAG=xPxC
	
	endif			; EMU_USE_FLAG_P
	BBL 0	

;;;---------------------------------------------------------------------------
;;; Logical operators
;;; and, or, xor
;;; destroy: P3(R6, R7)
;;;---------------------------------------------------------------------------

;;;---------------------------------------------------------------------------
;;; AND_R6_R7
;;; R6 = R6 & R7
;;;---------------------------------------------------------------------------
AND_R6_R7:
	CLB
	LD R7
	RAR
	JCN C, AND67_L1	; jump if R7.bit0==1
	LD R6
	RAR
	CLC
	RAL
	XCH R6		; R6.bit0=0
AND67_L1:
	LD R7
	RAR
	RAR
	JCN C, AND67_L2	; jump if R7.bit1==1
	LD R6
	RAR
	RAR
	CLC
	RAL
	RAL
	XCH R6		; R6.bit1=0
AND67_L2:
	LD R7
	RAL
	RAL
	JCN C, AND67_L3	; jump if R7.bit2==1
	LD R6
	RAL
	RAL
	CLC
	RAR
	RAR
	XCH R6		; R6.bit2=0
AND67_L3:
	LD R7
	RAL
	JCN C, AND67_L4	; jump if R7.bit3==1
	LD R6
	RAL
	CLC
	RAR
	XCH R6		; R6.bit3=0
AND67_L4:
	
	BBL 0

;;;---------------------------------------------------------------------------
;;; AND_P1_P2
;;; P1 = P1 & P2
;;;---------------------------------------------------------------------------
AND_P1_P2:
	LD P1_LO
	XCH R6
	LD P2_LO
	XCH R7
	JMS AND_R6_R7
	LD R6
	XCH P1_LO
	
	LD P1_HI
	XCH R6
	LD P2_HI
	XCH R7
	JMS AND_R6_R7
	LD R6
	XCH P1_HI
	BBL 0

;;;---------------------------------------------------------------------------
;;; XOR_R6_R7
;;; R6 = R6 ^ R7
;;;---------------------------------------------------------------------------
XOR_R6_R7:
	CLB
	LD R7
	RAR
	JCN CN, XOR67_L1	; jump if R7.bit0==0
	LD R6
	RAR
	CMC
	RAL
	XCH R6			; cmp R6.bit0
XOR67_L1:
	LD R7
	RAR
	RAR
	JCN CN, XOR67_L2	; jump if R7.bit1==0
	LD R6
	RAR
	RAR
	CMC
	RAL
	RAL
	XCH R6			; cmp R6.bit1
XOR67_L2:
	LD R7
	RAL
	RAL
	JCN CN, XOR67_L3	; jump if R7.bit2==0
	LD R6
	RAL
	RAL
	CMC
	RAR
	RAR
	XCH R6			; cmp R6.bit2
XOR67_L3:
	LD R7
	RAL
	JCN CN, XOR67_L4	; jump if R7.bit3==0
	LD R6
	RAL
	CMC
	RAR
	XCH R6			; cmp R6.bit3
XOR67_L4:
	BBL 0

;;;---------------------------------------------------------------------------
;;; XOR_P1_P2
;;; P1 = P1 ^ P2
;;;---------------------------------------------------------------------------
XOR_P1_P2:
	LD P1_LO
	XCH R6
	LD P2_LO
	XCH R7
	JMS XOR_R6_R7
	LD R6
	XCH P1_LO
	
	LD P1_HI
	XCH R6
	LD P2_HI
	XCH R7
	JMS XOR_R6_R7
	LD R6
	XCH P1_HI
	BBL 0

;;;---------------------------------------------------------------------------
;;; OR_P1_P2
;;; P1 = P1 | P2
;;;---------------------------------------------------------------------------
OR_P1_P2:
	LD P1_LO
	XCH R6
	LD P2_LO
	XCH R7
	JMS OR_R6_R7
	LD R6
	XCH P1_LO
	
	LD P1_HI
	XCH R6
	LD P2_HI
	XCH R7
	JMS OR_R6_R7
	LD R6
	XCH P1_HI
	BBL 0

;;;---------------------------------------------------------------------------
;;; OR_R6_R7
;;; R6 = R6 | R7
;;;---------------------------------------------------------------------------
OR_R6_R7:
	CLB
	LD R7
	RAR
	JCN CN, OR67_L1	; jump if R7.bit0==0
	LD R6
	RAR
	STC
	RAL
	XCH R6			; cmp R6.bit0
OR67_L1:
	LD R7
	RAR
	RAR
	JCN CN, OR67_L2	; jump if R7.bit1==0
	LD R6
	RAR
	RAR
	STC
	RAL
	RAL
	XCH R6			; cmp R6.bit1
OR67_L2:
	LD R7
	RAL
	RAL
	JCN CN, OR67_L3	; jump if R7.bit2==0
	LD R6
	RAL
	RAL
	STC
	RAR
	RAR
	XCH R6			; cmp R6.bit2
OR67_L3:
	LD R7
	RAL
	JCN CN, OR67_L4	; jump if R7.bit3==0
	LD R6
	RAL
	STC
	RAR
	XCH R6			; cmp R6.bit3
OR67_L4:
	BBL 0


;;;	org 0900H
;;;----------------------------------------------------------------------------
;;; Subroutines for REG16 (16bit registars)
;;;----------------------------------------------------------------------------
	
	
;;;----------------------------------------------------------------------------
;;; LD_REG16P0_REG16P1
;;; REG16(P0) = REG16(P1)
;;; destroy: P6, P7
;;;----------------------------------------------------------------------------
LD_REG16P0_REG16P1:
	LD_P6_P0
	LD_P7_P1
	JUN LD_REG16P6_REG16P7

;;;----------------------------------------------------------------------------
;;; LD_REG16P1_REG16P0
;;; REG16(P1) = REG16(P0)
;;; destroy: P6, P7
;;;----------------------------------------------------------------------------
LD_REG16P1_REG16P0:
	LD_P6_P1
	LD_P7_P0
	JUN LD_REG16P6_REG16P7

;;;----------------------------------------------------------------------------
;;; LD_REG16P7_P2P3
;;; REG16(P7) = P2P3(R4R5R6R7)
;;; destroy P7
;;;----------------------------------------------------------------------------
LD_REG16P7_P2P3:
	SRC P7
	LD P3_LO
	WRM

	INC P7_LO
	SRC P7
	LD P3_HI
	WRM

	INC P7_LO
	SRC P7
	LD P2_LO
	WRM

	INC P7_LO
	SRC P7
	LD P2_HI
	WRM

	BBL 0

;;;----------------------------------------------------------------------------
;;; LD_REG16P1_P2P3
;;; REG16(P1) = P2P3(R4R5R6R7)
;;; destroy P7
;;;----------------------------------------------------------------------------
LD_REG16P1_P2P3:
	LD_P7_P1
	JUN LD_REG16P7_P2P3

;;;----------------------------------------------------------------------------
;;; LD_REG16P0_P2P3
;;; REG16(P1) = P2P3(R4R5R6R7)
;;; destroy P7
;;;----------------------------------------------------------------------------
LD_REG16P0_P2P3:
	LD_P7_P0
	JUN LD_REG16P7_P2P3

;;;----------------------------------------------------------------------------
;;; ADD_REG8P0_P1
;;; REG8(P0) = REG16(P0)+P1
;;; destroy: P7(R14, R15)
;;;----------------------------------------------------------------------------
ADD_REG8P0_P1:
	LD_P7_P0
	SRC P7
	RDM
	LD P1_LO
	CLC
	ADM
	WRM
	INC P7_LO
	SRC P7
	RDM
	LD P1_HI
	ADM
	WRM
	BBL 0

;;;----------------------------------------------------------------------------
;;; INC_REG8P1
;;; REG8(P1) = REG16(P1)+1
;;; CY is set if overflow
;;; destroy: P7(R14, R15)
;;;----------------------------------------------------------------------------
INC_REG8P1:
	LD_P7_P1
	
	SRC P7
	RDM
	IAC 
	WRM			; REG(P0).lower++
	JCN NZ, REG8_INC_EXIT
	INC P7_LO
	SRC P7
	RDM
	IAC 
	WRM			; REG(P0).higher++
REG8_INC_EXIT:
	BBL 0

;;;----------------------------------------------------------------------------
;;; SUB_REG8P0_P1
;;; REG8(P0) = REG8(P0)-P1
;;; destroy: P7(R14, R15)
;;;----------------------------------------------------------------------------
SUB_REG8P0_P1:
	LD_P7_P0
	SRC P7
	RDM
	CLC
	SUB P1_LO
	WRM
	CMC

	INC P7_LO
	SRC P7
	RDM
	SUB P1_HI
	WRM
	CMC

	BBL 0	

;;;----------------------------------------------------------------------------
;;; DEC_REG8P1
;;; REG8(P1) = REG16(P1)+1
;;; destroy: P7(R14, R15)
;;;----------------------------------------------------------------------------
DEC_REG8P1:
	LD_P7_P1
	
	SRC P7
	RDM
	DAC 
	WRM			; REG(P0).lower--
	JCN C, REG8_DEC_EXIT	; borrow=0 then exit
	INC P7_LO
	SRC P7
	RDM
	DAC 
	WRM			; REG(P0).higher--
REG8_DEC_EXIT:
	BBL 0

;;;----------------------------------------------------------------------------
;;; LD_REG8P0_REG8P1
;;; REG8(P0)=REG8(P1)
;;; destroy: P6, P7
;;;----------------------------------------------------------------------------
LD_REG8P0_REG8P1:
	LD_P6_P0
	LD_P7_P1
LD_REG8P6_REG8P7:
	SRC P7
	RDM
	SRC P6
	WRM
	INC P7_LO
	INC P6_LO
	SRC P7
	RDM
	SRC P6
	WRM

	BBL 0

;;;----------------------------------------------------------------------------
;;; LD_REG8P0_P1
;;; REG8(P0)=P1
;;;----------------------------------------------------------------------------
LD_REG8P0_P1:
	LD_P7_P0
 	JUN LD_REG8P7_P1

;;;----------------------------------------------------------------------------
;;; LD_REG8P3_P1
;;; REG8(P3)=P1
;;;----------------------------------------------------------------------------
LD_REG8P3_P1:
	LD_P7_P3
 	JUN LD_REG8P7_P1

;;;----------------------------------------------------------------------------
;;; LD_REG8P2_P1
;;; REG8(P2) = P1
;;;----------------------------------------------------------------------------
LD_REG8P2_P1:
	LD_P7_P2
;;; 	JUN LD_REG8P7_P1
;;;----------------------------------------------------------------------------
;;; LD_REG8P7_P1
;;; REG8(P7)=P1
;;; destroy: P7
;;;----------------------------------------------------------------------------
LD_REG8P7_P1:
	SRC P7
	LD P1_LO
	WRM

	INC P7_LO
	SRC P7
	LD P1_HI
	WRM

	BBL 0
	
;;;----------------------------------------------------------------------------
;;; LD_P1_REG8P7
;;; P1 = REG8(P7)
;;;----------------------------------------------------------------------------
LD_P1_REG8P7:
	SRC P7
	RDM
	XCH P1_LO

	INC P7_LO		; P7_LO++
	SRC P7
	RDM
	XCH P1_HI
	BBL 0

;;;----------------------------------------------------------------------------
;;; LD_P1_REG8P0
;;; P1 = REG8(P0)
;;;----------------------------------------------------------------------------
LD_P1_REG8P0:
	LD_P7_P0
	JUN LD_P1_REG8P7

;;;----------------------------------------------------------------------------
;;; LD_P1_REG8P1
;;; P1 = REG8(P1)
;;;----------------------------------------------------------------------------
LD_P1_REG8P1:
	LD_P7_P1
	JUN LD_P1_REG8P7

;;;----------------------------------------------------------------------------
;;; LD_P1_REG8P2
;;; P1 = REG8(P2)
;;;----------------------------------------------------------------------------
LD_P1_REG8P2:
	LD_P7_P2
	JUN LD_P1_REG8P7

;;;----------------------------------------------------------------------------
;;; LD_P1_REG8P3
;;; P1 = REG8(P3)
;;;----------------------------------------------------------------------------
LD_P1_REG8P3:
	LD_P7_P3
	JUN LD_P1_REG8P7

;;;----------------------------------------------------------------------------
;;; PRINTHEX_REG16P1
;;; PRINT REG16(P1)
;;; destroy: P6, P7
;;;----------------------------------------------------------------------------
PRINTHEX_REG16P1:
	JMS PUSH_P0
	LD_P0_P3
	JMS PUSH_P0
	JMS PUSH_P1
	JMS PUSH_P2
	
	JMS LD_P2P3_REG16P1
	LD R4
	JMS PRINT_ACC		; print bit.FEDC
	LD R5
	JMS PRINT_ACC		; print bit.BA98
	LD R6
	JMS PRINT_ACC		; print bit.7654
	LD R7
	JMS PRINT_ACC		; print bit.3210

	JMS POP_P2
	JMS POP_P1
	JMS POP_P0
	LD_P3_P0
	JMS POP_P0
	BBL 0

;;;----------------------------------------------------------------------------
;;; LD_REG16P6_REG16P7
;;; REG16(P6) = REG16(P7)
;;; destroy: P6, P7, CNT_J
;;;----------------------------------------------------------------------------
LD_REG16P6_REG16P7:
	LDM loop(4)
	XCH CNT_J
LDREG16P6P7_LOOP:
	SRC P7
	RDM
	SRC P6
	WRM
	INC P7_LO
	INC P6_LO
	ISZ CNT_J, LDREG16P6P7_LOOP
	BBL 0

;;;----------------------------------------------------------------------------
;;; LD_P2P3_REG16P1
;;; P2(R4R5) = REG16(P1).bitFEDCBA98
;;; P3(R6R7) = REG16(P1).bit76543210
;;; destroy: P7
;;;----------------------------------------------------------------------------
LD_P2P3_REG16P1:
	LD_P7_P1
	SRC P7
	RDM
	XCH P3_LO		; R7 = REG16(P1).bit3210

	INC P7_LO
	SRC P7
	RDM
	XCH P3_HI		; R6 = REG16(P1).bit7654
	
	INC P7_LO
	SRC P7
	RDM
	XCH P2_LO		; R5 = REG16(P1).bitBA98

	INC P7_LO
	SRC P7
	RDM
	XCH P2_HI		; R4 = REG16(P1).bitFEDC

	BBL 0

;;;----------------------------------------------------------------------------
;;; INC_REG16P0
;;; REG16(P0) = REG16(P0)+1
;;; destroy: P7(R14, R15)
;;;----------------------------------------------------------------------------
INC_REG16P0:
	LD R1
	XCH R15			; save R1 to R15

	LDM loop(4)
	XCH R14			; R14 = 12, 13, 14, 15
REG16_INC_LOOP:
	SRC P0
	RDM
	IAC 
	WRM
	JCN NZ, REG16_INC_EXIT
	INC R1
	ISZ R14, REG16_INC_LOOP

REG16_INC_EXIT:
	LD R15
	XCH R1			; restore R1
	BBL 0

;;;----------------------------------------------------------------------------
;;; DEC_REG16P0
;;; REG16(P0) = REG16(P0) - 1
;;; destroy: P7(R14, R15)
;;;----------------------------------------------------------------------------
DEC_REG16P0:
	LD R1
	XCH R15			; save R1 to R15

	LDM loop(4)
	XCH R14			; R14 = 12, 13, 14, 15
	CLC
REG16_DEC_LOOP:
	SRC P0
	RDM
	DAC
	WRM
	JCN C, REG16_DEC_EXIT	; CY=1 if no borrow
	INC R1
	ISZ R14, REG16_DEC_LOOP
REG16_DEC_EXIT:
	LD R15
	XCH R1			; restore R1
	BBL 0

;;;----------------------------------------------------------------------------
;;; CMP_REG16P0_REG16P1
;;; execute REG16(P0) - REG16(P1) and generate flag
;;; output: ACC=1, CY=0 if REG16(P0) <	REG16(P1)
;;;	    ACC=0, CY=1 if REG16(P0) == REG16(P1)
;;;	    ACC=1, CY=1 if REG16(P0) >	REG16(P1)
;;; destroy: P6, P7, R5
;;;----------------------------------------------------------------------------
CMP_REG16P0_REG16P1:
	LD R1
	XCH R15			; save R1 to R15
	LD R3
	XCH R13			; save R3 to R13
	CLB
	XCH R12			; R12 = 0
	LDM loop(4)
	XCH R14			; R14=12, 13, 14, 15
	STC
REG16_CMP_LOOP:
	CMC
	SRC P0
	RDM
	SRC P1
	SBM
	INC R1
	INC R3
	XCH R11			; save ACC to R11 (exit with MSB)
	LD R11
	JCN Z, REG16_CMP_NEXT
	LDM 1
	XCH R12			; set flag for REG(P0) != REG(P1)
REG16_CMP_NEXT:
	ISZ R14, REG16_CMP_LOOP
	LD R11
	RAL
	CMC			; CY=~MSB

	LD R15
	XCH R1			; restore R1
	LD R13
	XCH R3			; restore R3

	LD R12
	JCN Z, REG16_CMP_EXIT0
	BBL 1
REG16_CMP_EXIT0:
	BBL 0

;;;----------------------------------------------------------------------------
;;; ADD_REG16P0_REG16P1
;;; REG16(P0) = REG16(P0) + REG16(P1)
;;; destroy: P6, P7
;;;----------------------------------------------------------------------------
ADD_REG16P0_REG16P1:
	LD R1
	XCH R15			; save R1 to R15
	LD R3
	XCH R13			; save R3 to R13

	LDM loop(4)
	XCH R14
	CLC
REG16_ADD_LOOP:
	SRC P1
	RDM
	SRC P0
	ADM
	WRM
	INC R1
	INC R3
	ISZ R14, REG16_ADD_LOOP

	LD R15
	XCH R1			; restore R1
	LD R13
	XCH R3			; restore R3
	BBL 0

;;;----------------------------------------------------------------------------
;;; GETHEX_REG16P1_PM16REG16P0_INCREMENT
;;; Get a hexadecimal number from the string PM16REG16P0
;;; and increment the pointer
;;; ACC=0 get number succeed
;;; ACC=1 no number, P1=first chalacter
;;; destroy: P6, P7, P2, P3
;;;----------------------------------------------------------------------------
GETHEX_REG16P1_PM16REG16P0_INCREMENT:
	JMS PUSH_P1
	JMS LD_P1_PM16REG16P0_INCREMENT	; P1 = PM12(REG16(P0)++)
	JMS ISHEX_P1
	JCN ZN, GETHEX_START
	;; the first character is not a number
	JMS POP_P1
	BBL 1
GETHEX_START:
	FIM P2, 00H
	FIM P3, 00H
GETHEX_LOOP:
	JMS CTOI_P1
	JMS MUL16_P2P3		; R4R5R6R7 *= 16
	LD P1_LO
	XCH P3_LO		; P3_LO=P1_LO
	JMS LD_P1_PM16REG16P0_INCREMENT	; P1 = PM12(REG16(P0)++)
	JMS ISHEX_P1
	JCN Z, GETHEX_EXIT	; not a hex number then exit
	JUN GETHEX_LOOP
GETHEX_EXIT:
	JMS POP_P1
	JUN LD_REG16P1_P2P3
;;;	BBL 0

;;;----------------------------------------------------------------------------
;;; EMULATE_OUT_P1
;;; Emulate OUT instruction
;;;----------------------------------------------------------------------------
EMULATE_OUT_P1:
	FIM P7, EMU_UARTRD
	JMS CMP_P1P7
	JCN ZN, EMU_OUT_P1_L1
	JUN EMU_OUT_UARTRD
EMU_OUT_P1_L1:
	FIM P7, EMU_UARTRC
	JMS CMP_P1P7
	JCN ZN, EMU_OUT_P1_L2
	JUN EMU_OUT_UARTRC
EMU_OUT_P1_L2:
	BBL 0

EMU_OUT_UARTRD:
	FIM P1, REG8_A
	JMS LD_P1_REG8P1
	JUN PUTCHAR_P1
;;;	BBL 0
EMU_OUT_UARTRC:			; do nothing
	BBL 0
	
;;;----------------------------------------------------------------------------
;;; EMULATE_IN_P1
;;; Emulate IN instruction
;;;----------------------------------------------------------------------------
EMULATE_IN_P1:
	FIM P7, EMU_UARTRD
	JMS CMP_P1P7
	JCN ZN, EMU_IN_P1_L1
	JUN EMU_IN_UARTRD
EMU_IN_P1_L1:
	FIM P7, EMU_UARTRC
	JMS CMP_P1P7
	JCN ZN, EMU_IN_P1_L2
	JUN EMU_IN_UARTRC
EMU_IN_P1_L2:
	BBL 0

EMU_IN_UARTRD:
	JMS GETCHAR_P1
	FIM P7, 1BH		; ESC
	JMS CMP_P1P7
	JCN Z, EMU_IN_EXIT
	
	FIM P0, REG8_A
	JUN LD_REG8P0_P1
;;;	BBL 0

EMU_IN_UARTRC:
	FIM P0, REG8_A
	FIM P1, EMU_IN_UARTRC_VALUE
	JUN LD_REG8P0_P1
;;;	BBL 0

EMU_IN_EXIT:
	JMS PRINT_CRLF
	JMS EMU_PRINT_REGISTERS
	JUN CMD_LOOP
	
;;;----------------------------------------------------------------------------
;;; EMU_PRINT_REGISTERS
;;;----------------------------------------------------------------------------
EMU_PRINT_REGISTERS:
	FIM P0, lo(STR_EMU_REG)
	JMS PRINTSTR_P0

	FIM P1, REG8_A
	JMS LD_P1_REG8P1
	JMS PRINTHEX_P1
	JMS PRINT_SPC

	JMS GETFLAG_S
	JMS PRINT_ACC
	JMS GETFLAG_Z
	JMS PRINT_ACC
	JMS GETFLAG_C
	JMS PRINT_ACC
	JMS PRINT_SPC

	FIM P1, REG16_BC
	JMS PRINTHEX_REG16P1
	JMS PRINT_SPC

	FIM P1, REG16_DE
	JMS PRINTHEX_REG16P1
	JMS PRINT_SPC

	FIM P1, REG16_HL
	JMS PRINTHEX_REG16P1
	JMS PRINT_SPC

	FIM P1, REG16_SP
	JMS PRINTHEX_REG16P1
	JMS PRINT_SPC

	FIM P1, REG16_PC
	JMS PRINTHEX_REG16P1
	JMS PRINT_SPC

	FIM P0, REG16_ADDR
	FIM P1, REG16_PC
	JMS LD_REG16P0_REG16P1
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS PRINTHEX_P1
	JMS PRINT_SPC

	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS PRINTHEX_P1
	JMS PRINT_SPC

	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS PRINTHEX_P1
	JMS PRINT_SPC

	FIM P0, REG16_BC
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS DEC_REG16P0
	JMS PRINTHEX_P1
	JMS PRINT_SPC
	
	FIM P0, REG16_DE
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS DEC_REG16P0
	JMS PRINTHEX_P1
	JMS PRINT_SPC

	FIM P0, REG16_HL
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS DEC_REG16P0
	JMS PRINTHEX_P1
	JMS PRINT_SPC

	FIM P0, REG16_SP
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS PRINTHEX_P1
	JMS PRINT_SPC
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS PRINTHEX_P1
;;; 	JMS PRINT_SPC

	JMS DEC_REG16P0
	JMS DEC_REG16P0
	
	JUN PRINT_CRLF
;;;	BBL 0


	
;;;---------------------------------------------------------------------------
;;; JIN_P2_CODE_80BF
;;; Jump table for CODE 80H to BFH
;;; P2=0F0H + CODE.bit(543)0
;;;---------------------------------------------------------------------------
	org 09EFH
JIN_P2_CODE_80BF:
	JIN P2
	org 09F0H
	JUN ADI_P1		; 9F0: 80H<=87H
	JUN ACI_P1		; 9F2: 88H<=8FH
	JUN SUI_P1		; 9F4: 90H<=97H
	JUN SBI_P1		; 9F6: 98H<=9FH
	JUN ANI_P1		; 9F8: A0H<=A7H
	JUN XRI_P1		; 9FA: A8H<=AFH
	JUN ORI_P1		; 9FC: B0H<=B7H
	JUN CPI_P1		; 9FE: B8H<=BFH
;;;---------------------------------------------------------------------------
;;; Jump table for CODE 01H-3FH, C0H-FFH
;;;---------------------------------------------------------------------------
	org 0A00H
JIN_P1_CODE_013F_C0FF:
	JIN P1
	NOP			; do not delete this NOP
	JUN CODE_01H
	JUN CODE_02H
	JUN CODE_03H
	JUN CODE_04H
	JUN CODE_05H
	JUN CODE_06H
	JUN CODE_07H
	JUN CODE_08H
	JUN CODE_09H
	JUN CODE_0AH
	JUN CODE_0BH
	JUN CODE_0CH
	JUN CODE_0DH
	JUN CODE_0EH
	JUN CODE_0FH
	JUN CODE_10H
	JUN CODE_11H
	JUN CODE_12H
	JUN CODE_13H
	JUN CODE_14H
	JUN CODE_15H
	JUN CODE_16H
	JUN CODE_17H
	JUN CODE_18H
	JUN CODE_19H
	JUN CODE_1AH
	JUN CODE_1BH
	JUN CODE_1CH
	JUN CODE_1DH
	JUN CODE_1EH
	JUN CODE_1FH
	JUN CODE_20H
	JUN CODE_21H
	JUN CODE_22H
	JUN CODE_23H
	JUN CODE_24H
	JUN CODE_25H
	JUN CODE_26H
	JUN CODE_27H
	JUN CODE_28H
	JUN CODE_29H
	JUN CODE_2AH
	JUN CODE_2BH
	JUN CODE_2CH
	JUN CODE_2DH
	JUN CODE_2EH
	JUN CODE_2FH
	JUN CODE_30H
	JUN CODE_31H
	JUN CODE_32H
	JUN CODE_33H
	JUN CODE_34H
	JUN CODE_35H
	JUN CODE_36H
	JUN CODE_37H
	JUN CODE_38H
	JUN CODE_39H
	JUN CODE_3AH
	JUN CODE_3BH
	JUN CODE_3CH
	JUN CODE_3DH
	JUN CODE_3EH
	JUN CODE_3FH
	JUN CODE_C0H
	JUN CODE_C1H
	JUN CODE_C2H
	JUN CODE_C3H
	JUN CODE_C4H
	JUN CODE_C5H
	JUN CODE_C6H
	JUN CODE_C7H
	JUN CODE_C8H
	JUN CODE_C9H
	JUN CODE_CAH
	JUN CODE_CBH
	JUN CODE_CCH
	JUN CODE_CDH
	JUN CODE_CEH
	JUN CODE_CFH
	JUN CODE_D0H
	JUN CODE_D1H
	JUN CODE_D2H
	JUN CODE_D3H
	JUN CODE_D4H
	JUN CODE_D5H
	JUN CODE_D6H
	JUN CODE_D7H
	JUN CODE_D8H
	JUN CODE_D9H
	JUN CODE_DAH
	JUN CODE_DBH
	JUN CODE_DCH
	JUN CODE_DDH
	JUN CODE_DEH
	JUN CODE_DFH
	JUN CODE_E0H
	JUN CODE_E1H
	JUN CODE_E2H
	JUN CODE_E3H
	JUN CODE_E4H
	JUN CODE_E5H
	JUN CODE_E6H
	JUN CODE_E7H
	JUN CODE_E8H
	JUN CODE_E9H
	JUN CODE_EAH
	JUN CODE_EBH
	JUN CODE_ECH
	JUN CODE_EDH
	JUN CODE_EEH
	JUN CODE_EFH
	JUN CODE_F0H
	JUN CODE_F1H
	JUN CODE_F2H
	JUN CODE_F3H
	JUN CODE_F4H
	JUN CODE_F5H
	JUN CODE_F6H
	JUN CODE_F7H
	JUN CODE_F8H
	JUN CODE_F9H
	JUN CODE_FAH
	JUN CODE_FBH
	JUN CODE_FCH
	JUN CODE_FDH
	JUN CODE_FEH
	JUN CODE_FFH

	org 0B00H
;;;----------------------------------------------------------------------------
;;; PUSH_P0, P1, P2
;;; POP_P0, P1, P2
;;; Push and Pop an 8bit register pair
;;; Stack area is a 16x4bit ring buffer using one register in data RAM.
;;; Stack pointer is register SP (configured in macors.inc)
;;; destroy P7, P6
;;;----------------------------------------------------------------------------

PUSHP	macro ThisR0, ThisR1
	LD SP_LO
	DAC
	XCH SP_LO		; --sp.3210
	JCN C, PUSH_NOBORROW_ThisR0_ThisR1
	LD SP_HI
	DAC
	XCH SP_HI		; --sp.7654
PUSH_NOBORROW_ThisR0_ThisR1:
	SRC SP
	LD ThisR0
	WRM			; (sp)=R0

	LD SP_LO
	DAC
	XCH SP_LO		; --sp.3210
;;;  Borrow check is omitted because SP must be even here
;;;	JCN C, PUSH_NOBORROW2_ThisR0_ThisR1
;;;	LD SP_HI
;;;	DAC
;;;	XCH SP_HI		; --sp.7654
;;; PUSH_NOBORROW2_ThisR0_ThisR1:
	SRC SP
	LD ThisR1
	WRM			; (sp)=R1

	BBL 0
	endm
;;;----------------------------------------------------------------------------
POPP	macro ThisR0, ThisR1
	SRC SP
	RDM
	XCH ThisR1		; ThisR1=(sp)
	INC SP_LO		; sp.3210++
;;; Carry check is omitted because SP must be odd here
	SRC SP
	RDM
	XCH ThisR0		; ThisR0=(sp)
	INC SP_LO		; sp.3210++
	LD SP_LO
	JCN ZN, POP_NOCARRY_ThisR0_ThisR1
	INC SP_HI		; sp.7654++
POP_NOCARRY_ThisR0_ThisR1:
	BBL 0
	endm
;;;----------------------------------------------------------------------------
;;;----------------------------------------------------------------------------
;;; Generate real codes from macros
;;;----------------------------------------------------------------------------
PUSH_P0: PUSHP	R0, R1
PUSH_P1: PUSHP	R2, R3
PUSH_P2: PUSHP	R4, R5
POP_P0: POPP R0, R1
POP_P1: POPP R2, R3
POP_P2: POPP R4, R5

;;;	org 0B00H
;;;---------------------------------------------------------------------------
;;; PM16
;;; Logical Program Memory with 16 bit address space
;;; 
;;; Phisical PM is 256byte x 16 x 16 bank memory
;;; PM16 is a logical memory space (0000H to FFFFH) mapped to Physical PM.
;;; The PM read routine PM_READ_P0_P1 occupies 2 bytes in each bank.
;;; If the PM_READ_P0_P1 is located at 0FFE-0FFF,
;;; it occupies 0FE00-0FFFF logical memory, and 0000H-0FDFFH is user's space.
;;; If the PM_READ_P0_P1 is located at 0F7E-0F7F,
;;; it occupies 07E00-07FFF logical memory,
;;; and 0000H-7DFF and 8000H-FFFFH are user's space.
;;; 
;;;    PM12(BA98.7654.3210)
;;;   -> PM(3210.BA98.7654) BANK=3210, ADD=BA98.7654
;;; 
;;;    PM16(FEDC.BA98.7654.3210)
;;;   -> PM(7654.3210.FEDC.BA98) BANK1=7654, BANK0=3210 ADD=FEDC.BA98
;;;   (for debug with 256 x 16bank)
;;;   -> PM(7654.3210.FEDC.BA98) BANK1=FEDC, BANK0=3210 ADD=BA98.7654
;;;---------------------------------------------------------------------------
;;;---------------------------------------------------------------------------
;;; LD_P1_PM16REG16P0_INCREMENT
;;; P1 = PM16(REG(P0)++)
;;; destroy: P6, P7
;;;---------------------------------------------------------------------------
LD_P1_PM16REG16P0_INCREMENT:
	LD_P6_P0		; P6 = P0
	SRC P6
	RDM			; ACC=REG(P0).bit3210

	FIM P7, CHIP_PMSELECT0
	SRC P7
	WMP			; set bank_low to REG(P0).bit3210

	INC P6_LO
	SRC P6
	RDM
	XCH P0_LO		; P0_LO=REG(P0).bit7654
	
	INC P6_LO
	SRC P6
	RDM
	XCH P0_HI		; P0_HI=REG(P0).bitBA98

	INC P6_LO
	SRC P6
	RDM

	FIM P7, CHIP_PMSELECT1
	SRC P7
	WMP			; set bank_high to REG(P0).bitFEDC

	JMS PM_READ_P0_P1	; P1 = PM(REG(P0))

	LD P6_HI			; restore P0
	XCH P0_HI
	LD P6_LO
	DAC
	DAC
	DAC
	XCH P0_LO
	JUN INC_REG16P0
;;;	BBL 0

;;;---------------------------------------------------------------------------
;;; LD_PM16REG16P0_P1
;;; PM16(REG(P0)) = P1
;;; 
;;; destroy: P7
;;;---------------------------------------------------------------------------
LD_PM16REG16P0_P1:
	SRC P0
	RDM			; bit3210 of REG(P0)
	FIM P7, CHIP_PMSELECT0
	SRC P7
	WMP			; set bank to REG(P0).bit3210


	INC P0_LO
	SRC P0
	RDM			; bit7654 of REG(P0)
	XCH P6_LO		; R13 = REG(P0).bit7654

	INC P0_LO
	SRC P0
	RDM
	XCH P6_HI		; R12 = REG(P0).bitBA98
	
	INC P0_LO
	SRC P0
	RDM

	FIM P7, CHIP_PMSELECT1
	SRC P7
	WMP			; set bank_high to REG(P0).bitFEDC

	SRC P6
	LD P1_LO
	WPM
	LD P1_HI
	WPM
	
	LD R1			; restore P0
	DAC
	DAC
	DAC
	XCH R1
	BBL 0

;;;----------------------------------------------------------------------------
;;; Subroutines for program memory operation
;;;----------------------------------------------------------------------------
;;;---------------------------------------------------------------------------
;;; PM_WRITE_P0_P1
;;; Write to program memory located at Page 15 (0F00H-0FFFH)
;;; (0F00H+P0) = P1
;;; input: P0, P1
;;; output: none
;;;---------------------------------------------------------------------------
PM_WRITE_P0_P1:
	SRC P0
	LD P1_LO
	WPM			; write lower 4bit
	LD P1_HI
	WPM			; write higher 4bit
	BBL 0

;;;---------------------------------------------------------------------------
;;; PM_WRITE_P6_P7
;;; Write to program memory located at Page 15 (0F00H-0FFFH)
;;; (0F00H+P6) = P7
;;; input: P6, P7
;;; output: none
;;;---------------------------------------------------------------------------
PM_WRITE_P6_P7:
	SRC P6
	LD P7_LO
	WPM			; write lower 4bit
	LD P7_HI
	WPM			; write higher 4bit
	BBL 0

;;;---------------------------------------------------------------------------
;;; PM_INIT_BANK
;;; initialization for program memory (RAM)
;;; Write a subroutne code for reading memory
;;; destroy: P6, P7
;;;---------------------------------------------------------------------------
PM_INIT_BANK:	
	FIM P6, lo(PM_READ_P0_P1)
	FIM P7, 32H		; FIN P1
	JMS PM_WRITE_P6_P7
	INC P6_LO
	FIM P7, 0C0H		; BBL 0
	JMS PM_WRITE_P6_P7
	BBL 0

;;;---------------------------------------------------------------------------
;;; PM_SELECTPMB_P1
;;; Write ACC to RAM port (CHIP_PMSELECT0 and CHIPSELECT1)
;;; destroy: P7
;;;---------------------------------------------------------------------------
PM_SELECTPMB_P1:
	FIM P7, CHIP_PMSELECT0
	SRC P7
	LD P1_LO
	WMP

	FIM P7, CHIP_PMSELECT1
	SRC P7
	LD P1_HI
	WMP
	BBL 0
;;;----------------------------------------------------------------------------
;;; GETLINE_PM16REG16P0
;;; Get line from serial input and store to PM16(REG(P0))
;;; The value of REG(P0) does not change
;;;----------------------------------------------------------------------------
GETLINE_PM16REG16P0:
	JMS PUSH_P0
	JMS PUSH_P1

	FIM P1, REG16_MON_TMP
	JMS LD_REG16P1_REG16P0	; REG(TMP)=REG(INDEX)

GETLINE_LOOP:
	JMS GETCHAR_P1		; P1 = getchar()
	JCN ZN, GETLINE_LOOP	; ACC!=0 (stop bit error)
	
	JMS ISCRLF_P1
	JCN Z, GETLINE_L1
	JMS PRINT_CR
	JMS PRINT_LF
	JUN GETLINE_EXIT
GETLINE_L1:
	FIM P7, 08H		; backspace
	JMS CMP_P1P7
	JCN Z, GETLINE_BS
	JUN GETLINE_INSERTCHAR
GETLINE_BS:
	FIM P1, REG16_MON_TMP
	JMS CMP_REG16P0_REG16P1
	JCN ZN, GETLINE_DO_BS	; do BS if REG(P0)!=REG(TMP)
	JUN GETLINE_LOOP	; ignore BS
GETLINE_DO_BS:			; delete a character on the cursor
	JMS DEC_REG16P0		; REG(P0)--
GETLINE_L1_NEXT:		; delete a character on the cursor
	FIM P1, 08H
	JMS PUTCHAR_P1		; put backspace
	JMS PRINT_SPC		; put ' '
	JMS PUTCHAR_P1		; put backspace

	JUN GETLINE_LOOP
GETLINE_INSERTCHAR:
	JMS PUTCHAR_P1
	JMS LD_PM16REG16P0_P1	; PM(REG(P0)) = P1
	JMS INC_REG16P0		; REG(P0)++
	
	JUN GETLINE_LOOP
GETLINE_EXIT:
	FIM P1, 00H
	JMS LD_PM16REG16P0_P1	; write NULL on the end of line buffer

	FIM P1, REG16_MON_TMP
	JMS LD_REG16P0_REG16P1	; restore REG(INDEX)
	JMS POP_P1		; restore P1
	JUN POP_P0		; restore P0
;;;	BBL 0

;;;----------------------------------------------------------------------------
;;; PRINTSTR_PM16REG16P0 (Delimiter is 0x00)
;;; Print a string 
;;; put a string on PM12(REG16(P0)) to serial output until the P1 or 00H
;;; REG(INDEX) is incremented to
;;;	the end of the string
;;; 
;;; destroy: P6, P7
;;;----------------------------------------------------------------------------
PRINTSTR_PM16REG16P0:
	JMS PUSH_P1
PRINTSTR_LOOP:
	JMS LD_P1_PM16REG16P0_INCREMENT
	JMS ISZEROORNOT_P1
	JCN Z, PRINTSTR_EXIT
	JMS PUTCHAR_P1
	JUN PRINTSTR_LOOP
PRINTSTR_EXIT:
	JUN POP_P1
;;;	BBL 0

;;;----------------------------------------------------------------------------
;;; GETHEXBYTE_P1_PM16REG16P0_INCREMENT
;;; Get a hexadecimal 1 byte from the string PM16REG16P0
;;; and increment the pointer
;;; output: P1
;;; ACC=0 get number success
;;; ACC=1 no number, P1=first character
;;; destroy: P6, P7
;;;----------------------------------------------------------------------------
GETHEXBYTE_P1_PM16REG16P0_INCREMENT:
	JMS LD_P1_PM16REG16P0_INCREMENT	; P1 = PM12(REG16(P0)++)
	JMS ISHEX_P1
	JCN ZN, GETHEXBYTE_L1
	BBL 1			; no hex number and exit
GETHEXBYTE_L1:	
	JMS PUSH_P2
	JMS CTOI_P1
	LD  P1_LO
	XCH P2_HI			; save for upper digit
	JMS LD_P1_PM16REG16P0_INCREMENT	; P1 = PM(REG16(P0)++)
	JMS ISHEX_P1
	JCN Z, GETHEXZBYTE_1DIGIT_EXIT
	JMS CTOI_P1
	LD P2_HI
	XCH P1_HI
	JUN POP_P2
;;;	BBL 0
GETHEXZBYTE_1DIGIT_EXIT:
	CLB
	XCH P1_HI
	LD P2_HI
	XCH P1_LO
	JUN POP_P2
;;;	BBL 0
	
;;;----------------------------------------------------------------------------
;;; I/O and some basic routines located in Page 0D00H
;;;----------------------------------------------------------------------------
;;;	org 0C00H
;;;---------------------------------------------------------------------------
;;; Software UART Routine
;;; GETCHAR_P1 and PUTCHAR_P1
;;; defined in separated file
;;;---------------------------------------------------------------------------
;;; supported baudrates are 4800bps or 9600bps
;; BAUDRATE equ 4800	; 4800 bps, 8 data bits, no parity, 1 stop bit
BAUDRATE equ 9600   ; 9600 bps, 8 data bits, no parity, 1 stop bit

	switch BAUDRATE
	case 4800
	include "4800bps.inc"
	case 9600
	include "9600bps.inc"
	endcase

;;;---------------------------------------------------------------------------
;;; INIT_SERIAL
;;; Initialize serial port
;;;---------------------------------------------------------------------------
INIT_SERIAL:
	if (BANK_SERIAL != BANK_DEFAULT)
	LDM BANK_SERIAL	    ; bank of output port
	DCL		    ; set port bank
	endif
	
	FIM P7, CHIP_SERIAL ; chip# of output port
	SRC P7		    ; set port address
	LDM 1
	WMP		    ; set serial port to 1 (TTL->H)

	if (BANK_SERIAL != BANK_DEFAULT)
	LDM BANK_DEFAULT    
	DCL		    ; restore bank to default
	endif
	
	BBL 0

;;;----------------------------------------------------------------------------
;;; PRINTHEX_P1
;;; Print 8bit register pair in HEX format
;;; PRINT HEX
;;; destroy: P6, P7
;;;----------------------------------------------------------------------------
PRINTHEX_P1:
	JMS PUSH_P0
	JMS PUSH_P1
	LD_P0_P1
	LD R0
	JMS PRINT_ACC		; print upper 4bit
	LD R1
	JMS PRINT_ACC		; print lower 4bit
	JMS POP_P1
	JMS POP_P0
	BBL 0

;;;---------------------------------------------------------------------------
;;; PRINT_SPC
;;; print " "
;;; destroy: ACC
;;; This routine consumes 2 PC stack
;;;---------------------------------------------------------------------------
PRINT_SPC:
	JMS PUSH_P1
	FIM P1, ' '
	JMS PUTCHAR_P1
	JUN POP_P1
;;;	BBL 0

;;;---------------------------------------------------------------------------
;;; PRINT_CRLF
;;; print "\r\n"
;;; destroy: ACC
;;; This routine consumes 2 PC stack
;;;---------------------------------------------------------------------------
PRINT_CRLF:
	JMS PUSH_P1
	FIM P1, '\r'
	JMS PUTCHAR_P1
	FIM P1, '\n'
	JMS PUTCHAR_P1
	JUN POP_P1
;;;	BBL 0

;;;---------------------------------------------------------------------------
;;; PRINT_CR
;;; print "\r"
;;; destroy: P1, ACC
;;; This routine consumes 1 PC stack
;;;---------------------------------------------------------------------------
PRINT_CR:
	FIM P1, '\r'
	JUN PUTCHAR_P1

;;;---------------------------------------------------------------------------
;;; PRINT_LF
;;; print "\n"
;;; destroy: P1, ACC
;;; This routine consumes 1 PC stack
;;;---------------------------------------------------------------------------
PRINT_LF:
	FIM P1, '\n'
	JUN PUTCHAR_P1

;;;---------------------------------------------------------------------------
;;; PRINT_ACC
;;; print contents of ACC('0'...'F') as a character
;;; destroy: P1, P6, P7, ACC
;;; This routine destroys P1, instead it consumes only 1 PC stack
;;;---------------------------------------------------------------------------
PRINT_ACC:
	FIM P1, '0'
	CLC			; clear carry
	DAA			; ACC=ACC+6 if ACC>9 and set carry
	JCN CN, PRINTACC_L1
	INC P1_HI
	IAC
PRINTACC_L1:	
	XCH P1_LO		; P1_LO<-ACC
	JUN PUTCHAR_P1		; not JMS but JUN (Jump to PUTCHAR and return)

;;;----------------------------------------------------------------------------
;;; INC_P1
;;; P1=P1+1
;;;----------------------------------------------------------------------------
INC_P1:	
	INC P1_LO
	LD P1_LO
	JCN ZN, INC_P1_EXIT
	INC P1_HI
INC_P1_EXIT:	
	BBL 0

;;;----------------------------------------------------------------------------
;;; DEC_P1
;;; P1=P1-1
;;;----------------------------------------------------------------------------
DEC_P1:	
	LD P1_LO
	DAC
	XCH P1_LO
	JCN C, DEC_P1_EXIT	; no borrow then exit
	LD P1_HI		; decrement upper 4bit
	DAC
	XCH P1_HI
DEC_P1_EXIT:	
	BBL 0
	
;;;----------------------------------------------------------------------------
;;; ISALPHA_P1
;;; check P1 is an alphabet as a ascii character
;;; return: ACC=0 if P1 is not an alphabet
;;;	    ACC=1 if P1 is an alphabet
;;; destroy: P7
;;;----------------------------------------------------------------------------
ISALPHA_P1:
ISALPHA_L1:
	FIM P7, 'A'
	JMS CMP_P1P7
	JCN C, ISALPHA_L10
	BBL 0			; P1<'A'
ISALPHA_L10:
	FIM P7, 'Z'+1
	JMS CMP_P1P7
	JCN C,	ISALPHA_L2	; P1>='Z'+1 then jump to next chance
	BBL 1			; 'A'<=P1<='Z'
ISALPHA_L2:
	FIM P7, 'a'
	JMS CMP_P1P7
	JCN C, ISALPHA_L20
	BBL 0			; P1<'a'
ISALPHA_L20:	
	FIM P7, 'z'+1
	JMS CMP_P1P7
	JCN C, ISALPHA_FALSE	; P1>='z'+1
	BBL 1			; 'a'<=P1<= 'z'
ISALPHA_FALSE:
	BBL 0

;;;---------------------------------------------------------------------------
;;; CTOI_P1
;;; convert character ('0'...'f') to value 0000 ... 1111
;;; no error check
;;; input: P1(R2R3)
;;; output: P1_LO, (P1_HI=0)
;;;---------------------------------------------------------------------------
CTOI_P1:
	CLB
	LDM 3
	SUB P1_HI
	JCN Z, CTOI_09	; check upper 4bit
	CLB
	LDM 9
	ADD P1_LO
	XCH P1_LO		; P1_HI = P1_LO+ 9 for 'a-fA-F'
CTOI_09:
	CLB
	XCH R2			; R2 = 0
	BBL 0
	
;;;----------------------------------------------------------------------------
;;; ISHEX_P1
;;; check P1 is a hex digit letter ('0' to '9') or ('a' to 'f') or ('A' to 'F')
;;; return: ACC=0 if P1 is not a hex digit letter
;;;	    ACC=1 if P1 is a hex digit letter
;;; destroy: P7
;;;----------------------------------------------------------------------------
ISHEX_P1:
	FIM P7, '0'
	JMS CMP_P1P7
	JCN C, ISHEX_L00
	BBL 0			; P1<'0'
ISHEX_L00:	
	FIM P7, '9'+1
	JMS CMP_P1P7
	JCN C,	ISHEX_L1	; P1>='9'+1 then jump to next chance
	BBL 1			; '0'<=P1<='9'
ISHEX_L1:
	FIM P7, 'A'
	JMS CMP_P1P7
	JCN C, ISHEX_L10
	BBL 0			; P1<'A'
ISHEX_L10:
	FIM P7, 'F'+1
	JMS CMP_P1P7
	JCN C,	ISHEX_L2	; P1>='F'+1 then jump to next chance
	BBL 1			; 'A'<=P1<='F'
ISHEX_L2:
	FIM P7, 'a'
	JMS CMP_P1P7
	JCN C, ISHEX_L20
	BBL 0			; P1<'a'
ISHEX_L20:	
	FIM P7, 'f'+1
	JMS CMP_P1P7
	JCN C, ISHEX_FALSE	; P1>='f'+1
	BBL 1			; 'a'<=P1<= 'f'
ISHEX_FALSE:
	BBL 0

;;;---------------------------------------------------------------------------
;;; CMP_P1P7
;;; compare P1(R2R3) and P7(R14R15)
;;; input: P1, P7
;;; output: ACC=1,CY=0 if P1<P7
;;;	    ACC=0,CY=1 if P1==P7
;;;	    ACC=1,CY=1 if P1>P7
;;; P1 - P7 (the carry bit is a complement of the borrow)
;;;---------------------------------------------------------------------------
CMP_P1P7:
	CLB
	LD R2			
	SUB R14			;R2-R14
	JCN Z, CMP17_L1		; jump if R2==R14
	BBL 1			; if P1<P7 then ACC=1, CY=0
CMP17_L1:	
	CLB
	LD R3
	SUB R15			;R3-R15
	JCN Z, CMP17_EXIT01	; jump if R3==R15
	BBL 1			; if P1<P7 then ACC=1, CY=0
				; if P1>P7 then ACC=1, CY=1
CMP17_EXIT01:
	BBL 0			; P1==P7, ACC=0, CY=1
	
;;;---------------------------------------------------------------------------
 ;;; ISZEROORNOT_P1
;;; check P1 is zero or not
;;; Return 0 if P1 is 0
;;; return: ACC=0 if P1 == 0
;;;	    ACC=1 if P1 != 0
;;;---------------------------------------------------------------------------
ISZEROORNOT_P1:
	LD P1_LO
	JCN ZN, ISZEROORNOT_EXIT1
	LD P1_HI
	JCN ZN, ISZEROORNOT_EXIT1
	BBL 0
ISZEROORNOT_EXIT1:
	BBL 1

;;;---------------------------------------------------------------------------
;;; ISCRLF_P1
;;; check if P1=='\r' | P1=='\n'
;;; input: P0
;;; output: ACC=1 if P1=='\r' || P1=='\n'
;;;	    ACC=0 P1!='\r' && P1!='\n'
;;;---------------------------------------------------------------------------
ISCRLF_P1:
	LD R2
	JCN NZ, ISCRLF_EXIT0	; check upper 4bit
	CLC
	LDM '\r'
	SUB R3
	JCN Z, ISCRLF_EXIT1	; check lower 4bit
	CLC
	LDM '\n'
	SUB R3
	JCN Z, ISCRLF_EXIT1	; check lower 4bit
ISCRLF_EXIT0:
	BBL 0
ISCRLF_EXIT1:
	BBL 1

;;;---------------------------------------------------------------------------
;;; TOUPPER_P1
;;; Convert 'a' to 'z'	to 'A' to 'Z'
;;;---------------------------------------------------------------------------
TOUPPER_P1:
	JMS ISALPHA_P1
	JCN Z, TOUPPER_P1_EXIT
	LD P1_HI
	RAR
	RAR
	CLC
	RAL
	RAL
	XCH P1_HI
TOUPPER_P1_EXIT:
	BBL 0

;;;---------------------------------------------------------------------------
;;; PRINT_DATARAM_P0
;;; Print one DATA RAM Register (ADDR=P0)
;;;---------------------------------------------------------------------------
PRINT_DATARAM_P0:
	LD P0_HI		; PRINT ADDDR
	JMS PRINT_ACC
	LD P0_LO
	JMS PRINT_ACC
	FIM P1, ':'
	JMS PUTCHAR_P1
CMDDD_L2:
	CLB		; PRINT data characters
	SRC P0		; set address
	RDM		; read data memory
	JMS PRINT_ACC
	ISZ P0_LO, CMDDD_L2

	FIM P1, ':'	; PRINT Status characters
	JMS PUTCHAR_P1
	SRC P0		; set address
	RD0
	XCH P1_HI
	RD1
	XCH P1_LO
	JMS PRINTHEX_P1
	SRC P0		; set address
	RD2
	XCH P1_HI
	RD3
	XCH P1_LO
	JMS PRINTHEX_P1
	JUN PRINT_CRLF
;;;	BBL 0

;;;----------------------------------------------------------------------------
;;; Print subroutine and string data located in Page E (0E00H-0EFFH)
;;; The string data sould be located in the same page as the print routine.
;;;----------------------------------------------------------------------------
	org 0E00H
;;;----------------------------------------------------------------------------
;;; PRINTSTR_P0
;;; Print a string with a delimiter 00H
;;; Input: P0 (top of the string is 0E00H+P0)
;;; Destroy: P6, P7 (by PUTCHAR)
;;;----------------------------------------------------------------------------
PRINTSTR_P0:
	JMS PUSH_P0
	JMS PUSH_P1
PRINTSTRP0_LOOP:
	FIN P1			; P1=(P0)
	LD P1_HI
	JCN ZN, PRINTSTRP0_PUT	; P1_HI!=0 then putchar
	LD P1_LO
	JCN Z, PRINTSTRP0_EXIT	; P1_HI==0 and P1_LO==0 then exit
PRINTSTRP0_PUT:
	JMS PUTCHAR_P1		; putchar(P1)
	ISZ P0_LO, PRINTSTRP0_LOOP   ; P0_LO++
	INC P0_HI
	JUN PRINTSTRP0_LOOP	; print remaining string
PRINTSTRP0_EXIT:
	JMS POP_P1
	JUN POP_P0
;;;	BBL 0
		
	
;;;----------------------------------------------------------------------------
;;; MUL16_P2P3
;;; P2P3 = P2P3*16
;;;----------------------------------------------------------------------------
MUL16_P2P3:	
	LD R5
	XCH R4			; 100'->1000'
	LD R6
	XCH R5			; 10'->100'
	LD R7
	XCH R6			; 1'->10'
	CLB
	XCH R7			; 0->1'
	BBL 0

;;;----------------------------------------------------------------------------
;;; String data
;;;----------------------------------------------------------------------------

STR_OMSG:
	data "\rIntel MCS-4 (4004) Tiny Monitor\r\n", 0
STR_VFD_INIT:		;reset VFD and set scroll mode
	data 1bH, 40H, 1fH, 02H, 0
STR_EMU_MESSAGE:
	data "\r\n8080 Emulator on 4004 Ver 1.0\r\n", 0

STR_EMU_REG:
	data "A  SZC  BC   DE   HL   SP   PC (+0 +1 +2)BC)DE)HL)SP +1)\r\n", 0
STR_EMU_HLT:
	data "\r\nHLT\r\n", 0
;;; strings for register command of 4004 monitor
;;; STR_REG0:
;;;	data "AC	SP1111\r\n", 0
;;; STR_REG1:
;;;	data "CY01234567890123\r\n", 0
;;; STR_DATAREG:
;;;	data "0123456789ABCDEF0123\r\n", 0

STR_CMDERR:
	data "?\r\n", 0 ;
STR_ERROR_UNKNOWN_MEMSPACE:
	data "?MEMSPACE\r\n", 0
STR_ERROR_LOADCOMMAND:
	data "?LOAD ERROR\r\n", 0

;;;---------------------------------------------------------------------------
;;; Subroutine for reading program memory located on page 15 (0F00H-0FFFH)
;;;---------------------------------------------------------------------------
;;; READPM_P0
;;; P1 = (P0)
;;; input: P0
;;; output: P1
;;;---------------------------------------------------------------------------
;;;	org 0F7EH
;;; PM_READ_P0_P1:
	FIN P1
	BBL 0

	end
