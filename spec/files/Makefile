source=source.cpp
all: amd64 i386
amd64: ${source}
	g++ -m64 ${source} -o amd64
i386: ${source}
	g++ -m32 ${source} -o i386
