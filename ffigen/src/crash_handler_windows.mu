DebugBreak() void #Foreign("DebugBreak")

abandonHandler(code int) {
	DebugBreak()
	Stderr.writeLine("Abandoned")
	exit(1)
}

readline2x() {
	Stdin.tryReadLine()
	Stdin.tryReadLine()
}

enableCrashHandler() {
	::abandonFn = abandonHandler
	::currentAllocator = Memory.newArenaAllocator(64 * 1024)
	//readline2x()
}
