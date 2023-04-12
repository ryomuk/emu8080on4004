;;; test1.asm
;;; 
;;; 00H to 0BH, RLC, RRC, RAL, RAR

	CPU	8080
START:
	NOP
	MVI A, 0DAH	;A=DAH
	LXI B, 0ABCH	;B=0ABCH
	STAX B		;PM(0ABC)=DA
	HLT

	INX B		;B=0ABDH, SZC=000
	LXI B, 0000H	;B=0000H
	INX B		;B=0001H
	DCX B		;B=0000H, SZC=000
	DCX B		;B=FFFFH, SZC=000
	DCX B		;B=FFFEH
	INX B		;B=FFFFH
	INX B		;B=0000H
	INX B		;B=0001H

	MVI B, 00H	;B=00H

	INR B		;B=01H, SZC=000
	DCR B		;B=00H, SZC=010
	DCR B		;B=FFH, SZC=100
	INR B		;B=00H, SZC=010
	INR B		;B=01H, SZC=000

	STC		;       SZC=001
	CMC		;       SZC=000
	CMC		;       SZC=001
	CMC		;       SZC=000
	MVI A, 01H	;A=01H, SZC=000
	RLC		;A=02H, SZC=000
	RLC		;A=04H, SZC=000
	RLC		;A=08H, SZC=000
	RLC		;A=10H, SZC=000
	RLC		;A=20H, SZC=000
	RLC		;A=40H, SZC=000
	RLC		;A=80H, SZC=000
	RLC		;A=01H, SZC=001
	RLC		;A=02H, SZC=000

	MVI A, 80H	;A=80H, SZC=000
	RRC		;A=40H, SZC=000
	RRC		;A=20H, SZC=000
	RRC		;A=10H, SZC=000
	RRC		;A=08H, SZC=000
	RRC		;A=04H, SZC=000
	RRC		;A=02H, SZC=000
	RRC		;A=01H, SZC=000
	RRC		;A=80H, SZC=001
	RRC		;A=40H, SZC=000
	
	MVI A, 01H	;A=01H, SZC=000
	RAL		;A=02H, SZC=000
	RAL		;A=04H, SZC=000
	RAL		;A=08H, SZC=000
	RAL		;A=10H, SZC=000
	RAL		;A=20H, SZC=000
	RAL		;A=40H, SZC=000
	RAL		;A=80H, SZC=000
	RAL		;A=00H, SZC=001
	RAL		;A=01H, SZC=000
	
	MVI A, 80H	;A=80H, SZC=000
	RAR		;A=40H, SZC=000
	RAR		;A=20H, SZC=000
	RAR		;A=10H, SZC=000
	RAR		;A=08H, SZC=000
	RAR		;A=04H, SZC=000
	RAR		;A=02H, SZC=000
	RAR		;A=01H, SZC=000
	RAR		;A=00H, SZC=001
	RAR		;A=80H, SZC=000

	LXI H, 1111H	;HL=1111H
	LXI B, 2222H	;BC=2222H
	DAD B		;HL=3333H, BC=2222H, SZC=000
	LXI H, 8FFFH	;HL=8FFFH
	LXI B, 7010H	;BC=8FFFH, BC=7010H
	DAD B		;HL=000FH, SZC=001

	LXI B, 0ABCH	;B=0ABCH
	LDAX B		;A=DAH
	
	JMP START

	END