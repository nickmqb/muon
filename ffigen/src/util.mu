exit(status int) void #Foreign("exit")

readFile(path string, errorMessage string) {
	sb := StringBuilder{}
	if !File.tryReadToStringBuilder(path, ref sb) {
		Stderr.writeLine(errorMessage)
		exit(1)
	}
	return sb.compactToString()
}

string {
	stripPrefix(s string, prefix string) {
		assert(s.startsWith(prefix))
		return s.slice(prefix.length, s.length)
	}
}

countLines(s string) {
	lines := 1
	for i := 0; i < s.length {
		if s[i] == '\n' {
			lines += 1
		}
	}
	return lines
}

StringBuilder {
	:hexDigits = "0123456789abcdef"
	
	writeUnescapedString(sb StringBuilder, s string) {
		for i := 0; i < s.length {
			ch := s[i]
			code := transmute(ch, byte)
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
	
	writeByteHexValue(sb StringBuilder, value byte) {
		sb.writeChar(hexDigits[value / 16])
		sb.writeChar(hexDigits[value & 0xf])
	}
}

stripConstModifier(s string) {
	if s.startsWith("const ") {
		s = s.slice("const ".length, s.length)
	}	
	return s
}

isIdentifier(s string) {
	if s == "" {
		return false
	}
	for i := 0; i < s.length {
		ch := s[i]
		if ('A' <= ch && ch <= 'Z') || ('a' <= ch && ch <= 'z') || ('0' <= ch && ch <= '9' && i > 0) || ch == '_' {
			// OK
		} else {
			return false
		}
	}
	return true
}

isValidCStructOrUnionName(s string) {
	if s.startsWith("struct ") {
		return isIdentifier(s.stripPrefix("struct "))
	} else if s.startsWith("union ") {
		return isIdentifier(s.stripPrefix("union "))
	} else {
		return isIdentifier(s)
	}
}

isValidCEnumName(s string) {
	if s.startsWith("enum ") {
		return isIdentifier(s.stripPrefix("enum "))
	} else {
		return isIdentifier(s)
	}
}

getMuonPaddingType(size int) {
	if size == 1 {
		return "byte"
	} else if size == 2 {
		return "ushort"
	} else if size == 4 {
		return "uint"
	} else if size == 8 {
		return "ulong"
	} else if size == 16 {
		return "s128"
	}
	return format("FFIGEN_INVALID_PADDING_TYPE_{}", size)
}

formatMuonPtr(name string, numPtr int) {
	assert(numPtr >= 0)
	return format("{}{}", string.repeatChar('*', numPtr), name)
}

isValidMuonIntegerConstType(s string) {
	return s == "sbyte" || s == "byte" || s == "short" || s == "ushort" || s == "int" || s == "uint" || s == "long" || s == "ulong"
}

isValidMuonFloatingConstType(s string) {
	return s == "float" || s == "double"
}

isValidMuonConstType(s string) {
	return s == "sbyte" || s == "byte" || s == "short" || s == "ushort" || s == "int" || s == "uint" || s == "long" || s == "ulong" || s == "float" || s == "double" || s == "cstring"
}

muonConstTypeToCType(type string) {
	if type == "sbyte" {
		return "int8_t"
	} else if type == "byte" {
		return "uint8_t"
	} else if type == "short" {
		return "int16_t"
	} else if type == "ushort" {
		return "uint16_t"
	} else if type == "int" {
		return "int32_t"
	} else if type == "uint" {
		return "uint32_t"
	} else if type == "long" {
		return "int64_t"
	} else if type == "ulong" {
		return "uint64_t"
	} else if type == "float" {
		return "float"
	} else if type == "double" {
		return "double"
	} else if type == "cstring" {
		return "char* const"
	}
	abandon()
}

getMuonConstLiteralSuffix(type string) {
	if type == "sbyte" {
		return "_sb"
	} else if type == "byte" {
		return "_b"
	} else if type == "short" {
		return "_s"
	} else if type == "ushort" {
		return "_us"
	} else if type == "int" {
		return ""
	} else if type == "uint" {
		return "_u"
	} else if type == "long" {
		return "_L"
	} else if type == "ulong" {
		return "_uL"
	} else if type == "float" {
		return ""
	} else if type == "double" {
		return "_d"
	}
	abandon()
}
