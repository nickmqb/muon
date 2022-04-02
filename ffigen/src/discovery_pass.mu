:generatedConstPrefix = "muon_ffigen_const_"

discoveryPass(cursor CXCursor, parent CXCursor, state AppState) int {
	kind := clang_getCursorKind(cursor)
	if kind == CXCursorKind.CXCursor_UnexposedDecl {
		// This could be an "extern "C"" declaration
		return CXChildVisit_Recurse
	
	} else if kind == CXCursorKind.CXCursor_TypedefDecl {
		type := clang_getCursorType(cursor)
		canonical := unwrapPointerType(clang_getCanonicalType(type))
		if canonical.numPtr != 0 {
			return CXChildVisit_Continue
		}

		name := convertString(clang_getCursorSpelling(cursor))
		canonicalName := convertString(clang_getTypeSpelling(canonical.type))
		sym := getSym(canonicalName, state.symbols)
		if sym.aliases == null {
			sym.aliases = new List<string>{}
		}
		sym.aliases.add(name)
		collisionCheck(state, name)
		collisionCheck(state, canonicalName)

	} else if kind == CXCursorKind.CXCursor_MacroDefinition {
		name := convertString(clang_getCursorSpelling(cursor))
		collisionCheck(state, name)

		if clang_Cursor_isMacroFunctionLike(cursor) != 0 {
			return CXChildVisit_Continue
		}

		alias := tryParseBasicAliasMacro(state.clangTranslationUnit, cursor, name)
		if alias != "" {
			sym := getSym(alias, state.symbols)
			if sym.macroAliases == null {
				sym.macroAliases = new List<string>{}
			}
			sym.macroAliases.add(name)
		}

		rule := findRule(state.ruleLookup, name, SymbolKind.const)
		if rule == null {
			return CXChildVisit_Continue
		}

		if !rule.skip {
			if state.macroDefinitionsSet.tryAdd(name) {
				state.macroDefinitions.add(name)
			} else {
				Stderr.writeLine(format("Note: duplicate macro definition: {}", name))
			}
		} else if rule.skip {
			rule.matched = true
		}

	} else if kind == CXCursorKind.CXCursor_VarDecl {
		name := convertString(clang_getCursorSpelling(cursor))
		collisionCheck(state, name)

		if name == "muon_ffigen_info_platform" {
			evalResult := clang_Cursor_Evaluate(cursor)			
			assert(clang_EvalResult_getKind(evalResult) == CXEvalResultKind.CXEval_StrLiteral)
			state.platform = string.from_cstring(clang_EvalResult_getAsStr(evalResult))
		} else if name == "muon_ffigen_info_target_bits" {
			evalResult := clang_Cursor_Evaluate(cursor)			
			assert(clang_EvalResult_getKind(evalResult) == CXEvalResultKind.CXEval_StrLiteral)
			state.targetBits = string.from_cstring(clang_EvalResult_getAsStr(evalResult))
		}
	} else if kind == CXCursorKind.CXCursor_StructDecl || kind == CXCursorKind.CXCursor_UnionDecl || kind == CXCursorKind.CXCursor_EnumDecl {
		type := clang_getCursorType(cursor)
		name := convertString(clang_getTypeSpelling(clang_getCanonicalType(type)))
		collisionCheck(state, name)

	} else {
		name := convertString(clang_getCursorSpelling(cursor))
		collisionCheck(state, name)
	}
	
	return CXChildVisit_Continue
}

getDiscoverySourceText(sourceText string) {
	rb := StringBuilder{}

	rb.write(sourceText)
	rb.write("\n")

	rb.write("#ifdef _WIN32\n")
	rb.write("const char *muon_ffigen_info_platform = \"Windows\";\n")
	rb.write("#elif __linux__\n")
	rb.write("const char *muon_ffigen_info_platform = \"Linux\";\n")
	rb.write("#elif __APPLE__\n")
	rb.write("const char *muon_ffigen_info_platform = \"MacOS\";\n")
	rb.write("#else\n")
	rb.write("const char *muon_ffigen_info_platform = \"Unknown\";\n")
	rb.write("#endif\n")

	rb.write("#if defined(__i386__) || (defined(__arm__) && !defined(__aarch64__))\n")
	rb.write("const char *muon_ffigen_info_target_bits = \"32-bit\";\n")
	rb.write("#elif defined(__amd64__) || defined(__aarch64__)\n")
	rb.write("const char *muon_ffigen_info_target_bits = \"64-bit\";\n")
	rb.write("#else\n")
	rb.write("const char *muon_ffigen_info_target_bits = \"Unknown\";\n")
	rb.write("#endif\n")

	return rb.compactToString()
}

getFinalSourceText(sourceText string, state AppState) {
	rb := StringBuilder{}
	rb.write(sourceText)
	rb.write("\n")
	for name in state.macroDefinitions {
		rule := findRule(state.ruleLookup, name, SymbolKind.const)
		assert(rule != null)
		targetType := rule.constType != "" ? rule.constType : "int"
		ctype := muonConstTypeToCType(targetType)
		if rule.useCast {
			rb.write(format("const {} {}{} = ({}){};\n", ctype, generatedConstPrefix, name, ctype, name))
		} else {
			rb.write(format("const {} {}{} = {};\n", ctype, generatedConstPrefix, name, name))
		}
	}
	return rb.compactToString()
}

collisionCheck(s AppState, name string) {
	if !s.collisionCheck {
		return false
	}
	
	col := name.endsWith("__") && !name.startsWith("__") && !name.startsWith("struct ") && !name.startsWith("union ") && !name.startsWith("enum ")
	col ||= name.endsWith("__v") || isLocalVarName(name)
	col ||= name.startsWith("tag_____")
	col ||= name.startsWith("mu_____")
	col ||= name.startsWith("ffigen")
	col ||= name.startsWith("FFIGEN")

	if col {
		Stderr.writeLine(format("Possible collision: {}", name))
		return true
	}
	return false
}

isLocalVarName(s string) {
	return s.startsWith("local") && int.tryParse(s.slice(5, s.length)).hasValue
}
