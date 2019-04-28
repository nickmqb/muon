memcpy(dest pointer, src pointer, count usize) void #Foreign("memcpy")
memmove(dest pointer, src pointer, count usize) void #Foreign("memmove")
memset(s pointer, c int, n usize) void #Foreign("memset")
memcmp(s1 pointer, s2 pointer, n usize) int #Foreign("memcmp")

sbyte {
	:minValue = -128_sb
	:maxValue = 0x7f_sb

	hash(val sbyte) {
		return cast(val, uint)
	}

	writeTo(val sbyte, sb StringBuilder) {
		long.writeTo(val, sb)
	}
}

byte {
	:minValue = 0_b
	:maxValue = 0xff_b

	hash(val byte) {
		return cast(val, uint)
	}

	writeTo(val byte, sb StringBuilder) {
		ulong.writeTo(val, sb)
	}
}

short {
	:minValue = -32768_s
	:maxValue = 0x7fff_s

	hash(val short) {
		return cast(val, uint)
	}

	writeTo(val short, sb StringBuilder) {
		long.writeTo(val, sb)
	}
}

ushort {
	:minValue = 0_us
	:maxValue = 0xffff_us

	hash(val ushort) {
		return cast(val, uint)
	}

	writeTo(val ushort, sb StringBuilder) {
		ulong.writeTo(val, sb)
	}
}

int {
	:minValue = -2147483648
	:maxValue = 0x7fffffff

	hash(val int) {
		return cast(val, uint)
	}

	compare(a int, b int) {
		if a < b {
			return -1
		} else if a > b {
			return 1
		}
		return 0
	}
	
	writeTo(val int, sb StringBuilder) {
		long.writeTo(val, sb)
	}
	
	tryParse(s string) {
		pr := long.tryParse(s)
		if pr.hasValue && int.minValue <= pr.value && pr.value <= int.maxValue {
			return Maybe.from(cast(pr.value, int))
		}
		return Maybe<int>{}
	}
}

uint {
	:minValue = 0_u
	:maxValue = 0xffffffff_u

	hash(val uint) {
		return val
	}

	compare(a uint, b uint) {
		if a < b {
			return -1
		} else if a > b {
			return 1
		}
		return 0
	}
	
	writeTo(val uint, sb StringBuilder) {
		ulong.writeTo(val, sb)
	}

	tryParse(s string) {
		pr := ulong.tryParse(s)
		if pr.hasValue && pr.value <= uint.maxValue {
			return Maybe.from(cast(pr.value, uint))
		}
		return Maybe<uint>{}
	}
}

long {
	:minValue = -9223372036854775808_L
	:maxValue = 0x7fffffffffffffff_L

	hash(val long) {
		return cast(val, uint)
	}
	
	compare(a long, b long) {
		if a < b {
			return -1
		} else if a > b {
			return 1
		}
		return 0
	}
	
	writeTo(val long, sb StringBuilder) {
		if val == 0 {
			sb.write("0")
			return
		}
		if val < 0 {
			sb.write("-")
			if val == long.minValue {
				ulong.writeTo(cast(long.maxValue, ulong) + 1, sb)
				return
			}
			val = -val
		}
		ulong.writeTo(cast(val, ulong), sb)
	}
	
	tryParse(s string) {
		if s == "" {
			return Maybe<long>{}
		}
		if s[0] != '-' {
			result := 0_L
			for i := 0; i < s.length {
				ch := s[i]
				if !(ch >= '0' && ch <= '9') {
					return Maybe<long>{}
				}
				val := ch - '0'
				if result > (long.maxValue - val) / 10 {
					return Maybe<long>{}
				}
				result = result * 10 + val
			}
			return Maybe.from(result)
		} else {
			if s.length == 1 {
				return Maybe<long>{}
			}
			result := 0_L
			for i := 1; i < s.length {
				ch := s[i]
				if !(ch >= '0' && ch <= '9') {
					return Maybe<long>{}
				}
				val := ch - '0'
				if result < (long.minValue + val) / 10 {
					return Maybe<long>{}
				}
				result = result * 10 - val
			}
			return Maybe.from(result)
		}
	}
	
	tryParseHex(s string) {
		result := ulong.tryParseHex(s)
		if !result.hasValue {
			return Maybe<long>{}
		}
		if result.value > cast(long.maxValue, ulong) {
			return Maybe<long>{}
		}
		return Maybe.from(cast(result.value, long))
	}
}	

ulong {
	:minValue = 0_uL
	:maxValue = 0xffffffffffffffff_uL

	hash(val ulong) {
		return cast(val, uint)
	}

	compare(a ulong, b ulong) {
		if a < b {
			return -1
		} else if a > b {
			return 1
		}
		return 0
	}
	
	writeTo(val ulong, sb StringBuilder) {
		if val == 0 {
			sb.write("0")
			return
		}
		from := sb.count
		while val > 0 {
			digit := val % 10
			sb.writeChar('0' + digit)
			val = val / 10
		}
		sb.reverseSlice(from, sb.count)
	}

	writeHexTo(val ulong, sb StringBuilder) {
		if val == 0 {
			sb.write("0")
			return
		}
		from := sb.count
		while val > 0 {
			digit := val & 0xf
			if digit < 10 {			
				sb.writeChar('0' + digit)
			} else {
				sb.writeChar('a' + digit - 10)
			}
			val >>= 4
		}
		sb.reverseSlice(from, sb.count)
	}

	tryParse(s string) {
		if s == "" {
			return Maybe<ulong>{}
		}
		result := 0_uL
		threshold := 1844674407370955161_uL
		for i := 0; i < s.length {
			ch := s[i]
			if !(ch >= '0' && ch <= '9') {
				return Maybe<ulong>{}
			}
			val := ch - '0'
			if result >= threshold {
				if val > 5 {
					return Maybe<ulong>{}
				} else {
					if result > threshold {
						return Maybe<ulong>{}
					}
				}
			}
			result = result * 10 + cast(val, ulong)
		}
		return Maybe.from(result)
	}

	tryParseHex(s string) {
		if s == "" || s.length > 16 {
			return Maybe<ulong>{}
		}
		result := 0_uL
		for i := 0; i < s.length {
			ch := s[i]
			val := 0
			if ch >= '0' && ch <= '9' {
				val = ch - '0'
			} else if ch >= 'A' && ch <= 'F' {
				val = ch - 'A' + 10
			} else if ch >= 'a' && ch <= 'f' {
				val = ch - 'a' + 10
			} else {
				return Maybe<ulong>{}
			}
			result = result * 16 + cast(val, ulong)
		}
		return Maybe.from(result)
	}
}

ssize {
	:minValue = _64bit ? cast(long.minValue, ssize) : cast(int.minValue, ssize)
	:maxValue = _64bit ? cast(long.maxValue, ssize) : cast(int.maxValue, ssize)

	hash(val ssize) {
		return cast(val, uint)
	}

	writeTo(val ssize, sb StringBuilder) {
		long.writeTo(val, sb)
	}
}

usize {
	:minValue = 0_usz
	:maxValue = _64bit ? cast(ulong.maxValue, usize) : cast(uint.maxValue, usize)

	hash(val usize) {
		return cast(val, uint)
	}

	writeTo(val usize, sb StringBuilder) {
		ulong.writeTo(val, sb)
	}
}

float {
	hash(val float) {
		return transmute(val, uint)
	}

	compare(a float, b float) {
		if a < b {
			return -1
		} else if a > b {
			return 1
		}
		return 0
	}

	writeTo(val float, sb StringBuilder) {
		double.writeTo(val, sb)
	}
}

double {
	hash(val double) {
		return transmute(val, uint)
	}

	compare(a double, b double) {
		if a < b {
			return -1
		} else if a > b {
			return 1
		}
		return 0
	}

	snprintf_(str pointer #As("char *"), size usize, format cstring) int #Foreign("snprintf") #VarArgs
	
	writeTo(val double, sb StringBuilder) {
		max := 64
		sb.reserveForWrite(max)
		// TODO: we probably want a locale independent way to convert floating point numbers
		size := snprintf_(sb.dataPtr + sb.count, cast(max, uint), "%lf", val)
		assert(0 < size && size < max)
		sb.count += size
	}
}

bool {
	hash(val bool) {
		return transmute(val, uint)
	}

	writeTo(val bool, sb StringBuilder) {
		if val {
			sb.write("true")
		} else {
			sb.write("false")
		}
	}
}

bool32 {
	hash(val bool32) {
		return transmute(val, uint)
	}

	writeTo(val bool32, sb StringBuilder) {
		if val {
			sb.write("true")
		} else {
			sb.write("false")
		}
	}
}

char {
	hash(ch char) {
		return transmute(ch, uint)
	}

	compare(a char, b char) {
		if a < b {
			return -1
		} else if a > b {
			return 1
		}
		return 0
	}
	
	writeTo(ch char, sb StringBuilder) {
		sb.writeChar(ch)
	}
}

cstring {
	hash(cstr cstring) {
		return cast(transmute(cstr, usize) >> 3, uint)
	}

	length(cstr cstring) {
		from := pointer_cast(cstr, pointer)
		p := from
		while pointer_cast(p, *byte)^ != 0 {
			p += 1
		}
		return checked_cast(pointer.subtractSigned(p, from), int)		
	}
	
	writeTo(cstr cstring, sb StringBuilder) {
		sb.write(string.from_cstring(cstr))
	}
}

pointer {
	hash(p pointer) {
		return cast(transmute(p, usize) >> 3, uint)
	}
	
	compare(a pointer, b pointer) {
		if a < b {
			return -1
		} else if a > b {
			return 1
		}
		return 0
	}
	
	writeTo(p pointer, sb StringBuilder) {
		ulong.writeHexTo(transmute(p, ulong), sb)
	}

	subtractSigned(a pointer, b pointer) {
		return transmute(transmute(a, usize) - transmute(b, usize), ssize)
	}

	subtractUnsigned(a pointer, b pointer) {
		return transmute(a, usize) - transmute(b, usize)
	}
}

string {
	:fnvOffsetBasis = 2166136261_u
	:fnvPrime = 16777619_u
	
	hash(s string) {
		hash := fnvOffsetBasis
		for i := 0; i < s.length {
			val := transmute(unchecked_index(s, i), byte)
			hash = xor(hash, val)
			hash *= fnvPrime
		}
		return hash
	}
	
	from(dataPtr pointer, length int) {
		return string { dataPtr: dataPtr, length: length }
	}
	
	from_cstring(cstr cstring) {
		return string { dataPtr: pointer_cast(cstr, pointer), length: cstr.length() }
	}
	
	alloc(dataPtr pointer, length int) {
		if dataPtr == null {
			assert(length == 0)
			return string{}
		}
		result := string { dataPtr: currentAllocator.alloc(length), length: length }
		memcpy(result.dataPtr, dataPtr, checked_cast(length, usize))
		return result		
	}
	
	alloc_cstring(s string) {
		assert(s.length >= 0)
		ptr := currentAllocator.alloc(s.length + 1)
		memcpy(ptr, s.dataPtr, cast(s.length, usize))
		pointer_cast(ptr + s.length, *byte)^ = 0
		return pointer_cast(ptr, cstring)
	}
	
	slice(s string, from int, to int) string {
		assert(0 <= from && from <= to && to <= s.length)
		return string { dataPtr: s.dataPtr + from, length: to - from }
	}	

	equals(a string, b string) {
		if a.length != b.length {
			return false
		}
		ap := a.dataPtr
		bp := b.dataPtr
		for i := 0; i < a.length {
			ach := pointer_cast(ap, *char)^
			bch := pointer_cast(bp, *char)^
			if ach != bch {
				return false
			}
			ap += 1
			bp += 1
		}
		return true
	}

	compare(a string, b string) {
		len := min(a.length, b.length)
		ap := a.dataPtr
		bp := b.dataPtr
		for i := 0; i < len {
			ach := pointer_cast(ap, *char)^
			bch := pointer_cast(bp, *char)^
			if ach == bch {
				// OK
			} else if ach < bch {
				return -1
			} else {
				return 1
			}
			ap += 1
			bp += 1
		}
		if a.length < b.length {
			return -1
		} else if a.length > b.length {
			return 1
		}
		return 0
	}
}
	
StringBuilder struct #RefType {
	dataPtr pointer
	count int
	capacity int
	
	write(sb StringBuilder, s string) {
		runway := sb.capacity - sb.count
		if runway < s.length {
			reserveForWrite(sb, s.length)
		}
		memcpy(sb.dataPtr + sb.count, s.dataPtr, cast(s.length, usize))
		sb.count += s.length
	}
	
	writeChar(sb StringBuilder, ch char) {
		if sb.count == sb.capacity {
			reserveForWrite(sb, 1)
		}
		pointer_cast(sb.dataPtr + sb.count, *char)^ = ch
		sb.count += 1
	}
	
	reserve(sb StringBuilder, capacity int) {
		assert(capacity >= 0)
		if capacity < sb.capacity {
			return
		}
		sb.dataPtr = ::currentAllocator.realloc(sb.dataPtr, capacity, sb.capacity, sb.count)
		sb.capacity = capacity
	}
	
	reserveForWrite(sb StringBuilder, numBytesToWrite int) {
		target := CheckedMath.addPositiveInt(sb.count, numBytesToWrite)
		if sb.capacity >= target {
			return
		}
		cap := sb.capacity
		if cap == 0 {
			cap = 16
		}
		while cap < target {
			cap = CheckedMath.mulPositiveInt(cap, 2)
		}
		reserve(sb, cap)
	}
	
	reverseSlice(sb StringBuilder, from int, to int) {
		assert(0 <= from && from <= to && to <= sb.count)
		lp := sb.dataPtr + from
		rp := sb.dataPtr + to - 1
		while lp < rp {
			lc := pointer_cast(lp, *char)
			rc := pointer_cast(rp, *char)			
			temp := lc^
			lc^ = rc^
			rc^ = temp
			lp += 1
			rp -= 1
		}
	}
	
	toString(this StringBuilder) {
		return string.alloc(this.dataPtr, this.count)
	}
	
	// Creates a string from the StringBuilder.
	// Reuses the internal buffer for the string, so no additional allocation is necessary.
	compactToString(sb StringBuilder) {
		dataPtr := ::currentAllocator.realloc(sb.dataPtr, sb.count, sb.capacity, sb.count)
		count := sb.count
		sb.dataPtr = null
		sb.count = 0
		sb.capacity = 0
		return string.from(dataPtr, count)
	}
	
	clear(sb StringBuilder) {
		sb.count = 0
	}
}

Maybe<T> struct {
	value T
	hasValue bool
	
	from(value T) {
		return Maybe { value: value, hasValue: true }
	}
	
	unwrap(this Maybe<T>) {
		assert(this.hasValue)
		return this.value
	}
}

Result<T> struct {
	value T
	error int
	
	fromValue(value T) {
		return Result { value: value }
	}
	
	fromError<T>(error int) {
		return Result<T> { error: error }
	}
	
	unwrap(this Result<T>) {
		assert(this.error == 0)
		return this.value
	}
}

CheckedMath {
	addPositiveInt(x int, y int) {
		if int.maxValue - x >= y {
			return x + y
		}
		abandon()
	}
	
	mulPositiveInt(x int, y int) {
		if x <= short.maxValue && y <= short.maxValue {
			return x * y
		}
		if x <= int.maxValue / y {
			return x * y
		}
		abandon()
	}

	mulPositiveSsize(x ssize, y ssize) {
		if ::_64bit {
			if x <= int.maxValue && y <= int.maxValue {
				return x * y
			}
			if x <= long.maxValue / y {
				return x * y
			}
		} else {
			if x <= short.maxValue && y <= short.maxValue {
				return x * y
			}
			if cast(x, int) <= int.maxValue / cast(y, int) {
				return x * y
			}
		}
		abandon()
	}
}

IAllocator {
	alloc(a IAllocator, numBytes ssize) {
		return a.allocFn(a.data, numBytes)
	}
	
	realloc(a IAllocator, ptr pointer, newSizeInBytes ssize, prevSizeInBytes ssize, copySizeInBytes ssize) {
		return a.reallocFn(a.data, ptr, newSizeInBytes, prevSizeInBytes, copySizeInBytes)
	}
	
	free(a IAllocator, ptr pointer) {
		a.freeFn(a.data, ptr)
	}
}
