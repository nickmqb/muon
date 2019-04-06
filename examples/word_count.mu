Array {
	countOccurrences(items Array<T>) {
		map := Map.create<T, int>()
		for items {
			count := map.getOrDefault(it)
			map.addOrUpdate(it, count + 1)
		}
		return map
	}
}

main() {
	::currentAllocator = Memory.newArenaAllocator(4096)
	s := "How much wood could a wood chuck chuck if a wood chuck could chuck wood?"
	freq := s.split(' ').countOccurrences() // Equivalent to: Array.countOccurrences(ref string.split(s, ' '))
	for e in freq {
		Stdout.writeLine(format("word: {}, count: {}", e.key, e.value))
	}
}
