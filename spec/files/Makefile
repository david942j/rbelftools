source=source.cpp
FLAGS=
TARGETS=amd64 i386
.PHONY: clean
all: ${TARGETS}

amd64: ${source}
	g++ -m64 ${source} -o amd64 ${FLAGS}
i386: ${source}
	g++ -m32 ${source} -o i386 ${FLAGS}

clean:
	rm -f ${TARGETS}
