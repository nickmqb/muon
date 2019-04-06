Array {
	stableSort(items Array<T>, compareFn fun<T, T, int>) {
		if items.count <= 1 {
			return
		}

		assert(items.count < (1 << 30)) // TODO: remove this limitation

		count := items.count
		for i := 0; i < (count / 2 * 2); i += 2 {
			if compareFn(items[i], items[i + 1]) > 0 {
				temp := items[i]
				items[i] = items[i + 1]
				items[i + 1] = temp
			}
		}
		
		src := items
		dest := ref Array<T>(count)
		
		chunk := 2
		while chunk < count {
			step := chunk * 2
			for i := 0; i < count; i += step {
				stableSortMerge_(src, dest, i, chunk, compareFn)
			}
			chunk *= 2
			temp := src
			src = dest
			dest = temp
		}
		
		if items != src {
			src.copySlice(0, count, items, 0)
		}
		
		// TODO: free allocated buffer
	}
	
	stableSortMerge_(src Array<T>, dest Array<T>, from int, chunk int, compareFn fun<T, T, int>) {
		a := from
		ae := a + chunk
		if ae >= src.count {
			src.copySlice(from, src.count, dest, from)
			return
		}
		b := ae
		be := min(b + chunk, src.count)
		i := from
		while a < ae || b < be {
			if a < ae && (b >= be || compareFn(src[a], src[b]) <= 0) {
				dest[i] = src[a]
				a += 1
				i += 1
			} else {
				dest[i] = src[b]
				b += 1
				i += 1
			}
		}		
	}
}

List {
	stableSort(this List<T>, compareFn fun<T, T, int>) {
		this.slice(0, this.count).stableSort(compareFn)
	}
}
