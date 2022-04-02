mapFunction(s AppState, cursor CXCursor) {
	cname := convertString(clang_getCursorSpelling(cursor))
	if !isIdentifier(cname) {
		Stderr.writeLine(format("Warning: encountered strange function name, ignoring: {}", cname))
		return
	}

	mf := mapSymbol(s, cname, SymbolKind.function, false)
	if !mf.generate {
		return
	}

	rb := new StringBuilder{}
	rb.write(mf.sym.muName)
	rb.write("(")

	numParams := clang_Cursor_getNumArguments(cursor)
	sep := false

	for i := 0; i < numParams {
		if sep {
			rb.write(", ")
		}
		sep = true

		param := clang_Cursor_getArgument(cursor, checked_cast(i, uint))
		paramName := convertString(clang_getCursorSpelling(param))
		rb.write(paramName.length > 0 ? paramName : format("p{}", i)) // TODO: Handle rare case where pX already exists
		rb.write(" ")

		type := clang_getCursorType(param)
		typeName := convertString(clang_getTypeSpelling(type))
		mapped := mapType(s, type, mf.flags | MapFlags.param | MapFlags.usage)
		writeMarshalledMappedType(rb, mapped, typeName)
	}

	rb.write(") ")
	returnType := clang_getCursorResultType(cursor)
	returnTypeName := convertString(clang_getTypeSpelling(returnType))	
	mapped := mapType(s, returnType, mf.flags | MapFlags.param | MapFlags.usage)
	writeMarshalledMappedType(rb, mapped, returnTypeName)

	if clang_Cursor_isVariadic(cursor) != 0 {
		rb.write(" #VarArgs")	
	}

	rb.write(" #Foreign(\"")
	rb.write(mf.sym.cName)
	rb.write("\")\n")			

	s.output.write(rb.compactToString())
}

mapFunctionPointer(s AppState, name string, funcType CXType) {
	if !isIdentifier(name) {
		Stderr.writeLine(format("Warning: encountered strange function pointer name, ignoring: {}", name))
		return
	}

	mf := mapSymbol(s, name, SymbolKind.function, false)
	if !mf.generate {
		return
	}

	rb := new StringBuilder{}
	numParams := clang_getNumArgTypes(funcType)
	sep := false

	for i := 0; i < numParams {
		if sep {
			rb.write(", ")
		}
		sep = true

		rb.write(format("p{} ", i))
		paramType := clang_getArgType(funcType, checked_cast(i, uint))
		typeName := convertString(clang_getTypeSpelling(paramType))
		mapped := mapType(s, paramType, mf.flags | MapFlags.param | MapFlags.usage)
		writeMarshalledMappedType(rb, mapped, typeName)
	}

	rb.write(") ")
	returnType := clang_getResultType(funcType)
	returnTypeName := convertString(clang_getTypeSpelling(returnType))	
	mapped := mapType(s, returnType, mf.flags | MapFlags.param | MapFlags.usage)
	writeMarshalledMappedType(rb, mapped, returnTypeName)

	rb.write(" #Foreign(\"")
	rb.write(mf.sym.cName)
	rb.write("\")\n")			

	s.output.write(rb.compactToString())
}

writeMarshalledMappedType(rb StringBuilder, mapped MappedType, marshalAs string) {
	rb.write(mapped.type)
	if mapped.marshal {
		rb.write(" #As(\"")
		rb.write(marshalAs)
		rb.write("\")")
	}
}
