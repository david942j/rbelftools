source=source.cpp
FLAGS=
SO_FLAGS=-shared -fPIC
PIE_FLAGS=-pie
FULL_RELRO_FLAGS=-Wl,-z,relro,-z,now
NO_RELRO_FLAGS=-Wl,-z,norelro
TARGETS=amd64 i386
.PHONY: clean
all: ${TARGETS}

amd64: ${source}
	g++ -m64 ${source} -o amd64.elf ${FLAGS}
	strip -s amd64.elf -o amd64.strip.elf
	g++ -m64 ${source} -o amd64.frelro.elf ${FLAGS} ${FULL_RELRO_FLAGS}
	g++ -m64 ${source} -o amd64.nrelro.elf ${FLAGS} ${NO_RELRO_FLAGS}
i386: ${source}
	g++ -m32 ${source} -o i386.elf ${FLAGS}
	g++ -m32 ${source} -o i386.so.elf ${FLAGS} ${SO_FLAGS}
	g++ -m32 ${source} -o i386.pie.elf ${FLAGS} ${PIE_FLAGS}

clean:
	rm -f *.elf
