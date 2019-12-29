Args struct {
	sourcePath string
	clangArgs string
	rulesPath string
	outputPath string
	includePaths List<string>
	isPlatformAgnostic bool
}

parseArgs(parser CommandLineArgsParser) {
	args := Args { includePaths: new List<string>{} }

	hasSource := false
	hasOutput := false

	token := parser.readToken()
	
	while token != "" {
		if token == "--source" {
			hasSource = true
			args.sourcePath = parseString(parser, "path")
		} else if token == "--clang-args" {
			args.clangArgs = parseString(parser, "path")
		} else if token == "--rules" {
			args.rulesPath = parseString(parser, "path")
		} else if token == "--output" {
			hasOutput = true
			args.outputPath = parseString(parser, "path")
		} else if token == "--include-path" {
			path := parseString(parser, "path")
			if path != "" {
				args.includePaths.add(path)
			}
		} else if token == "--platform-agnostic" {
			args.isPlatformAgnostic = true
		} else {
			parser.error(format("Invalid flag: {}", token))
		}
		token = parser.readToken()
	}

	if !hasSource {
		parser.expected("--source [path]")
	}
	if !hasOutput {
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