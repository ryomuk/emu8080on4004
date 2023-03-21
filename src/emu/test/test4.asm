;;; test4.asm
;;; 
;;; ADD, ADC, SUB, SBB

	CPU	8080
START:
;;; ----------------------------------
	MVI A, 11H
	MVI B, 22H
	ADD B			;A=33H

	MVI A, 0F0H
	MVI C, 11H
	ADD C			;A=01H,CY=1

	MVI A, 0F0H
	MVI D, 00FH
	ADD D			;A=FF,CY=0

	XRA A			;A=00,CY=0
	MVI A, 0F0H		;
	MVI E, 0FH
	ADD E			;A=FF
;;; ----------------------------------
	MVI A, 11H
	MVI B, 22H
	ADC B			;A=33H

	MVI A, 0F0H
	MVI C, 11H
	ADC C			;A=01H

	STC			;CY=1
	MVI A, 0F0H
	MVI D, 0FH
	ADC D			;A=00

	XRA A			;CY=0
	MVI A, 0F0H
	MVI E, 0FH
	ADC E			;A=FF
;;; ----------------------------------
	MVI A, 33H
	MVI B, 11H
	SUB B			;A=22H

	MVI A, 10H
	MVI C, 11H
	SUB C			;A=FFH,CY=1

	STC
	MVI A, 10H
	MVI D, 10H
	SUB D			;A=00,CY=0

	XRA A
	MVI A, 10H
	MVI E, 10H
	SUB E			;A=00,CY=0
;;; ----------------------------------
	MVI A, 33H
	MVI B, 11H
	SBB B			;A=22

	MVI A, 10H
	MVI C, 11H
	SBB C			;A=FF,CY=1

	STC
	MVI A, 10H
	MVI D, 10H
	SBB D			;A=FF,CY=1

	XRA A
	MVI A, 10H
	MVI E, 10H
	SBB E			;A=0,CY=0
;;; ----------------------------------
	LXI H, 0ABCH
	MVI M, 11H
	MVI A, 0FFH
	SUB M
	SUB M
	SUB M
	SUB M
	SUB M
	
	HLT

	END
	
