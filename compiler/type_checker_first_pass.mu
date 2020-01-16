Compilation struct #RefType {
	units List<CodeUnit>
	errors List<Error>
	firstTypeCheckErrorIndex int
	top Namespace
	tags CommonTags
	strings Map<string, int>
	flags CompilationFlags
}

CompilationFlags enum #Flags {
	useArgcArgv
	target64bit
}

NamespaceMember tagged_pointer {
	FunctionDef
	FieldDef
	StaticFieldDef
	Namespace
}

Namespace struct #RefType {
	name string
	parent Namespace
	kind NamespaceKind
	flags TypeFlags
	members Map<string, Node>
	defs List<NamespaceDef>
	primaryDef NamespaceDef
	fields List<FieldDef>
	taggedPointerOptions Set<Tag>
	typeParamList List<Namespace>
	tas CustomSet<Array<Tag>>
	tasGenerated CustomSet<Array<Tag>>
	typeUsages Set<Tag>
	rank int
	
	toString(ns Namespace) {
		sb := StringBuilder{}
		ns.writeTo(ref sb)
		return sb.toString()
	}
	
	writeTo(ns Namespace, sb StringBuilder) {
		if ns.parent != null && ns.parent.name != "top___" {
			ns.parent.writeTo(sb)
			sb.write(".")
		}
		sb.write(ns.name)
	}
}

TypeFlags enum #Flags {
	intval
	unsigned
	floatval
	boolval
	char_
	string_
	cstring_
	pointer_
	struct_
	refType
	enum_
	flagsEnum
	taggedPointerEnum
	typeParam
	embeddedTypeParam
	ptr_
	fun_
	isChecking
	hasChecked
	missing
	generated
	
	anyValue = intval | floatval | boolval | char_ | string_ | cstring_ | pointer_ | struct_ | enum_ | taggedPointerEnum | typeParam | ptr_ | fun_
	anyNumber = intval | floatval
	anyPointer = cstring_ | pointer_ | taggedPointerEnum | ptr_ | fun_
	anyString = string_ | cstring_
	anyPointerExceptTaggedPointer = cstring_ | pointer_ | ptr_ | fun_
	anyTransmutableValue = intval | floatval | boolval | char_ | cstring_ | pointer_ | struct_ | enum_ | ptr_ | fun_
}

CommonTags struct #RefType {
	void_ Tag
	sbyte_ Tag
	byte_ Tag
	short_ Tag
	ushort_ Tag
	int_ Tag
	uint_ Tag
	long_ Tag
	ulong_ Tag
	ssize_ Tag
	usize_ Tag
	float_ Tag
	double_ Tag
	bool_ Tag
	bool32_ Tag
	char_ Tag
	string_ Tag
	cstring_ Tag
	pointer_ Tag
	ptrTi Namespace
	funTi Namespace
	// TODO: Make these non-special:
	arrayTi Namespace
	listTi Namespace
	setTi Namespace
	setEntryTi Namespace
	customSetTi Namespace
	mapTi Namespace
	mapEntryTi Namespace
	customMapTi Namespace
}

Tag struct {
	ti Namespace
	args Array<Tag>
	
	toString(tag Tag) {
		sb := StringBuilder{}
		tag.writeTo(ref sb)
		return sb.toString()
	}
	
	writeTo(tag Tag, sb StringBuilder) {
		if tag.ti == null {
			sb.write("?")
			return
		}
		ptr := false
		while (tag.ti.flags & TypeFlags.ptr_) != 0 {
			tag = tag.args[0]
			if tag.ti == null {
				sb.write("*?")
				return
			}
			if (tag.ti.flags & TypeFlags.refType) == 0 {
				sb.write("*")
			}
			ptr = true
		}
		if !ptr && (tag.ti.flags & TypeFlags.refType) != 0 {
			sb.write("$")
		}
		sb.write(tag.ti.name)
		if tag.args == null {
			return
		}
		sb.write("<")
		insertComma := false
		for tag.args {
			if insertComma {
				sb.write(",")
			} else {
				insertComma = true
			}
			it.writeTo(sb)
		}
		sb.write(">")
	}
	
	argsToString(a Array<Tag>) {
		sb := StringBuilder{}
		writeArgsTo(a, ref sb)
		return sb.toString()
	}
	
	writeArgsTo(a Array<Tag>, sb StringBuilder) {
		insertComma := false
		for a {
			if insertComma {
				sb.write(",")
			} else {
				insertComma = true
			}
			it.writeTo(sb)
		}		
	}
	
	equals(a Tag, b Tag) bool {
		if a.ti != b.ti {
			return false
		}
		if a.args != null || b.args != null {
			return argsEquals(a.args, b.args)
		}
		return true
	}
	
	hash(tag Tag) uint {
		h := transmute(tag.ti, uint) >> 3
		if tag.args != null {
			h = xor(h, argsHash(tag.args) << 11)
		}
		return h
	}
	
	argsEquals(a Array<Tag>, b Array<Tag>) bool {
		if a == null && b == null {
			return true
		}
		if a == null || b == null {
			return false
		}
		if a.count != b.count {
			return false
		}
		for i := 0; i < a.count {
			if !equals(a[i], b[i]) {
				return false
			}
		}
		return true
	}
	
	argsHash(args Array<Tag>) uint {
		h := 1_u
		for args {
			h = xor(h, it.hash() + h << 5)
		}
		return h
	}
	
	anyFlags(tag Tag) TypeFlags {
		flags := cast(0_u, TypeFlags)
		if tag.ti != null && tag.ti != Tag.null_.ti {
			flags |= tag.ti.flags
		} else {
			flags |= TypeFlags.missing
		}
		if tag.args != null {
			flags |= argsAnyFlags(tag.args)
		}
		return flags
	}
	
	argsAnyFlags(args Array<Tag>) {
		flags := cast(0_u, TypeFlags)
		for t in args {
			flags |= anyFlags(t)
		}
		return flags
	}
	
	createArgsSet() {
		return CustomSet.create<Array<Tag>>(Tag.argsHash, Tag.argsEquals)
	}
	
	:null_ #Mutable = Tag{}
	
	static_init() {
		null_ = Tag { ti: new Namespace { name: "null___", members: new Map.create<string, Node>(), defs: new List<NamespaceDef>{} } }
	}
}

TypeCheckerFirstPass {
	createContext(comp Compilation) {
		builtins := new Map.create<string, FunctionDef>()
		builtins.add("abandon", new FunctionDef { builtin: BuiltinFunction.abandon })
		builtins.add("assert", new FunctionDef { builtin: BuiltinFunction.assert })
		builtins.add("checked_cast", new FunctionDef { builtin: BuiltinFunction.checked_cast })
		builtins.add("cast", new FunctionDef { builtin: BuiltinFunction.cast })
		builtins.add("pointer_cast", new FunctionDef { builtin: BuiltinFunction.pointer_cast })
		builtins.add("transmute", new FunctionDef { builtin: BuiltinFunction.transmute })
		builtins.add("format", new FunctionDef { builtin: BuiltinFunction.format })
		builtins.add("min", new FunctionDef { builtin: BuiltinFunction.min })
		builtins.add("max", new FunctionDef { builtin: BuiltinFunction.max })
		builtins.add("xor", new FunctionDef { builtin: BuiltinFunction.xor })
		builtins.add("sizeof", new FunctionDef { builtin: BuiltinFunction.sizeof })
		builtins.add("compute_hash", new FunctionDef { builtin: BuiltinFunction.compute_hash })
		builtins.add("default_value", new FunctionDef { builtin: BuiltinFunction.default_value })
		builtins.add("unchecked_index", new FunctionDef { builtin: BuiltinFunction.unchecked_index })
		builtins.add("get_argc_argv", new FunctionDef { builtin: BuiltinFunction.get_argc_argv })
		
		c := new TypeCheckerContext {
			comp: comp, 
			units: comp.units,
			errors: comp.errors,
			top: new Namespace { name: "top___", members: new Map.create<string, Node>(), defs: new List<NamespaceDef>{} },
			locals: new Map.create<string, Tag>(),
			localsList: new List<string>{},
			builtins: builtins,
			builtinIs: new FunctionDef { builtin: BuiltinFunction.is },
			builtinAs: new FunctionDef { builtin: BuiltinFunction.as },
			strings: new Map.create<string, int>(),
			nextStringId: 1,
		}
		
		comp.top = c.top
		comp.strings = c.strings

		return c
	}
	
	check(c TypeCheckerContext) {
		for c.units {
			checkUnit(c, it)
		}
		prevErrorCount := c.errors.count
		buildTags(c)
		if c.errors.count != prevErrorCount {
			return false
		}
		updateCoreTags(c)
		return true
	}
	
	checkUnit(c TypeCheckerContext, unit CodeUnit) {
		c.unit = unit
		for unit.contents {
			match it {
				NamespaceDef: checkNamespace(c, c.top, it)
				FunctionDef: checkFunction(c, c.top, it)
				StaticFieldDef: checkStaticField(c, c.top, it)
				Token: {}
			}
		}
	}
	
	checkNamespace(c TypeCheckerContext, parent Namespace, nd NamespaceDef) {
		mem := parent.members.getOrDefault(nd.name.value)
		ns := cast(null, Namespace)
		newKind := false
		if !mem.is(Namespace) {
			ns = new Namespace { name: nd.name.value, parent: parent, kind: nd.kind, members: new Map.create<string, Node>(), defs: new List<NamespaceDef>{}, primaryDef: nd }
			if mem == null {
				if !isSingleUppercaseLetter(nd.name.value) {
					parent.members.add(nd.name.value, ns)
				} else {
					c.errors.add(Error.at(nd.unit, nd.name.span, "Namespace name must either be longer than 1 character or be lowercase"))
				}
			} else {
				duplicateMember(c, nd.name)
			}
			newKind = true
		} else {
			ns = mem.as(Namespace)
			if ns.kind != NamespaceKind.default_ && nd.kind != NamespaceKind.default_ {
				c.errors.add(Error.at(nd.unit, nd.kindToken.span, "Modifier is incompatible with previous declaration"))
			}
			if ns.kind == NamespaceKind.default_ && nd.kind != NamespaceKind.default_ {
				ns.kind = nd.kind
				ns.primaryDef = nd
				newKind = true
			}
		}
		if newKind {
			if ns.kind == NamespaceKind.struct_ {
				ns.flags |= TypeFlags.struct_
				ns.fields = new List<FieldDef>{}
			} else if ns.kind == NamespaceKind.enum_ {
				ns.flags |= TypeFlags.enum_
				c.hasSeenExplicitEnumValue = false
			} else if ns.kind == NamespaceKind.taggedPointerEnum {
				ns.flags |= TypeFlags.taggedPointerEnum
			}
		}
		nd.ns = ns
		ns.defs.add(nd)
		if nd.typeParams != null {
			if nd.kind == NamespaceKind.struct_ {
				ns.typeParamList = checkTypeParams(c, nd.typeParams)
				ns.tas = new Tag.createArgsSet()
			} else {
				c.errors.add(Error.at(nd.unit, RangeFinder.find(nd.typeParams), "Type parameters can only be defined for struct type"))
			}
		}
		if nd.attributes != null {
			for a in nd.attributes {
				if a.name.value == "RefType" {
					checkRefTypeAttribute(c, ns, a)
				} else if a.name.value == "Flags" {
					checkFlagsAttribute(c, ns, a)
				} else {
					badAttribute(c, a)
				}
			}
		}
		if nd.kind == NamespaceKind.enum_ {
			c.nextAutoValue = (ns.flags & TypeFlags.flagsEnum) != 0 ? 1_u : 0_u
		}
		for nd.contents {
			match it {
				FunctionDef: checkFunction(c, ns, it)
				StaticFieldDef: checkStaticField(c, ns, it)
				FieldDef: checkField(c, ns, it)
				TaggedPointerOptionDef: checkTaggedPointerOption(c, ns, it)
				NamespaceDef: checkNamespace(c, ns, it)
				Token: {}
				TypeParams: {}
			}
		}
	}

	checkTypeParams(c TypeCheckerContext, typeParams TypeParams) {
		result := new List<Namespace>{}
		for tp in typeParams.params {
			if isSingleUppercaseLetter(tp.value) {
				if TypeChecker.findTypeParamByNameOrNull(result, tp.value) == null {
					result.add(new Namespace { name: tp.value, flags: TypeFlags.typeParam })
				} else {
					result.add(null)
					c.errors.add(Error.at(c.unit, tp.span, "A type parameter with the same name has already been defined"))
				}
			} else {
				result.add(null)
				c.errors.add(Error.at(c.unit, tp.span, "Type parameter name must be a single upper case letter"))
			}
		}
		return result
	}
	
	checkFunction(c TypeCheckerContext, parent Namespace, fd FunctionDef) {
		fd.ns = parent
		if !parent.members.tryAdd(fd.name.value, fd) {
			duplicateMember(c, fd.name)
		}
		if fd.typeParams != null {
			fd.typeParamList = checkTypeParams(c, fd.typeParams)
			fd.tas = new Tag.createArgsSet()
		}
		asAttribute := cast(null, Attribute)
		varArgsAttribute := cast(null, Attribute)
		callingConventionAttribute := cast(null, Attribute)
		if fd.attributes != null {
			for a in fd.attributes {
				if a.name.value == "Foreign" {					
					checkFunctionForeignAttribute(c, fd, a)
				} else if a.name.value == "As" {
					if asAttribute == null {
						asAttribute = a
					}
					checkFunctionAsAttribute(c, fd, a)
				} else if a.name.value == "VarArgs" {
					if varArgsAttribute == null {
						varArgsAttribute = a
					}
					checkFunctionVarArgsAttribute(c, fd, a)
				} else if a.name.value == "CallingConvention" {
					if callingConventionAttribute == null {
						callingConventionAttribute = a
					}
					checkFunctionCallingConventionAttribute(c, fd, a)
				} else {
					badAttribute(c, a)
				}
			}
		}
		if (fd.flags & FunctionFlags.foreign) == 0 && asAttribute != null {
			c.errors.add(Error.at(fd.unit, asAttribute.name.span, "Attribute can only be applied to foreign function"))
		}
		if (fd.flags & FunctionFlags.foreign) == 0 && varArgsAttribute != null {
			c.errors.add(Error.at(fd.unit, varArgsAttribute.name.span, "Attribute can only be applied to foreign function"))
		}
		for p in fd.params {
			if p.attributes != null {
				for a in p.attributes {
					if a.name.value == "As" {
						checkParamAsAttribute(c, fd, p, a)
					} else {
						badAttribute(c, a)
					}
				}
			}
		}
		if (fd.flags & FunctionFlags.foreign) != 0 && fd.returnType == null {
			c.errors.add(Error.at(fd.unit, fd.name.span, "Foreign function must declare a return type"))
		}
		if (fd.flags & FunctionFlags.foreign) != 0 && fd.body != null {
			c.errors.add(Error.at(fd.unit, fd.name.span, "Foreign function may not declare a body"))
		}
		if (fd.flags & FunctionFlags.foreign) == 0 && fd.body == null {
			c.errors.add(Error.at(fd.unit, fd.name.span, "Function must declare a body"))
		}
	}

	checkStaticField(c TypeCheckerContext, parent Namespace, sf StaticFieldDef) {
		sf.ns = parent
		if !parent.members.tryAdd(sf.name.value, sf) {
			duplicateMember(c, sf.name)
		}
		if sf.attributes != null {
			for a in sf.attributes {
				if a.name.value == "Mutable" {
					checkMutableAttribute(c, sf, a)
				} else if a.name.value == "ThreadLocal" {
					checkThreadLocalAttribute(c, sf, a)
				} else if a.name.value == "Foreign" {
					checkStaticFieldForeignAttribute(c, sf, a)
				} else {
					badAttribute(c, a)
				}
			}
		}
		if (sf.flags & StaticFieldFlags.isEnumOption) == 0 && sf.type == null && sf.initializeExpr == null {
			c.errors.add(Error.at(sf.unit, sf.name.span, "Static field must declare a type"))
		}
		if (sf.flags & StaticFieldFlags.isEnumOption) != 0 {
			if sf.initializeExpr != null {
				c.hasSeenExplicitEnumValue = true
			} else if c.hasSeenExplicitEnumValue {
				c.errors.add(Error.at(sf.unit, sf.name.span, "Enum option with automatically assigned value must be declared before any options with a manually assigned value"))
			}
		}
		
		if (sf.flags & StaticFieldFlags.isEnumOption) != 0 && sf.initializeExpr == null {
			if (parent.flags & TypeFlags.flagsEnum) != 0 {
				if c.nextAutoValue < uint.maxValue {
					sf.value = c.nextAutoValue
					sf.tag = Tag { ti: parent }
					sf.flags |= StaticFieldFlags.hasFinalType
					if c.nextAutoValue <= uint.maxValue / 2 {
						c.nextAutoValue *= 2
					} else {
						c.nextAutoValue = uint.maxValue
					}					
				} else {
					c.errors.add(Error.at(sf.unit, sf.name.span, "Automatically assigned value overflows"))
				}
			} else {
				assert(c.nextAutoValue < uint.maxValue)
				sf.value = c.nextAutoValue
				sf.tag = Tag { ti: parent }
				sf.flags |= StaticFieldFlags.hasFinalType
				c.nextAutoValue += 1
			}
		}
	}

	checkField(c TypeCheckerContext, parent Namespace, fd FieldDef) {
		fd.ns = parent
		if !parent.members.tryAdd(fd.name.value, fd) {
			duplicateMember(c, fd.name)
		}
		parent.fields.add(fd)
	}

	checkTaggedPointerOption(c TypeCheckerContext, parent Namespace, fd TaggedPointerOptionDef) {
		// TODO?
	}
	
	checkRefTypeAttribute(c TypeCheckerContext, ns Namespace, a Attribute) {
		if ns.kind != NamespaceKind.struct_ {
			c.errors.add(Error.at(c.unit, a.name.span, "Attribute can only be applied to struct type"))
			return
		}		
		if (ns.flags & TypeFlags.refType) != 0 {
			redundantAttribute(c, a)
			return
		}
		checkAttributeArgCount(c, a, 0)
		ns.flags |= TypeFlags.refType
	}
	
	checkFlagsAttribute(c TypeCheckerContext, ns Namespace, a Attribute) {
		if ns.kind != NamespaceKind.enum_ {
			c.errors.add(Error.at(c.unit, a.name.span, "Attribute can only be applied to enum type"))
			return
		}		
		if (ns.flags & TypeFlags.flagsEnum) != 0 {
			redundantAttribute(c, a)
			return
		}
		checkAttributeArgCount(c, a, 0)
		ns.flags |= TypeFlags.flagsEnum
	}
	
	checkFunctionForeignAttribute(c TypeCheckerContext, fd FunctionDef, a Attribute) {
		if (fd.flags & FunctionFlags.foreign) != 0 {
			redundantAttribute(c, a)
			return
		}
		fd.flags |= FunctionFlags.foreign
		if checkAttributeArgCount(c, a, 1) {
			maybeForeignName := getConstantString(c, a.args[0])
			if maybeForeignName.hasValue {
				fd.foreignName = maybeForeignName.value
			}			
		}		
	}
	
	checkFunctionAsAttribute(c TypeCheckerContext, fd FunctionDef, a Attribute) {
		if (fd.flags & FunctionFlags.marshalReturnType) != 0 {
			redundantAttribute(c, a)
			return
		}
		fd.flags |= FunctionFlags.marshalReturnType
		if checkAttributeArgCount(c, a, 1) {
			maybeType := getConstantString(c, a.args[0])
			if maybeType.hasValue {
				fd.marshalReturnType = maybeType.value
			}			
		}	
	}
	
	checkFunctionVarArgsAttribute(c TypeCheckerContext, fd FunctionDef, a Attribute) {
		if (fd.flags & FunctionFlags.varArgs) != 0 {
			redundantAttribute(c, a)
			return
		}
		checkAttributeArgCount(c, a, 0)
		fd.flags |= FunctionFlags.varArgs
	}

	checkFunctionCallingConventionAttribute(c TypeCheckerContext, fd FunctionDef, a Attribute) {
		if (fd.flags & FunctionFlags.callingConvention) != 0 {
			redundantAttribute(c, a)
			return
		}
		fd.flags |= FunctionFlags.callingConvention
		if checkAttributeArgCount(c, a, 1) {
			maybeCalllingConvention := getConstantString(c, a.args[0])
			if maybeCalllingConvention.hasValue {
				fd.callingConvention = maybeCalllingConvention.value
			}			
		}		
	}

	checkParamAsAttribute(c TypeCheckerContext, fd FunctionDef, p Param, a Attribute) {
		if (p.flags & ParamFlags.marshalType) != 0 {
			redundantAttribute(c, a)
			return
		}
		if (fd.flags & FunctionFlags.foreign) == 0 {
			c.errors.add(Error.at(fd.unit, a.name.span, "Attribute can only be applied to foreign function"))
		}
		p.flags |= ParamFlags.marshalType
		if checkAttributeArgCount(c, a, 1) {
			maybeType := getConstantString(c, a.args[0])
			if maybeType.hasValue {
				p.marshalType = maybeType.value
			}			
		}	
	}
	
	checkMutableAttribute(c TypeCheckerContext, sf StaticFieldDef, a Attribute) {
		if (sf.flags & StaticFieldFlags.mutable) != 0 {
			redundantAttribute(c, a)
			return
		}
		checkAttributeArgCount(c, a, 0)
		sf.flags |= StaticFieldFlags.mutable
	}
	
	checkThreadLocalAttribute(c TypeCheckerContext, sf StaticFieldDef, a Attribute) {
		if (sf.flags & StaticFieldFlags.threadLocal) != 0 {
			redundantAttribute(c, a)
			return
		}
		checkAttributeArgCount(c, a, 0)
		sf.flags |= StaticFieldFlags.threadLocal
	}
	
	checkStaticFieldForeignAttribute(c TypeCheckerContext, sf StaticFieldDef, a Attribute) {
		if (sf.flags & StaticFieldFlags.foreign) != 0 {
			redundantAttribute(c, a)
			return
		}
		sf.flags |= StaticFieldFlags.foreign
		if checkAttributeArgCount(c, a, 1) {
			maybeForeignName := getConstantString(c, a.args[0])
			if maybeForeignName.hasValue {
				sf.foreignName = maybeForeignName.value
			}			
		}		
	}
	
	checkAttributeArgCount(c TypeCheckerContext, a Attribute, expected int) {
		actual := a.args != null ? a.args.count : 0
		if actual != expected {
			c.errors.add(Error.at(c.unit, a.openParen != null ? a.openParen.span : a.name.span, format("Expected {} args but got {} args", expected, actual)))
			return false
		}
		return true
	}
	
	redundantAttribute(c TypeCheckerContext, a Attribute) {
		c.errors.add(Error.at(c.unit, a.name.span, format("Redundant attribute: {}", a.name.value)))
	}
	
	badAttribute(c TypeCheckerContext, a Attribute) {
		c.errors.add(Error.at(c.unit, a.name.span, format("Invalid attribute: {}", a.name.value)))
	}
	
	getConstantString(c TypeCheckerContext, a Node) {
		if !a.is(StringExpression) {
			c.errors.add(Error.at(c.unit, RangeFinder.find(a), "Expected: string literal"))	
			return Maybe<string>{}
		}
		e := a.as(StringExpression)
		if e.evaluatedString == "" {
			c.errors.add(Error.at(c.unit, RangeFinder.find(a), "Expected: non-empty string literal"))	
			return Maybe<string>{}
		}
		return Maybe.from(e.evaluatedString)
	}
	
	duplicateMember(c TypeCheckerContext, name Token) {
		c.errors.add(Error.at(c.unit, name.span, "A member with the same name has already been defined"))
	}
	
	invalidTypeDeclaration(c TypeCheckerContext, ti Namespace) {
		c.errors.add(Error.at(ti.primaryDef.unit, ti.primaryDef.name.span, format("Invalid declaration of type {}", ti.name)))
	}
	
	buildTags(c TypeCheckerContext) {
		tags := new CommonTags{}
		tags.void_ = getCoreTypeTag(c, "void")
		tags.sbyte_ = getCoreTypeTag(c, "sbyte")
		tags.byte_ = getCoreTypeTag(c, "byte")
		tags.short_ = getCoreTypeTag(c, "short")
		tags.ushort_ = getCoreTypeTag(c, "ushort")
		tags.int_ = getCoreTypeTag(c, "int")
		tags.uint_ = getCoreTypeTag(c, "uint")
		tags.long_ = getCoreTypeTag(c, "long")
		tags.ulong_ = getCoreTypeTag(c, "ulong")
		tags.ssize_ = getCoreTypeTag(c, "ssize")
		tags.usize_ = getCoreTypeTag(c, "usize")
		tags.float_ = getCoreTypeTag(c, "float")
		tags.double_ = getCoreTypeTag(c, "double")
		tags.bool_ = getCoreTypeTag(c, "bool")
		tags.bool32_ = getCoreTypeTag(c, "bool32")
		tags.char_ = getCoreTypeTag(c, "char")
		
		str := getTypeTi(c, "string")
		if str != null && (str.flags & TypeFlags.struct_) != 0 && str.typeParamList == null
				&& str.members.getOrDefault("dataPtr") != null 
				&& str.members.getOrDefault("length") != null {
			// TODO: verify type of fields?
			// TODO: make sure no other fields are present
			tags.string_ = Tag { ti: str }
		} else {
			badCoreType(c, "string", str)
		}
				
		tags.pointer_ = getCoreTypeTag(c, "pointer")
		tags.cstring_ = getCoreTypeTag(c, "cstring")

		tags.ptrTi = getCoreTypeTag(c, "Ptr").ti
		if tags.ptrTi != null && tags.ptrTi.members.count > 0 {
			badCoreType(c, "Ptr", tags.ptrTi)
		}
		
		tags.funTi = getCoreTypeTag(c, "fun").ti
		if tags.funTi != null && tags.funTi.members.count > 0 {
			badCoreType(c, "fun", tags.funTi)
		}
		
		tags.arrayTi = getTypeTi(c, "Array")
		if tags.arrayTi != null {
			ti := tags.arrayTi
			if ti.typeParamList != null && ti.typeParamList.count == 1 && (ti.flags & TypeFlags.refType) != 0 {
				// OK 
			} else {
				invalidTypeDeclaration(c, ti)
			}
		}
		
		tags.listTi = getTypeTi(c, "List")
		if tags.listTi != null {
			ti := tags.listTi
			if ti.typeParamList != null && ti.typeParamList.count == 1 && (ti.flags & TypeFlags.refType) != 0 {
				// OK 
			} else {
				invalidTypeDeclaration(c, ti)
			}
		}

		tags.setTi = getTypeTi(c, "Set")
		if tags.setTi != null {
			ti := tags.setTi
			if ti.typeParamList != null && ti.typeParamList.count == 1 && (ti.flags & TypeFlags.refType) != 0 {
				// OK 
			} else {
				invalidTypeDeclaration(c, ti)
			}
		}

		tags.setEntryTi = getTypeTi(c, "SetEntry")
		if tags.setEntryTi != null {
			ti := tags.setEntryTi
			if ti.typeParamList != null && ti.typeParamList.count == 1 && (ti.flags & TypeFlags.refType) == 0 {
				// OK 
			} else {
				invalidTypeDeclaration(c, ti)
			}
		}

		tags.customSetTi = getTypeTi(c, "CustomSet")
		if tags.customSetTi != null {
			ti := tags.customSetTi
			if ti.typeParamList != null && ti.typeParamList.count == 1 && (ti.flags & TypeFlags.refType) != 0 {
				// OK 
			} else {
				invalidTypeDeclaration(c, ti)
			}
		}

		tags.mapTi = getTypeTi(c, "Map")
		if tags.mapTi != null {
			ti := tags.mapTi
			if ti.typeParamList != null && ti.typeParamList.count == 2 && (ti.flags & TypeFlags.refType) != 0 {
				// OK 
			} else {
				invalidTypeDeclaration(c, ti)
			}
		}

		tags.customMapTi = getTypeTi(c, "CustomMap")
		if tags.customMapTi != null {
			ti := tags.customMapTi
			if ti.typeParamList != null && ti.typeParamList.count == 2 && (ti.flags & TypeFlags.refType) != 0 {
				// OK 
			} else {
				invalidTypeDeclaration(c, ti)
			}
		}

		tags.mapEntryTi = getTypeTi(c, "MapEntry")
		if tags.mapEntryTi != null {
			ti := tags.mapEntryTi
			if ti.typeParamList != null && ti.typeParamList.count == 2 && (ti.flags & TypeFlags.refType) == 0 {
				// OK 
			} else {
				invalidTypeDeclaration(c, ti)
			}
		}

		c.tags = tags
		c.comp.tags = tags
	}
	
	updateCoreTags(c TypeCheckerContext) {
		tags := c.tags
		
		tags.sbyte_.ti.flags = TypeFlags.intval
		tags.sbyte_.ti.rank = 1

		tags.byte_.ti.flags = TypeFlags.intval | TypeFlags.unsigned
		tags.byte_.ti.rank = 1
		
		tags.short_.ti.flags = TypeFlags.intval
		tags.short_.ti.rank = 2
		
		tags.ushort_.ti.flags = TypeFlags.intval | TypeFlags.unsigned
		tags.ushort_.ti.rank = 2
		
		tags.int_.ti.flags = TypeFlags.intval
		tags.int_.ti.rank = 4
		
		tags.uint_.ti.flags = TypeFlags.intval | TypeFlags.unsigned
		tags.uint_.ti.rank = 4

		tags.long_.ti.flags = TypeFlags.intval
		tags.long_.ti.rank = 8
		
		tags.ulong_.ti.flags = TypeFlags.intval | TypeFlags.unsigned
		tags.ulong_.ti.rank = 8
		
		tags.ssize_.ti.flags = TypeFlags.intval
		tags.ssize_.ti.rank = 6
		
		tags.usize_.ti.flags = TypeFlags.intval | TypeFlags.unsigned
		tags.usize_.ti.rank = 6
		
		tags.float_.ti.flags = TypeFlags.floatval
		tags.float_.ti.rank = 4
		
		tags.double_.ti.flags = TypeFlags.floatval
		tags.double_.ti.rank = 8
		
		tags.bool_.ti.flags = TypeFlags.boolval
		
		tags.bool32_.ti.flags = TypeFlags.boolval
		
		tags.char_.ti.flags = TypeFlags.char_
		
		tags.string_.ti.flags = TypeFlags.struct_ | TypeFlags.string_
		
		tags.cstring_.ti.flags = TypeFlags.cstring_
		
		tags.pointer_.ti.flags = TypeFlags.pointer_
		
		tags.ptrTi.flags = TypeFlags.ptr_
		
		tags.funTi.flags = TypeFlags.fun_
		tags.funTi.tas = new Tag.createArgsSet()
	}
	
	getTypeTi(c TypeCheckerContext, name string) {
		mem := c.top.members.getOrDefault(name)
		return mem.is(Namespace) ? mem.as(Namespace) : null	
	}
	
	getCoreTypeTag(c TypeCheckerContext, name string) {
		ti := getTypeTi(c, name)
		if ti == null || ti.flags != 0 || ti.typeParamList != null {
			badCoreType(c, name, ti)
		}
		return Tag { ti: ti }
	}
	
	badCoreType(c TypeCheckerContext, name string, ti Namespace) {
		c.errors.add(Error.at(null, IntRange{}, format("Fatal: {} declaration of core type {}", ti != null ? "invalid" : "missing", name)))
	}
	
	isSingleUppercaseLetter(s string) {
		return s.length == 1 && s[0] >= 'A' && s[0] <= 'Z'
	}
}


































