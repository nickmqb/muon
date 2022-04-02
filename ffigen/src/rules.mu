buildRuleLookup(rules List<Rule>) {
	root := new RuleLookupNode{}
	for r in rules {
		addRule(root, r.pattern, r)
	}
	return root
}

addRule(node RuleLookupNode, pattern string, rule Rule) {
	if pattern.length == 0 {
		if node.rules == null {
			node.rules = new List<Rule>{}
		}
		node.rules.add(rule)
		return
	}
	ch := pattern[0]
	rest := pattern.slice(1, pattern.length)
	if ch != '*' {
		if node.edges == null {
			node.edges = new List<RuleLookupEdge>{}
		}
		for e in node.edges {
			if e.ch == ch {
				addRule(e.node, rest, rule)
				return
			}
		}
		next := new RuleLookupNode{}
		node.edges.add(RuleLookupEdge { ch: ch, node: next })
		addRule(next, rest, rule)
	} else {
		next := node.star
		if next == null {
			next = new RuleLookupNode{}
			next.star = next
			node.star = next
		}
		addRule(next, rest, rule)
	}
}

findRule(node RuleLookupNode, id string, kind SymbolKind) Rule {
	if id == "" {
		if node.rules != null {
			for r in node.rules {
				if r.symbolKind == SymbolKind.any || r.symbolKind == kind {
					return r
				}
			}
		}
		return null
	}
	ch := id[0]
	rest := id.slice(1, id.length)
	if node.edges != null {
		for e in node.edges {
			if e.ch == ch {
				rule := findRule(e.node, rest, kind)
				if rule != null {
					return rule
				}
			}
		}
	}
	if node.star != null {
		if node.star.edges == null {
			// Fast lookup
			return findRule(node.star, "", kind)
		} else {
			return findRule(node.star, rest, kind)
		}
	}
	return null
}

ruleToString(r Rule) {
	rb := StringBuilder{}
	rb.write(r.pattern)
	if r.symbolKind != SymbolKind.any {
		rb.write(" ")
		rb.write(symbolKindToString(r.symbolKind))
	}
	if r.skip {
		rb.write(" skip")
	}
	return rb.compactToString()
}

symbolKindToString(k SymbolKind) {
	if k == SymbolKind.function {
		return "fun"
	} else if k == SymbolKind.struct_ {
		return "struct"
	} else if k == SymbolKind.enum_ {
		return "enum"
	} else if k == SymbolKind.const {
		return "const"
	} else if k == SymbolKind.var {
		return "var"
	}
	return ""
}

