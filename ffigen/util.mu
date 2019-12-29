string {
	split_noEmptyEntries(s string, sep char) {
		result := List<string>{}
		from := 0
		j := 0
		for i := 0; i < s.length {
			if s[i] == sep {
				if from < i {
					result.add(s.slice(from, i))
				}
				from = i + 1
				j += 1
			}
		}
		if from < s.length {
			result.add(s.slice(from, s.length))
		}
		return result		
	}

	trim(s string) {
		from := 0
		while from < s.length {
			ch := s[from]
			if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
				from += 1
			} else {
				break
			}
		}
		to := s.length - 1
		while to >= from {
			ch := s[to]
			if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
				to -= 1
			} else {
				break
			}
		}
		return s.slice(from, to + 1)
	}

	stripPrefix(s string, prefix string) {
		assert(s.startsWith(prefix))
		return s.slice(prefix.length, s.length)
	}
}

Util {
	countLines(s string) {
		lines := 1
		for i := 0; i < s.length {
			if s[i] == '\n' {
				lines += 1
			}
		}
		return lines
	}
}

StringBuilder {
	:hexDigits = "0123456789abcdef"
	
	writeUnescapedString(sb StringBuilder, s string) {
		for i := 0; i < s.length {
			ch := s[i]
			code := transmute(ch, int)
			if ch == '"' {
				sb.write("\"")
			} else if ch == '\\' {
				sb.write("\\")
			} else if 32 <= code && code < 127 {
				sb.writeChar(ch)
			} else {
				sb.write("\\x")
				writeByteHexValue(sb, code)
			}
		}
		return sb.toString()
	}
	
	writeByteHexValue(sb StringBuilder, value int) {
		sb.writeChar(hexDigits[value / 16])
		sb.writeChar(hexDigits[value & 0xf])
	}
}