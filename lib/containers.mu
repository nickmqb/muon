Array<T> struct #RefType {
	dataPtr pointer
	count int
	
	cons<T>(count int) {
		numBytes := CheckedMath.mulPositiveSsize(count, sizeof(T))
		result := Array<T> { dataPtr: ::currentAllocator.alloc(numBytes), count: count }
		Memory.memset(result.dataPtr, 0, cast(numBytes, usize))
		return result
	}

	fromTypedPtr(dataPtr *T, count int) {
		return Array<T> { dataPtr: pointer_cast(dataPtr, pointer), count: count }
	}

	createUninitialized<T>(count int) {
		numBytes := CheckedMath.mulPositiveSsize(count, sizeof(T))
		return Array<T> { dataPtr: ::currentAllocator.alloc(numBytes), count: count }
	}
	
	slice(this Array<T>, from int, to int) {
		assert(0 <= from && from <= to && to <= this.count)
		return Array<T> { dataPtr: this.dataPtr + cast(from, ssize) * sizeof(T), count: to - from }
	}

	copySlice(src Array<T>, from int, to int, dest Array<T>, index int) {
		assert(0 <= from && from <= to && to <= src.count)
		count := to - from
		assert(0 <= index && index <= dest.count - count)
		Memory.memcpy(dest.dataPtr + cast(index, ssize) * sizeof(T), src.dataPtr + cast(from, ssize) * sizeof(T), cast(cast(count, ssize) * sizeof(T), usize))
	}
	
	clear(this Array<T>) {
		Memory.memset(this.dataPtr, 0, cast(cast(this.count, ssize) * sizeof(T), usize))
	}
}

List<T> struct #RefType {
	dataPtr pointer
	count int
	capacity int
	
	add(this List<T>, item T) {
		if this.count == this.capacity {
			grow(this)
		}
		unchecked_index(this, this.count) = item
		this.count += 1
	}
	
	grow(this List<T>) {
		reserve(this, this.capacity != 0 ? CheckedMath.mulPositiveInt(this.capacity, 2) : 4)
	}
	
	reserve(this List<T>, capacity int) {
		assert(capacity >= 0)
		if capacity < this.capacity {
			return
		}
		this.dataPtr = ::currentAllocator.realloc(this.dataPtr, CheckedMath.mulPositiveSsize(capacity, sizeof(T)), cast(this.capacity, ssize) * sizeof(T), cast(this.count, ssize) * sizeof(T))
		this.capacity = capacity
	}
	
	slice(this List<T>, from int, to int) {
		assert(0 <= from && from <= to && to <= this.count)
		return Array<T> { dataPtr: this.dataPtr + cast(from, ssize) * sizeof(T), count: to - from }
	}
	
	removeIndexShift(this List<T>, index int) {
		assert(0 <= index && index < this.count)
		dest := this.dataPtr + cast(index, ssize) * sizeof(T)
		src := dest + sizeof(T)
		Memory.memmove(dest, src, cast(cast(this.count - (index + 1), ssize) * sizeof(T), usize))
		this.count -= 1
	}
	
	removeIndexSwap(this List<T>, index int) {
		assert(0 <= index && index < this.count)
		unchecked_index(this, index) = unchecked_index(this, this.count - 1)
		this.count -= 1
	}

	clear(this List<T>) {
		this.count = 0
	}
	
	setCountChecked(this List<T>, count int) {
		assert(0 <= count && count <= this.count)
		this.count = count
	}
}

SetEntry<T> struct {
	hash uint
	value T
}

Set<T> struct #RefType {
	entries $Array<SetEntry<T>>
	count int
	capacityMask uint
	growThreshold int
	
	create<T>() {
		cap := 8 // Must be power of 2
		return Set {
			entries: Array<SetEntry<T>>(cap),
			count: 0,
			capacityMask: cast(cap - 1, uint),
			growThreshold: cap / 3 * 2,
		}
	}
	
	add(this Set<T>, value T) {
		assert(tryAdd(this, value))
	}
	
	tryAdd(this Set<T>, value T) {
		if this.count > this.growThreshold {
			grow(this)
		}
		h := compute_hash(value)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				break
			}
			if e.hash == h && e.value == value {
				return false
			}
			b = (b + 1) & this.capacityMask
		}
		this.entries[b] = SetEntry { hash: h, value: value }
		this.count += 1
		return true
	}
	
	contains(this Set<T>, value T) bool {
		h := compute_hash(value)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return false
			}
			if e.hash == h && e.value == value {
				return true
			}
			b = (b + 1) & this.capacityMask
		}
	}

	remove(this Set<T>, value T) {
		assert(tryRemove(this, value))
	}
	
	tryRemove(this Set<T>, value T) {
		h := compute_hash(value)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return false
			}
			if e.hash == h && e.value == value {
				break
			}
			b = (b + 1) & this.capacityMask
		}
		z := b
		b = (b + 1) & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				break
			}
			ib := e.hash & this.capacityMask
			if ((ib - (z + 1)) & this.capacityMask) >= ((b - z) & this.capacityMask) {
				this.entries[z] = e^
				z = b
			}
			b = (b + 1) & this.capacityMask
		}
		this.entries[z].hash = 0
		this.count -= 1
		return true
	}

	clear(this Set<T>) {
		this.entries.clear()
		this.count = 0
	}

	getEmptyEntry_(this Set<T>, h uint) {
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return e
			}
			b = (b + 1) & this.capacityMask
		}
	}

	grow(this Set<T>) {
		newCap := CheckedMath.mulPositiveInt(this.entries.count, 2)
		prev := this.entries
		this.entries = Array<SetEntry<T>>(newCap)
		this.capacityMask = cast(newCap - 1, uint)
		this.growThreshold = newCap / 3 * 2
		for i := 0; i < prev.count {
			e := ref prev[i]
			if e.hash != 0 {
				getEmptyEntry_(this, e.hash)^ = e^
			}
		}
	}
}

CustomSet<T> struct #RefType {
	entries $Array<SetEntry<T>>
	count int
	capacityMask uint
	growThreshold int
	hashFn fun<T, uint>
	equalsFn fun<T, T, bool>
	
	create<T>(hashFn fun<T, uint>, equalsFn fun<T, T, bool>) {
		cap := 8 // Must be power of 2
		return CustomSet {
			entries: Array<SetEntry<T>>(cap),
			count: 0,
			capacityMask: cast(cap - 1, uint),
			growThreshold: cap / 3 * 2,
			hashFn: hashFn,
			equalsFn: equalsFn,
		}
	}
	
	add(this CustomSet<T>, value T) {
		assert(tryAdd(this, value))
	}
	
	tryAdd(this CustomSet<T>, value T) {
		if this.count > this.growThreshold {
			grow(this)
		}
		h := this.hashFn(value)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				break
			}
			if e.hash == h && this.equalsFn(e.value, value) {
				return false
			}
			b = (b + 1) & this.capacityMask
		}
		this.entries[b] = SetEntry { hash: h, value: value }
		this.count += 1
		return true
	}
	
	contains(this CustomSet<T>, value T) bool {
		h := this.hashFn(value)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return false
			}
			if e.hash == h && this.equalsFn(e.value, value) {
				return true
			}
			b = (b + 1) & this.capacityMask
		}
	}

	remove(this CustomSet<T>, value T) {
		assert(tryRemove(this, value))
	}
	
	tryRemove(this CustomSet<T>, value T) {
		h := this.hashFn(value)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return false
			}
			if e.hash == h && this.equalsFn(e.value, value) {
				break
			}
			b = (b + 1) & this.capacityMask
		}
		z := b
		b = (b + 1) & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				break
			}
			ib := e.hash & this.capacityMask
			if ((ib - (z + 1)) & this.capacityMask) >= ((b - z) & this.capacityMask) {
				this.entries[z] = e^
				z = b
			}
			b = (b + 1) & this.capacityMask
		}
		this.entries[z].hash = 0
		this.count -= 1
		return true
	}

	clear(this CustomSet<T>) {
		this.entries.clear()
		this.count = 0
	}

	getEmptyEntry_(this CustomSet<T>, h uint) {
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return e
			}
			b = (b + 1) & this.capacityMask
		}
	}

	grow(this CustomSet<T>) {
		newCap := CheckedMath.mulPositiveInt(this.entries.count, 2)
		prev := this.entries
		this.entries = Array<SetEntry<T>>(newCap)
		this.capacityMask = cast(newCap - 1, uint)
		this.growThreshold = newCap / 3 * 2
		for i := 0; i < prev.count {
			e := ref prev[i]
			if e.hash != 0 {
				getEmptyEntry_(this, e.hash)^ = e^
			}
		}
	}
}

MapEntry<K, V> struct {
	hash uint
	key K
	value V
}

Map<K, V> struct #RefType {
	entries $Array<MapEntry<K, V>>
	count int	
	capacityMask uint
	growThreshold int
	
	create<K, V>() {
		cap := 8 // Must be power of 2
		return Map {
			entries: Array<MapEntry<K, V>>(cap),
			count: 0,
			capacityMask: cast(cap - 1, uint),
			growThreshold: cap / 3 * 2,
		}
	}
	
	add(this Map<K, V>, key K, value V) {
		assert(tryAdd(this, key, value))
	}
	
	tryAdd(this Map<K, V>, key K, value V) {
		if this.count > this.growThreshold {
			grow(this)
		}
		h := compute_hash(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				break
			}
			if e.hash == h && e.key == key {
				return false
			}
			b = (b + 1) & this.capacityMask
		}
		this.entries[b] = MapEntry { hash: h, key: key, value: value }
		this.count += 1
		return true
	}
	
	addOrUpdate(this Map<K, V>, key K, value V) {
		if this.count > this.growThreshold {
			grow(this)
		}
		h := compute_hash(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				break
			}
			if e.hash == h && e.key == key {
				e.value = value
				return
			}
			b = (b + 1) & this.capacityMask
		}
		this.entries[b] = MapEntry { hash: h, key: key, value: value }
		this.count += 1
	}
	
	update(this Map<K, V>, key K, value V) {
		h := compute_hash(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			assert(e.hash != 0)
			if e.hash == h && e.key == key {
				e.value = value
				return
			}
			b = (b + 1) & this.capacityMask
		}
	}

	containsKey(this Map<K, V>, key K) {
		h := compute_hash(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return false
			}
			if e.hash == h && e.key == key {
				return true
			}
			b = (b + 1) & this.capacityMask
		}
	}

	get(this Map<K, V>, key K) {
		h := compute_hash(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			assert(e.hash != 0)
			if e.hash == h && e.key == key {
				return e.value
			}
			b = (b + 1) & this.capacityMask
		}
	}

	getOrDefault(this Map<K, V>, key K) {
		h := compute_hash(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return default_value(V)
			}
			if e.hash == h && e.key == key {
				return e.value
			}
			b = (b + 1) & this.capacityMask
		}
	}

	maybeGet(this Map<K, V>, key K) {
		h := compute_hash(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return Maybe<V>{}
			}
			if e.hash == h && e.key == key {
				return Maybe.from(e.value)
			}
			b = (b + 1) & this.capacityMask
		}
	}

	remove(this Map<K, V>, key K) {
		assert(tryRemove(this, key))
	}
	
	tryRemove(this Map<K, V>, key K) {
		h := compute_hash(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return false
			}
			if e.hash == h && e.key == key {
				break
			}
			b = (b + 1) & this.capacityMask
		}
		z := b
		b = (b + 1) & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				break
			}
			ib := e.hash & this.capacityMask
			if ((ib - (z + 1)) & this.capacityMask) >= ((b - z) & this.capacityMask) {
				this.entries[z] = e^
				z = b
			}
			b = (b + 1) & this.capacityMask
		}
		this.entries[z].hash = 0
		this.count -= 1
		return true
	}

	clear(this Map<K, V>) {
		this.entries.clear()
		this.count = 0
	}

	getEmptyEntry_(this Map<K, V>, h uint) {
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return e
			}
			b = (b + 1) & this.capacityMask
		}
	}

	grow(this Map<K, V>) {
		newCap := CheckedMath.mulPositiveInt(this.entries.count, 2)
		prev := this.entries
		this.entries = Array<MapEntry<K, V>>(newCap)
		this.capacityMask = cast(newCap - 1, uint)
		this.growThreshold = newCap / 3 * 2
		for i := 0; i < prev.count {
			e := ref prev[i]
			if e.hash != 0 {
				getEmptyEntry_(this, e.hash)^ = e^
			}
		}
	}
}

CustomMap<K, V> struct #RefType {
	entries $Array<MapEntry<K, V>>
	count int	
	capacityMask uint
	growThreshold int
	hashFn fun<K, uint>
	equalsFn fun<K, K, bool>
	
	create<K, V>(hashFn fun<K, uint>, equalsFn fun<K, K, bool>) {
		cap := 8 // Must be power of 2
		return CustomMap {
			entries: Array<MapEntry<K, V>>(cap),
			count: 0,
			capacityMask: cast(cap - 1, uint),
			growThreshold: cap / 3 * 2,
			hashFn: hashFn,
			equalsFn: equalsFn,
		}
	}
	
	add(this CustomMap<K, V>, key K, value V) {
		assert(tryAdd(this, key, value))
	}
	
	tryAdd(this CustomMap<K, V>, key K, value V) {
		if this.count > this.growThreshold {
			grow(this)
		}
		h := this.hashFn(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				break
			}
			if e.hash == h && this.equalsFn(e.key, key) {
				return false
			}
			b = (b + 1) & this.capacityMask
		}
		this.entries[b] = MapEntry { hash: h, key: key, value: value }
		this.count += 1
		return true
	}
	
	addOrUpdate(this CustomMap<K, V>, key K, value V) {
		if this.count > this.growThreshold {
			grow(this)
		}
		h := this.hashFn(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				break
			}
			if e.hash == h && this.equalsFn(e.key, key) {
				e.value = value
				return
			}
			b = (b + 1) & this.capacityMask
		}
		this.entries[b] = MapEntry { hash: h, key: key, value: value }
		this.count += 1
	}
	
	update(this CustomMap<K, V>, key K, value V) {
		h := this.hashFn(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			assert(e.hash != 0)
			if e.hash == h && this.equalsFn(e.key, key) {
				e.value = value
				return
			}
			b = (b + 1) & this.capacityMask
		}
	}

	containsKey(this CustomMap<K, V>, key K) {
		h := this.hashFn(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return false
			}
			if e.hash == h && this.equalsFn(e.key, key) {
				return true
			}
			b = (b + 1) & this.capacityMask
		}
	}

	get(this CustomMap<K, V>, key K) {
		h := this.hashFn(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			assert(e.hash != 0)
			if e.hash == h && this.equalsFn(e.key, key) {
				return e.value
			}
			b = (b + 1) & this.capacityMask
		}
	}

	getOrDefault(this CustomMap<K, V>, key K) {
		h := this.hashFn(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return default_value(V)
			}
			if e.hash == h && this.equalsFn(e.key, key) {
				return e.value
			}
			b = (b + 1) & this.capacityMask
		}
	}

	maybeGet(this CustomMap<K, V>, key K) {
		h := this.hashFn(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return Maybe<V>{}
			}
			if e.hash == h && this.equalsFn(e.key, key) {
				return Maybe.from(e.value)
			}
			b = (b + 1) & this.capacityMask
		}
	}

	remove(this CustomMap<K, V>, key K) {
		assert(tryRemove(this, key))
	}
	
	tryRemove(this CustomMap<K, V>, key K) {
		h := this.hashFn(key)
		if h == 0 {
			h = 1
		}
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return false
			}
			if e.hash == h && this.equalsFn(e.key, key) {
				break
			}
			b = (b + 1) & this.capacityMask
		}
		z := b
		b = (b + 1) & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				break
			}
			ib := e.hash & this.capacityMask
			if ((ib - (z + 1)) & this.capacityMask) >= ((b - z) & this.capacityMask) {
				this.entries[z] = e^
				z = b
			}
			b = (b + 1) & this.capacityMask
		}
		this.entries[z].hash = 0
		this.count -= 1
		return true
	}

	clear(this CustomMap<K, V>) {
		this.entries.clear()
		this.count = 0
	}

	getEmptyEntry_(this CustomMap<K, V>, h uint) {
		b := h & this.capacityMask
		while true {
			e := ref this.entries[b]
			if e.hash == 0 {
				return e
			}
			b = (b + 1) & this.capacityMask
		}
	}

	grow(this CustomMap<K, V>) {
		newCap := CheckedMath.mulPositiveInt(this.entries.count, 2)
		prev := this.entries
		this.entries = Array<MapEntry<K, V>>(newCap)
		this.capacityMask = cast(newCap - 1, uint)
		this.growThreshold = newCap / 3 * 2
		for i := 0; i < prev.count {
			e := ref prev[i]
			if e.hash != 0 {
				getEmptyEntry_(this, e.hash)^ = e^
			}
		}
	}
}
