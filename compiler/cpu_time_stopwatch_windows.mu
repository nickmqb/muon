LARGE_INTEGER struct {
	QuadPart ulong
}

QueryPerformanceCounter(lpPerformanceCount *LARGE_INTEGER #As("LARGE_INTEGER *")) bool32 #Foreign("QueryPerformanceCounter")
QueryPerformanceFrequency(lpFrequency *LARGE_INTEGER #As("LARGE_INTEGER *")) bool32 #Foreign("QueryPerformanceFrequency")

CpuTimeStopwatch {
	:invQpcFreq double #ThreadLocal #Mutable
	:qpcStartCount ulong #ThreadLocal #Mutable
	
	start() {
		if invQpcFreq == cast(0, double) {
			freq := LARGE_INTEGER{}
			assert(QueryPerformanceFrequency(ref freq))
			assert(freq.QuadPart != 0)
			invQpcFreq = cast(1, double) / freq.QuadPart
		}
		count := LARGE_INTEGER{}
		assert(QueryPerformanceCounter(ref count))
		qpcStartCount = count.QuadPart
	}
	
	// Note: this actually returns wall clock time
	elapsed() {
		count := LARGE_INTEGER{}
		assert(QueryPerformanceCounter(ref count))
		return (count.QuadPart - qpcStartCount) * invQpcFreq
	}
}
