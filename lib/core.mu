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

s128 { // Note: not well supported yet, currently only usable for struct padding
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

:_32bit bool #Foreign("_32bit")

IAllocator struct {
	data pointer
	allocFn fun<pointer, ssize, pointer> // data, sizeInBytes, resultPtr
	reallocFn fun<pointer, pointer, ssize, ssize, ssize, pointer> // data, userPtr, newSizeInBytes, prevSizeInBytes, copySizeInBytes, resultPtr
	freeFn fun<pointer, pointer, void> // data, userPtr
}

:currentAllocator IAllocator #ThreadLocal #Mutable

:abandonFn fun<int, void> #ThreadLocal #Mutable
