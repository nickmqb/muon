Debug {
	break() {
		abandon()
	}
}

Environment {
	system(command cstring) int #Foreign("system")
	exit(status int) void #Foreign("exit")
	
	runCommandSync(command string) int {
		return system(command.alloc_cstring())
	}
}

LocationInfo struct {
	line int
	span IntRange
	columnSpan IntRange
	lineText string	
}

ErrorHelper {
	// TODO PERF: This is O(N), so it's not ideal to call this from within a loop.
	spanToLocationInfo(source string, span IntRange) {
		assert(span.from <= span.to)
		from := span.from
		lines := 0
		lineStart := 0
		i := 0
		while i < from {
			ch := source[i]
			if ch == '\n' {
				lines += 1
				lineStart = i + 1
			}
			i += 1
		}
		i = from
		lineEnd := 0
		while true {
			ch := source[i]
			if ch == '\n' || ch == '\r' || ch == '\0' {
				lineEnd = i
				break
			}
			i += 1
		}
		to := min(span.to, lineEnd)
		return LocationInfo { 
			line: lines + 1,
			span: IntRange(from, to),
			columnSpan: IntRange(from - lineStart, to - lineStart),
			lineText: source.slice(lineStart, lineEnd)
		}
	}
	
	getNumColumns(s string, tabSize int) {
		cols := 0
		for i := 0; i < s.length {
			if s[i] == '\t' {
				cols += tabSize
			} else {
				cols += 1
			}
		}
		return cols
	}

	getErrorDesc(path string, source string, span IntRange, text string) {
		li := spanToLocationInfo(source, span)
		indent := getNumColumns(li.lineText.slice(0, li.columnSpan.from), 4)
		width := getNumColumns(li.lineText.slice(li.columnSpan.from, li.columnSpan.to), 4)
		pathInfo := path != "" ? format("\n-> {}:{}", path, li.line) : ""
		return format("{}{}\n{}\n{}{}",
			text,
			pathInfo,
			li.lineText.replace("\t", "    "),
			string.repeatChar(' ', indent),
			string.repeatChar('~', max(1, width)))
			
	}
	
	compareErrors(a Error, b Error) {
		if a.unit == null {
			return -1
		}
		if b.unit == null {
			return 1
		}
		if a.unit.id != b.unit.id {
			return int.compare(a.unit.id, b.unit.id)
		}
		return int.compare(a.span.from, b.span.from)
	}
}

dumpSymbols(ns Namespace, indent int) {
	for e in ns.members {
		Stdout.writeLine(format("{}{}", string.repeatChar(' ', indent), e.key))
		if e.value.is(Namespace) {
			dumpSymbols(e.value.as(Namespace), indent + 2)
		}
		if e.value.is(StaticFieldDef) && e.value.as(StaticFieldDef).type == null {
			Stdout.writeLine(format("{}{}", string.repeatChar(' ', indent + 2), e.value.as(StaticFieldDef).value))
		}
	}
}

compile(comp Compilation, args CompileArgs) {
	//aa := pointer_cast(::currentAllocator.data, ArenaAllocator)
	//memoryBeforeParse := aa.current

	CpuTimeStopwatch.start()
	for si, id in args.sources {
		//Stdout.writeLine(path)
		
		unit := Parser.parse(si.source, comp.errors)
		unit.path = si.path
		unit.id = id
		comp.units.add(unit)

		//AstPrinter.printAny(new PrintState{}, unit)
	}
	
	parseTime := CpuTimeStopwatch.elapsed()

	//memoryAfterParse := aa.current

	CpuTimeStopwatch.start()
	
	comp.firstTypeCheckErrorIndex = comp.errors.count
	tcc := TypeCheckerFirstPass.createContext(comp)
	if !TypeCheckerFirstPass.check(tcc) {
		return
	}
	
	TypeChecker.check(tcc)
	if !args.noEntryPoint {
		TypeChecker.checkHasEntryPoint(tcc)
	}
	
	typeCheckTime := CpuTimeStopwatch.elapsed()
	CpuTimeStopwatch.start()
	
	if comp.errors.count > 0 {
		return
	}

	expc := new ExpandContext { top: comp.top }
	Expander.expandPass1(expc)
	Expander.expandPass2(expc)
	//Expander.debug(comp.top)
	genc := new CGenerator.createContext(comp)
	if args.target64bit {
		comp.flags |= CompilationFlags.target64bit
	}
	CGenerator.generate(genc, args.includeFile, !args.noEntryPoint, CompileArgs.compilerVersion)

	generateTime := CpuTimeStopwatch.elapsed()

	if comp.errors.count > 0 {
		return
	}
	
	if args.printStats {
		numSourceBytes := 0
		numLines := 0
		for si in args.sources {
			index := si.source.length - 1
			numSourceBytes += index
			li := ErrorHelper.spanToLocationInfo(si.source, IntRange(index, index))
			numLines += li.line
		}
		Stdout.writeLine(format("NumSourceBytes: {}", numSourceBytes))
		//numAstBytes := pointer.subtractSigned(memoryAfterParse, memoryBeforeParse)		
		//Stdout.writeLine(format("NumAstBytes: {}", numAstBytes))
		//Stdout.writeLine(format("NumAstBytes / NumSourceBytes: {}", numAstBytes / cast(numSourceBytes, double)))
		Stdout.writeLine(format("NumLines: {}", numLines))
		CStdlib.printf("Parse: %lfms\n", parseTime * 1000)
		CStdlib.printf("TypeCheck: %lfms\n", typeCheckTime * 1000)
		CStdlib.printf("Generate: %lfms\n", generateTime * 1000)
		CStdlib.printf("Total: %lfms\n", (parseTime + typeCheckTime + generateTime) * 1000)
	}

	if !File.tryWriteString(args.outputFile, genc.out.toString()) {
		comp.errors.add(Error { text: format("Could not write to output file: {}", args.outputFile) })
		return
	}
	
	Stdout.writeLine(format("Generated output: {}", args.outputFile))
	
	if args.buildCommand != "" {
		Stdout.writeLine(format("Running: {}", args.buildCommand))
		exitCode := Environment.runCommandSync(args.buildCommand)
		
		if exitCode != 0 {
			Environment.exit(exitCode)
		}
		
		if args.runCommand != "" {
			exitCode = Environment.runCommandSync(args.runCommand)
			if exitCode != 0 {
				Environment.exit(exitCode)
			}
		}
	}
}

main() {
	::currentAllocator = Memory.newArenaAllocator(256 * 1024 * 1024)
	
	argErrors := new List<ArgsParserError>{}
	argsArray := Environment.getCommandLineArgs()
	argsParseResult := ArgsParser.parse(argsArray, argErrors)
	args := argsParseResult.args

	if args.printVersion || args.printHelp {
		Stdout.writeLine(format("Muon compiler, version {}", CompileArgs.compilerVersion))
		if args.printHelp {
			Stdout.writeLine("For documentation, see: https://github.com/nickmqb/muon")
		}
		Environment.exit(1)
		return
	}
	
	if argErrors.count > 0 {
		for e, i in argErrors {
			if i > 0 {
				Stdout.writeLine("")
			}
			if e.path == "" {
				Stdout.writeLine(CommandLineArgsParser.getErrorDesc(e.commandLineError, argsParseResult.commandLineInfo))
			} else {
				Stdout.writeLine(ErrorHelper.getErrorDesc(e.path, e.source, e.span, e.text))
			}
		}
		Environment.exit(1)
		return
	}
	
	Tag.static_init()

	comp := new Compilation { units: new List<CodeUnit>{}, errors: new List<Error>{} }
	compile(comp, args)
	
	if comp.errors.count > 0 {
		// Sort errors, but always show syntax errors first.
		comp.errors.slice(0, comp.firstTypeCheckErrorIndex).stableSort(ErrorHelper.compareErrors)
		comp.errors.slice(comp.firstTypeCheckErrorIndex, comp.errors.count).stableSort(ErrorHelper.compareErrors)
		
		for e, i in comp.errors {
			if i >= args.maxErrors {
				break
			}
			if i > 0 {
				Stdout.writeLine("")
			}
			if e.unit != null {
				Stdout.writeLine(ErrorHelper.getErrorDesc(e.unit.path, e.unit.source, e.span, e.text))
			} else {
				Stdout.writeLine(e.text)
			}
		}
		if comp.errors.count > args.maxErrors {
			Stdout.writeLine(format("{} errors ({} shown)", comp.errors.count, args.maxErrors))
		} else {
			Stdout.writeLine(format("{} errors", comp.errors.count))
		}
		Environment.exit(1)
	}
	
	//if args.printStats {
	//	aa := pointer_cast(::currentAllocator.data, ArenaAllocator)
	//	Stdout.writeLine(format("Used {} bytes", transmute(aa.current.subtractSigned(aa.from), ulong)))
	//}
}

















