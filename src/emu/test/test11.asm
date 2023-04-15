;;; test11.asm
;;; 
;;; P flag (JPE, JPO)
;;; though it is not properly implemented
	
	CPU	8080
	
START:
	XRA A
	MOV B,A
L1:
	MOV A,B
	JPE L_JPE
	MVI A,'O'
	JMP L_OUT
L_JPE:	
	MVI A,'E'
L_OUT:
	OUT 0

	INR B
	MOV A, B
	ANI 15
	JNZ L_NEXT
	MVI A,'\r'
	OUT 0
	MVI A,'\n'
	OUT 0
	
L_NEXT:	
	XRA A
	ORA B
	JNZ L1
	
	MVI A,'\r'
	OUT 0
	MVI A,'\n'
	OUT 0

	HLT
	
	END
