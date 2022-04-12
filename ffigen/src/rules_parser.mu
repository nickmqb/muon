RuleParseError struct {
	line int
	text string
}

StringIndex struct {
	s string
	index int
}

parseRules(text string, errors List<RuleParseError>) {
	result := new List<Rule>{}
	lines := text.split('\n')
	for ln, i in lines {
		rule := parseRule(ln, i, errors)
		if rule != null {
			result.add(rule)
		}
	}
	return result
}

parseRule(text string, line int, errors List<RuleParseError>) {
	si := ref StringIndex { s: text, index: 0 }
	token := readToken(si)	
	if token == "" || token.startsWith("//") {
		return null
	}
	rule := new Rule{}
	category := ""
	if token == "struct" || token == "union" || token == "enum" {
		category = token
		token = readToken(si)
	}
	if token != "" {
		if isValidPattern(token) {
			if category == "" {
				rule.pattern = token
			} else {
				rule.pattern = format("{} {}", category, token)
				rule.symbolKind = category != "enum" ? SymbolKind.struct_ : SymbolKind.enum_
			}
			token = readToken(si)
		} else {
			errors.add(RuleParseError { text: format("Invalid pattern: {}", token), line: line })
			return null
		}
	} else {
		errors.add(RuleParseError { text: "Expected: pattern", line: line })
		return null
	}
	if category == "" {
		if token == "fun" {
			rule.symbolKind = SymbolKind.function
			token = readToken(si)
		} else if token == "struct" {
			rule.symbolKind = SymbolKind.struct_
			token = readToken(si)
		} else if token == "enum" {
			rule.symbolKind = SymbolKind.enum_
			token = readToken(si)
		} else if token == "const" {
			rule.symbolKind = SymbolKind.const
			token = readToken(si)
		} else if token == "var" {
			rule.symbolKind = SymbolKind.var
			token = readToken(si)
		} else if token == "fun_ptr" {
			rule.symbolKind = SymbolKind.functionPointer
			token = readToken(si)
		}		
	}
	if rule.symbolKind == SymbolKind.function {
		if token == "prefer_cstring" {
			rule.prefer_cstring = true
			token = readToken(si)
		}
		if token == "check_macro_aliases" {
			rule.checkMacroAliases = true
			token = readToken(si)
		}
	}
	if rule.symbolKind == SymbolKind.struct_ {
		if token == "prefer_cstring" {
			rule.prefer_cstring = true
			token = readToken(si)
		}
	}	
	if rule.symbolKind == SymbolKind.const {
		if token == "cast" {
			rule.useCast = true
			token = readToken(si)
		}
		if token != "" {
			if isValidMuonConstType(token) {
				rule.constType = token
				token = readToken(si)
			} else {
				errors.add(RuleParseError { text: format("Invalid constant type: {}", token), line: line })
				return null
			}
		}
	}
	if token == "skip" {
		rule.skip = true
		token = readToken(si)
	}
	if token != "" {
		errors.add(RuleParseError { text: format("Unexpected token(s): {}", text.slice(si.index - token.length, text.length)), line: line })
		return null
	}
	return rule
}

isValidPattern(s string) {
	if s == "*" {
		return false
	}
	count := 0
	for i := 0; i < s.length {
		if s[i] == '*' {
			count += 1
		}
	}
	return count <= 1
}

readToken(si *StringIndex) {
	while si.index < si.s.length && si.s[si.index] == ' ' {
		si.index += 1
	}
	if si.index == si.s.length {
		return ""
	}
	from := si.index
	while si.index < si.s.length && (si.s[si.index] != ' ' && si.s[si.index] != '\n' && si.s[si.index] != '\r') {
		si.index += 1
	}
	return si.s.slice(from, si.index)
}

