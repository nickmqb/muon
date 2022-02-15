Rule struct #RefType {
	pattern string
	symbolKind SymbolKind
	constType ConstType
	useCast bool
	prefer_cstring bool
	skip bool
	isMatched bool
}

SymbolKind enum {
	none
	any
	function
	struct_
	const
	var
	enum_
}

ConstType enum {
	none
	int_
	uint_
	long_
	ulong_
	sbyte_
	byte_
	short_
	ushort_
	float_
	double_
	cstring_
}

RuleLookupNode struct {
	ch char
	forward int
	next int
	alt int
	star int
	rule Rule
}

RuleParseState struct #RefType {
	source string
	index int
	token string
	line int
	isLineBreak bool
	nodes List<RuleLookupNode>
	errors List<RuleParseError>
}

RuleParseError struct {
	line int
	text string
}

readToken(s RuleParseState) {
	s.isLineBreak = false
	ch := s.source[s.index]
	while true {
		while ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
			if ch == '\n' {
				s.line += 1
				s.isLineBreak = true
			}
			s.index += 1
			ch = s.source[s.index]
		}
		if ch == '\0' {
			s.isLineBreak = true
			s.token = ""
			return
		}
		if ch == '/' && s.source[s.index + 1] == '/' {
			s.index += 2
			ch = s.source[s.index]
			while ch != '\0' && ch != '\n' {
				s.index += 1
				ch = s.source[s.index]
			}
		} else {
			break
		}
	}
	from := s.index
	ch = s.source[s.index]
	while !(ch == '\0' || ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
		s.index += 1
		ch = s.source[s.index]
	}
	s.token = s.source.slice(from, s.index)
}

makeError(s RuleParseState, text string) {
	return RuleParseError { text: text, line: s.line }
}

getSymbolKind(s string) {
	if s == "any" {
		return SymbolKind.any
	} else if s == "fun" {
		return SymbolKind.function
	} else if s == "struct" {
		return SymbolKind.struct_
	} else if s == "enum" {
		return SymbolKind.enum_
	} else if s == "const" {
		return SymbolKind.const
	} else if s == "var" {
		return SymbolKind.var
	}
	return SymbolKind.none
}

getConstType(s string) {
	if s == "sbyte" {
		return ConstType.sbyte_
	} else if s == "byte" {
		return ConstType.byte_
	} else if s == "short" {
		return ConstType.short_
	} else if s == "ushort" {
		return ConstType.ushort_
	} else if s == "int" {
		return ConstType.int_
	} else if s == "uint" {
		return ConstType.uint_
	} else if s == "long" {
		return ConstType.long_
	} else if s == "ulong" {
		return ConstType.ulong_
	} else if s == "float" {
		return ConstType.float_
	} else if s == "double" {
		return ConstType.double_
	} else if s == "cstring" {
		return ConstType.cstring_
	}
	return ConstType.none
}

parseRule(s RuleParseState) {
	rule := new Rule{}
	done := false
	first := s.token

	if first == "struct" || first == "union" || first == "enum" {
		readToken(s)
		if !s.isLineBreak {
			rule.pattern = format("{} {}", first, s.token)
			rule.symbolKind = first != "enum" ? SymbolKind.struct_ : SymbolKind.enum_
			readToken(s)
		} else {
			s.errors.add(makeError(s, "Expected: identifier"))
			done = true
		}
	} else {
		rule.pattern = first
		readToken(s)
	}

	if !done && s.isLineBreak {
		if rule.symbolKind == SymbolKind.none {
			rule.symbolKind = SymbolKind.any
		}
		done = true
	}

	if !done && !s.isLineBreak {
		symbolKind := getSymbolKind(s.token)
		if rule.symbolKind == SymbolKind.none {
			if symbolKind != SymbolKind.none {
				rule.symbolKind = symbolKind
				readToken(s)
			} else {
				rule.symbolKind = SymbolKind.any
			}
		} else {
			if symbolKind != SymbolKind.none && symbolKind != rule.symbolKind {
				s.errors.add(makeError(s, format("Inconsistent symbol kind: {}", s.token)))
				readToken(s)
			}
		}

		if (rule.symbolKind == SymbolKind.function || rule.symbolKind == SymbolKind.struct_) && !s.isLineBreak && s.token == "prefer_cstring" {
			rule.prefer_cstring = true
			readToken(s)
		} else if rule.symbolKind == SymbolKind.const {
			if !s.isLineBreak {
				if s.token == "cast" {
					rule.useCast = true
					readToken(s)
				}
			}
			if !s.isLineBreak {
				type := getConstType(s.token)
				if type != ConstType.none {
					rule.constType = type
				} else {
					s.errors.add(makeError(s, format("Invalid constant type: {}", s.token)))
				}
				readToken(s)
			}
		}
		
		if !s.isLineBreak {
			if s.token == "skip" {
				rule.skip = true
				readToken(s)
			}
		}		
	}

	while !s.isLineBreak {
		if s.token == "" {
			break
		}
		s.errors.add(makeError(s, format("Unexpected token: {}", s.token)))
		readToken(s)
	}

	return rule
}

findNextNode(ch char, index int, nodes List<RuleLookupNode>) {
	i := nodes[index].forward
	while true {
		f := ref nodes[i]
		if f.ch == ch {
			return i
		}
		if f.next == 0 {
			return 0
		}
		i = f.next
	}
}

matchRuleByKind(k int, kind SymbolKind, nodes List<RuleLookupNode>) Rule {
	while k != 0 {		
		rule := nodes[k].rule
		if rule == null {
			break
		}
		if rule.symbolKind == SymbolKind.any || rule.symbolKind == kind {
			return rule
		}
		k = nodes[k].alt
	}
	return null
}

findRule(s string, k int, kind SymbolKind, nodes List<RuleLookupNode>) Rule {
	if s.length == 0 {
		if nodes[k].rule != null {
			rule := matchRuleByKind(k, kind, nodes)
			if rule != null {
				return rule
			}
		}
		if nodes[k].star != 0 {
			return matchRuleByKind(nodes[k].star, kind, nodes)
		}
		return null
	}
	ch := s[0]
	s = s.slice(1, s.length)
	next := findNextNode(ch, k, nodes)
	if next != 0 {
		rule := findRule(s, next, kind, nodes)
		if rule != null {
			return rule
		}
	}
	next = nodes[k].star
	if next != 0 {
		for j := 0; j <= s.length {
			rule := findRule(s.slice(j, s.length), next, kind, nodes)
			if rule != null {
				return rule
			}
		}
	}
	return null
}

addNode(ch char, index int, nodes List<RuleLookupNode>) {
	if nodes[index].forward == 0 {
		k := nodes.count
		nodes.add(RuleLookupNode { ch: ch })
		nodes[index].forward = k
		return k
	} else {
		index = nodes[index].forward
		while true {
			f := ref nodes[index]
			if f.ch == ch {
				return index
			}
			if f.next == 0 {
				break
			}
			index = f.next
		}
		k := nodes.count
		nodes.add(RuleLookupNode { ch: ch })
		nodes[index].next = k
		return k
	}
}

addRule(rule Rule, nodes List<RuleLookupNode>, s RuleParseState, ruleLine int) {
	pattern := rule.pattern
	hasStar := false
	k := 0
	for i := 0; i < pattern.length {
		ch := pattern[i]
		if ch == '*' {
			if !hasStar {
				if nodes[k].star != 0 {
					k = nodes[k].star
				} else {
					star := nodes.count
					nodes.add(RuleLookupNode{})
					nodes[k].star = star
					k = star
				}
			} else {
				s.errors.add(RuleParseError { text: "At most one * is allowed per rule", line: ruleLine })
			}
			hasStar = true
		} else {
			k = addNode(ch, k, nodes)
		}
	}
	if nodes[k].rule != null {
		while nodes[k].alt != 0 {
			k = nodes[k].alt
		}
		alt := nodes.count
		nodes.add(RuleLookupNode{})
		nodes[k].alt = alt
		k = alt
	}
	nodes[k].rule = rule
}

ParseRulesResult struct {
	rules List<Rule>
	lookup List<RuleLookupNode>
}

parseRules(s string, errors List<RuleParseError>) {
	sb := StringBuilder{}
	sb.write(s)
	sb.writeChar('\0')

	rules := new List<Rule>{}
	lookup := new List<RuleLookupNode>{}
	lookup.add(RuleLookupNode{})

	st := new RuleParseState { source: sb.toString(), index: 0, nodes: lookup, errors: errors }
	readToken(st)

	while st.token != "" {
		ruleLine := st.line
		rule := parseRule(st)
		if rule.pattern == "" {
			continue
		}
		rules.add(rule)
		addRule(rule, lookup, st, ruleLine)
		
		//Stdout.writeLine(format("{} {}", rule.pattern, cast(rule.type, uint)))
	}

	return ParseRulesResult { rules: rules, lookup: lookup }
}

defaultRuleLookup() {
	result := new List<RuleLookupNode>{}
	result.add(RuleLookupNode { star: 1 })
	result.add(RuleLookupNode { ch: '*', rule: new Rule { pattern: "*", symbolKind: SymbolKind.any } })
	return result
}
