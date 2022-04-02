MapEnumContext struct {
	state AppState
	rb StringBuilder
	writeMembers bool
}

mapEnum(s AppState, type CXType, outerFlags MapFlags) {
	type = clang_getCanonicalType(type)
	declCursor := clang_getTypeDeclaration(type)
	if clang_Cursor_isAnonymous(declCursor) != 0 {
		mapEnum_membersOnly(s, type, declCursor)
		return null
	}

	name := convertString(clang_getTypeSpelling(type))
	if outerFlags & MapFlags.usage != 0 {
		name = stripConstModifier(name)
	}
	if !isValidCEnumName(name) {
		Stderr.writeLine(format("Warning: encountered strange enum name, ignoring: {}", name))
		mapEnum_membersOnly(s, type, declCursor)
		return null
	}		

	me := mapSymbol(s, name, SymbolKind.enum_, outerFlags & MapFlags.usage != 0)
	if !me.generate {
		mapEnum_membersOnly(s, type, declCursor)
		return me.sym
	}

	rb := new StringBuilder{}
	rb.write(me.sym.muName)
	rb.write(" ")
	rb.write("enum #Flags {\n")
	ctx := MapEnumContext { state: s, rb: rb, writeMembers: true }
	clang_visitChildren(declCursor, pointer_cast(mapEnumMember, pointer), pointer_cast(ref ctx, pointer))
	rb.write("}\n")
	s.output.write(rb.compactToString())
	return me.sym
}

mapEnum_membersOnly(s AppState, type CXType, declCursor CXCursor) {
	if s.enums.tryAdd(type) {
		return // Already done
	}
	ctx := MapEnumContext { state: s }
	clang_visitChildren(declCursor, pointer_cast(mapEnumMember, pointer), pointer_cast(ref ctx, pointer))
}

mapEnumMember(cursor CXCursor, parent CXCursor, ctx *MapEnumContext) int {
	s := ctx.state
	if cursor.kind == CXCursorKind.CXCursor_EnumConstantDecl {
		name := convertString(clang_getCursorSpelling(cursor))
		value := clang_getEnumConstantDeclValue(cursor)
		assert(value <= int.maxValue)

		forceConst := false
		if ctx.writeMembers {
			rb := ctx.rb			
			if value >= 0 {
				rb.write(format("\t{} = {}_u\n", name, value))
			} else {
				rb.write(format("\t// ffigen_note: enum member value out of range, skipping: {} = {}\n", name, value))
				forceConst = true
			}
		}

		mapEnumMemberConst(s, name, value, forceConst)
	}
	return CXChildVisit_Continue
}

mapEnumMemberConst(s AppState, name string, value long, force bool) {
	if !isIdentifier(name) {
		Stderr.writeLine(format("Warning: encountered strange enum member name, ignoring: {}", name))
		return
	}

	mc := mapSymbol(s, name, SymbolKind.const, force)
	if !mc.generate {
		return
	}

	rb := s.output
	rb.write(":")
	rb.write(name)
	rb.write(" ")
	
	muonType := (mc.generateRule != null && mc.generateRule.constType != "") ? mc.generateRule.constType : "int"
	if !isValidMuonIntegerConstType(muonType) {
		rb.write("FFIGEN_INVALID_ENUM_MEMBER_TARGET_TYPE_")
		rb.write(muonType)
		rb.write("\n")
		return
	}

	rb.write(muonType)
	rb.write(" = ")
	value.writeTo(rb)
	rb.write(getMuonConstLiteralSuffix(muonType))
	rb.write("\n")
}
