;;; test5.asm
;;; 
;;; ANI, XRI, ORI, CPI

	CPU	8080
START:
;;; ----------------------------------
	MVI A, 00H
	ANI 00H
	MVI A, 00H
	ANI 0FFH

	MVI A, 0FFH
	ANI 00H
	MVI A, 0FFH
	ANI 0FFH

	MVI A, 55H
	ANI 0AAH
	MVI A, 0AAH
	ANI 55H

	MVI A, 0FFH
	ANI 55H
	MVI A, 0FFH
	ANI 0AAH
;;; ----------------------------------
	MVI A, 00H
	ORI 00H
	MVI A, 00H
	ORI 0FFH

	MVI A, 0FFH
	ORI 00H
	MVI A, 0FFH
	ORI 0FFH

	MVI A, 55H
	ORI 0AAH
	MVI A, 0AAH
	ORI 55H

	MVI A, 0FFH
	ORI 55H
	MVI A, 0FFH
	ORI 0AAH
;;; ----------------------------------
	MVI A, 00H
	XRI 00H
	MVI A, 00H
	XRI 0FFH

	MVI A, 0FFH
	XRI 00H
	MVI A, 0FFH
	XRI 0FFH

	MVI A, 55H
	XRI 0AAH
	MVI A, 0AAH
	XRI 55H

	MVI A, 0FFH
	XRI 55H
	MVI A, 0FFH
	XRI 0AAH
;;; ----------------------------------
	MVI A, 00H
	CPI 00H
	MVI A, 00H
	CPI 0FFH

	MVI A, 0FFH
	CPI 00H
	MVI A, 0FFH
	CPI 0FFH

	MVI A, 55H
	CPI 0AAH
	MVI A, 0AAH
	CPI 55H

	MVI A, 0FFH
	CPI 55H
	MVI A, 0FFH
	CPI 0AAH
;;; ----------------------------------
	
	HLT

	END
	
