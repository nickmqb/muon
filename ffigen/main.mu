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
	if file != null {
		filename := convertString(clang_getFileName(file))
		return SourceLocation { filename: filename, line: checked_cast(line, int) }
	} else {
		return SourceLocation{}
	}
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


CXType {
	hash(t CXType) {
		return xor(xor(cast(t.kind, uint), transmute(t.data_0, uint)), transmute(t.data_1, uint))
	}

	equals(a CXType, b CXType) {
		return a.kind == b.kind && a.data_0 == b.data_0 && a.data_1 == b.data_1
	}
}


Sym struct #RefType {
	muName string
	isDone bool
	isZeroSizeStruct bool
	isFunction bool
	aliases List<string>
}

AppState struct #RefType {
	clangTranslationUnit pointer
	isPlatformAgnostic bool
	rules List<Rule>
	ruleLookup List<RuleLookupNode>
	symbols Map<string, Sym>
	anonymousStructs Map<CXType, string>
	macroDefinitions List<string>
	generateErrors List<string>
	output StringBuilder	
	platform string
	targetBits string
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

getSym(name string, symbols Map<string, Sym>) {
	sym := symbols.getOrDefault(name)
	if sym == null {
		sym = new Sym {}
		symbols.add(name, sym)
	}
	return sym
}

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
		sym.muName = name
		if sym.aliases == null {
			sym.aliases = new List<string>{}
		}
		sym.aliases.add(name)

	} else if kind == CXCursorKind.CXCursor_MacroDefinition {
		if clang_Cursor_isMacroFunctionLike(cursor) != 0 {
			return CXChildVisit_Continue
		}

		name := convertString(clang_getCursorSpelling(cursor))
		rule := findRule(name, 0, SymbolKind.const, state.ruleLookup)
		if rule == null {
			return CXChildVisit_Continue
		}

		if !rule.skip && rule.pattern != "*" {
			state.macroDefinitions.add(name)
		} else if rule.skip {
			rule.isMatched = true
		}

	} else if kind == CXCursorKind.CXCursor_VarDecl {
		name := convertString(clang_getCursorSpelling(cursor))
		if name == "muon_ffigen_constant_platform" {
			evalResult := clang_Cursor_Evaluate(cursor)			
			assert(clang_EvalResult_getKind(evalResult) == CXEvalResultKind.CXEval_StrLiteral)
			state.platform = string.from_cstring(clang_EvalResult_getAsStr(evalResult))
		} else if name == "muon_ffigen_constant_target_bits" {
			evalResult := clang_Cursor_Evaluate(cursor)			
			assert(clang_EvalResult_getKind(evalResult) == CXEvalResultKind.CXEval_StrLiteral)
			state.targetBits = string.from_cstring(clang_EvalResult_getAsStr(evalResult))
		}
	}	
	
	return CXChildVisit_Continue
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

getDiscoverySourceText(sourceText string) {
	rb := StringBuilder{}

	rb.write(sourceText)
	rb.write("\n")

	rb.write("#ifdef _WIN32\n")
	rb.write("const char *muon_ffigen_constant_platform = \"Windows\";\n")
	rb.write("#elif __linux__\n")
	rb.write("const char *muon_ffigen_constant_platform = \"Linux\";\n")
	rb.write("#elif __APPLE__\n")
	rb.write("const char *muon_ffigen_constant_platform = \"MacOS\";\n")
	rb.write("#else\n")
	rb.write("const char *muon_ffigen_constant_platform = \"\";\n")
	rb.write("#endif\n")

	rb.write("#if defined(__i386__) || (defined(__arm__) && !defined(__aarch64__))\n")
	rb.write("const char *muon_ffigen_constant_target_bits = \"32-bit\";\n")
	rb.write("#elif defined(__amd64__) || defined(__aarch64__)\n")
	rb.write("const char *muon_ffigen_constant_target_bits = \"64-bit\";\n")
	rb.write("#else\n")
	rb.write("const char *muon_ffigen_constant_target_bits = \"\";\n")
	rb.write("#endif\n")

	return rb.compactToString()
}

getFinalSourceText(sourceText string, state AppState) {
	rb := StringBuilder{}
	rb.write(sourceText)
	rb.write("\n")
	for name in state.macroDefinitions {
		rule := findRule(name, 0, SymbolKind.const, state.ruleLookup)
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
	alignInBytes int
	structName string
	mapTypeFlags MapTypeFlags
	anonymousFieldID int
	nestedID int
	isUnion bool
	hasBitFields bool
	lastOffset int
}

getTypeForSize(size int) {
	if size == 1 {
		return "byte"
	} else if size == 2 {
		return "ushort"
	} else if size == 4 {
		return "uint"
	} else if size == 8 {
		return "ulong"
	} else if size == 16 {
		return "s128"
	}
	return format("FFIGEN_INVALID_PADDING_ELEMENT_{}", size)
}

mapStructFieldWithName(name string, type CXType, ctx *MapStructContext) {
	rb := ctx.rb

	if name == "" {
		name = format("ffigen_anonymous_field{}", ctx.anonymousFieldID)
		ctx.anonymousFieldID += 1
	}

	maybeSizeInBytes := tryGetSizeOfTypeInBytes(type)
	if !maybeSizeInBytes.hasValue {
		rb.write("\t")
		rb.write(name)
		rb.write(" FFIGEN_INVALID_FIELD_SIZE\n")
		return
	}

	size := maybeSizeInBytes.unwrap()
	align := getAlignOfTypeInBytes(type)
	if type.kind == CXTypeKind.CXType_LongDouble || align > ctx.alignInBytes {		
		writeStructPadding(name, size, min(align, ctx.alignInBytes), ctx.rb)

	} else if type.kind == CXTypeKind.CXType_ConstantArray {
		elementType := clang_getArrayElementType(type)
		numElements := clang_getNumElements(type)
		for i := 0_L; i < numElements {
			mapStructFieldWithName(format("{}_{}", name, i), elementType, ctx)
		}

	} else if clang_Cursor_isAnonymous(clang_getTypeDeclaration(type)) != 0 {
		typename := ctx.state.anonymousStructs.getOrDefault(type)
		if typename == "" {
			typename = format("{}_Anonymous{}", ctx.structName, ctx.nestedID)
			ctx.nestedID += 1
			genStruct(typename, type, ctx.mapTypeFlags, ctx.state)
			ctx.state.anonymousStructs.add(type, typename)
		}

		rb.write("\t")
		rb.write(name)
		rb.write(" ")
		rb.write(typename)
		rb.write("\n")
		
	} else {
		rb.write("\t")
		rb.write(name)
		rb.write(" ")
		rb.write(mapType(type, ctx.mapTypeFlags, true, ctx.state).type)
		rb.write("\n")
	}
}

mapStructField(cursor CXCursor, ctx *MapStructContext) int {
	name := convertString(clang_getCursorSpelling(cursor))
	type := clang_getCursorType(cursor)
	mapStructFieldWithName(name, type, ctx)
	return CXChildVisit_Continue
}

MapUnionContext struct {
	muName string
	variantID int
	state AppState
	flags MapTypeFlags
}

mapUnionVariant(cursor CXCursor, ctx *MapUnionContext) int {
	if clang_Cursor_isBitField(cursor) != 0 {
		return CXChildVisit_Continue
	}

	state := ctx.state

	muName := format("{}_Variant{}", ctx.muName, ctx.variantID)
	ctx.variantID += 1

	rb := new StringBuilder{}
	rb.write(muName)
	rb.write(" struct {\n")

	name := convertString(clang_getCursorSpelling(cursor))
	type := clang_getCursorType(cursor)
	align := getAlignOfTypeInBytes(type)
	fieldCtx := MapStructContext { rb: rb, state: state, alignInBytes: align, mapTypeFlags: ctx.flags, structName: muName }
	mapStructFieldWithName(name, type, ref fieldCtx)

	rb.write("}\n")

	state.output.write(rb.compactToString())
	return CXChildVisit_Continue
}

writeStructPadding(name string, size int, elementSize int, rb StringBuilder) {
	count := size / elementSize
	if size % elementSize != 0 {
		rb.write("\t")
		rb.write(name)
		rb.write(" FFIGEN_INVALID_FIELD_ALIGNMENT\n")
	}
	elementType := getTypeForSize(elementSize)
	for i := 0; i < count {
		rb.write("\t")
		rb.write(name)
		rb.write("_")
		i.writeTo(rb)
		rb.write(" ")
		rb.write(elementType)
		rb.write("\n")
	}
}

checkStructField(cursor CXCursor, ctx *MapStructContext) int {
	offset := getOffsetOfFieldInBits(cursor) / 8
	if offset == ctx.lastOffset {
		ctx.isUnion = true
	}
	if clang_Cursor_isBitField(cursor) != 0 {
		ctx.hasBitFields = true
	}
	ctx.lastOffset = offset
	return CXChildVisit_Continue
}

genStruct(muName string, type CXType, flags MapTypeFlags, state AppState) {
	rb := new StringBuilder{}
	rb.write(muName)
	rb.write(" struct {\n")	

	maybeSize := tryGetSizeOfTypeInBytes(type)
	if maybeSize.hasValue {
		size := maybeSize.unwrap()
		align := getAlignOfTypeInBytes(type)

		ctx := MapStructContext { lastOffset: -1 }
		clang_Type_visitFields(type, pointer_cast(checkStructField, pointer), pointer_cast(ref ctx, pointer))
		isUnion := ctx.isUnion
		hasBitFields := ctx.hasBitFields
		ctx = MapStructContext { rb: rb, state: state, alignInBytes: align, mapTypeFlags: flags, structName: muName }

		if !isUnion && !hasBitFields {
			clang_Type_visitFields(type, pointer_cast(mapStructField, pointer), pointer_cast(ref ctx, pointer))
		} else {
			writeStructPadding("padding", size, align, ctx.rb)
			if isUnion {
				uc := MapUnionContext { muName: muName, state: state, flags: flags }
				clang_Type_visitFields(type, pointer_cast(mapUnionVariant, pointer), pointer_cast(ref uc, pointer))
			}
		}
	} else {
		rb.write("\tFFIGEN_INVALID_ZERO_SIZED_STRUCT\n")
	}
	
	rb.write("}\n")

	state.output.write(rb.compactToString())
}

findRuleForAliases(sym Sym, kind SymbolKind, nodes List<RuleLookupNode>) {
	if sym.aliases == null {
		return null
	}
	for a in sym.aliases {
		rule := findRule(a, 0, SymbolKind.struct_, nodes)
		if rule != null {
			return rule
		}
	}
	return null
}

mapStruct(type CXType, isUsage bool, state AppState) {
	assert(type.kind == CXTypeKind.CXType_Record)
	name := stripConstUnaligned(convertString(clang_getTypeSpelling(clang_getCanonicalType(type))))
	sym := getSym(name, state.symbols)
	if sym.isDone {
		return sym
	}

	if sym.muName == "" {
		if name.startsWith("struct ") {
			sym.muName = name.stripPrefix("struct ")
		} else if name.startsWith("union ") {
			sym.muName = name.stripPrefix("union ")
		} else {
			sym.muName = name
		}
	}

	maybeSize := tryGetSizeOfTypeInBytes(type)
	if !maybeSize.hasValue {
		sym.isZeroSizeStruct = true
		return sym
	}

	rule := findRule(name, 0, SymbolKind.struct_, state.ruleLookup)
	if rule == null {
		rule = findRuleForAliases(sym, SymbolKind.struct_, state.ruleLookup)
	}

	if rule == null && !isUsage {
		return sym
	}

	sym.isDone = true

	if rule != null {
		rule.isMatched = true
		if rule.skip {
			return sym
		}
	}

	genStruct(sym.muName, type, (rule != null && rule.prefer_cstring) ? MapTypeFlags.prefer_cstring : MapTypeFlags.none, state)

	return sym
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
			rb := ctx.rb
			value := origValue
			if value >= int.minValue {
				if value < 0 {
					name = format("{}_ffigen_modified", name)
					value = cast(transmute(cast(value, int), uint), long)
				}
				rb.write("\t")
				rb.write(name)
				rb.write(" = ")
				value.writeTo(rb)
				rb.write("_u\n")
			} else {
				rb.write("\tFFIGEN_INVALID_ENUM_VALUE\n")
			}
		}

		mapEnumMemberConst(name, origValue, state)
	}
	return CXChildVisit_Continue
}

mapEnum(type CXType, isUsage bool, state AppState) {
	assert(type.kind == CXTypeKind.CXType_Enum)
	name := stripConstUnaligned(convertString(clang_getTypeSpelling(clang_getCanonicalType(type))))
	sym := getSym(name, state.symbols)
	if sym.isDone {
		return sym
	}

	if sym.muName == "" {
		if name.startsWith("enum ") {
			sym.muName = name.stripPrefix("enum ")
		} else {
			sym.muName = name
		}
	}

	rule := findRule(name, 0, SymbolKind.enum_, state.ruleLookup)
	if rule == null {
		rule = findRuleForAliases(sym, SymbolKind.enum_, state.ruleLookup)
	}

	if rule == null && !isUsage {
		return sym
	}

	sym.isDone = true

	if rule != null {
		rule.isMatched = true
		if rule.skip {
			return sym
		}
	}

	sym.isDone = true

	rb := new StringBuilder{}
	rb.write(sym.muName)
	rb.write(" ")
	rb.write("enum #Flags {\n")

	ctx := MapEnumContext { rb: rb, state: state }
	cursor := clang_getTypeDeclaration(type)
	clang_visitChildren(cursor, pointer_cast(mapEnumMember, pointer), pointer_cast(ref ctx, pointer))

	rb.write("}\n")
	state.output.write(rb.compactToString())
	return sym
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
	return MappedType { type: format("FFIGEN_INVALID_TYPE_{}", cast(type.kind, uint)), error: true }
}

formatPtr(name string, numPtr int) {
	return format("{}{}", string.repeatChar('*', numPtr), name)
}

mapType(type_ CXType, flags MapTypeFlags, isUsage bool, state AppState) MappedType {
	info := unwrapPointerType(clang_getCanonicalType(type_))
	if info.type.kind == CXTypeKind.CXType_Void {
		if info.numPtr > 0 {
			return MappedType { type: formatPtr("pointer", info.numPtr - 1) }
		} else {
			return MappedType { type: "void" }
		}
	} else if info.type.kind == CXTypeKind.CXType_Record {
		sym := mapStruct(info.type, isUsage, state)
		if sym.isZeroSizeStruct {
			if info.numPtr > 0 {
				return MappedType { type: formatPtr("pointer", info.numPtr - 1), marshal: true }
			} else {
				return MappedType { type: "FFIGEN_INVALID_ZERO_SIZED_STRUCT" }
			}
		}
		return MappedType { type: formatPtr(sym.muName, info.numPtr), marshal: true }
	} else if info.type.kind == CXTypeKind.CXType_Enum {
		sym := mapEnum(info.type, isUsage, state)
		return MappedType { type: formatPtr(sym.muName, info.numPtr), marshal: true }
	} else if info.type.kind == CXTypeKind.CXType_ConstantArray || info.type.kind == CXTypeKind.CXType_IncompleteArray {
		elementType := clang_getArrayElementType(info.type)
		mapped := mapType(elementType, MapTypeFlags.none, isUsage, state)
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

mapFunction(cursor CXCursor, state AppState) {
	name := convertString(clang_getCursorSpelling(cursor))
	sym := getSym(name, state.symbols)
	if sym.isDone {
		assert(sym.isFunction)
		return sym
	}
	sym.isFunction = true
	sym.isDone = true
	assert(sym.muName == "")
	sym.muName = name

	rule := findRule(name, 0, SymbolKind.function, state.ruleLookup)
	if rule != null {
		rule.isMatched = true
	}
	if rule == null || rule.skip {
		return sym
	}

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
		mapped := mapType(type, flags, true, state)
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
	mapped := mapType(returnType, flags, true, state)
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
	return sym
}

mapEnumMemberConst(name string, value long, state AppState) {
	sym := getSym(name, state.symbols)
	assert(!sym.isDone)
	sym.isDone = true
	assert(sym.muName == "")
	sym.muName = name

	rule := findRule(name, 0, SymbolKind.const, state.ruleLookup)
	if rule != null {
		rule.isMatched = true
	}
	if rule == null || rule.skip {
		return sym
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
	return sym
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

mapConst(name string, cursor CXCursor, state AppState) {
	sym := getSym(name, state.symbols)
	assert(!sym.isDone)
	sym.isDone = true
	assert(sym.muName == "")
	sym.muName = name

	rule := findRule(name, 0, SymbolKind.const, state.ruleLookup)
	if rule != null {
		rule.isMatched = true
	}
	if rule == null || rule.skip {
		return sym
	}

	evalResult := clang_Cursor_Evaluate(cursor)			
	kind := clang_EvalResult_getKind(evalResult)
	targetType := mapType(clang_getCursorType(cursor), MapTypeFlags.none, true, state).type

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
	return sym
}

mapVar(name string, cursor CXCursor, state AppState) {
	sym := getSym(name, state.symbols)
	assert(!sym.isDone)
	sym.isDone = true
	assert(sym.muName == "")
	sym.muName = name

	rule := findRule(name, 0, SymbolKind.var, state.ruleLookup)
	if rule != null {
		rule.isMatched = true
	}
	if rule == null || rule.skip {
		return sym
	}

	rb := new StringBuilder{}

	rb.write(":")
	rb.write(name)
	rb.write(" ")

	type := clang_getCursorType(cursor)
	typeName := convertString(clang_getTypeSpelling(type))	
	mapped := mapType(type, MapTypeFlags.none, true, state)
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
	return sym
}

generatePass(cursor CXCursor, parent CXCursor, state AppState) int {
	kind := clang_getCursorKind(cursor)
	if kind == CXCursorKind.CXCursor_UnexposedDecl {
		// This could be an "extern "C"" declaration
		return CXChildVisit_Recurse
	
	} else if kind == CXCursorKind.CXCursor_FunctionDecl {
		mapFunction(cursor, state)
	
	} else if kind == CXCursorKind.CXCursor_TypedefDecl {
		type := clang_getCursorType(cursor)
		mapType(type, MapTypeFlags.none, false, state)
	
	} else if kind == CXCursorKind.CXCursor_StructDecl || kind == CXCursorKind.CXCursor_UnionDecl {
		type := clang_getCursorType(cursor)
		mapStruct(type, false, state)

	} else if kind == CXCursorKind.CXCursor_EnumDecl {
		if clang_Cursor_isAnonymous(cursor) != 0 {
			mapAnonymousEnum(cursor, state)
		} else {
			type := clang_getCursorType(cursor)
			mapEnum(type, false, state)
		}

	} else if kind == CXCursorKind.CXCursor_VarDecl {
		name := convertString(clang_getCursorSpelling(cursor))
		type := clang_getCursorType(cursor)
		if clang_isConstQualifiedType(type) != 0 {			
			if name.startsWith(generatedConstPrefix) {
				name = name.slice(generatedConstPrefix.length, name.length)
			}
			mapConst(name, cursor, state)
		} else {
			mapVar(name, cursor, state)
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

	unit := parse(index, args.sourcePath, getDiscoverySourceText(sourceText), clangArgs)
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
		symbols: new Map.create<string, Sym>(),
		anonymousStructs: new Map.create<CXType, string>(),
		macroDefinitions: new List<string>{},
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
	clang_visitChildren(cursor, pointer_cast(discoveryPass, pointer), pointer_cast(state, pointer))

	finalSourceText := getFinalSourceText(sourceText, state)
	unit = parse(index, args.sourcePath, finalSourceText, clangArgs)
	numDiagnostics = clang_getNumDiagnostics(unit)
	generatedConstFirstLine := Util.countLines(sourceText) + 1

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
	state.output.write("// Generated by ffigen 0.2.0\n")
	if state.platform != "" {
		state.output.write(format("// Platform: {}\n", state.platform))
	}
	if state.targetBits != "" {
		state.output.write(format("// Target: {}\n", state.targetBits))
	}
	cursor = clang_getTranslationUnitCursor(unit)
	clang_visitChildren(cursor, pointer_cast(generatePass, pointer), pointer_cast(state, pointer))

	usedSymbols := Set.create<string>()
	duplicates := Set.create<string>()
	for e in state.symbols {
		sym := e.value
		if sym.isDone {
			assert(sym.muName != "")
			if !usedSymbols.tryAdd(sym.muName) {
				duplicates.tryAdd(sym.muName)
			}
		}
	}

	if duplicates.count > 0 || state.generateErrors.count > 0 {
		for it in duplicates {
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

	//Stdout.writeLine(format("{}", state.symbols.count))
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
	} else {
		return "?"
	}
}
