PROG = wakeup
OBJECTS = wakeup.o
CFLAGS :=

KLCC_PATH = $(shell which klcc 2>/dev/null)
ifeq ($(KLCC_PATH),)
	CC = gcc
else
	CC = klcc
	LDFLAGS = -static
endif
ifeq ($(ARCH),i386)
	CFLAGS += -m32
	# libklibc-dev:i386 conflicts with libklibc-dev, so fall back to gcc
	CC = gcc
endif

main : $(OBJECTS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $(PROG) $(OBJECTS)
	rm -f $(OBJECTS)
	strip $(PROG)
clean:
	rm -fr $(PROG)	$(OBJECTS)
