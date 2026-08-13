source=source.cpp
freestanding=freestanding.cpp
FLAGS=
SO_FLAGS=-shared -fPIC
PIE_FLAGS=-pie
FULL_RELRO_FLAGS=-Wl,-z,relro,-z,now
NO_RELRO_FLAGS=-Wl,-z,norelro
TARGETS=amd64 i386
# Architectures other than x86 are cross compiled, see README.md.
CROSS_TARGETS=aarch64 arm riscv64 ppc64 mips
CROSS=clang++
# lld handles every target here but ppc64, whose big endian flavor is ELFv1.
LLD=-fuse-ld=lld
PPC64_LD=-fuse-ld=/usr/bin/powerpc-linux-gnu-ld
.PHONY: clean
all: ${TARGETS} ${CROSS_TARGETS}

amd64: ${source}
	g++ -m64 ${source} -o amd64.elf ${FLAGS}
	strip -s amd64.elf -o amd64.strip.elf
	g++ -m64 ${source} -o amd64.frelro.elf ${FLAGS} ${FULL_RELRO_FLAGS}
	g++ -m64 ${source} -o amd64.nrelro.elf ${FLAGS} ${NO_RELRO_FLAGS}
i386: ${source}
	g++ -m32 ${source} -o i386.elf ${FLAGS}
	g++ -m32 ${source} -o i386.so.elf ${FLAGS} ${SO_FLAGS}
	g++ -m32 ${source} -o i386.pie.elf ${FLAGS} ${PIE_FLAGS}

aarch64: ${source}
	${CROSS} --target=aarch64-linux-gnu ${LLD} ${source} -o aarch64.elf ${FLAGS}
# Thumb code only differs in relocations that a linker resolves, so the Thumb
# flavor is kept as an object file.
arm: ${source} ${freestanding}
	${CROSS} --target=arm-linux-gnueabihf ${LLD} ${source} -o arm.elf ${FLAGS}
	${CROSS} --target=arm-linux-gnueabihf -mthumb -c ${freestanding} -o arm.thumb.o ${FLAGS}
riscv64: ${source}
	${CROSS} --target=riscv64-linux-gnu ${LLD} ${source} -o riscv64.elf ${FLAGS}
ppc64: ${source}
	${CROSS} --target=powerpc64-linux-gnu ${PPC64_LD} ${source} -o ppc64.elf ${FLAGS}
# No MIPS libc is available to link against, object files are used instead.
mips: ${freestanding}
	${CROSS} --target=mips-linux-gnu -c ${freestanding} -o mips.o ${FLAGS}
	${CROSS} --target=mips64-linux-gnuabi64 -c ${freestanding} -o mips64.o ${FLAGS}

clean:
	rm -f *.elf *.o
