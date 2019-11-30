malloc(size usize) pointer #Foreign("malloc")
realloc(ptr pointer, new_size usize) pointer #Foreign("realloc")
free(ptr pointer) void #Foreign("free")

Memory {
	newArenaAllocator(capacity ssize) {
		prev := ::currentAllocator
		::currentAllocator = heapAllocator()
		a := new ArenaAllocator(capacity)
		::currentAllocator = prev
		return a.iAllocator_escaping()
	}
	
	heapAllocator() {
		return IAllocator {
			allocFn: heapAllocFn,
			reallocFn: heapReallocFn,
			freeFn: heapFreeFn,
		}
	}
	
	heapAllocFn(data pointer, numBytes ssize) {
		result := malloc(checked_cast(numBytes, usize))
		assert(result != null)
		return result
	}

	heapReallocFn(data pointer, ptr pointer, newSizeInBytes ssize, prevSizeInBytes ssize, copySizeInBytes ssize) {
		result := realloc(ptr, checked_cast(newSizeInBytes, usize))
		assert(result != null)
		return result
	}

	heapFreeFn(data pointer, ptr pointer) {
		assert(ptr != null)
		free(ptr)
	}

	pushAllocator(allocator IAllocator) {
		prev := ::currentAllocator
		::currentAllocator = allocator
		return prev
	}

	restoreAllocator(allocator IAllocator) {
		::currentAllocator = allocator
	}
}

ArenaAllocator struct #RefType {
	from pointer
	to pointer
	current pointer
	
	cons(capacity ssize) {
		from := ::currentAllocator.alloc(capacity)
		assert((transmute(from, usize) & 7) == 0) // Ensure qword aligned
		return ArenaAllocator { 
			from: from,
			current: from,
			to: from + capacity,
		}	
	}
	
	alloc(a ArenaAllocator, numBytes ssize) {
		runway := a.to.subtractSigned(a.current)
		assert(cast(numBytes, usize) <= cast(runway, usize))
		numBytes = (numBytes + 7) & ~7 // Round up to next qword
		ptr := a.current
		a.current += numBytes
		return ptr
	}
	
	realloc(a ArenaAllocator, ptr pointer, newSizeInBytes ssize, prevSizeInBytes ssize, copySizeInBytes ssize) {
		assert(cast(prevSizeInBytes, usize) <= cast(ssize.maxValue - 7, usize))
		prevSizeInBytes = (prevSizeInBytes + 7) & ~7
		if ptr + prevSizeInBytes == a.current && prevSizeInBytes > 0 {
			if newSizeInBytes > prevSizeInBytes {
				alloc(a, newSizeInBytes - prevSizeInBytes)
			} else {
				assert(newSizeInBytes >= 0)
				newSizeInBytes = (newSizeInBytes + 7) & ~7
				a.current = ptr + newSizeInBytes
			}			
			return ptr
		}	
		newPtr := a.alloc(newSizeInBytes)
		memcpy(newPtr, ptr, checked_cast(min(copySizeInBytes, newSizeInBytes), usize))
		return newPtr
	}
	
	iAllocator_escaping(a ArenaAllocator) {
		return IAllocator {
			data: pointer_cast(a, pointer),
			allocFn: pointer_cast(ArenaAllocator.alloc, fun<pointer, ssize, pointer>),
			reallocFn: pointer_cast(ArenaAllocator.realloc, fun<pointer, pointer, ssize, ssize, ssize, pointer>),
		}
	}

	pushState(a ArenaAllocator) {
		return a.current
	}

	restoreState(a ArenaAllocator, state pointer) {
		assert(a.from <= state && state <= a.to)
		a.current = state
	}
}
