CompileArgs struct #RefType {
	:compilerVersion = "0.3.0"
	
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
	result CompileArgs
	includedPaths Set<string>
	path string
	source string
	index int
	token string
	tokenSpan IntRange
	errors List<ArgsParserError>
}

ArgsParserError struct {
	path string
	source string
	span IntRange
	text string
}

ArgsParser {
	parse(args Array<string>, errors List<ArgsParserError>) {
		// Reconstruct original command line string (skip over binary name).
		// This is kind of hacky, because the shell may have already made changes to the string (e.g. it may have removed quotes), which we now try to undo.
		// TODO: Get raw command line string from the OS and parse that (unfortunately no good cross platform way to do this).
		sb := new StringBuilder{}
		insertSep := false
		for i := 1; i < args.count {
			if insertSep {
				sb.write(" ")
			} else {
				insertSep = true
			}
			a := args[i]
			if a.indexOfChar(' ') >= 0 {
				sb.write("\"")
				sb.write(a)
				sb.write("\"")
			} else {
				sb.write(a)
			}
		}
		sb.write("\0")
		
		s := new ArgsParserState {			
			result: new CompileArgs { sources: new List<SourceInfo>{}, maxErrors: 25, includeFile: "external.h", outputFile: "out.c" },
			includedPaths: new Set.create<string>(),
			source: sb.toString(),
			errors: errors,
		}
		
		readToken(s)
		if s.token != "" {
			parseArgs(s)
		} else {
			s.result.printHelp = true
		}			
		
		return s.result
	}
	
	parseArgs(s ArgsParserState) {
		while s.token != "" {
			if s.token == "--args" {
				parseArgsFile(s)
			} else if s.token == "--include-file" {
				parseIncludeFile(s)
			} else if s.token == "--output-file" {
				parseOutputFile(s)
			} else if s.token == "-m32" {
				s.result.target64bit = false
				readToken(s)
			} else if s.token == "-m64" {
				s.result.target64bit = true
				readToken(s)
			} else if s.token == "--no-entry-point" {
				s.result.noEntryPoint = true
				readToken(s)
			} else if s.token == "--build-command" {
				parseBuildCommand(s)
			} else if s.token == "--run-command" {
				parseRunCommand(s)
			} else if s.token == "--max-errors" {
				parseMaxErrors(s)
			} else if s.token == "--print-stats" {
				s.result.printStats = true
				readToken(s)
			} else if s.token == "--version" {
				s.result.printVersion = true
				readToken(s)
			} else if s.token == "--help" {
				s.result.printHelp = true
				readToken(s)
			} else if !s.token.startsWith("--") {
				parseSourceFile(s)
			} else {
				error(s, format("Invalid flag: {}", s.token))
				readToken(s)
			}
		}
	}
	
	parseArgsFile(s ArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "filename")
			return
		}
		
		path := s.token
		if s.includedPaths.contains(path) {
			error(s, format("Args file has already been included: {}", path))
			readToken(s)
			return
		}
		
		s.includedPaths.add(path)
				
		sb := StringBuilder{}
		if !File.tryReadToStringBuilder(path, ref sb) {
			error(s, format("Cannot open args file: ", path))
			readToken(s)
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
		readToken(s)
	}
	
	parseIncludeFile(s ArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "filename")
			return
		} else {
			s.result.includeFile = s.token
		}
		readToken(s)
	}

	parseOutputFile(s ArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "filename")
			return
		} else {
			s.result.outputFile = s.token
		}
		readToken(s)
	}
	
	parseBuildCommand(s ArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "command")			
			return
		} else {
			s.result.buildCommand = s.token
		}
		readToken(s)
	}
	
	parseRunCommand(s ArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "command")			
			return
		} else {
			s.result.runCommand = s.token
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
			
		s.result.maxErrors = cast(pr.value, int)
		readToken(s)
	}
	
	parseSourceFile(s ArgsParserState) {
		path := s.token
		sb := StringBuilder{}
		if !File.tryReadToStringBuilder(path, ref sb) {
			error(s, format("Cannot open source file: {}", path))
			readToken(s)
			return
		}
		sb.write("\0")
		s.result.sources.add(SourceInfo { path: path, source: sb.toString() })
		readToken(s)
	}
	
	expected(s ArgsParserState, text string) {
		s.errors.add(ArgsParserError { path: s.path, source: s.source, span: IntRange(s.tokenSpan.from, s.tokenSpan.from), text: format("Expected: {}", text) })
	}
	
	error(s ArgsParserState, text string) {
		s.errors.add(ArgsParserError { path: s.path, source: s.source, span: s.tokenSpan, text: text })
	}
	
	readToken(s ArgsParserState) {
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
