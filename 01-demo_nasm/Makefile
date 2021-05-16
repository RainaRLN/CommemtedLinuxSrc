AS	=nasm

all: Image

Image: boot
	dd bs=512 if=boot of=Image count=1

boot:	boot.s
	$(AS) -o boot boot.s

clean: cleanless
	rm -f Image boot

cleanless:
	rm -f boot
