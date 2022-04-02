AppState struct #RefType {
	clangTranslationUnit pointer
	isPlatformAgnostic bool
	collisionCheck bool
	rules List<Rule>
	ruleLookup RuleLookupNode
	symbols Map<string, Sym>
	anonymousStructs Set<CXType>
	enums Set<CXType>
	macroDefinitions List<string>
	macroDefinitionsSet Set<string>
	output StringBuilder
	validationOutput StringBuilder
	platform string
	targetBits string
}

Rule struct #RefType {
	pattern string
	symbolKind SymbolKind
	constType string
	useCast bool
	prefer_cstring bool
	checkMacroAliases bool
	skip bool
	matched bool
}

RuleLookupNode struct #RefType {
	rules List<Rule>
	edges List<RuleLookupEdge>
	star RuleLookupNode
}

RuleLookupEdge struct {
	ch char
	node RuleLookupNode
}

SymbolKind enum {
	any
	function
	struct_
	const
	var
	enum_
	functionPointer
}

Sym struct #RefType {
	muName string
	cName string
	done bool
	done_noForce bool
	kind SymbolKind
	isZeroSizeStruct bool
	aliases List<string>
	macroAliases List<string>
}

getSym(name string, symbols Map<string, Sym>) {
	sym := symbols.getOrDefault(name)
	if sym == null {
		sym = new Sym {}
		symbols.add(name, sym)
	}
	return sym
}
