;;; test3.asm
;;; 
;;; ADI, ACI, SUI, SBI

	CPU	8080
START:
;;; ----------------------------------
	MVI A, 11H
	ADI 22H			;A=33H

	MVI A, 0F0H
	ADI 11H			;A=01H

	STC			;CY=1
	MVI A, 0F0H
	ADI 0FH			;A=FF,CY=0

	XRA A			;A=00,CY=0
	MVI A, 0F0H		;
	ADI 0FH			;A=FF
;;; ----------------------------------
	MVI A, 11H
	ACI 22H			;A=33H

	MVI A, 0F0H
	ACI 11H			;A=01H

	STC			;CY=1
	MVI A, 0F0H
	ACI 0FH			;A=00

	XRA A			;CY=0
	MVI A, 0F0H
	ACI 0FH			;A=FF
;;; ----------------------------------
	MVI A, 33H
	SUI 11H			;A=22H

	MVI A, 10H
	SUI 11H			;A=FFH,CY=1

	STC
	MVI A, 10H
	SUI 10H			;A=00,CY=0

	XRA A
	MVI A, 10H
	SUI 10H			;A=00,CY=0
;;; ----------------------------------
	MVI A, 33H
	SBI 11H			;A=22

	MVI A, 10H
	SBI 11H			;A=FF,CY=1

	STC
	MVI A, 10H
	SBI 10H			;A=FF,CY=1

	XRA A
	MVI A, 10H
	SBI 10H			;A=0,CY=0
;;; ----------------------------------
	LXI H, 0ABCH
	MVI M, 12H
	INX H
	MVI M, 34H

	MOV A, M		;A=34
	
	HLT

	END
	
