PROG = wakeup
OBJECTS = wakeup.o
CFLAGS :=

ifeq ($(ARCH),i386)
	CFLAGS += -m32
	# libklibc-dev:i386 conflicts with libklibc-dev, so fall back to gcc
	CC = gcc
else
	CC = klcc
endif

main : $(OBJECTS)
	$(CC) $(CFLAGS) -static -o $(PROG) $(OBJECTS)
	rm -f $(OBJECTS)
	strip $(PROG)
clean:
	rm -fr $(PROG)	$(OBJECTS)
