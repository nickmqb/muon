convertString(str CXString) {
	cstr := clang_getCString(str)
	return string.from_cstring(cstr)
}

SourceLocation struct {
	filename string
	line int

	toString(this SourceLocation) {
		return format("{}:{}", this.filename, this.line)
	}
}

convertLocation(loc CXSourceLocation) {
	file := pointer_cast(null, pointer)
	line := 0_u
	col := 0_u
	offset := 0_u
	clang_getFileLocation(loc, ref file, ref line, ref col, ref offset)
	if file != null {
		filename := convertString(clang_getFileName(file))
		return SourceLocation { filename: filename, line: checked_cast(line, int) }
	} else {
		return SourceLocation{}
	}
}

getCursorLocationString(cursor CXCursor) {
	return convertLocation(clang_getCursorLocation(cursor)).toString()
}

getSizeOfTypeInBytes(type CXType) {
	size := clang_Type_getSizeOf(type)
	assert(size >= 0)
	return checked_cast(size, int)
}

tryGetSizeOfTypeInBytes(type CXType) {
	size := clang_Type_getSizeOf(type)
	return size >= 0 ? Maybe.from(checked_cast(size, int)) : Maybe<int>{}
}

getOffsetOfFieldInBits(cursor CXCursor) {
	offset := clang_Cursor_getOffsetOfField(cursor)
	assert(offset >= 0)
	return checked_cast(offset, int)
}

getAlignOfTypeInBytes(type CXType) {
	offset := clang_Type_getAlignOf(type)
	assert(offset >= 0)
	return checked_cast(offset, int)
}

CXType {
	hash(t CXType) {
		return xor(xor(cast(t.kind, uint), transmute(t.data_0, uint)), transmute(t.data_1, uint))
	}

	equals(a CXType, b CXType) {
		return a.kind == b.kind && a.data_0 == b.data_0 && a.data_1 == b.data_1
	}
}

UnwrapPointerTypeResult struct {
	type CXType
	numPtr int
}

unwrapPointerType(type CXType) {
	num := 0
	while type.kind == CXTypeKind.CXType_Pointer {
		type = clang_getPointeeType(type)
		num += 1
	}
	return UnwrapPointerTypeResult { type: type, numPtr: num }
}

severityToString(sev CXDiagnosticSeverity) {
	if sev == CXDiagnosticSeverity.CXDiagnostic_Error {
		return "Error"
	} else if sev == CXDiagnosticSeverity.CXDiagnostic_Warning {
		return "Warning"
	} else if sev == CXDiagnosticSeverity.CXDiagnostic_Note {
		return "Note"
	} else if sev == CXDiagnosticSeverity.CXDiagnostic_Fatal {
		return "Fatal"
	} else if sev == CXDiagnosticSeverity.CXDiagnostic_Ignored {
		return "Ignored"
	}
	abandon()
}

diagnosticToString(diag pointer) {
	loc := convertLocation(clang_getDiagnosticLocation(diag))	
	sev := severityToString(clang_getDiagnosticSeverity(diag))		
	return format("[{}:{}] {}: {}", loc.filename, loc.line, sev, convertString(clang_getDiagnosticSpelling(diag)))
}

parseCFile(sourcePath string, sourceText string, clangArgs Array<cstring>) {
	index := clang_createIndex(0, 0)
	unsavedFiles := new Array<CXUnsavedFile>(1)
	unsavedFiles[0] = CXUnsavedFile {
		Filename: pointer_cast(sourcePath.alloc_cstring(), *sbyte),
		Contents: pointer_cast(sourceText.alloc_cstring(), *sbyte),
		Length: checked_cast(sourceText.length, uint)
	}
	unit := clang_parseTranslationUnit(index, sourcePath.alloc_cstring(), pointer_cast(clangArgs.dataPtr, *cstring), clangArgs.count, ref unsavedFiles[0], 1, cast(CXTranslationUnit_DetailedPreprocessingRecord, uint))
	assert(unit != null)
	return unit
}

tryParseBasicAliasMacro(clangTranslationUnit pointer, cursor CXCursor, name string) {
	range := clang_getCursorExtent(cursor)
	tokensPtr := pointer_cast(null, *CXToken)
	numTokens := 0_u
	clang_tokenize(clangTranslationUnit, range, ref tokensPtr, ref numTokens)
	if numTokens != 2 {
		return ""
	}

	tokens := Array<CXToken> { dataPtr: pointer_cast(tokensPtr, pointer), count: cast(numTokens, int) }
	if convertString(clang_getTokenSpelling(clangTranslationUnit, tokens[0])) != name {
		return ""
	}

	alias := convertString(clang_getTokenSpelling(clangTranslationUnit, tokens[1]))
	if !isIdentifier(alias) {
		return ""
	}

	return alias
}

FindFirstStructFieldContext struct {
	result string
}

findFirstStructFieldName(cursor CXCursor, ctx *FindFirstStructFieldContext) int {
	name := convertString(clang_getCursorSpelling(cursor))
	if name != "" {
		ctx.result = name
	} else {
		type := clang_getCursorType(cursor)
		if type.kind == CXTypeKind.CXType_Record {
			clang_Type_visitFields(type, pointer_cast(findFirstStructFieldName, pointer), pointer_cast(ctx, pointer))
		} else {
			ctx.result = "FFIGEN_INVALID_ANONYMOUS_FIELD"
		}
	}
	return CXChildVisit_Break
}

getFirstStructFieldName(type CXType) {
	ctx := FindFirstStructFieldContext {}
	clang_Type_visitFields(type, pointer_cast(findFirstStructFieldName, pointer), pointer_cast(ref ctx, pointer))
	return ctx.result
}

isFunctionPointer(type CXType) {
	unwrapped := unwrapPointerType(type)
	return unwrapped.type.kind == CXTypeKind.CXType_FunctionProto && unwrapped.numPtr == 1
}
