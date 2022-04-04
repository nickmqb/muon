CheckStructContext struct {
	state AppState
	isUnion bool
	hasBitFields bool
	lastOffset int
	alignInBytes int
}

MapStructContext struct {
	state AppState
	rb StringBuilder
	structName string
	anonymousFieldID int
	nestedID int
	flags MapFlags
	vc ValidationContext
}

MapUnionContext struct {
	structName string
	variantID int
	state AppState
	flags MapFlags
	vc ValidationContext
}

StructOffset struct {
	structName string
	fieldName string
}

ValidationContext struct #RefType {
	offsets List<StructOffset>
	outerStructType CXType
	cprefix string
	coffset Maybe<long>

	clone(vc ValidationContext) {
		offsets := new List<StructOffset>{}
		for ofs in vc.offsets {
			offsets.add(ofs)
		}
		return ValidationContext {
			offsets: offsets,
			outerStructType: vc.outerStructType,
			cprefix: vc.cprefix,
			coffset: vc.coffset,
		}
	}
}

mapStruct(s AppState, type CXType, outerFlags MapFlags) {
	name := convertString(clang_getTypeSpelling(clang_getCanonicalType(type)))
	if outerFlags & MapFlags.usage != 0 {
		name = stripConstModifier(name)
	}
	if !isValidCStructOrUnionName(name) {
		Stderr.writeLine(format("Warning: encountered strange struct/union name, ignoring: {}", name))
		return null
	}
	ms := mapSymbol(s, name, SymbolKind.struct_, outerFlags & MapFlags.usage != 0)
	if !ms.generate {
		return ms.sym
	}

	maybeSize := tryGetSizeOfTypeInBytes(type)
	if !maybeSize.hasValue {
		ms.sym.isZeroSizeStruct = true
		return ms.sym
	}

	vc := new ValidationContext { offsets: new List<StructOffset>{}, outerStructType: type }
	genStruct(s, ms.sym.muName, type, ms.flags, vc)
	return ms.sym
}

checkStructField(cursor CXCursor, ctx *CheckStructContext) int {
	isBitField := clang_Cursor_isBitField(cursor) != 0
	offsetInBits := getOffsetOfFieldInBits(cursor)
	fieldType := clang_getCursorType(cursor)

	offsetInBytes := offsetInBits / 8
	assert(isBitField || (offsetInBits % 8 == 0))

	if offsetInBytes == ctx.lastOffset {
		ctx.isUnion = true
	}
	if isBitField {
		ctx.hasBitFields = true
	}	
	ctx.alignInBytes = max(ctx.alignInBytes, getAlignOfTypeInBytes(fieldType))

	ctx.lastOffset = offsetInBytes
	return CXChildVisit_Continue
}

genStruct(s AppState, muName string, type CXType, flags MapFlags, vc ValidationContext) {
	rb := new StringBuilder{}
	rb.write(muName)
	rb.write(" struct {\n")	

	maybeSize := tryGetSizeOfTypeInBytes(type)
	if maybeSize.hasValue {		
		validateStruct(s, muName, type)

		checkCtx := CheckStructContext { lastOffset: -1 }
		clang_Type_visitFields(type, pointer_cast(checkStructField, pointer), pointer_cast(ref checkCtx, pointer))

		size := maybeSize.unwrap()
		align := getAlignOfTypeInBytes(type)

		if checkCtx.isUnion {
			writeStructPadding(size, align, rb)
			ctx := MapUnionContext { state: s, flags: flags, structName: muName, vc: vc }
			clang_Type_visitFields(type, pointer_cast(mapUnionVariant, pointer), pointer_cast(ref ctx, pointer))

		} else if checkCtx.hasBitFields {
			rb.write("\t// ffigen_note: generated padding only due to bitfield(s)\n")
			writeStructPadding(size, align, rb)

		} else if checkCtx.alignInBytes != align {
			rb.write("\t// ffigen_note: generated padding only due to non-standard alignment\n")
			writeStructPadding(size, align, rb)

		} else {
			ctx := MapStructContext { state: s, rb: rb, flags: flags, structName: muName, vc: vc }
			clang_Type_visitFields(type, pointer_cast(mapStructField, pointer), pointer_cast(ref ctx, pointer))

		}
	} else {
		rb.write("\tFFIGEN_INVALID_ZERO_SIZED_STRUCT\n")
	}
	
	rb.write("}\n")

	s.output.write(rb.compactToString())
}

mapStructField(cursor CXCursor, ctx *MapStructContext) int {
	name := convertString(clang_getCursorSpelling(cursor))
	type := clang_getCursorType(cursor)
	mapStructFieldWithName(name, name, type, ctx)
	return CXChildVisit_Continue
}

mapStructFieldWithName(name string, cname string, type CXType, ctx *MapStructContext) {
	s := ctx.state
	rb := ctx.rb

	maybeSizeInBytes := tryGetSizeOfTypeInBytes(type)
	if !maybeSizeInBytes.hasValue {
		rb.write("\t")
		rb.write(name)
		rb.write(" FFIGEN_INVALID_FIELD_SIZE\n")
		return
	}

	if name == "" && type.kind != CXTypeKind.CXType_Record {
		rb.write("\t")
		rb.write(name)
		rb.write(" FFIGEN_INVALID_ANONYMOUS_FIELD\n")
		return
	}

	if type.kind == CXTypeKind.CXType_ConstantArray {
		elementType := clang_getArrayElementType(type)
		numElements := clang_getNumElements(type)
		for i := 0_L; i < numElements {			
			prev := ctx.vc.coffset
			ctx.vc.coffset = Maybe.from(ctx.vc.coffset.value + getSizeOfTypeInBytes(elementType) * i)
			mapStructFieldWithName(format("{}_{}", name, i), cname, elementType, ctx)
			ctx.vc.coffset = prev
		}
		return
	}

	hasName := name != ""
	if !hasName {
		name = format("ffigen_anonymous_field{}", ctx.anonymousFieldID)
		cname = getFirstStructFieldName(type)
		ctx.anonymousFieldID += 1
	}

	typename := ""
	if clang_Cursor_isAnonymous(clang_getTypeDeclaration(type)) != 0 {
		if ctx.vc.coffset.hasValue {
			rb.write("\t")
			rb.write(name)
			rb.write(" FFIGEN_INVALID_NESTED_ANONYMOUS_STRUCT\n")
			return
		}

		ctx.state.anonymousStructs.add(type)
		typename = format("{}_Anonymous{}", ctx.structName, ctx.nestedID)
		ctx.nestedID += 1	

		vc := new ctx.vc.clone()
		vc.offsets.add(StructOffset { structName: ctx.structName, fieldName: name })
		if hasName {
			vc.cprefix = format("{}{}.", vc.cprefix, cname)
		}
		genStruct(ctx.state, typename, type, ctx.flags, vc)
	} else {
		typename = mapType(ctx.state, type, ctx.flags | MapFlags.usage).type
	}

	validateField(s, ctx.structName, name, cname, ctx.vc)

	rb.write("\t")
	rb.write(name)
	rb.write(" ")
	rb.write(typename)
	rb.write("\n")
}

mapUnionVariant(cursor CXCursor, ctx *MapUnionContext) int {
	if clang_Cursor_isBitField(cursor) != 0 {
		return CXChildVisit_Continue
	}

	state := ctx.state

	muName := format("{}_Variant{}", ctx.structName, ctx.variantID)
	ctx.variantID += 1

	rb := new StringBuilder{}
	rb.write(muName)
	rb.write(" struct {\n")

	fieldCtx := MapStructContext { rb: rb, state: state, flags: ctx.flags, structName: muName, vc: ctx.vc }
	mapStructField(cursor, ref fieldCtx)

	rb.write("}\n")

	state.output.write(rb.compactToString())
	return CXChildVisit_Continue
}

writeStructPadding(size int, elementSize int, rb StringBuilder) {
	count := size / elementSize
	if size % elementSize != 0 {
		rb.write("\tFFIGEN_INVALID_FIELD_ALIGNMENT\n")
		return
	}
	elementType := getMuonPaddingType(elementSize)
	for i := 0; i < count {
		rb.write("\tffigen_padding")
		i.writeTo(rb)
		rb.write(" ")
		rb.write(elementType)
		rb.write("\n")
	}
}

validateStruct(s AppState, muName string, type CXType) {
	label := "\"Struct validation error\""
	if clang_Cursor_isAnonymous(clang_getTypeDeclaration(type)) != 0 {
		size := getSizeOfTypeInBytes(type)
		align := getAlignOfTypeInBytes(type)
		s.validationOutput.write(format("_Static_assert(sizeof({}__) == {}, {}); // Anonymous struct\n", muName, size, label))
		s.validationOutput.write(format("_Static_assert(alignof({}__) == {}, {}); // Anonymous struct\n", muName, align, label))
	} else {
		cname := convertString(clang_getTypeSpelling(type))
		s.validationOutput.write(format("_Static_assert(sizeof({}__) == sizeof({}), {});\n", muName, cname, label))
		s.validationOutput.write(format("_Static_assert(alignof({}__) == alignof({}), {});\n", muName, cname, label))
	}
}

validateField(s AppState, muStructName string, muName string, cname string, vc ValidationContext) {
	sb := new StringBuilder{}
	sb.write("_Static_assert(")
	for ofs in vc.offsets {
		sb.write("offsetof(")
		sb.write(ofs.structName)
		sb.write("__, ")
		sb.write(ofs.fieldName)
		sb.write("__) + ")
	}
	sb.write("offsetof(")
	sb.write(muStructName)
	sb.write("__, ")
	sb.write(muName)
	sb.write("__) == ")
	
	ctypename := convertString(clang_getTypeSpelling(vc.outerStructType))
	sb.write("offsetof(")
	sb.write(ctypename)
	sb.write(", ")
	sb.write(vc.cprefix)
	sb.write(cname)
	sb.write(")")
	if vc.coffset.hasValue {
		sb.write(" + ")
		vc.coffset.value.writeTo(sb)
	}
	sb.write(", \"Field validation error\");\n")

	s.validationOutput.write(sb.compactToString())
}
