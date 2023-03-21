PRG=test10

.SUFFIXES: .asm .p .bin .lst .hex

PFILE=$(PRG).p
LFILE=$(PRG).lst
HEXFILE=$(PRG).hex

SRC=$(PRG).asm

# INCDIR=../include
#ASM=asl -L -i $(INCDIR)
ASM=asl -L

P2BIN=p2bin
P2HEX=p2hex

all: $(HEXFILE)

.asm.p:
	$(ASM) $<
.p.hex:
	$(P2HEX) -F Intel $<

$(BIN): $(PFILE)

$(PFILE): $(SRC)

clean:
	rm $(BIN) $(PFILE) $(LFILE)
