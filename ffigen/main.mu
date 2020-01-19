exit(status int) void #Foreign("exit")
//DebugBreak() void #Foreign("DebugBreak")

convertString(str CXString) {
	cstr := clang_getCString(str)
	return string.from_cstring(cstr)
}

convertLocation(loc CXSourceLocation) {
	file := pointer_cast(null, pointer)
	line := 0_u
	col := 0_u
	offset := 0_u
	clang_getFileLocation(loc, ref file, ref line, ref col, ref offset)
	filename := convertString(clang_getFileName(file))
	return SourceLocation { filename: filename, line: checked_cast(line, int) }
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

SourceLocation struct {
	filename string
	line int

	toString(this SourceLocation) {
		return format("{}:{}", this.filename, this.line)
	}
}

getCursorLocationString(cursor CXCursor) {
	return convertLocation(clang_getCursorLocation(cursor)).toString()
}

//Stdout.writeLine("Path")
//while parent.kind != CXCursor_TranslationUnit {
//	Stdout.writeLine(format("\t{} {}.", parent.kind, getCursorLocationString(parent)))
//	parent = clang_getCursorLexicalParent(parent)
//}




AppState struct #RefType {
	clangTranslationUnit CXTranslationUnit
	isPlatformAgnostic bool
	rules List<Rule>
	ruleLookup List<RuleLookupNode>
	rename Map<string, string>
	renamePtr Map<string, string>
	origName Map<string, string>
	duplicates Set<string>
	macroDefinitions List<string>
	generateErrors List<string>
	output StringBuilder
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

bestTypenameDiscoveryPass(cursor CXCursor, parent CXCursor, state AppState) int {
	kind := clang_getCursorKind(cursor)
	if kind == CXCursorKind.CXCursor_TypedefDecl {
		type := clang_getCursorType(cursor)
		typedefName := convertString(clang_getTypeSpelling(type))
		canonicalTypeInfo := unwrapPointerType(clang_getCanonicalType(type))
		canonicalTypeName := convertString(clang_getTypeSpelling(canonicalTypeInfo.type))
		if canonicalTypeName != typedefName {
			if canonicalTypeName.startsWith("struct ") || canonicalTypeName.startsWith("union ") || canonicalTypeName.startsWith("enum ") {
				if canonicalTypeInfo.numPtr == 0 {
					state.rename.addOrUpdate(canonicalTypeName, typedefName)
				} else if canonicalTypeInfo.numPtr == 1 {
					state.renamePtr.addOrUpdate(canonicalTypeName, typedefName)
				}
			} else {
				if canonicalTypeInfo.numPtr == 0 {
					state.rename.addOrUpdate(canonicalTypeName, typedefName)
				}
			}
		}
	} else if kind == CXCursorKind.CXCursor_MacroDefinition {
		if clang_Cursor_isMacroFunctionLike(cursor) == 0 {
			name := convertString(clang_getCursorSpelling(cursor))
			rule := findRule(name, 0, RuleType.const, state.ruleLookup)
			if rule != null {
				if (rule.type == RuleType.const || rule.type == RuleType.any) && rule.pattern != "*" {
					state.macroDefinitions.add(name)
				} else if rule.type == RuleType.skip {
					rule.isMatched = true
				}
			}
		}
	}	
	return CXChildVisit_Recurse
}

:generatedConstPrefix = "muon_ffigen_"

getDefaultConstType(value ConstType) {
	if value == ConstType.none {
		return ConstType.int_
	}
	return value
}

constTypeToCType(value ConstType) {
	if value == ConstType.sbyte_ {
		return "int8_t"
	} else if value == ConstType.byte_ {
		return "uint8_t"
	} else if value == ConstType.short_ {
		return "int16_t"
	} else if value == ConstType.ushort_ {
		return "uint16_t"
	} else if value == ConstType.int_ {
		return "int32_t"
	} else if value == ConstType.uint_ {
		return "uint32_t"
	} else if value == ConstType.long_ {
		return "int64_t"
	} else if value == ConstType.ulong_ {
		return "uint64_t"
	} else if value == ConstType.float_ {
		return "float"
	} else if value == ConstType.double_ {
		return "double"
	} else if value == ConstType.cstring_ {
		return "char* const"
	}
	abandon()
}

constTypeToString(value ConstType) {
	if value == ConstType.sbyte_ {
		return "sbyte"
	} else if value == ConstType.byte_ {
		return "byte"
	} else if value == ConstType.short_ {
		return "short"
	} else if value == ConstType.ushort_ {
		return "ushort"
	} else if value == ConstType.int_ {
		return "int"
	} else if value == ConstType.uint_ {
		return "uint"
	} else if value == ConstType.long_ {
		return "long"
	} else if value == ConstType.ulong_ {
		return "ulong"
	} else if value == ConstType.float_ {
		return "float"
	} else if value == ConstType.double_ {
		return "double"
	} else if value == ConstType.cstring_ {
		return "cstring"
	} else {
		return "<any>"
	}
}

getFinalSourceText(sourceText string, state AppState) {
	rb := StringBuilder{}
	rb.write(sourceText)
	for name in state.macroDefinitions {
		rule := findRule(name, 0, RuleType.const, state.ruleLookup)
		assert(rule != null)
		ctype := constTypeToCType(getDefaultConstType(rule.constType))
		if rule.useCast {
			rb.write(format("const {} {}{} = ({}){};\n", ctype, generatedConstPrefix, name, ctype, name))
		} else {
			rb.write(format("const {} {}{} = {};\n", ctype, generatedConstPrefix, name, name))
		}
	}
	return rb.compactToString()
}

MapStructContext struct {
	rb StringBuilder
	state AppState
	hasFields bool
	prefix string
	sizeInBytes int
	lastOffset int
	lastSizeInBytes int
	isDone bool
	mapTypeFlags MapTypeFlags
}

mapField(name string, type CXType, ctx *MapStructContext) {
	if ctx.isDone {
		if type.kind == CXTypeKind.CXType_ConstantArray {
			elementType := clang_getArrayElementType(type)
			if clang_Cursor_isAnonymous(clang_getTypeDeclaration(elementType)) == 0 {
				mapType(elementType, ctx.mapTypeFlags, ctx.state)
			}
		} else {
			mapType(type, ctx.mapTypeFlags, ctx.state)
		}
		return
	}

	rb := ctx.rb
	if type.kind == CXTypeKind.CXType_ConstantArray {
		elementType := clang_getArrayElementType(type)
		numElements := clang_getNumElements(type)
		for i := 0_L; i < numElements {
			rb.write("\t")
			rb.write(ctx.prefix)
			rb.write(name)
			rb.write("_")
			long.writeTo(i, rb)
			rb.write(" ")
			rb.write(mapType(elementType, ctx.mapTypeFlags, ctx.state).type)
			rb.write("\n")
		}
	} else {
		rb.write("\t")
		rb.write(ctx.prefix)
		if name != "" {
			rb.write(name)
		} else {
			rb.write("ffigen_anonymous")
		}
		rb.write(" ")
		rb.write(mapType(type, ctx.mapTypeFlags, ctx.state).type)
		rb.write("\n")
	}
}

mapStructField(cursor CXCursor, ctx *MapStructContext) int {
	rb := ctx.rb

	ctx.hasFields = true

	type := clang_getCursorType(cursor)
	name := convertString(clang_getCursorSpelling(cursor))
	maybeSizeInBytes := tryGetSizeOfTypeInBytes(type)
	offset := getOffsetOfFieldInBits(cursor) / 8
	isNested := clang_Cursor_isAnonymous(clang_getTypeDeclaration(type)) != 0
	isArrayNested := type.kind == CXTypeKind.CXType_ConstantArray && clang_Cursor_isAnonymous(clang_getTypeDeclaration(clang_getArrayElementType(type))) != 0

	//rb.write(format("\t//offset of {}: {}\n", name, offsetInBits))

	if !ctx.isDone {
		if clang_Cursor_isBitField(cursor) != 0 || offset == ctx.lastOffset || !maybeSizeInBytes.hasValue || isArrayNested || type.kind == CXTypeKind.CXType_LongDouble {
			ctx.isDone = true
			for i := ctx.lastOffset + ctx.lastSizeInBytes; i < ctx.sizeInBytes {
				rb.write("\t")
				rb.write(ctx.prefix)
				rb.write("ffigen_padding_")
				i.writeTo(rb)
				rb.write(" byte\n")
			}
		} else {
			ctx.lastOffset = offset
			ctx.lastSizeInBytes = maybeSizeInBytes.unwrap()
		}
	}

	if isNested {
		newCtx := MapStructContext { 
			rb: rb,
			state: ctx.state,
			prefix: format("{}{}_", ctx.prefix, name),
			sizeInBytes: maybeSizeInBytes.unwrap(),
			lastOffset: -1,
			lastSizeInBytes: 1,
			isDone: ctx.isDone,
			mapTypeFlags: ctx.mapTypeFlags
		}
		clang_Type_visitFields(type, pointer_cast(mapStructField, pointer), pointer_cast(ref newCtx, pointer))
	} else {
		mapField(name, type, ctx)
	}

	return CXChildVisit_Continue
}

checkStructField(cursor CXCursor, ctx *MapStructContext) int {
	ctx.hasFields = true
	return CXChildVisit_Break
}

MapStructFlags enum #Flags {
	asRefType
	none = 0
}

mapStruct(fromName string, name string, type CXType, flags MapStructFlags, state AppState) {
	origName := state.origName.getOrDefault(name)
	if origName != "" {
		if fromName != origName {
			state.duplicates.tryAdd(name)
		}
		return name
	}

	state.origName.add(name, fromName)

	rule := findRule(fromName, 0, RuleType.struct_, state.ruleLookup)
	if rule != null {
		rule.isMatched = true
		if rule.type == RuleType.skip {
			return name
		}
	}

	rb := new StringBuilder{}
	rb.write(name)
	rb.write(" ")
	rb.write("struct ")
	if (flags & MapStructFlags.asRefType) != 0 {
		rb.write("#RefType ")
	}
	rb.write("{\n")

	maybeSize := tryGetSizeOfTypeInBytes(type)
	if maybeSize.hasValue && maybeSize.unwrap() > 0 {
		ctx := MapStructContext { rb: rb, state: state, sizeInBytes: maybeSize.unwrap(), lastOffset: -1, lastSizeInBytes: 1, mapTypeFlags: (rule != null && rule.prefer_cstring) ? MapTypeFlags.prefer_cstring : MapTypeFlags.none }
		clang_Type_visitFields(type, pointer_cast(mapStructField, pointer), pointer_cast(ref ctx, pointer))
	} else {
		ctx := MapStructContext{}
		clang_Type_visitFields(type, pointer_cast(checkStructField, pointer), pointer_cast(ref ctx, pointer))
		if (!ctx.hasFields) {
			// Generate dummy field to avoid field-less structs, which are not allowed in C
			rb.write("\tunused int\n")
		} else {
			rb.write("\tFFIGEN_INVALID_STRUCT\n")
		}
	}

	rb.write("}\n")
	state.output.write(rb.compactToString())
	return name
}

MapEnumContext struct {
	rb StringBuilder
	state AppState
	isAnonymous bool
}

mapEnumMember(cursor CXCursor, parent CXCursor, ctx *MapEnumContext) int {
	state := ctx.state
	if cursor.kind == CXCursorKind.CXCursor_EnumConstantDecl {
		name := convertString(clang_getCursorSpelling(cursor))
		origValue := clang_getEnumConstantDeclValue(cursor)

		if !ctx.isAnonymous {
			value := origValue
			if value < 0 {
				name = format("{}_ffigen_modified", name)
				value = cast(transmute(cast(value, int), uint), long)
			}

			rb := ctx.rb
			rb.write("\t")
			rb.write(name)
			rb.write(" = ")
			value.writeTo(rb)
			rb.write("_u\n")
		}

		rule := findRule(name, 0, RuleType.const, state.ruleLookup)
		if rule != null {
			if rule.type == RuleType.const || rule.type == RuleType.any {
				generateEnumMemberConst(name, origValue, rule, state)
				rule.isMatched = true
			}
		}
	}
	return CXChildVisit_Continue
}

mapEnum(fromName string, name string, cursor CXCursor, state AppState) {
	origName := state.origName.getOrDefault(name)
	if origName != "" {
		if fromName != origName {
			state.duplicates.tryAdd(name)
		}
		return name
	}

	state.origName.add(name, fromName)

	rule := findRule(fromName, 0, RuleType.enum_, state.ruleLookup)
	if rule != null {
		rule.isMatched = true
		if rule.type == RuleType.skip {
			return name
		}
	}

	rb := new StringBuilder{}
	rb.write(name)
	rb.write(" ")
	rb.write("enum #Flags {\n")

	ctx := MapEnumContext { rb: rb, state: state }
	clang_visitChildren(cursor, pointer_cast(mapEnumMember, pointer), pointer_cast(ref ctx, pointer))

	rb.write("}\n")
	state.output.write(rb.compactToString())
	return name
}

mapAnonymousEnum(cursor CXCursor, state AppState) {
	ctx := MapEnumContext { rb: state.output, state: state, isAnonymous: true }
	clang_visitChildren(cursor, pointer_cast(mapEnumMember, pointer), pointer_cast(ref ctx, pointer))
}

stripConstUnaligned(s string) {
	while true {
		if s.startsWith("const ") {
			s = s.slice("const ".length, s.length)
		} else if s.startsWith("__unaligned") {
			s = s.slice("__unaligned ".length, s.length)
		} else {
			break
		}
	}	
	return s
}

MappedType struct {
	type string
	marshal bool
	error bool
}

MapTypeFlags enum #Flags {
	prefer_cstring
	none = 0
}

mapNonPointerType(type CXType, state AppState) {
	if type.kind == CXTypeKind.CXType_SChar || type.kind == CXTypeKind.CXType_Char_S {
		return MappedType { type: "sbyte" }
	} else if type.kind == CXTypeKind.CXType_UChar || type.kind == CXTypeKind.CXType_Char_U {
		return MappedType { type: "byte" }
	} else if type.kind == CXTypeKind.CXType_Short {
		return MappedType { type: "short" }
	} else if type.kind == CXTypeKind.CXType_UShort {
		return MappedType { type: "ushort" }
	} else if type.kind == CXTypeKind.CXType_Int {
		return MappedType { type: "int" }
	} else if type.kind == CXTypeKind.CXType_UInt {
		return MappedType { type: "uint" }
	} else if type.kind == CXTypeKind.CXType_Long {
		size := getSizeOfTypeInBytes(type)
		if size == 4 && !state.isPlatformAgnostic {
			return MappedType { type: "int" }
		} else if size == 8 && !state.isPlatformAgnostic {
			return MappedType { type: "long" }
		} else {
			return MappedType { type: "FFIGEN_INVALID_TYPE_SIGNED_LONG", error: true }
		}
	} else if type.kind == CXTypeKind.CXType_ULong {
		size := getSizeOfTypeInBytes(type)
		if size == 4 && !state.isPlatformAgnostic {
			return MappedType { type: "uint" }
		} else if size == 8 && !state.isPlatformAgnostic {
			return MappedType { type: "ulong" }
		} else {
			return MappedType { type: "FFIGEN_INVALID_TYPE_UNSIGNED_LONG", error: true }
		}
	} else if type.kind == CXTypeKind.CXType_Float {
		return MappedType { type: "float" }
	} else if type.kind == CXTypeKind.CXType_Double {
		return MappedType { type: "double" }
	} else if type.kind == CXTypeKind.CXType_LongLong {
		return MappedType { type: "long" }
	} else if type.kind == CXTypeKind.CXType_ULongLong {
		return MappedType { type: "ulong" }
	}
	return MappedType { type: format("FFIGEN_UNKNOWN_TYPE_{}", cast(type.kind, uint)), error: true }
}

mapType(type_ CXType, flags MapTypeFlags, state AppState) MappedType {
	info := unwrapPointerType(clang_getCanonicalType(type_))
	if info.type.kind == CXTypeKind.CXType_Void {
		if info.numPtr > 0 {
			return MappedType { type: format("{}{}", string.repeatChar('*', info.numPtr - 1), "pointer") }
		} else {
			return MappedType { type: "void" }
		}
	} else if info.type.kind == CXTypeKind.CXType_Record {
		name := stripConstUnaligned(convertString(clang_getTypeSpelling(info.type)))
		newName := state.rename.getOrDefault(name)
		if newName != "" {
			return MappedType { type: format("{}{}", string.repeatChar('*', info.numPtr), mapStruct(newName, newName, info.type, MapStructFlags.none, state)), marshal: true }
		}
		if info.numPtr > 0 {
			newPtrName := state.renamePtr.getOrDefault(name)
			if newPtrName != "" {
				return MappedType { type: format("{}{}", string.repeatChar('*', info.numPtr - 1), mapStruct(newPtrName, newPtrName, info.type, MapStructFlags.asRefType, state)), marshal: true }
			}
		}
		cursor := clang_getTypeDeclaration(info.type)
		if clang_Cursor_isAnonymous(cursor) != 0 {
			return MappedType { type: format("{}UNKNOWN_TYPE_{}", string.repeatChar('*', info.numPtr), cast(info.type.kind, uint)), error: true }
		}
		if name.startsWith("struct ") {
			return MappedType { type: format("{}{}", string.repeatChar('*', info.numPtr), mapStruct(name, name.stripPrefix("struct "), info.type, MapStructFlags.none, state)), marshal: true }
		}
		if name.startsWith("union ") {
			return MappedType { type: format("{}{}", string.repeatChar('*', info.numPtr), mapStruct(name, name.stripPrefix("union "), info.type, MapStructFlags.none, state)), marshal: true }
		}
		return MappedType { type: format("{}{}", string.repeatChar('*', info.numPtr), mapStruct(name, name, info.type, MapStructFlags.none, state)), marshal: true }
	} else if info.type.kind == CXTypeKind.CXType_Enum {
		cursor := clang_getTypeDeclaration(info.type)
		name := stripConstUnaligned(convertString(clang_getTypeSpelling(info.type)))
		newName := state.rename.getOrDefault(name)
		if newName != "" {
			return MappedType { type: format("{}{}", string.repeatChar('*', info.numPtr), mapEnum(newName, newName, cursor, state)), marshal: true }
		}
		if name.startsWith("enum ") {
			return MappedType { type: format("{}{}", string.repeatChar('*', info.numPtr), mapEnum(name, name.stripPrefix("enum "), cursor, state)), marshal: true }
		}
		return MappedType { type: format("{}{}", string.repeatChar('*', info.numPtr), mapEnum(name, name, cursor, state)), marshal: true }
	} else if info.type.kind == CXTypeKind.CXType_ConstantArray || info.type.kind == CXTypeKind.CXType_IncompleteArray {
		elementType := clang_getArrayElementType(info.type)
		mapped := mapType(elementType, MapTypeFlags.none, state)
		return MappedType { type: format("{}{}", string.repeatChar('*', info.numPtr + 1), mapped.type), marshal: mapped.marshal }
	} else if (info.type.kind == CXTypeKind.CXType_FunctionProto || info.type.kind == CXTypeKind.CXType_FunctionNoProto) {
		return MappedType { type: format("{}{}", string.repeatChar('*', max(0, info.numPtr - 1)), "pointer"), marshal: true }
	} else if (flags & MapTypeFlags.prefer_cstring) != 0 && (info.type.kind == CXTypeKind.CXType_SChar || info.type.kind == CXTypeKind.CXType_Char_S) && info.numPtr > 0 {
		return MappedType { type: format("{}{}", string.repeatChar('*', max(0, info.numPtr - 1)), "cstring") }
	} else {
		mapped := mapNonPointerType(info.type, state)
		return MappedType { type: format("{}{}", string.repeatChar('*', info.numPtr), mapped.type), marshal: mapped.marshal, error: mapped.error }
	}
}

generateFunction(name string, cursor CXCursor, rule Rule, state AppState) {
	origName := state.origName.getOrDefault(name)
	if origName != "" {
		if name != origName {
			state.duplicates.tryAdd(name)
		}
		return
	}

	state.origName.add(name, name)

	rb := StringBuilder{}

	rb.write(name)
	rb.write("(")

	numParams := clang_Cursor_getNumArguments(cursor)
	writeSep := false
	flags := rule.prefer_cstring ? MapTypeFlags.prefer_cstring : MapTypeFlags.none

	for i := 0; i < numParams {
		if writeSep {
			rb.write(", ")
		} else {
			writeSep = true
		}

		param := clang_Cursor_getArgument(cursor, checked_cast(i, uint))
		paramName := convertString(clang_getCursorSpelling(param))
		rb.write(paramName.length > 0 ? paramName : format("p{}", i)) // TODO: Handle rare case where pX already exists
		rb.write(" ")

		type := clang_getCursorType(param)
		typeName := convertString(clang_getTypeSpelling(type))
		mapped := mapType(type, flags, state)
		if !mapped.error {
			rb.write(mapped.type)
			if mapped.marshal {
				rb.write(" #As(\"")
				rb.write(typeName)
				rb.write("\")")
			}
		} else {
			rb.write("pointer #As(\"")
			rb.write(mapped.type)
			rb.write("\")")
		}
	}

	rb.write(") ")
	returnType := clang_getCursorResultType(cursor)
	returnTypeName := convertString(clang_getTypeSpelling(returnType))	
	mapped := mapType(returnType, flags, state)
	if !mapped.error {
		rb.write(mapped.type)
		if mapped.marshal {
			rb.write(" #As(\"")
			rb.write(returnTypeName)
			rb.write("\")")
		}
	} else {
		rb.write("pointer #As(\"")
		rb.write(mapped.type)
		rb.write("\")")
	}

	if clang_Cursor_isVariadic(cursor) != 0 {
		rb.write(" #VarArgs")	
	}

	rb.write(" #Foreign(\"")
	rb.write(name)
	rb.write("\")\n")			

	state.output.write(rb.compactToString())
}

generateEnumMemberConst(name string, value long, rule Rule, state AppState) {
	origName := state.origName.getOrDefault(name)
	if origName != "" && name != origName {
		state.duplicates.tryAdd(name)
		return
	}

	rb := state.output

	rb.write(":")
	rb.write(name)
	rb.write(" ")

	type := rule.constType
	if type == ConstType.sbyte_ {
		rb.write("sbyte = ")
		value.writeTo(rb)
		rb.write("_sb")
	} else if type == ConstType.byte_ {
		rb.write("byte = ")
		value.writeTo(rb)
		rb.write("_b")
	} else if type == ConstType.short_ {
		rb.write("short = ")
		value.writeTo(rb)
		rb.write("_s")
	} else if type == ConstType.ushort_ {
		rb.write("ushort = ")
		value.writeTo(rb)
		rb.write("_us")
	} else if type == ConstType.int_ || type == ConstType.none {
		rb.write("int = ")
		value.writeTo(rb)
	} else if type == ConstType.uint_ {
		rb.write("uint = ")
		value.writeTo(rb)
		rb.write("_u")
	} else if type == ConstType.long_ {
		rb.write("long = ")
		value.writeTo(rb)
		rb.write("_L")
	} else if type == ConstType.ulong_ {
		rb.write("ulong = ")
		value.writeTo(rb)
		rb.write("_uL")
	} else {
		state.generateErrors.add(format("Cannot convert {} to {} (rule: {})", name, constTypeToString(type), ruleToString(rule)))
	}

	rb.write("\n")
}

getSuffix(type string) {
	if type == "sbyte" {
		return "_sb"
	} else if type == "byte" {
		return "_b"
	} else if type == "short" {
		return "_s"
	} else if type == "ushort" {
		return "_us"
	} else if type == "int" {
		return ""
	} else if type == "uint" {
		return "_u"
	} else if type == "long" {
		return "_L"
	} else if type == "ulong" {
		return "_uL"
	} else if type == "float" {
		return ""
	} else if type == "double" {
		return "_d"
	}
	return ""
}

generateConst(name string, cursor CXCursor, rule Rule, state AppState) {
	origName := state.origName.getOrDefault(name)
	if origName != "" && name != origName {
		state.duplicates.tryAdd(name)
		return
	}

	evalResult := clang_Cursor_Evaluate(cursor)			
	kind := clang_EvalResult_getKind(evalResult)
	targetType := mapType(clang_getCursorType(cursor), MapTypeFlags.none, state).type

	rb := state.output

	rb.write(":")
	rb.write(name)
	rb.write(" ")

	if kind == CXEvalResultKind.CXEval_Int {
		if clang_EvalResult_isUnsignedInt(evalResult) == 0 {
			value := clang_EvalResult_getAsLongLong(evalResult)
			rb.write(targetType)
			rb.write(" = ")
			value.writeTo(rb)
			rb.write(getSuffix(targetType))
		} else {
			value := clang_EvalResult_getAsUnsigned(evalResult)
			rb.write(targetType)
			rb.write(" = ")
			value.writeTo(rb)
			rb.write(getSuffix(targetType))
		}
	} else if kind == CXEvalResultKind.CXEval_Float {
		value := clang_EvalResult_getAsDouble(evalResult)
		rb.write(targetType)
		rb.write(" = ")
		value.writeTo(rb)
		rb.write(getSuffix(targetType))
	} else if kind == CXEvalResultKind.CXEval_StrLiteral {
		value := clang_EvalResult_getAsStr(evalResult)
		rb.write("string = \"")
		rb.writeUnescapedString(string.from_cstring(value))
		rb.write("\"")
	} else if targetType == "sbyte" || targetType == "byte" || targetType == "short" || targetType == "ushort" || targetType == "int" || targetType == "uint" || targetType == "long" || targetType == "ulong" {
		rb.write(targetType)
		rb.write(" = 0")
		rb.write(getSuffix(targetType))
	} else if targetType == "float" || targetType == "double" {
		rb.write(targetType)
		rb.write(" = 0.0")
		rb.write(getSuffix(targetType))
	} else {
		rb.write("pointer #Foreign(\"FFIGEN_UNSUPPORTED_VALUE\")")
	}

	rb.write("\n")
}

generateVar(name string, cursor CXCursor, rule Rule, state AppState) {
	origName := state.origName.getOrDefault(name)
	if origName != "" && name != origName {
		state.duplicates.tryAdd(name)
		return
	}

	rb := new StringBuilder{}

	rb.write(":")
	rb.write(name)
	rb.write(" ")

	type := clang_getCursorType(cursor)
	typeName := convertString(clang_getTypeSpelling(type))	
	mapped := mapType(type, MapTypeFlags.none, state)
	if !mapped.error && (!mapped.marshal || mapped.type.startsWith("*")) {
		rb.write(mapped.type)
		rb.write(" #Mutable #Foreign(\"")
		rb.write(name)
		rb.write("\")\n")			
	} else {
		rb.write("pointer #Mutable #Foreign(\"FFIGEN_UNSUPPORTED_VALUE_")
		rb.write(mapped.type)
		rb.write("\")\n")
	}

	state.output.write(rb.compactToString())
}

generatePass(cursor CXCursor, parent CXCursor, state AppState) int {
	kind := clang_getCursorKind(cursor)
	if kind == CXCursorKind.CXCursor_UnexposedDecl {
		// This could be an "extern "C"" declaration, so always recurse into unexposed decls
		return CXChildVisit_Recurse
	
	} else if kind == CXCursorKind.CXCursor_FunctionDecl {
		name := convertString(clang_getCursorSpelling(cursor))
		rule := findRule(name, 0, RuleType.function, state.ruleLookup)
		if rule != null {
			if rule.type != RuleType.skip {
				generateFunction(name, cursor, rule, state)
			}
			rule.isMatched = true	
		}
	
	} else if kind == CXCursorKind.CXCursor_TypedefDecl {
		name := convertString(clang_getCursorSpelling(cursor))
		info := unwrapPointerType(clang_getCanonicalType(clang_getCursorType(cursor)))
		rule := findRule(name, 0, info.type.kind == CXTypeKind.CXType_Enum ? RuleType.enum_ : RuleType.struct_, state.ruleLookup)
		if rule != null {
			if rule.type != RuleType.skip {
				type := clang_getCursorType(cursor)
				mapType(type, MapTypeFlags.none, state)
			}
			rule.isMatched = true	
		}
	
	} else if kind == CXCursorKind.CXCursor_StructDecl || kind == CXCursorKind.CXCursor_UnionDecl {
		name := convertString(clang_getTypeSpelling(clang_getCursorType(cursor)))
		rule := findRule(name, 0, RuleType.struct_, state.ruleLookup)
		if rule != null {
			if rule.type != RuleType.skip {
				type := clang_getCursorType(cursor)
				mapType(type, MapTypeFlags.none, state)
			}
			rule.isMatched = true	
		}

	} else if kind == CXCursorKind.CXCursor_EnumDecl {
		if clang_Cursor_isAnonymous(cursor) != 0 {
			mapAnonymousEnum(cursor, state)
		} else {
			name := convertString(clang_getTypeSpelling(clang_getCursorType(cursor)))
			rule := findRule(name, 0, RuleType.enum_, state.ruleLookup)		
			if rule != null {
				if rule.type != RuleType.skip {
					type := clang_getCursorType(cursor)
					mapType(type, MapTypeFlags.none, state)
				}
				rule.isMatched = true	
			}
		}

	} else if kind == CXCursorKind.CXCursor_VarDecl {
		name := convertString(clang_getCursorSpelling(cursor))
		type := clang_getCursorType(cursor)
		if clang_isConstQualifiedType(type) != 0 {			
			if name.startsWith(generatedConstPrefix) {
				name = name.slice(generatedConstPrefix.length, name.length)
			}
			rule := findRule(name, 0, RuleType.const, state.ruleLookup)
			if rule != null {
				if rule.type != RuleType.skip {
					generateConst(name, cursor, rule, state)
				}
				rule.isMatched = true			
			}
		} else {
			rule := findRule(name, 0, RuleType.var, state.ruleLookup)
			if rule != null {
				if rule.type != RuleType.skip {
					generateVar(name, cursor, rule, state)
				}
				rule.isMatched = true	
			}
		}
	}

	return CXChildVisit_Continue
}

abandonHandler(code int) {
	Stdout.writeLine("Abandoned")
	//DebugBreak()
	exit(1)
}

parse(index pointer, sourcePath string, sourceText string, clangArgs Array<cstring>) {
	unsavedFiles := new Array<CXUnsavedFile>(1)
	unsavedFiles[0] = CXUnsavedFile { Filename: sourcePath.alloc_cstring(), Contents: sourceText.alloc_cstring(), Length: checked_cast(sourceText.length, uint) }
	unit := clang_parseTranslationUnit(index, sourcePath.alloc_cstring(), pointer_cast(clangArgs.dataPtr, *cstring), clangArgs.count, ref unsavedFiles[0], 1, cast(CXTranslationUnit_DetailedPreprocessingRecord, uint))
	assert(unit != null)
	return unit
}

readFile(path string, errorMessage string) {
	sb := StringBuilder{}
	if !File.tryReadToStringBuilder(path, ref sb) {
		Stderr.writeLine(errorMessage)
		exit(1)
	}
	return sb.compactToString()
}

main() {
	::abandonFn = abandonHandler
	::currentAllocator = Memory.newArenaAllocator(256 * 1024 * 1024)

	errors := new List<CommandLineArgsParserError>{}
	parser := new CommandLineArgsParser.from(Environment.getCommandLineArgs(), errors)
	args := parseArgs(parser)

	if errors.count > 0 {
		info := parser.getCommandLineInfo()
		for errors {
			Stderr.writeLine(CommandLineArgsParser.getErrorDesc(it, info))
		}
		exit(1)
	}

	sourceText := readFile(args.sourcePath, "Could not read source file")
	index := clang_createIndex(0, 0)

	clangArgs := new Array<cstring>(args.clangArgs.count)
	for it, i in args.clangArgs {
		clangArgs[i] = it.alloc_cstring()
	}

	unit := parse(index, args.sourcePath, sourceText, clangArgs)
	numDiagnostics := clang_getNumDiagnostics(unit)
	if numDiagnostics > 0 {
		Stderr.writeLine(format("clang compilation failed:"))
		for i := 0_u; i < numDiagnostics {
			diag := clang_getDiagnostic(unit, i)
			Stderr.writeLine(convertString(clang_getDiagnosticSpelling(diag)))
		}
		exit(1)
	}

	state := new AppState { 
		clangTranslationUnit: unit, 
		isPlatformAgnostic: args.isPlatformAgnostic,
		rename: new Map.create<string, string>(),
		renamePtr: new Map.create<string, string>(),
		origName: new Map.create<string, string>(),
		macroDefinitions: new List<string>{},
		duplicates: new Set.create<string>(),
		generateErrors: new List<string>{},
	}	

	if args.rulesPath != "" {
		rulesText := readFile(args.rulesPath, "Could not read rules file")
		ruleErrors := new List<RuleParseError>{}
		result := parseRules(rulesText, ruleErrors)
		state.rules = result.rules
		state.ruleLookup = result.lookup
		if ruleErrors.count > 0 {
			for e in ruleErrors {
				Stderr.writeLine(format("{}\n-> {}:{}", e.text, args.rulesPath, e.line + 1))
			}
			exit(1)
		}
	} else {
		state.rules = new List<Rule>{}
		state.ruleLookup = defaultRuleLookup()
	}

	cursor := clang_getTranslationUnitCursor(unit)
	clang_visitChildren(cursor, pointer_cast(bestTypenameDiscoveryPass, pointer), pointer_cast(state, pointer))
	finalSourceText := getFinalSourceText(sourceText, state)
	unit = parse(index, args.sourcePath, finalSourceText, clangArgs)
	numDiagnostics = clang_getNumDiagnostics(unit)
	generatedConstFirstLine := Util.countLines(sourceText)
	if numDiagnostics > 0 {
		Stderr.writeLine(format("clang temp source file compilation failed:"))
		for i := 0_u; i < numDiagnostics {
			diag := clang_getDiagnostic(unit, i)
			Stderr.writeLine(convertString(clang_getDiagnosticSpelling(diag)))
			loc := convertLocation(clang_getDiagnosticLocation(diag))
			if loc.filename == args.sourcePath && loc.line >= generatedConstFirstLine {
				Stderr.writeLine(format("-> {}", state.macroDefinitions[loc.line - generatedConstFirstLine]))
			}
		}
		exit(1)
	}

	state.output = new StringBuilder{}
	state.output.write("// Generated by ffigen 0.1.0\n")
	cursor = clang_getTranslationUnitCursor(unit)
	clang_visitChildren(cursor, pointer_cast(generatePass, pointer), pointer_cast(state, pointer))

	if state.duplicates.count > 0 || state.generateErrors.count > 0 {
		for it in state.duplicates {
			Stderr.writeLine(format("Duplicate definition: {}", it))
		}
		for e in state.generateErrors {
			Stderr.writeLine(e)
		}
		exit(1)
	}

	if !File.tryWriteString(args.outputPath, state.output.toString()) {
		Stderr.writeLine("Could not write output file")
		exit(1)
	}

	for r in state.rules {
		if !r.isMatched {
			Stdout.writeLine(format("Warning: unmatched rule: {}", ruleToString(r)))
		}
	}	
}

ruleToString(r Rule) {
	if r.type == RuleType.any {
		return r.pattern
	}
	return format("{} {}", r.pattern, ruleTypeToString(r.type))
}

ruleTypeToString(t RuleType) {
	if t == RuleType.function {
		return "fun"
	} else if t == RuleType.struct_ {
		return "struct"
	} else if t == RuleType.enum_ {
		return "enum"
	} else if t == RuleType.const {
		return "const"
	} else if t == RuleType.var {
		return "var"
	} else if t == RuleType.skip {
		return "skip"
	} else {
		return ""
	}
}
