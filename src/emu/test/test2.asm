;;; test2.asm
;;; 
;;; MVI, MOV

	CPU	8080
START:
	MVI A, 12H
	MVI B, 34H
	MVI C, 56H
	MVI D, 78H
	MVI E, 9AH
	MVI H, 0BCH
	MVI L, 0DEH

	MOV A, A
	MOV B, A
	MOV C, A
	MOV D, A
	MOV E, A
	MOV H, A
	MOV L, A

	MVI B, 34H
	MOV A, B
	MOV B, B
	MOV C, B
	MOV D, B
	MOV E, B
	MOV H, B
	MOV L, B

	MVI C, 56H
	MOV A, C
	MOV B, C
	MOV C, C
	MOV D, C
	MOV E, C
	MOV H, C
	MOV L, C

	MVI D, 78H
	MOV A, D
	MOV B, D
	MOV C, D
	MOV D, D
	MOV E, D
	MOV H, D
	MOV L, D

	MVI E, 9AH
	MOV A, E
	MOV B, E
	MOV C, E
	MOV D, E
	MOV E, E
	MOV H, E
	MOV L, E

	MVI H, 0BCH
	MOV A, H
	MOV B, H
	MOV C, H
	MOV D, H
	MOV E, H
	MOV H, H
	MOV L, H

	MVI L, 0DEH
	MOV A, L
	MOV B, L
	MOV C, L
	MOV D, L
	MOV E, L
	MOV H, L
	MOV L, L

	LXI H, 345H
	MVI A, 01H
	MVI B, 02H
	MVI C, 03H
	MVI D, 04H
	MVI E, 05H
	MOV M, A
	MOV M, B
	MOV M, C
	MOV M, D
	MOV M, E

	MVI M, 12H
	MOV A, M
	MVI M, 23H
	MOV B, M
	MVI M, 34H
	MOV C, M
	MVI M, 45H
	MOV D, M
	MVI M, 56H
	MOV E, M
	
	HLT

	END
	
