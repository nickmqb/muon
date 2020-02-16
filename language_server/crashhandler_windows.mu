:crashAllocator IAllocator #Mutable

// This is a temporary workaround for: https://github.com/nickmqb/muon/issues/31
MINIDUMP_EXCEPTION_INFORMATION struct {
	ThreadId uint
	ExceptionPointers_0 uint
	ExceptionPointers_1 uint
	ClientPointers int
}

UIntPair struct {
	first uint
	second uint
}

enableCrashHandler() {
	assert(AddVectoredExceptionHandler(1, pointer_cast(crashHandler, pointer)) != null)
	::crashAllocator = Memory.newArenaAllocator(64 * 1024)
}

crashHandler(info *EXCEPTION_POINTERS) int #CallingConvention("__stdcall") {
	::currentAllocator = ::crashAllocator
	threadId := GetCurrentThreadId()
	debugMessage(format("Entering crash handler (thread {}) {}\n", threadId, info.ExceptionRecord.ExceptionCode))
	info_ := transmute(info, UIntPair)
	mei := MINIDUMP_EXCEPTION_INFORMATION { ThreadId: threadId, ExceptionPointers_0: info_.first, ExceptionPointers_1: info_.second, ClientPointers: 1 }
	if ::crashDumpPath != "" {
		writeCrashDump(::crashDumpPath, ref mei)
	}
	return EXCEPTION_CONTINUE_SEARCH
}

writeCrashDump(path string, exceptionData *MINIDUMP_EXCEPTION_INFORMATION) {
	::currentAllocator = ::crashAllocator
	file := CreateFileA(path.alloc_cstring(), GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, null)
	if file == null {
		debugMessage("Failed to write crash dump: could not open file\n")
		return
	}
	process := GetCurrentProcess()
	processId := GetCurrentProcessId()
	//if MiniDumpWriteDump(process, processId, file, MINIDUMP_TYPE.MiniDumpWithFullMemory, exceptionData, null, null) != 0 {
	if MiniDumpWriteDump(process, processId, file, MINIDUMP_TYPE.MiniDumpNormal, exceptionData, null, null) != 0 {
		debugMessage("Crash dump written\n")
	} else {
		debugMessage(format("Failed to write crash dump: MiniDumpWriteDump failed with error code {}.\n", GetLastError()))
	}
	CloseHandle(file)
}
