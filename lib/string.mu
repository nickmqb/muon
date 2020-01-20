string {
	repeatChar(ch char, count int) {
		rb := StringBuilder{}
		for i := 0; i < count {
			rb.writeChar(ch)
		}
		return rb.compactToString()
	}

	split(s string, sep char) {
		num := 1
		for i := 0; i < s.length {
			if s[i] == sep {
				num += 1
			}
		}
		result := Array<string>(num)
		from := 0
		j := 0
		for i := 0; i < s.length {
			if s[i] == sep {
				result[j] = s.slice(from, i)
				from = i + 1
				j += 1
			}
		}
		result[j] = s.slice(from, s.length)
		return result		
	}
	
	join(sep string, items Array<string>) {
		rb := StringBuilder{}
		insertSep := false
		for items {
			if insertSep {
				rb.write(sep)
			} else {
				insertSep = true
			}
			rb.write(it)
		}
		return rb.compactToString()
	}

	startsWith(s string, prefix string) {
		if s.length < prefix.length {
			return false
		}
		for i := 0; i < prefix.length {
			if s[i] != prefix[i] {
				return false
			}
		}
		return true
	}
	
	endsWith(s string, suffix string) {
		if s.length < suffix.length {
			return false
		}
		from := s.length - suffix.length
		for i := 0; i < suffix.length {
			if s[from + i] != suffix[i] {
				return false
			}
		}
		return true
	}

	startsWith_ignoreCase(s string, prefix string) {
		if s.length < prefix.length {
			return false
		}
		for i := 0; i < prefix.length {
			if toLower_(s[i]) != toLower_(prefix[i]) {
				return false
			}
		}
		return true
	}

	compare_ignoreCase(a string, b string) {
		len := min(a.length, b.length)
		ap := a.dataPtr
		bp := b.dataPtr
		for i := 0; i < len {
			ach := toLower_(pointer_cast(ap, *char)^)
			bch := toLower_(pointer_cast(bp, *char)^)
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

	toLower_(ch char) {
		if 'A' <= ch && ch <= 'Z' {
			return ch + 32
		}
		return ch
	}

	replace(s string, sub string, replacement string) {
		rb := StringBuilder{}
		last := 0
		i := 0
		to := s.length - sub.length
		while i <= to {
			j := i
			k := 0
			while k < sub.length {
				if s[j] == sub[k] {
					j += 1
					k += 1
				} else {
					break
				}
			}
			if k == sub.length {
				rb.write(s.slice(last, i))
				rb.write(replacement)
				i += sub.length
				last = i
			} else {
				i += 1
			}
		}
		rb.write(s.slice(last, s.length))
		return rb.compactToString()
	}
	
	indexOf(s string, sub string) {
		to := s.length - sub.length
		for i := 0; i <= to {
			j := i
			k := 0
			while k < sub.length {
				if s[j] == sub[k] {
					j += 1
					k += 1
				} else {
					break
				}
			}
			if k == sub.length {
				return i
			}
		}
		return -1
	}

	indexOfChar(s string, ch char) {
		for i := 0; i < s.length {
			if s[i] == ch {
				return i
			}
		}
		return -1
	}
}
