CompileArgs struct #RefType {
	:compilerVersion = "0.3.3"
	
	sources List<SourceInfo>
	includeFile string
	outputFile string
	target64bit bool
	noEntryPoint bool
	buildCommand string	
	runCommand string
	maxErrors int
	printStats bool
	printVersion bool
	printHelp bool
}

SourceInfo struct {
	path string
	source string
}

ArgsParserState struct #RefType {
	args CompileArgs
	resolvePath fun<string, pointer, string>
	resolvePathUserData pointer
	includedPaths Set<string>
	commandLineParser CommandLineArgsParser
	path string
	source string
	index int
	token string
	tokenSpan IntRange
	errors List<ArgsParserError>
}

ArgsParserError struct {
	path string
	commandLineError CommandLineArgsParserError
	source string
	span IntRange
	text string
}

ArgsParserResult struct {
	args CompileArgs
	commandLineInfo CommandLineInfo
}

ArgsParser {
	parse(args Array<string>, errors List<ArgsParserError>) {
		commandLineParser := new CommandLineArgsParser.from(args, null)

		s := new ArgsParserState {
			args: new CompileArgs { sources: new List<SourceInfo>{}, maxErrors: 25, includeFile: "external.h", outputFile: "out.c" },
			includedPaths: new Set.create<string>(),
			commandLineParser: commandLineParser,
			errors: errors,
		}
		
		readToken(s)
		if s.token != "" {
			parseArgs(s)
		} else {
			s.args.printHelp = true
		}			
		
		return ArgsParserResult { args: s.args, commandLineInfo: commandLineParser.getCommandLineInfo() }
	}

	parseArgsFile(path string, errors List<ArgsParserError>, resolvePath fun<string, pointer, string>, resolvePathUserData pointer) {
		s := new ArgsParserState {			
			args: new CompileArgs { sources: new List<SourceInfo>{}, maxErrors: 25, includeFile: "external.h", outputFile: "out.c" },
			resolvePath: resolvePath,
			resolvePathUserData: resolvePathUserData,
			includedPaths: new Set.create<string>(),
			errors: errors,
		}

		parseArgsFileImpl(s, path)

		return s.args
	}
	
	parseArgs(s ArgsParserState) {
		while s.token != "" {
			if s.token == "--args" {
				parseArgsFileFlag(s)
			} else if s.token == "--include-file" {
				parseIncludeFile(s)
			} else if s.token == "--output-file" {
				parseOutputFile(s)
			} else if s.token == "-m32" {
				s.args.target64bit = false
				readToken(s)
			} else if s.token == "-m64" {
				s.args.target64bit = true
				readToken(s)
			} else if s.token == "--no-entry-point" {
				s.args.noEntryPoint = true
				readToken(s)
			} else if s.token == "--build-command" {
				parseBuildCommand(s)
			} else if s.token == "--run-command" {
				parseRunCommand(s)
			} else if s.token == "--max-errors" {
				parseMaxErrors(s)
			} else if s.token == "--print-stats" {
				s.args.printStats = true
				readToken(s)
			} else if s.token == "--version" {
				s.args.printVersion = true
				readToken(s)
			} else if s.token == "--help" {
				s.args.printHelp = true
				readToken(s)
			} else if !s.token.startsWith("--") {
				parseSourceFile(s)
			} else {
				error(s, format("Invalid flag: {}", s.token))
				readToken(s)
			}
		}
	}
	
	parseArgsFileFlag(s ArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "filename")
			return
		}
		parseArgsFileImpl(s, s.token)
		readToken(s)
	}

	parseArgsFileImpl(s ArgsParserState, path string) {
		assert(path != "")
		if s.includedPaths.contains(path) {
			error(s, format("Args file has already been included: {}", path))
			return
		}
		
		s.includedPaths.add(path)
		
		sb := StringBuilder{}
		fullPath := s.resolvePath != null ? s.resolvePath(path, s.resolvePathUserData) : path
		if !File.tryReadToStringBuilder(fullPath, ref sb) {
			error(s, format("Cannot open args file: {}", fullPath))
			return
		}
		sb.write("\0")
		
		prevPath := s.path
		prevSource := s.source
		prevIndex := s.index

		s.path = path
		s.source = sb.toString()
		s.index = 0
		readToken(s)
		parseArgs(s)

		s.path = prevPath
		s.source = prevSource
		s.index = prevIndex		
	}
	
	parseIncludeFile(s ArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "filename")
			return
		} else {
			s.args.includeFile = s.token
		}
		readToken(s)
	}

	parseOutputFile(s ArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "filename")
			return
		} else {
			s.args.outputFile = s.token
		}
		readToken(s)
	}
	
	parseBuildCommand(s ArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "command")			
			return
		} else {
			s.args.buildCommand = s.token
		}
		readToken(s)
	}
	
	parseRunCommand(s ArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "command")			
			return
		} else {
			s.args.runCommand = s.token
		}
		readToken(s)
	}
	
	parseMaxErrors(s ArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "number")
			return
		}
		pr := long.tryParse(s.token)
		if !pr.hasValue || pr.value <= 0 || pr.value > int.maxValue {
			error(s, "Expected: number")
		}
			
		s.args.maxErrors = cast(pr.value, int)
		readToken(s)
	}
	
	parseSourceFile(s ArgsParserState) {
		path := s.token
		sb := StringBuilder{}
		fullPath := s.resolvePath != null ? s.resolvePath(path, s.resolvePathUserData) : path
		if !File.tryReadToStringBuilder(fullPath, ref sb) {
			error(s, format("Cannot open source file: {}", fullPath))
			readToken(s)
			return
		}
		sb.write("\0")
		s.args.sources.add(SourceInfo { path: path, source: sb.toString() })
		readToken(s)
	}
	
	expected(s ArgsParserState, text string) {
		text = format("Expected: {}", text)
		if s.path == "" {
			s.errors.add(ArgsParserError { commandLineError: CommandLineArgsParserError { index: s.commandLineParser.index, text: text }, text: text })
		} else {
			s.errors.add(ArgsParserError { path: s.path, source: s.source, span: IntRange(s.tokenSpan.from, s.tokenSpan.from), text: text })
		}
	}
	
	error(s ArgsParserState, text string) {
		if s.path == "" {
			if s.commandLineParser != null {
				parser := s.commandLineParser
				arg := parser.args[parser.index - 1]
				s.errors.add(ArgsParserError { commandLineError: CommandLineArgsParserError { index: parser.index - 1, innerSpan: IntRange(0, arg.length), text: text }, text: text })
			} else {
				s.errors.add(ArgsParserError { text: text })
			}
		} else {
			s.errors.add(ArgsParserError { path: s.path, source: s.source, span: s.tokenSpan, text: text })
		}
	}
	
	readToken(s ArgsParserState) {
		if s.path == "" {
			s.token = s.commandLineParser.readToken()
			return
		}
		while isWhitespaceChar(s.source[s.index]) {
			s.index += 1
		}
		if s.source[s.index] == '[' && s.source[s.index + 1] == '[' {
			rb := StringBuilder{}
			s.index += 2
			while isWhitespaceChar(s.source[s.index]) {
				s.index += 1
			}
			from := s.index
			next := 0
			while true {
				ch := s.source[s.index]
				if ch == '\0' {
					next = s.index
					break
				} else if ch == '\n' || ch == '\r' || ch == '\t' {					
					ch = ' '
				} else if ch == ']' && s.source[s.index + 1] == ']' {
					next = s.index + 2
					break
				}
				rb.writeChar(ch)
				s.index += 1
			}
			to := s.index
			while to > from && isWhitespaceChar(s.source[to - 1]) {
				to -= 1
			}
			s.token = rb.toString().slice(0, to - from)
			s.tokenSpan = IntRange(from, to)
			s.index = next
		} else {
			quote := false
			if s.source[s.index] == '"' {
				quote = true
				s.index += 1				
			}
			from := s.index			
			next := 0
			while true {
				ch := s.source[s.index]
				if ch == '"' && quote {
					next = s.index + 1
					break
				} else if ch == ' ' && !quote {
					next = s.index + 1
					break
				} else if ch == '\n' || ch == '\r' || ch == '\0' {
					next = s.index
					break
				} else {
					s.index += 1
				}
			}
			s.token = s.source.slice(from, s.index)
			s.tokenSpan = IntRange(from, s.index)
			s.index = next
		}
	}
	
	isWhitespace(s string) {
		for i := 0; i < s.length {
			if !isWhitespaceChar(s[i]) {
				return false			
			}
		}
		return true
	}
	
	isWhitespaceChar(ch char) {
		return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
	}
}
