ARCH=32
CC=gcc
CFLAGS=-m$(ARCH) -O3
PREFIX=/usr/local
BINPATH=bootstrap/mu
RM=rm

mu:
	$(CC) $(CFLAGS) -o $(BINPATH) $(BINPATH)$(ARCH).c

clean:
	$(RM) $(BINPATH)

install: mu
	cp $(BINPATH) $(PREFIX)/bin

uninstall:
	$(RM) $(PREFIX)/bin/mu

.PHONY: clean install uninstall
