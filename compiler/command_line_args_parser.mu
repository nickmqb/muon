CommandLineArgsParser struct #RefType {
	index int
	args Array<string>
	errors List<CommandLineArgsParserError>
}

CommandLineArgsParserError struct {
	index int
	innerSpan IntRange
	text string
}

CommandLineInfo struct {
	text string
	argSpans Array<IntRange>
}

CommandLineArgsParser {
	from(args Array<string>, errors List<CommandLineArgsParserError>) {
		assert(args.count >= 1)
		return CommandLineArgsParser { index: 1, args: args, errors: errors }
	}

	readToken(self CommandLineArgsParser) {
		if self.index >= self.args.count {
			return ""
		}
		result := self.args[self.index]
		self.index += 1
		return result
	}

	expected(self CommandLineArgsParser, text string) {
		self.errors.add(CommandLineArgsParserError { index: self.index, text: format("Expected: {}", text) })
	}

	error(self CommandLineArgsParser, text string) {
		arg := self.args[self.index - 1]
		self.errors.add(CommandLineArgsParserError { index: self.index - 1, innerSpan: IntRange(0, arg.length), text: text })
	}

	getCommandLineInfo(self CommandLineArgsParser) {
		result := CommandLineInfo { argSpans: new Array<IntRange>(self.args.count) }

		sb := new StringBuilder{}
		insertSep := false
		for i := 0; i < self.args.count {
			if insertSep {
				sb.write(" ")
			} else {
				insertSep = true
			}
			a := self.args[i]
			from := sb.count
			delta := 0
			if a.indexOfChar(' ') >= 0 {
				sb.write("\"")
				sb.write(a)
				sb.write("\"")
				delta = 1
			} else {
				sb.write(a)
			}

			result.argSpans[i] = IntRange(from + delta, sb.count - delta)
		}

		result.text = sb.toString()
		return result
	}

	getNumColumns_(s string, tabSize int) {
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

	getErrorDesc(e CommandLineArgsParserError, info CommandLineInfo) {
		span := IntRange{}
		extraSpaces := 0
		if e.index >= info.argSpans.count {
			at := info.argSpans[info.argSpans.count - 1].to
			span = IntRange(at, at)
			extraSpaces = 1
		} else {
			offset := info.argSpans[e.index].from 
			span = IntRange(offset + e.innerSpan.from, offset + e.innerSpan.to)
		}
		indent := getNumColumns_(info.text.slice(0, span.from), 4) + extraSpaces
		width := getNumColumns_(info.text.slice(span.from, span.to), 4) + extraSpaces
		return format("{}\n{}\n{}{}",
			e.text,
			info.text.replace("\t", "    "),
			string.repeatChar(' ', indent),
			string.repeatChar('~', max(1, width)))
	}
}
