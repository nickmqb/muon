CpuTimeStopwatch {	
	clock() int #Foreign("clock")
	
	:CLOCKS_PER_SEC int #Foreign("CLOCKS_PER_SEC")
	
	:startClock int #ThreadLocal #Mutable
	
	start() {
		startClock = clock()
	}
	
	elapsed() {
		endClock := clock()
		elapsed := cast(endClock - startClock, uint)
		return elapsed / cast(CLOCKS_PER_SEC, double)
	}
}
