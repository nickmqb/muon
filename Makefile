CC=gcc
CFLAGS=-m32 -O3
INSTALLDIR=/usr/bin
BINDIR=bootstrap/mu

mu:
	$(CC) $(CFLAGS) -o $(BINDIR) $(BINDIR).c

clean:
	$(RM) $(BINDIR)

install: mu
	cp $(BINDIR) $(INSTALLDIR)

uninstall:
	$(RM) $(INSTALLDIR)/mu


