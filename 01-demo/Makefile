AS86	=as86 -0 -a
LD86	=ld86 -0

all: Image

Image: boot
	dd bs=32 if=boot of=Image skip=1

boot:	boot.s
	$(AS86) -o boot.o boot.s
	$(LD86) -s -o boot boot.o

clean: cleanless
	rm -f Image boot head *.o

cleanless:
	rm -f boot head *.o
