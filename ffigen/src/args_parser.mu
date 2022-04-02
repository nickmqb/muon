Args struct {
	sourcePath string
	rulesPath string
	outputPath string
	validationPath string
	clangArgs List<string>
	isPlatformAgnostic bool
	collisionCheck bool
}

parseArgs(parser CommandLineArgsParser) {
	args := Args { clangArgs: new List<string>{} }

	token := parser.readToken()
	
	while token != "" {
		if token == "--source" {
			args.sourcePath = parseString(parser, "path")
		} else if token == "--rules" {
			args.rulesPath = parseString(parser, "path")
		} else if token == "--output" {
			args.outputPath = parseString(parser, "path")
		} else if token == "--validation" {
			args.validationPath = parseString(parser, "path")
		} else if token == "--clang-arg" {
			arg := parseString(parser, "argument")
			if arg != "" {
				args.clangArgs.add(arg)
			}
		} else if token == "--platform-agnostic" {
			args.isPlatformAgnostic = true
		} else if token == "--collision-check" {
			args.collisionCheck = true
		} else {
			parser.error(format("Invalid flag: {}", token))
		}
		token = parser.readToken()
	}

	if args.sourcePath == "" {
		parser.expected("--source [path]")
	}
	if args.rulesPath == "" {
		parser.expected("--rules [path]")
	}
	if args.outputPath == "" {
		parser.expected("--output [path]")
	}

	return args
}

parseString(parser CommandLineArgsParser, desc string) {
	token := parser.readToken()
	if token == "" {
		parser.expected(desc)
	}
	return token
}
