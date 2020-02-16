ServerArgs struct #RefType {
	argsPath string
	rootPath string
	crashDumpPath string
	logPort int
	logStderr bool
	logFile bool
}

parseArgs(parser CommandLineArgsParser) {
	args := new ServerArgs{}
	hasArgsPath := false

	token := parser.readToken()

	while token != "" {
		if token == "--args" {
			args.argsPath = parsePathFlag(parser)
			hasArgsPath = true
		} else if token == "--root-path" {
			args.rootPath = parsePathFlag(parser)
		} else if token == "--log-port" {
			parseLogPortFlag(args, parser)
		} else if token == "--log-stderr" {
			args.logStderr = true
		} else if token == "--log-file" {
			args.logFile = true
		} else if token == "--crash-dump-path" {
			args.crashDumpPath = parsePathFlag(parser)
		} else {
			parser.error(format("Invalid flag: {}", token))
		}
		token = parser.readToken()
	}
	
	if !hasArgsPath {
		parser.expected("--args [path]")
	}

	return args
}

parsePathFlag(parser CommandLineArgsParser) {
	token := parser.readToken()
	if token == "" {
		parser.expected("path")
	}
	return token
}

parseLogPortFlag(args ServerArgs, parser CommandLineArgsParser) {
	token := parser.readToken()
	if token == "" {
		parser.expected("port number")
		return
	}
	port := int.tryParse(token)
	if port.hasValue {
		args.logPort = port.unwrap()
	} else {
		parser.error("Expected: number")
	}	
}
