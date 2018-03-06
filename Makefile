ifeq ($(OS), Windows_NT)
	NASM = /c/Program\ Files/SASM/NASM/nasm.exe
	IO = include/io.win.inc
	EXE = calc.exe
else
	NASM = nasm
	IO = include/io.lin.inc
	EXE = calc
endif

CC = gcc
CFLAGS = -g -m32
LDFLAGS = -g -m32

.PHONY: all clean pack

all: calc

calc: main.o calc.o macro.o

main.o: main.c util.h

calc.o: calc.asm $(IO)
	$(NASM) -f elf32 $< -o $@

macro.o: macro.c

pack:
	zip -r iocla-tema2-submisie.zip main.c macro.c calc.asm include/ util.h README Makefile

clean:
	-rm -fr $(EXE)
	-rm -fr *~
	-rm -fr *.o
