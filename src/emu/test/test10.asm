;;; test10.asm
;;; 
;;; echo back
	CPU	8080
	org 0000H
START:
	IN 01H
	OUT 01H
	JMP START

	END
