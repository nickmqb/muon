Path {
	:filePrefix = "file:///"

	equals(a string, b string) {
		return string.compare_ignoreCase(a, b) == 0
	}

	isAbsolutePath(s string) {
		return s.length >= 2 && isLetter_(s[0]) && s[1] == ':'
	}

	isLetter_(ch char) {
		return ('A' <= ch && ch <= 'Z') || ('a' <= ch && ch <= 'z')
	}
}
