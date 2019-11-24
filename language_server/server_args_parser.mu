ServerArgs struct #RefType {
	argsPath string
	logPort int
	logStderr bool
	logFile bool
}

ServerArgsParserState struct #RefType {
	result ServerArgs
	source string
	index int
	token string
	tokenSpan IntRange
	errors List<ArgsParserError>
}

ServerArgsParser {
	parse(args string, errors List<ArgsParserError>) {
		sb := StringBuilder{}
		sb.write(args)
		sb.writeChar('\0')

		s := new ServerArgsParserState {			
			result: new ServerArgs{},
			source: sb.toString(),
			errors: errors,
		}
		
		readToken(s)
		parseArgs(s)
		
		return s.result
	}

	parseArgs(s ServerArgsParserState) {
		args := false

		while s.token != "" {
			if s.token == "--args" {
				parseArgsPathFlag(s)
				args = true
			} else if s.token == "--log-port" {
				parseLogPortFlag(s)
			} else if s.token == "--log-stderr" {
				readToken(s)
				s.result.logStderr = true
			} else if s.token == "--log-file" {
				readToken(s)
				s.result.logFile = true
			} else {
				error(s, format("Invalid flag: {}", s.token))
				readToken(s)
			}
		}
		
		if !args {
			expected(s, "--args [path]")
		}
	}
	
	parseArgsPathFlag(s ServerArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "path")
			return
		}
		s.result.argsPath = s.token
		readToken(s)
	}

	parseLogPortFlag(s ServerArgsParserState) {
		readToken(s)
		if s.token == "" {
			expected(s, "port number")
			return
		}
		port := int.tryParse(s.token)
		if port.hasValue {
			s.result.logPort = port.unwrap()
		} else {
			error(s, "Expected: number")
		}
		readToken(s)
	}

	expected(s ServerArgsParserState, text string) {
		s.errors.add(ArgsParserError { source: s.source, span: IntRange(s.tokenSpan.from, s.tokenSpan.from), text: format("Expected: {}", text) })
	}
	
	error(s ServerArgsParserState, text string) {
		s.errors.add(ArgsParserError { source: s.source, span: s.tokenSpan, text: text })
	}
	
	readToken(s ServerArgsParserState) {
		while isWhitespaceChar(s.source[s.index]) {
			s.index += 1
		}
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
	
	isWhitespaceChar(ch char) {
		return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
	}
}
