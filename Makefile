CC=gcc
CFLAGS=-m32 -O3
INSTALLDIR=/usr/bin
BINPATH=bootstrap/mu

mu:
	$(CC) $(CFLAGS) -o $(BINPATH) $(BINPATH).c

clean:
	$(RM) $(BINPATH)

install: mu
	cp $(BINPATH) $(INSTALLDIR)

uninstall:
	$(RM) $(INSTALLDIR)/mu


