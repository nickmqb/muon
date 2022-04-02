abandonHandler(code int) {
	Stderr.writeLine("Abandoned")
	exit(1)
}

enableCrashHandler() {
	::abandonFn = abandonHandler
}
