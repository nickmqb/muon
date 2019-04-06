void {
}

sbyte {
}

byte {
}

short {
}

ushort {
}

int {
}

uint {
}

long {
}

ulong {
}

ssize {
}

usize {
}

float {
}

double {
}

bool {
}

bool32 {
}

char {
}

string struct {
	dataPtr pointer
	length int
}

cstring {
}

pointer {
}

Ptr {
}

fun {
}

IAllocator struct {
	data pointer
	allocFn fun<pointer, ssize, pointer> // data, sizeInBytes, resultPtr
	reallocFn fun<pointer, pointer, ssize, ssize, ssize, pointer> // data, userPtr, newSizeInBytes, prevSizeInBytes, copySizeInBytes, resultPtr
	freeFn fun<pointer, pointer, void> // data, userPtr
}

:currentAllocator IAllocator #ThreadLocal #Mutable

:abandonFn fun<int, void> #ThreadLocal #Mutable
