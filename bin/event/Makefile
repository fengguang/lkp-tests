CC = klcc
PROG = wakeup
OBJECTS = wakeup.o

main : $(OBJECTS)
	$(CC) -static -o $(PROG) $(OBJECTS)
	strip $(PROG)
clean:
	rm -fr $(PROG)	$(OBJECTS)
