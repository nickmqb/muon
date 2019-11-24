Path {
	:filePrefix = "file://"

	equals(a string, b string) {
		return string.equals(a, b)
	}

	isAbsolutePath(s string) {
		return s.startsWith("/")
	}
}