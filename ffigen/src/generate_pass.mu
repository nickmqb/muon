MapFlags enum #Flags {
	none = 0
	prefer_cstring = 1
	param = 2
	usage = 4
}

MapSymbolResult struct {
	sym Sym
	generate bool
	generateRule Rule
	flags MapFlags
}

MappedType struct {
	type string
	marshal bool
}

mapSymbol(s AppState, name string, kind SymbolKind, force bool) {
	assert(name != "")
	assert(kind != SymbolKind.any)
	sym := getSym(name, s.symbols)
	if sym.done || sym.done_noForce {
		assert(sym.kind == kind)
	}
	if sym.done || (!force && sym.done_noForce) {
		return MapSymbolResult { sym: sym }
	}
	sym.muName = name
	sym.cName = name
	sym.kind = kind
	rule := cast(null, Rule)
	if kind == SymbolKind.struct_ || kind == SymbolKind.enum_ {
		if name.startsWith("struct ") {
			sym.muName = name.stripPrefix("struct ")
		} else if name.startsWith("union ") {
			sym.muName = name.stripPrefix("union ")
		} else if name.startsWith("enum ") {
			sym.muName = name.stripPrefix("enum ")
		}
		if sym.aliases != null {
			for i := sym.aliases.count - 1; i >= 0; i -= 1 {
				alias := sym.aliases[i]
				rule = findRule(s.ruleLookup, alias, kind)
				if rule != null {
					sym.cName = alias
					sym.muName = alias
					break
				}
			}
		}
	} else if kind == SymbolKind.function || kind == SymbolKind.functionPointer {
		if sym.macroAliases != null {
			for i := sym.macroAliases.count - 1; i >= 0; i -= 1 {
				alias := sym.macroAliases[i]
				r := findRule(s.ruleLookup, alias, kind)
				if r != null && r.checkMacroAliases {
					rule = r
					sym.cName = alias
					sym.muName = alias
					break
				}
			}
		}
	}
	if rule == null {
		rule = findRule(s.ruleLookup, name, kind)
	}
	if rule != null {
		rule.matched = true
	}
	if rule == null && !force {
		sym.done_noForce = true
		return MapSymbolResult { sym: sym }
	}
	sym.done = true
	if rule != null && rule.skip {
		return MapSymbolResult { sym: sym }
	}
	flags := cast(0, MapFlags)
	if rule != null {
		if (kind == SymbolKind.function || kind == SymbolKind.struct_) && rule.prefer_cstring {
			flags |= MapFlags.prefer_cstring
		}		
	}
	return MapSymbolResult { sym: sym, generate: true, generateRule: rule, flags: flags }
}

mapNonPointerType(s AppState, type CXType) {
	type = clang_getCanonicalType(type)
	if type.kind == CXTypeKind.CXType_SChar || type.kind == CXTypeKind.CXType_Char_S {
		assert(getSizeOfTypeInBytes(type) == 1)
		return MappedType { type: "sbyte" }
	} else if type.kind == CXTypeKind.CXType_UChar || type.kind == CXTypeKind.CXType_Char_U {
		assert(getSizeOfTypeInBytes(type) == 1)
		return MappedType { type: "byte" }
	} else if type.kind == CXTypeKind.CXType_Bool {
		assert(getSizeOfTypeInBytes(type) == 1)
		return MappedType { type: "bool" }
	} else if type.kind == CXTypeKind.CXType_Short {
		assert(getSizeOfTypeInBytes(type) == 2)
		return MappedType { type: "short" }
	} else if type.kind == CXTypeKind.CXType_UShort {
		assert(getSizeOfTypeInBytes(type) == 2)
		return MappedType { type: "ushort" }
	} else if type.kind == CXTypeKind.CXType_Int {
		assert(getSizeOfTypeInBytes(type) == 4)
		return MappedType { type: "int" }
	} else if type.kind == CXTypeKind.CXType_UInt {
		assert(getSizeOfTypeInBytes(type) == 4)
		return MappedType { type: "uint" }
	} else if type.kind == CXTypeKind.CXType_Long {
		size := getSizeOfTypeInBytes(type)
		if size == 4 && !s.isPlatformAgnostic {
			return MappedType { type: "int" }
		} else if size == 8 && !s.isPlatformAgnostic {
			return MappedType { type: "long" }
		} else {
			return MappedType { type: "FFIGEN_INVALID_TYPE_SIGNED_LONG" }
		}
	} else if type.kind == CXTypeKind.CXType_ULong {
		size := getSizeOfTypeInBytes(type)
		if size == 4 && !s.isPlatformAgnostic {
			return MappedType { type: "uint" }
		} else if size == 8 && !s.isPlatformAgnostic {
			return MappedType { type: "ulong" }
		} else {
			return MappedType { type: "FFIGEN_INVALID_TYPE_UNSIGNED_LONG" }
		}
	} else if type.kind == CXTypeKind.CXType_Float {
		assert(getSizeOfTypeInBytes(type) == 4)
		return MappedType { type: "float" }
	} else if type.kind == CXTypeKind.CXType_Double {
		assert(getSizeOfTypeInBytes(type) == 8)
		return MappedType { type: "double" }
	} else if type.kind == CXTypeKind.CXType_LongLong {
		assert(getSizeOfTypeInBytes(type) == 8)
		return MappedType { type: "long" }
	} else if type.kind == CXTypeKind.CXType_ULongLong {
		assert(getSizeOfTypeInBytes(type) == 8)
		return MappedType { type: "ulong" }
	}
	return MappedType { type: format("FFIGEN_INVALID_TYPE_{}", cast(type.kind, uint)) }
}

mapType(s AppState, type CXType, flags MapFlags) MappedType {
	info := unwrapPointerType(clang_getCanonicalType(type))
	if info.type.kind == CXTypeKind.CXType_Void {
		if info.numPtr > 0 {
			return MappedType { type: formatMuonPtr("pointer", info.numPtr - 1), marshal: true }
		} else {
			return MappedType { type: "void" }
		}

	} else if info.type.kind == CXTypeKind.CXType_Record {
		sym := mapStruct(s, info.type, flags & MapFlags.usage)
		if sym != null {
			if !sym.isZeroSizeStruct {
				return MappedType { type: formatMuonPtr(sym.muName, info.numPtr), marshal: true }
			} else {
				if info.numPtr > 0 {
					return MappedType { type: formatMuonPtr("pointer", info.numPtr - 1), marshal: true }
				} else {
					return MappedType { type: "FFIGEN_INVALID_ZERO_SIZED_STRUCT" }
				}
			}
		} else {
			return MappedType { type: "FFIGEN_INVALID_STRUCT" }
		}

	} else if info.type.kind == CXTypeKind.CXType_Enum {
		sym := mapEnum(s, info.type, flags & MapFlags.usage)
		if sym != null {
			return MappedType { type: formatMuonPtr(sym.muName, info.numPtr), marshal: true }
		} else {
			return MappedType { type: "FFIGEN_INVALID_ENUM" }
		}

	} else if info.type.kind == CXTypeKind.CXType_ConstantArray || info.type.kind == CXTypeKind.CXType_IncompleteArray {
		if flags & MapFlags.param != 0 {
			elementType := clang_getArrayElementType(info.type)		
			mapped := mapType(s, elementType, flags & MapFlags.usage)
			return MappedType { type: formatMuonPtr(mapped.type, info.numPtr + 1), marshal: mapped.marshal }
		} else {
			return MappedType { type: "FFIGEN_INVALID_CONSTANT_ARRAY_IN_THIS_CONTEXT" }
		}

	} else if (info.type.kind == CXTypeKind.CXType_FunctionProto || info.type.kind == CXTypeKind.CXType_FunctionNoProto) {
		if info.numPtr > 0 {
			return MappedType { type: formatMuonPtr("pointer", info.numPtr - 1), marshal: true }
		} else {
			return MappedType { type: "FFIGEN_INVALID_FUNCTION_PROTO_MUST_BE_POINTER" }
		}

	} else if info.numPtr > 0 && (flags & MapFlags.prefer_cstring) != 0 && (info.type.kind == CXTypeKind.CXType_SChar || info.type.kind == CXTypeKind.CXType_Char_S) {
		return MappedType { type: formatMuonPtr("cstring", info.numPtr - 1) }

	} else {
		mapped := mapNonPointerType(s, info.type)
		return MappedType { type: formatMuonPtr(mapped.type, info.numPtr), marshal: mapped.marshal }
	}
}

mapConst(s AppState, name string, cursor CXCursor) {
	if !isIdentifier(name) {
		Stderr.writeLine(format("Warning: encountered strange constant name, ignoring: {}", name))
		return
	}

	mc := mapSymbol(s, name, SymbolKind.const, false)
	if !mc.generate {
		return
	}
	
	evalResult := clang_Cursor_Evaluate(cursor)			
	kind := clang_EvalResult_getKind(evalResult)	

	rb := s.output
	rb.write(":")
	rb.write(name)
	rb.write(" ")

	if kind == CXEvalResultKind.CXEval_Int {
		targetType := mapNonPointerType(s, clang_getCursorType(cursor)).type
		if isValidMuonIntegerConstType(targetType) {
			if clang_EvalResult_isUnsignedInt(evalResult) == 0 {
				value := clang_EvalResult_getAsLongLong(evalResult)
				rb.write(targetType)
				rb.write(" = ")
				value.writeTo(rb)
				rb.write(getMuonConstLiteralSuffix(targetType))
			} else {
				value := clang_EvalResult_getAsUnsigned(evalResult)
				rb.write(targetType)
				rb.write(" = ")
				value.writeTo(rb)
				rb.write(getMuonConstLiteralSuffix(targetType))
			}
		} else {
			rb.write("FFIGEN_INVALID_INTEGER_CONST_TYPE ")
			rb.write(targetType)
		}
	} else if kind == CXEvalResultKind.CXEval_Float {
		targetType := mapNonPointerType(s, clang_getCursorType(cursor)).type
		if isValidMuonFloatingConstType(targetType) {
			value := clang_EvalResult_getAsDouble(evalResult)
			rb.write(targetType)
			rb.write(" = ")
			value.writeTo(rb)
			rb.write(getMuonConstLiteralSuffix(targetType))
		} else {
			rb.write("FFIGEN_INVALID_FLOATING_CONST_TYPE ")
			rb.write(targetType)
		}
	} else if kind == CXEvalResultKind.CXEval_StrLiteral {
		value := clang_EvalResult_getAsStr(evalResult)
		rb.write("string = \"")
		rb.writeUnescapedString(string.from_cstring(value))
		rb.write("\"")
	} else {
		rb.write("FFIGEN_INVALID_CONST_TYPE")
	}

	rb.write("\n")
}

mapVar(s AppState, name string, cursor CXCursor) {
	if !isIdentifier(name) {
		Stderr.writeLine(format("Warning: encountered strange var name, ignoring: {}", name))
		return
	}

	mv := mapSymbol(s, name, SymbolKind.var, false)
	if !mv.generate  {
		return
	}

	rb := new StringBuilder{}
	rb.write(":")
	rb.write(name)
	rb.write(" ")
	type := clang_getCursorType(cursor)
	typeName := convertString(clang_getTypeSpelling(type))	
	mapped := mapType(s, type, MapFlags.usage)
	if !mapped.marshal {
		rb.write(mapped.type)
		rb.write(" #Mutable #Foreign(\"")
		rb.write(name)
		rb.write("\")\n")			
	} else {
		rb.write("FFIGEN_INVALID_UNSUPPORTED_VAR_TYPE_{}")
		rb.write(mapped.type)
		rb.write("\n")
	}

	s.output.write(rb.compactToString())
}

mapDecl(s AppState, cursor CXCursor) {
	kind := clang_getCursorKind(cursor)
	anon := clang_Cursor_isAnonymous(cursor) != 0
	if !anon && kind == CXCursorKind.CXCursor_FunctionDecl {
		mapFunction(s, cursor)
	
	} else if !anon && (kind == CXCursorKind.CXCursor_StructDecl || kind == CXCursorKind.CXCursor_UnionDecl) {
		type := clang_getCursorType(cursor)
		mapStruct(s, type, MapFlags.none)

	} else if kind == CXCursorKind.CXCursor_EnumDecl {
		type := clang_getCursorType(cursor)
		mapEnum(s, type, MapFlags.none) // anonymous is OK for enums

	} else if !anon && kind == CXCursorKind.CXCursor_VarDecl {
		name := convertString(clang_getCursorSpelling(cursor))
		type := clang_getCursorType(cursor)
		if clang_isConstQualifiedType(type) != 0 {			
			if name.startsWith(generatedConstPrefix) {
				name = name.slice(generatedConstPrefix.length, name.length)
			}
			mapConst(s, name, cursor)
		} else {
			if isFunctionPointer(type) {
				mapFunctionPointer(s, name, type)
			} else {
				mapVar(s, name, cursor)
			}
		}

	} else if kind == CXCursorKind.CXCursor_TypedefDecl {
		type := clang_getCanonicalType(clang_getCursorType(cursor))
		innerDecl := clang_getTypeDeclaration(type)
		assert(clang_equalCursors(cursor, innerDecl) == 0)
		mapDecl(s, innerDecl)
	}
}

generatePass(cursor CXCursor, parent CXCursor, s AppState) int {
	kind := clang_getCursorKind(cursor)
	if kind == CXCursorKind.CXCursor_UnexposedDecl {
		// This could be an "extern "C"" declaration
		return CXChildVisit_Recurse	
	} else {
		mapDecl(s, cursor)
	}

	return CXChildVisit_Continue
}
