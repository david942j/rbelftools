source=source.cpp
FLAGS=
SO_FLAGS=-shared -fPIC
PIE_FLAGS=-pie
TARGETS=amd64 i386
.PHONY: clean
all: ${TARGETS}

amd64: ${source}
	g++ -m64 ${source} -o amd64.elf ${FLAGS}
	strip -s amd64.elf -o amd64.strip.elf
i386: ${source}
	g++ -m32 ${source} -o i386.elf ${FLAGS}
	g++ -m32 ${source} -o i386.so ${FLAGS} ${SO_FLAGS}
	g++ -m32 ${source} -o i386.pie.elf ${FLAGS} ${PIE_FLAGS}

clean:
	rm -f *.elf *.so
