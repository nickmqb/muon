TypeCheckerContext struct #RefType {
	comp Compilation
	units List<CodeUnit>
	errors List<Error>
	top Namespace
	tags CommonTags
	unit CodeUnit
	ns Namespace
	func FunctionDef
	staticField StaticFieldDef
	infoMap Map<Node, NodeInfo>
	locals Map<string, Tag>
	localsList List<string>
	builtins Map<string, FunctionDef>
	builtinIs FunctionDef
	builtinAs FunctionDef
	loop int
	nextAutoValue uint
	strings Map<string, int>
	nextStringId int
	hasSeenExplicitEnumValue bool
}

ResolveTypeOptions enum #Flags {
	structTypeParams
	allowNewFunctionTypeParams
	allowVoid
	structInitializer
	argMask = structTypeParams | allowNewFunctionTypeParams
	none = 0
}

ResolutionContext struct {
	unit CodeUnit
	ns Namespace
	func FunctionDef
	staticField StaticFieldDef
	infoMap Map<Node, NodeInfo>
}

ResolveExpressionOptions enum {
	none
	callTarget
	dotLhs
}

ResolveResult struct {
	tag Tag
	instanceTag Tag
	mem Node
	canAssign bool
}

TypeChecker {
	push(c TypeCheckerContext, unit CodeUnit, ns Namespace) {
		rc := ResolutionContext {
			unit: c.unit,
			ns: c.ns,
			func: c.func,
			staticField: c.staticField,
			infoMap: c.infoMap
		}
		c.unit = unit
		c.ns = ns
		return rc
	}
	
	restore(c TypeCheckerContext, rc ResolutionContext) {
		c.unit = rc.unit
		c.ns = rc.ns
		c.func = rc.func
		c.staticField = rc.staticField
		c.infoMap = rc.infoMap
	}
	
	check(c TypeCheckerContext) {
		doStructPass(c)
		for c.units {
			checkCodeUnit(c, it)
		}
	}
	
	checkHasEntryPoint(c TypeCheckerContext) {
		main := c.top.members.getOrDefault("main")
		if main == null || !main.is(FunctionDef) {
			c.errors.add(Error.at(null, IntRange{}, "Entry point not found: main"))
		}
	}
	
	doStructPass(c TypeCheckerContext) {
		for u in c.units {
			c.unit = u
			for u.contents {
				match it {
					NamespaceDef: checkNamespaceDefStructs(c, it)
					default: {}
				}
			}
		}
	}
	
	checkNamespaceDefStructs(c TypeCheckerContext, nd NamespaceDef) {
		ns := nd.ns
		if nd.kind == NamespaceKind.struct_ {
			if (ns.flags & TypeFlags.hasChecked) == 0 {
				checkStructFields(c, ns)
			}
		} else if nd.kind == NamespaceKind.taggedPointerEnum {
			if ns.taggedPointerOptions == null {
				checkTaggedPointerOptions(c, nd)
			}
		}
		for it in nd.contents {
			match it {
				NamespaceDef: checkNamespaceDefStructs(c, it)
				default: {}
			}
		}
	}
	
	checkStructFields(c TypeCheckerContext, type Namespace) {
		type.flags |= TypeFlags.isChecking
		for fd in type.fields {
			c.unit = fd.unit
			c.ns = type
			fd.tag = resolveType(c, fd.type, ResolveTypeOptions.structTypeParams)
			checkFieldCycles(c, type, fd, fd.tag)
		}
		type.flags &= ~TypeFlags.isChecking
		type.flags |= TypeFlags.hasChecked
	}
	
	checkFieldCycles(c TypeCheckerContext, type Namespace, fd FieldDef, tag Tag) {
		if tag.ti == null {
			return
		}
		if (tag.ti.flags & TypeFlags.struct_) != 0 {
			if (tag.ti.flags & TypeFlags.isChecking) != 0 {
				c.errors.add(Error.at(fd.unit, fd.name.span, "Field forms a cycle"))
				return
			}
			if (tag.ti.flags & TypeFlags.hasChecked) == 0 {
				checkStructFields(c, tag.ti)
			} 
			if tag.args != null {
				for tp, i in tag.ti.typeParamList {
					if (tp.flags & TypeFlags.embeddedTypeParam) != 0 {
						arg := tag.args[i]
						checkFieldCycles(c, type, fd, arg)
					}
				}
			}				
		} else if (tag.ti.flags & TypeFlags.typeParam) != 0 {
			tag.ti.flags |= TypeFlags.embeddedTypeParam
		}
	}
	
	checkTaggedPointerOptions(c TypeCheckerContext, nd NamespaceDef) {
		options := new Set.create<Tag>()
		for nd.contents {
			match it {
				TaggedPointerOptionDef: {
					tag := resolveType(c, it.type, ResolveTypeOptions.none)
					if tag.ti != null {
						if tag.ti == c.tags.ptrTi {
							if !options.tryAdd(tag) {
								c.errors.add(Error.at(nd.unit, RangeFinder.find(it.type), format("Duplicate option: {}", tag.toString())))
							}
						} else {
							c.errors.add(Error.at(nd.unit, RangeFinder.find(it.type), "Expected: pointer type"))
						}					
					}
				}
				default: {}
			}
		}
		nd.ns.taggedPointerOptions = options
	}
	
	resolveType(c TypeCheckerContext, type Node, options ResolveTypeOptions) Tag {
		if type == null {
			return Tag{}
		}
		
		origType := type
		tae := cast(null, TypeArgsExpression)
		if type.is(TypeArgsExpression) {
			tae = type.as(TypeArgsExpression)
			type = tae.target
		}
		
		ptrCount := 0
		firstDollar := cast(null, TypeModifierExpression)
		while type.is(TypeModifierExpression) {
			tme := type.as(TypeModifierExpression)
			if tme.modifier.value == "*" {
				ptrCount += 1
			} else if tme.modifier.value == "$" {
				ptrCount -= 1
				if firstDollar == null {
					firstDollar = tme
				}
			}
			type = tme.arg
		}
		
		top := false
		if type.is(UnaryOperatorExpression) && type.as(UnaryOperatorExpression).op.value == "::" {
			e := type.as(UnaryOperatorExpression)
			top = true
			type = e.expr
		}
		
		ti := cast(null, Namespace)
		args := cast(null, List<Node>)
		errorToken := cast(null, Token)
		
		match type {
			Token: {
				mem := c.top.members.getOrDefault(type.value)
				if mem.is(Namespace) {
					ns := mem.as(Namespace)
					if (ns.flags & TypeFlags.anyValue) != 0 || ns == c.tags.void_.ti {
						ti = ns
					}
				}
				if tae == null {
					if ti == null && !top {
						if c.func != null {
							if c.func.typeParamList != null {
								ti = findTypeParamByNameOrNull(c.func.typeParamList, type.value)
							}						
							if ti == null && (options & ResolveTypeOptions.allowNewFunctionTypeParams) != 0 && TypeCheckerFirstPass.isSingleUppercaseLetter(type.value) {
								if c.func.typeParamList == null {
									c.func.typeParamList = new List<Namespace>{}
									c.func.tas = new Tag.createArgsSet()
								}
								ti = new Namespace { name: type.value, flags: TypeFlags.typeParam }
								c.func.typeParamList.add(ti)
							}
						} else if (options & ResolveTypeOptions.structTypeParams) != 0 && c.ns.typeParamList != null {
							ti = findTypeParamByNameOrNull(c.ns.typeParamList, type.value)
						}
					}
					if ti == null {
						if mem != null {						
							c.errors.add(Error.at(c.unit, type.span, format("Expected type, but got: {}", type.value)))
						} else {
							c.errors.add(Error.at(c.unit, type.span, format("Undefined type: {}", type.value)))
						}
						return getPtrTag(c, Tag{}, ptrCount)
					}
					errorToken = type
				} else {				
					if ti == null {
						if mem != null {						
							c.errors.add(Error.at(c.unit, type.span, format("Expected type, but got: {}", type.value)))
						} else {
							c.errors.add(Error.at(c.unit, type.span, format("Undefined type: {}", type.value)))
						}
						if tae.args != null {
							for a in tae.args {
								resolveType(c, a, options & ResolveTypeOptions.argMask)
							}
						}
						return getPtrTag(c, Tag{}, ptrCount)
					}
					args = tae.args
					errorToken = tae.openAngleBracket
				}
			}
			default: {
				c.errors.add(Error.at(c.unit, RangeFinder.find(origType), "Expected: type"))
				return Tag{}
			}
			null: {
				// Already generated parse error
				return Tag{}
			}
		}

		if (ti.flags & TypeFlags.refType) != 0 && (options & ResolveTypeOptions.structInitializer) == 0 {
			ptrCount += 1
		}
		
		if ptrCount < 0 {
			c.errors.add(Error.at(c.unit, firstDollar.modifier.span, "Cannot apply operator to non-pointer type"))
		}
		
		if ti == c.tags.ptrTi {
			c.errors.add(Error.at(c.unit, type.as(Token).span, "Type is not valid here: Ptr"))
			if args != null {
				for a in args {
					resolveType(c, a, options & ResolveTypeOptions.argMask)
				}
			}
			return Tag{}
		}
		
		typeParamCount := ti.typeParamList != null ? ti.typeParamList.count : 0
		argCount := args != null ? args.count : 0
		
		if ti == c.tags.funTi {
			if argCount > 0 {
				result := Tag { ti: ti, args: new Array<Tag>(argCount) }
				for i := 0; i < argCount - 1 {
					result.args[i] = resolveType(c, args[i], options & ResolveTypeOptions.argMask)
				}
				result.args[argCount - 1] = resolveType(c, args[argCount - 1], (options & ResolveTypeOptions.argMask) | ResolveTypeOptions.allowVoid)
				useType(c, result, (options & ResolveTypeOptions.structTypeParams) != 0)
				return getPtrTag(c, result, ptrCount)
			} else {
				if args == null {
					c.errors.add(Error.at(c.unit, errorToken.span, "Expected: 1 or more type args"))
				} else {
					// Already generated syntax error
				}
				return getPtrTag(c, getSingleArgTag(ti, Tag{}), ptrCount)
			}
		}
		
		if typeParamCount != argCount {
			if (options & ResolveTypeOptions.structInitializer) != 0 && argCount == 0 {
				typeParamCount = 0
			} else {
				c.errors.add(Error.at(c.unit, errorToken.span, format("Expected {} type args but got {} type args", typeParamCount, argCount)))
			}
		}
		
		result := Tag { ti: ti }
		if typeParamCount > 0 {
			result.args = new Array<Tag>(typeParamCount)
			if args != null {
				for a, i in args {
					argTag := resolveType(c, a, options & ResolveTypeOptions.argMask)
					if i < typeParamCount {
						result.args[i] = argTag
					}
				}
				useType(c, result, (options & ResolveTypeOptions.structTypeParams) != 0)
			}		
		} else {
			if args != null {
				for a in args {
					resolveType(c, a, options & ResolveTypeOptions.argMask)
				}
			}
			if ti == c.tags.void_.ti {
				if ptrCount > 0 {
					c.errors.add(Error.at(c.unit, RangeFinder.find(origType), format("Type is not valid: {}", getPtrTag(c, result, ptrCount).toString())))
					return Tag{}
				} else if (options & ResolveTypeOptions.allowVoid) == 0 {
					c.errors.add(Error.at(c.unit, RangeFinder.find(origType), "Type is not valid here: void"))
					return Tag{}
				}
			}
		}

		return getPtrTag(c, result, ptrCount)
	}
	
	useType(c TypeCheckerContext, tag Tag, isFieldType bool) {
		flags := tag.anyFlags()
		if (flags & TypeFlags.missing) != 0 {
			return
		}
		if (flags & TypeFlags.typeParam) != 0 {
			if c.func != null {
				if c.func.typeUsages == null {
					c.func.typeUsages = new Set.create<Tag>()
				}
				c.func.typeUsages.tryAdd(tag)
			} else if isFieldType {
				if c.ns.typeUsages == null {
					c.ns.typeUsages = new Set.create<Tag>()
				}
				c.ns.typeUsages.tryAdd(tag)
			}
		} else {
			tag.ti.tas.tryAdd(tag.args)
		}
	}
	
	recordTag(c TypeCheckerContext, node Node, tag Tag) {
		if tag.ti == null {
			return
		}
		c.infoMap.add(node, NodeInfo { tag: tag })
	}

	recordInfo(c TypeCheckerContext, node Node, rr ResolveResult) {
		c.infoMap.add(node, NodeInfo { tag: rr.tag, mem: rr.mem })
	}
	
	checkCodeUnit(c TypeCheckerContext, unit CodeUnit) {
		c.unit = unit
		for unit.contents {
			match it {
				NamespaceDef: checkNamespace(c, it)
				FunctionDef: {
					if (it.flags & FunctionFlags.hasFinalReturnType) == 0 {
						c.ns = c.top
						checkFunction(c, it)
					}
				}
				StaticFieldDef: {
					c.ns = c.top
					checkStaticField(c, it)
				}
				Token: {}
			}
		}
	}
	
	checkNamespace(c TypeCheckerContext, nd NamespaceDef) {
		for nd.contents {
			match it {
				FunctionDef: {
					if (it.flags & FunctionFlags.hasFinalReturnType) == 0 {
						c.ns = nd.ns
						checkFunction(c, it)
					}
				}
				StaticFieldDef: {
					c.ns = nd.ns
					checkStaticField(c, it)
				}
				NamespaceDef: checkNamespace(c, it)
				FieldDef: {}
				TaggedPointerOptionDef: {}
				Token: {}
				TypeParams: {}
			}
		}
	}
	
	checkFunction(c TypeCheckerContext, fd FunctionDef) {
		c.func = fd
		c.staticField = null
		
		assert((fd.flags & FunctionFlags.hasFinalReturnType) == 0)
		
		for p in fd.params {
			p.tag = resolveType(c, p.type, ResolveTypeOptions.allowNewFunctionTypeParams)
			if (fd.flags & FunctionFlags.foreign) != 0 && p.tag.ti == c.tags.string_.ti {
				c.errors.add(Error.at(c.unit, RangeFinder.find(p.type), "Type is not allowed in foreign function parameter list: string"))
				p.tag = Tag{}
			}
		}
		fd.returnTag = resolveType(c, fd.returnType, ResolveTypeOptions.allowVoid)
		
		if fd.returnTag.ti == null && (fd.flags & FunctionFlags.returnsValue) == 0 {
			fd.returnTag = c.tags.void_
		}
		
		if fd.returnTag.ti != null {
			fd.flags |= FunctionFlags.hasFinalReturnType
		} else {
			fd.flags |= FunctionFlags.isDeterminingReturnType
		}		
		
		if fd.body != null {
			prevLocals := c.locals
			c.locals = new Map.create<string, Tag>()
			fd.infoMap = new Map.create<Node, NodeInfo>()
			c.infoMap = fd.infoMap
			for p in fd.params {		
				name := p.name.value
				if !c.locals.tryAdd(name, p.tag) {
					c.errors.add(Error.at(fd.unit, p.name.span, format("A parameter with the same name has already been defined: {}", name)))
				}
			}		
			checkBlockStatement(c, fd.body)
			c.locals = prevLocals
		}

		fd.flags &= ~FunctionFlags.isDeterminingReturnType
		fd.flags |= FunctionFlags.hasFinalReturnType
		
		if fd.returnTag.ti == Tag.null_.ti || (fd.flags & FunctionFlags.requireExplicitReturnType) != 0 {
			c.errors.add(Error.at(fd.unit, fd.name.span, "The return type cannot be inferred; specify it explicitly"))
		}
		if (fd.flags & FunctionFlags.foreign) != 0 && fd.typeParamList != null {
			c.errors.add(Error.at(fd.unit, fd.name.span, "Foreign function may not declare any type parameters"))
		}
	}
	
	checkStaticField(c TypeCheckerContext, sf StaticFieldDef) {
		c.func = null
		c.staticField = sf
		
		if (sf.flags & StaticFieldFlags.hasFinalType) != 0 {
			return
		}
		
		if (sf.flags & StaticFieldFlags.isEnumOption) != 0 {
			sf.tag = Tag { ti: sf.ns }
		} else {
			sf.tag = resolveType(c, sf.type, ResolveTypeOptions.none)
		}		
		
		if sf.initializeExpr != null {
			sf.flags |= StaticFieldFlags.isChecking
			sf.infoMap = new Map.create<Node, NodeInfo>()
			c.infoMap = sf.infoMap
			exprTag := checkExpression(c, sf.initializeExpr)
			sf.flags &= ~StaticFieldFlags.isChecking

			if (sf.flags & StaticFieldFlags.cycle) != 0 {
				c.errors.add(Error.at(sf.unit, RangeFinder.find(sf.initializeExpr), "Static field initializer expression forms a cycle"))
			}
			if (sf.flags & StaticFieldFlags.threadLocal) != 0 {
				c.errors.add(Error.at(sf.unit, sf.assign.span, format("Thread local static field cannot be initialized at compile time")))
			}
			if (sf.flags & StaticFieldFlags.foreign) != 0 {
				c.errors.add(Error.at(sf.unit, sf.assign.span, "Foreign static field cannot specify initializer expression"))
			}
			if exprTag.ti != null {
				if (sf.flags & StaticFieldFlags.isEnumOption) != 0 && sf.initializeExpr.is(NumberExpression) {
					if !assign(c, exprTag, sf.initializeExpr, c.tags.uint_) {
						badConversion(c, sf.assign, exprTag, sf.tag)
					}
				} else if sf.tag.ti != null {
					if !assign(c, exprTag, sf.initializeExpr, sf.tag) {
						c.errors.add(Error.at(sf.unit, sf.assign.span, format("Cannot assign {} to {}", exprTag.toString(), sf.tag.toString())))
					}
				} else {
					sf.tag = exprTag
				}
			}
		}

		sf.flags |= StaticFieldFlags.hasFinalType
	}

	checkBlockStatement(c TypeCheckerContext, a BlockStatement) {
		prev := c.localsList.count
		for a.contents {
			match it {
				BlockStatement: checkBlockStatement(c, it)
				ExpressionStatement: checkExpressionStatement(c, it)
				ReturnStatement: checkReturnStatement(c, it)
				BreakStatement: checkBreakStatement(c, it)
				ContinueStatement: checkContinueStatement(c, it)
				IfStatement: checkIfStatement(c, it)
				WhileStatement: checkWhileStatement(c, it)
				ForEachStatement: checkForEachStatement(c, it)
				ForIndexStatement: checkForIndexStatement(c, it)
				MatchStatement: checkMatchStatement(c, it)
				Token: {}
			}
		}
		removeLocals(c, prev)
	}
	
	checkInlineStatement(c TypeCheckerContext, st Node) {
		match st {
			BlockStatement: checkBlockStatement(c, st)
			ExpressionStatement: checkExpressionStatement(c, st)
			ReturnStatement: checkReturnStatement(c, st)
			Token: {}
		}
	}
	
	removeLocals(c TypeCheckerContext, from int) {
		for i := from; i < c.localsList.count {
			c.locals.remove(c.localsList[i])
		}
		c.localsList.setCountChecked(from)
	}
	
	checkExpressionStatement(c TypeCheckerContext, st ExpressionStatement) {
		if st.expr.is(BinaryOperatorExpression) {
			bin := st.expr.as(BinaryOperatorExpression)
			if bin.op.value == ":=" {
				checkDeclareStatement(c, bin)
				return
			} else if Parser.isAssignOp(bin.op.value) {
				checkAssignStatement(c, bin)
				return
			}
		}
		checkExpression(c, st.expr)
	}
	
	checkDeclareStatement(c TypeCheckerContext, e BinaryOperatorExpression) {
		rhsTag := checkExpression(c, e.rhs)
		if !e.lhs.is(Token) {
			c.errors.add(Error.at(c.unit, RangeFinder.find(e.lhs), "Expected: identifier"))
			return
		}
		if rhsTag.ti != null && (rhsTag.ti.flags & TypeFlags.anyValue) == 0 {
			c.errors.add(Error.at(c.unit, e.op.span, format("Cannot assign expression of type {} to variable", rhsTag.toString())))
			rhsTag = Tag{}
		}
		name := e.lhs.as(Token).value
		if !c.locals.tryAdd(name, rhsTag) {
			badLocalVar(c, name, e.lhs)
			return
		}
		c.localsList.add(name)		
	}
	
	checkAssignStatement(c TypeCheckerContext, e BinaryOperatorExpression) {
		rhsTag := checkExpression(c, e.rhs)
		lr := resolveExpression(c, e.lhs, ResolveExpressionOptions.none)
		mem := lr.mem
		if mem.is(StaticFieldDef) && (mem.as(StaticFieldDef).flags & StaticFieldFlags.mutable) == 0 {
			c.errors.add(Error.at(c.unit, RangeFinder.find(e.lhs), "Constant static field cannot be assigned to"))
			return
		}
		if lr.tag.ti != null {
			if lr.canAssign {
				tag := lr.tag
				if e.op.value == "=" {
					if !assign(c, rhsTag, e.rhs, tag) {
						badConversion(c, e.op, rhsTag, tag)
					}
				} else {
					pe := c.errors.count
					op := e.op.value
					op = op.slice(0, op.length - 1)
					resultTag := applyBinaryOperator(c, op, tag, e.lhs, rhsTag, e.rhs, e.op)
					if c.errors.count == pe && !assign(c, resultTag, null, tag) {
						badConversion(c, e.op, resultTag, tag)
					}
					recordTag(c, e, resultTag)
				}
			} else {
				c.errors.add(Error.at(c.unit, RangeFinder.find(e.lhs), "Expression cannot be assigned to"))
			}
		}
	}

	checkReturnStatement(c TypeCheckerContext, st ReturnStatement) {
		if st.expr != null {
			tag := checkExpression(c, st.expr)
			tag = unify(c, c.func.returnTag, null, tag, st.expr, st.expr)
			if tag.ti != null {
				c.func.returnTag = tag
			}
		} else {
			if (c.func.flags & FunctionFlags.returnsValue) != 0 || c.func.returnTag.ti != c.tags.void_.ti {
				c.errors.add(Error.at(c.unit, st.keyword.span, "Function must return a value"))
			}
		}
	}
	
	checkBreakStatement(c TypeCheckerContext, st BreakStatement) {
		if c.loop == 0 {
			c.errors.add(Error.at(c.unit, st.keyword.span, "break is not valid here"))
		}
	}
	
	checkContinueStatement(c TypeCheckerContext, st ContinueStatement) {
		if c.loop == 0 {
			c.errors.add(Error.at(c.unit, st.keyword.span, "continue is not valid here"))
		}
	}
	
	checkIfStatement(c TypeCheckerContext, st IfStatement) {
		cond := checkExpression(c, st.conditionExpr)
		if cond.ti != null && (cond.ti.flags & TypeFlags.boolval) == 0 {
			c.errors.add(Error.at(c.unit, RangeFinder.find(st.conditionExpr), "Expected: expression of type bool"))
		}
		if st.ifBranch != null {
			checkBlockStatement(c, st.ifBranch)
		}
		elseBranch := st.elseBranch
		match elseBranch {
			IfStatement: checkIfStatement(c, elseBranch)
			BlockStatement: checkBlockStatement(c, elseBranch)
			null: {}
		}
	}
	
	checkWhileStatement(c TypeCheckerContext, st WhileStatement) {
		cond := checkExpression(c, st.conditionExpr)
		if cond.ti != null && (cond.ti.flags & TypeFlags.boolval) == 0 {
			c.errors.add(Error.at(c.unit, RangeFinder.find(st.conditionExpr), "Expected: expression of type bool"))
		}
		if st.body != null {
			c.loop += 1
			checkBlockStatement(c, st.body)
			c.loop -= 1
		}
	}
	
	checkForEachStatement(c TypeCheckerContext, st ForEachStatement) {
		seqWrapped := checkExpression(c, st.sequenceExpr)
		seq := seqWrapped.ti == c.tags.ptrTi ? seqWrapped.args[0] : seqWrapped
		element := Tag{}
		if seq.ti != null {
			if seq.ti == c.tags.arrayTi || seq.ti == c.tags.listTi || seq.ti == c.tags.setTi || seq.ti == c.tags.customSetTi || ((seq.ti.flags & TypeFlags.indexable) != 0 && seq.args != null && seq.args.count > 0) {
				element = seq.args[0]
			} else if seq.ti == c.tags.setTi || seq.ti == c.tags.customSetTi {
				if c.tags.setEntryTi != null {
					element = seq.args[0]
				} else {
					c.errors.add(Error.at(c.unit, RangeFinder.find(st.keyword), "Missing declaration of type SetEntry; cannot iterate over set"))
				}
			} else if seq.ti == c.tags.mapTi || seq.ti == c.tags.customMapTi {
				if c.tags.mapEntryTi != null {
					element = Tag { ti: c.tags.mapEntryTi, args: seq.args }
				} else {
					c.errors.add(Error.at(c.unit, RangeFinder.find(st.keyword), "Missing declaration of type MapEntry; cannot iterate over map"))
				}
			} else {
				c.errors.add(Error.at(c.unit, RangeFinder.find(st.sequenceExpr), format("Expected: expression of type Array, List, Set, Map or some #Indexable, but got: {}", seq.toString())))
			}
		}
		prev := c.localsList.count
		it := st.iteratorVariable != null ? st.iteratorVariable.value : "it"
		if c.locals.tryAdd(it, element) {
			c.localsList.add(it)
		} else {
			badLocalVar(c, it, st.iteratorVariable != null ? st.iteratorVariable : st.keyword)
		}
		if st.indexIteratorVariable != null {
			index := st.indexIteratorVariable.value
			if c.locals.tryAdd(index, c.tags.int_) {
				c.localsList.add(index)
			} else {
				badLocalVar(c, index, st.indexIteratorVariable)
			}			
		}
		if st.body != null {
			c.loop += 1
			checkBlockStatement(c, st.body)
			c.loop -= 1
		}
		removeLocals(c, prev)
	}
	
	checkForIndexStatement(c TypeCheckerContext, st ForIndexStatement) {
		prev := c.localsList.count
		if st.initializeStatement != null {
			checkExpressionStatement(c, st.initializeStatement)
		}
		cond := checkExpression(c, st.conditionExpr)
		if cond.ti != null && (cond.ti.flags & TypeFlags.boolval) == 0 {
			c.errors.add(Error.at(c.unit, RangeFinder.find(st.conditionExpr), "Expected: expression of type bool"))
		}
		if st.nextStatement != null {
			checkInlineStatement(c, st.nextStatement)
		}
		if st.body != null {
			c.loop += 1
			checkBlockStatement(c, st.body)
			c.loop -= 1
		}
		removeLocals(c, prev)
	}
	
	checkMatchStatement(c TypeCheckerContext, st MatchStatement) {
		matchTag := checkExpression(c, st.expr)
		options := cast(null, Set<Tag>)
		if matchTag.ti != null {
			if (matchTag.ti.flags & TypeFlags.taggedPointerEnum) != 0 {
				options = matchTag.ti.taggedPointerOptions
			} else {
				c.errors.add(Error.at(c.unit, RangeFinder.find(st.expr), "Expected: tagged pointer enum"))
			}
		}
		local := st.expr.is(Token) && st.expr.as(Token).type == TokenType.identifier ? st.expr.as(Token).value : ""		
		savedTag := local != "" ? c.locals.get(local) : Tag{}
		allCaseFlags := cast(0_u, MatchCaseFlags)
		allOptions := Set.create<Tag>()
		for case in st.cases {
			tag := Tag{}
			if case.flags != 0 {
				if ((allCaseFlags & case.flags) & MatchCaseFlags.null_) != 0 {
					c.errors.add(Error.at(c.unit, RangeFinder.find(case.type.as(Token).value == "null" ? case.type : case.secondType), "Duplicate match case"))
				}
				if ((allCaseFlags & case.flags) & MatchCaseFlags.default_) != 0 {
					c.errors.add(Error.at(c.unit, RangeFinder.find(case.type.as(Token).value == "default" ? case.type : case.secondType), "Duplicate match case"))
				}
				allCaseFlags |= case.flags
			} else {
				tag = resolveType(c, case.type, ResolveTypeOptions.none)
				if tag.ti != null {
					case.tag = tag
					flags := tag.anyFlags()
					if (flags & TypeFlags.typeParam) != 0 {
						c.errors.add(Error.at(c.unit, RangeFinder.find(case.type), "Match case type may not contain any type parameters"))
					} else if (flags & TypeFlags.missing) != 0 {
						// Already generated type error
					} else if options != null && !options.contains(tag) {
						c.errors.add(Error.at(c.unit, RangeFinder.find(case.type), "Match case will never be run"))
					} else if !allOptions.tryAdd(tag) {
						c.errors.add(Error.at(c.unit, RangeFinder.find(case.type), "Duplicate match case"))
					}
				}				
			}
			if local != "" {
				c.locals.update(local, tag.ti != null ? tag : savedTag)
			}
			if case.statement != null {
				checkInlineStatement(c, case.statement)
			}
		}		
		if local != "" {
			c.locals.update(local, savedTag)
		}
	}
	
	unpackMember(c TypeCheckerContext, mem Node, e Node, opt ResolveExpressionOptions) ResolveResult {
		match mem {
			FunctionDef: {
				if (mem.flags & FunctionFlags.hasFinalReturnType) == 0 {
					recursiveCheckFunction(c, mem)
				}
				if opt == ResolveExpressionOptions.callTarget {
					result := ResolveResult { mem: mem } // Omit tag, don't need it for call.
					recordInfo(c, e, result)
					return result
				}
				result := ResolveResult { mem: mem, tag: getFunctionPointerTag(c, mem, (mem.flags & FunctionFlags.isDeterminingReturnType) != 0, e) }
				recordInfo(c, e, result)
				return result
			}
			StaticFieldDef: {
				if (mem.flags & StaticFieldFlags.hasFinalType) == 0 {
					recursiveCheckStaticField(c, mem)
				}
				result := ResolveResult { mem: mem, tag: mem.tag, canAssign: (mem.flags & StaticFieldFlags.mutable) != 0 }
				recordInfo(c, e, result)
				return result
			}
			Namespace: {
				ns := mem
				if opt == ResolveExpressionOptions.dotLhs {
					result := ResolveResult { mem: ns }
					recordInfo(c, e, result)
					return result
				} else if opt == ResolveExpressionOptions.none {
					badTypeHere(c, e, ns)
					return ResolveResult{}
				}
				if (ns.flags & TypeFlags.anyValue) == 0 {
					c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Expected type, but got: {}", ns.toString())))
				}
				cons := ns.members.getOrDefault("cons")
				if cons != null && cons.is(FunctionDef) {
					consFd := cons.as(FunctionDef)
					if (consFd.flags & FunctionFlags.hasFinalReturnType) == 0 {
						recursiveCheckFunction(c, consFd)
					}
					result := ResolveResult { mem: cons.as(FunctionDef) } // Omit tag, don't need it for call.
					recordInfo(c, e, result)
					return result
				} else {
					c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Undefined member: {}.cons", ns.name)))
					return ResolveResult{}
				}							
			}
		}
	}
	
	resolveExpression(c TypeCheckerContext, e Node, opt ResolveExpressionOptions) ResolveResult {
		match e {
			Token: {
				if e.type == TokenType.identifier {					
					if e.value == "null" {						
						result := ResolveResult { tag: Tag.null_ }
						recordInfo(c, e, result)
						return result
					} else if e.value == "true" || e.value == "false" {
						result := ResolveResult { tag: c.tags.bool_ }
						recordInfo(c, e, result)
						return result
					}
					local := c.locals.maybeGet(e.value)
					if local.hasValue {
						result := ResolveResult { tag: local.value, canAssign: true }
						recordInfo(c, e, result)
						return result
					}
					mem := c.ns.members.getOrDefault(e.value)
					if mem == null || mem.is(FieldDef) {
						mem = c.top.members.getOrDefault(e.value)	
						if mem == null && opt == ResolveExpressionOptions.callTarget {
							builtin := c.builtins.getOrDefault(e.value)
							if builtin != null {
								result := ResolveResult { mem: builtin }
								recordInfo(c, e, result)
								return result
							}
						}
					}
					if mem == null {
						c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Undefined symbol: {}", e.value)))
						return ResolveResult{}
					}
					return unpackMember(c, mem, e, opt)
				} else {
					return ResolveResult { tag: checkToken(c, e) }
				}
			}
			UnaryOperatorExpression: {
				if e.op.value == "::" {
					if e.expr == null {
						return ResolveResult{}
					}
					token := e.expr.as(Token)
					mem := c.top.members.getOrDefault(token.value)
					if mem == null {
						c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Undefined top-level symbol: {}", token.value)))
						return ResolveResult{}
					}
					return unpackMember(c, mem, e, opt)
				} else {
					return ResolveResult { tag: checkUnaryOperatorExpression(c, e) }
				}
			}
			DotExpression: {
				rhs := e.rhs
				if rhs == null {
					return ResolveResult{}
				}
				rl := resolveExpression(c, e.lhs, ResolveExpressionOptions.dotLhs)
				mem := rl.mem
				match mem {
					FunctionDef: {
						c.errors.add(Error.at(c.unit, rhs.span, format("Undefined member: fun<>.{}", rhs.value)))
						return ResolveResult{}
					}
					Namespace: {
						ns := mem
						rhsMem := ns.members.getOrDefault(rhs.value)
						if rhsMem.is(FieldDef) {
							c.errors.add(Error.at(c.unit, rhs.span, format("Must access field via instance: {}.{}", ns.name, rhs.value)))
							return ResolveResult{}
						}
						if rhsMem == null {
							c.errors.add(Error.at(c.unit, rhs.span, format("Undefined member: {}.{}", ns.name, rhs.value)))
							return ResolveResult{}
						}
						return unpackMember(c, rhsMem, e, opt)
					}
					default | null: {}
				}
				if rl.tag.ti == null {
					return ResolveResult{}
				}
				if opt == ResolveExpressionOptions.callTarget {
					if (rl.tag.ti == Tag.null_.ti || (rl.tag.ti.flags & TypeFlags.anyPointer) != 0) {
						if rhs.value == "as" {
							result := ResolveResult { mem: c.builtinAs, instanceTag: rl.tag }
							recordInfo(c, e, result)
							return result
						}
					} else if e.lhs.is(StringExpression) {
						if rhs.value == "format" {
							result := ResolveResult { mem: c.builtins.get("format"), instanceTag: rl.tag }
							recordInfo(c, e, result)
							return result
						}
					}				
				}
				rlTag := rl.tag
				isPtr := false
				if rlTag.ti == c.tags.ptrTi {
					rlTag = rl.tag.args[0]
					if rlTag.ti == null {
						return ResolveResult{}
					}
					isPtr = true
				}
				if opt == ResolveExpressionOptions.callTarget && (rlTag.ti.flags & TypeFlags.taggedPointerEnum) != 0 {
					if rhs.value == "is" {
						result := ResolveResult { mem: c.builtinIs, instanceTag: rl.tag }
						recordInfo(c, e, result)
						return result
					} else if rhs.value == "as" {
						result := ResolveResult { mem: c.builtinAs, instanceTag: rl.tag }
						recordInfo(c, e, result)
						return result
					}
				}
				if (rlTag.ti.flags & TypeFlags.typeParam) != 0 {
					c.errors.add(Error.at(c.unit, rhs.span, format("Undefined member: {}.{}", rl.tag.ti.name, rhs.value)))
					return ResolveResult{}
				}
				mem = rlTag.ti.members.getOrDefault(rhs.value)
				match mem {
					Namespace: {
						c.errors.add(Error.at(c.unit, rhs.span, format("Must access namespace via namespace: {}.{}", rlTag.ti.name, rhs.value)))
						return ResolveResult{}
					}
					StaticFieldDef: {
						c.errors.add(Error.at(c.unit, rhs.span, format("Must access static field via namespace: {}.{}", rlTag.ti.name, rhs.value)))
						return ResolveResult{}
					}
					FunctionDef: {
						if (mem.flags & FunctionFlags.hasFinalReturnType) == 0 {
							recursiveCheckFunction(c, mem)
						}
						if opt == ResolveExpressionOptions.callTarget {
							result := ResolveResult { mem: mem, instanceTag: rl.tag } // Omit tag, don't need it for call.
							recordInfo(c, e, result)
							return result
						}
						c.errors.add(Error.at(c.unit, rhs.span, format("Must obtain fun<> via namespace: {}.{}", mem.ns.name, mem.name.value)))
						return ResolveResult{}
					}
					FieldDef: {
						result := ResolveResult { mem: mem, tag: closeTag(mem.tag, rlTag.ti.typeParamList, rlTag.args), instanceTag: rl.tag, canAssign: rl.canAssign || isPtr }
						recordInfo(c, e, result)
						return result
					}
					null: {
						c.errors.add(Error.at(c.unit, rhs.span, format("Undefined member: {}.{}", rlTag.ti.name, rhs.value)))
						return ResolveResult{}
					}
				}
			}
			IndexExpression: {
				return resolveIndexExpression(c, e)
			}
			PostfixUnaryOperatorExpression: {
				return ResolveResult { tag: checkPostfixUnaryOperatorExpression(c, e), canAssign: true }
			}
			CallExpression: {
				return resolveCallExpression(c, e)
			}
			default: return ResolveResult { tag: checkExpression(c, e) }
			null: return ResolveResult{}
		}
	}
	
	recursiveCheckFunction(c TypeCheckerContext, fd FunctionDef) {
		if (fd.flags & FunctionFlags.isDeterminingReturnType) != 0 {
			fd.flags |= FunctionFlags.requireExplicitReturnType
		} else {
			prev := push(c, fd.unit, fd.ns)
			checkFunction(c, fd)
			restore(c, prev)
		}						
	}
	
	recursiveCheckStaticField(c TypeCheckerContext, sf StaticFieldDef) {
		if (sf.flags & StaticFieldFlags.isChecking) != 0 {
			sf.flags |= StaticFieldFlags.cycle
		} else {
			prev := push(c, sf.unit, sf.ns)
			checkStaticField(c, sf)
			restore(c, prev)
		}
	}
	
	getFunctionPointerTag(c TypeCheckerContext, fd FunctionDef, eraseReturnType bool, err Node) {
		if fd.typeParamList != null {
			c.errors.add(Error.at(c.unit, RangeFinder.find(err), "Cannot convert function with type parameters to fun<>"))
			return Tag{}
		}
		if (fd.flags & FunctionFlags.foreign) != 0 {
			c.errors.add(Error.at(c.unit, RangeFinder.find(err), "Cannot convert foreign function to fun<>"))
			return Tag{}
		}
		ta := new Array<Tag>(fd.params.count + 1)
		for p, i in fd.params {
			ta[i] = p.tag
		}
		if !eraseReturnType {
			ta[fd.params.count] = fd.returnTag
			if (Tag.argsAnyFlags(ta) & TypeFlags.missing) == 0 {
				c.tags.funTi.tas.tryAdd(ta)				
			}
		}
		return Tag { ti: c.tags.funTi, args: ta }
	}

	checkExpression(c TypeCheckerContext, e Node) Tag {
		match e {
			Token: return checkToken(c, e)
			NumberExpression: return checkNumberExpression(c, e)
			StringExpression: return checkStringExpression(c, e)
			UnaryOperatorExpression: return checkUnaryOperatorExpression(c, e)
			PostfixUnaryOperatorExpression: return checkPostfixUnaryOperatorExpression(c, e)
			DotExpression: return resolveExpression(c, e, ResolveExpressionOptions.none).tag
			BinaryOperatorExpression: return checkBinaryOperatorExpression(c, e)
			TernaryOperatorExpression: return checkTernaryOperatorExpression(c, e)
			CallExpression: return resolveCallExpression(c, e).tag
			StructInitializerExpression: return checkStructInitializerExpression(c, e)
			IndexExpression: return resolveIndexExpression(c, e).tag
			TypeArgsExpression: {
				tag := resolveType(c, e, ResolveTypeOptions.none)
				if tag.ti != null {
					badTagHere(c, e, tag)
				}
				return Tag{}
			}
			TypeModifierExpression: {
				tag := resolveType(c, e, ResolveTypeOptions.none)
				if tag.ti != null {
					badTagHere(c, e, tag)
				}
				return Tag{}
			}
			ParenExpression: {
				result := checkExpression(c, e.expr)
				recordTag(c, e, result)
				return result
			}
			null: return Tag{}
		}
	}
	
	checkToken(c TypeCheckerContext, e Token) Tag {
		if e.value == "null" {
			result := Tag.null_
			recordTag(c, e, result)
			return result
		} else if e.value == "true" || e.value == "false" {
			result := c.tags.bool_
			recordTag(c, e, result)
			return result
		} else if e.type == TokenType.stringLiteral {
			result := c.tags.string_
			recordTag(c, e, result)
			return result
		} else if e.type == TokenType.characterLiteral {
			result := c.tags.char_
			recordTag(c, e, result)
			return result
		} else if e.type == TokenType.identifier {
			return resolveExpression(c, e, ResolveExpressionOptions.none).tag
		} else {
			abandon()
		}
	}
	
	checkNumberExpression(c TypeCheckerContext, e NumberExpression) {
		suffixFrom := e.valueSpan.to + 1
		suffix := suffixFrom < e.token.span.to ? e.token.value.slice(suffixFrom - e.token.span.from, e.token.value.length) : ""
		if (e.flags & NumberFlags.intval) != 0 {
			tag := suffix != "" ? numberSuffixToTag(c, suffix) : c.tags.int_
			if tag.ti != null {
				if (tag.ti.flags & TypeFlags.intval) != 0 {
					value := e.token.value.slice(e.valueSpan.from - e.token.span.from, e.valueSpan.to - e.token.span.from)
					if (tag.ti.flags & TypeFlags.unsigned) != 0 {
						pr := (e.flags & NumberFlags.hex) != 0 ? ulong.tryParseHex(value) : ulong.tryParse(value)
						if pr.hasValue && canFitUnsigned(pr.value, tag) {
							e.tag = tag
							e.opaqueValue = pr.value
						} else {
							c.errors.add(Error.at(c.unit, e.valueSpan, format("Value does not fit into {}", tag.toString())))
						}						
					} else {
						pr := (e.flags & NumberFlags.hex) != 0 ? long.tryParseHex(value) : long.tryParse(value)
						if pr.hasValue && canFitSigned(pr.value, tag) {
							e.tag = tag
							e.opaqueValue = transmute(pr.value, ulong)
						} else {
							c.errors.add(Error.at(c.unit, e.valueSpan, format("Value does not fit into {}", tag.toString())))
						}
					}
				}
				recordTag(c, e, tag)
				return tag
			} else {
				c.errors.add(Error.at(c.unit, IntRange(suffixFrom, e.token.span.to), "Invalid number suffix"))
				result := c.tags.int_
				recordTag(c, e, result)
				return result
			}
		} else {
			if suffix == "" {
				result := c.tags.float_
				e.tag = result
				recordTag(c, e, result)
				return result
			} else if suffix == "d" {
				result := c.tags.double_
				e.tag = result
				recordTag(c, e, result)
				return result
			} else {
				c.errors.add(Error.at(c.unit, IntRange(suffixFrom, e.token.span.to), "Invalid number suffix"))
				result := c.tags.float_
				e.tag = result
				recordTag(c, e, result)
				return result
			}
		}
	}
	
	checkStringExpression(c TypeCheckerContext, e StringExpression) {
		str := e.evaluatedString
		if str != "" {
			id := c.strings.getOrDefault(str)
			if id == 0 {
				id = c.nextStringId
				c.strings.add(str, id)
				c.nextStringId += 1
			}
			e.id = id
		}
		result := checkToken(c, e.token)
		recordTag(c, e, result)
		return result
	}
	
	checkUnaryOperatorExpression(c TypeCheckerContext, e UnaryOperatorExpression) {
		op := e.op.value
		if op == "::" {
			return resolveExpression(c, e, ResolveExpressionOptions.none).tag
		}	
		at := checkExpression(c, e.expr)
		if at.ti == null {
			return at
		}
		if op == "-" {
			if (at.ti.flags & (TypeFlags.intval | TypeFlags.floatval)) == 0 {
				badUnaryOp(c, e.op, at)
				return Tag{}
			}
			if (at.ti.flags & TypeFlags.intval) != 0 {
				at = promoteUnaryOperatorIntvalArgument(c.tags, at)
			}
			recordTag(c, e, at)
			return at
		} else if op == "!" {
			if (at.ti.flags & TypeFlags.boolval) == 0 {
				badUnaryOp(c, e.op, at)
				return c.tags.bool_
			}
			recordTag(c, e, at)
			return at
		} else if op == "~" {
			if (at.ti.flags & (TypeFlags.intval | TypeFlags.flagsEnum)) == 0 {
				badUnaryOp(c, e.op, at)
				return Tag{}
			}
			if (at.ti.flags & TypeFlags.intval) != 0 {
				at = promoteUnaryOperatorIntvalArgument(c.tags, at)
			}
			recordTag(c, e, at)
			return at
		} else if op == "new" || op == "ref" {
			if (at.ti.flags & TypeFlags.anyValue) == 0 {
				badUnaryOp(c, e.op, at)
				return Tag{}
			}
			result := getPtrTag(c, at, 1)
			recordTag(c, e, result)
			return result
		}
		abandon()
	}
	
	checkPostfixUnaryOperatorExpression(c TypeCheckerContext, e PostfixUnaryOperatorExpression) {
		at := checkExpression(c, e.expr)
		if at.ti == null {
			return at
		}
		op := e.op.value
		if op == "^" {
			if (at.ti.flags & TypeFlags.ptr_) == 0 {
				badUnaryOp(c, e.op, at)
				return Tag{}
			}
			result := at.args[0]
			recordTag(c, e, result)
			return result
		}
		abandon()
	}
	
	checkBinaryOperatorExpression(c TypeCheckerContext, e BinaryOperatorExpression) {
		lhsTag := checkExpression(c, e.lhs)
		rhsTag := checkExpression(c, e.rhs)
		result := applyBinaryOperator(c, e.op.value, lhsTag, e.lhs, rhsTag, e.rhs, e.op) 
		recordTag(c, e, result)
		return result
	}
	
	checkTernaryOperatorExpression(c TypeCheckerContext, e TernaryOperatorExpression) {
		cond := checkExpression(c, e.conditionExpr)
		if cond.ti != null && (cond.ti.flags & TypeFlags.boolval) == 0 {
			c.errors.add(Error.at(c.unit, RangeFinder.find(e.conditionExpr), "Expected: bool"))
		}
		tt := checkExpression(c, e.trueExpr)
		ft := checkExpression(c, e.falseExpr)
		result := unify(c, tt, e.trueExpr, ft, e.falseExpr, e.question)
		recordTag(c, e, result)
		return result
	}
	
	resolveCallExpression(c TypeCheckerContext, e CallExpression) {
		target := e.target
		tae := cast(null, TypeArgsExpression)
		if target.is(TypeArgsExpression) {
			tae = target.as(TypeArgsExpression)
			target = tae.target
		}
		rt := resolveExpression(c, target, ResolveExpressionOptions.callTarget)
		
		if !rt.mem.is(FunctionDef) {
			if rt.tag.ti != null {
				checkNoTypeArgs(c, tae)
				return ResolveResult { tag: checkFunctionPointerCall(c, e, target, rt.tag) }
			} else {
				if tae != null {
					for a in tae.args {
						resolveType(c, a, ResolveTypeOptions.none)
					}
				}
				for a in e.args {
					checkExpression(c, a)
				}				
				return ResolveResult{}
			}
		}
		
		func := rt.mem.as(FunctionDef)
		if func.builtin != BuiltinFunction.none {			
			checkNoTypeArgs(c, tae)
			result := Tag{}
			if func.builtin == BuiltinFunction.abandon {
				result = checkAbandon(c, e)
			} else if func.builtin == BuiltinFunction.assert {
				result = checkAssert(c, e)
			} else if func.builtin == BuiltinFunction.checked_cast {
				result = checkCheckedCast(c, e)
			} else if func.builtin == BuiltinFunction.cast {
				result = checkCast(c, e)
			} else if func.builtin == BuiltinFunction.pointer_cast {
				result = checkPointerCast(c, e)
			} else if func.builtin == BuiltinFunction.transmute {
				result = checkTransmute(c, e)
			} else if func.builtin == BuiltinFunction.is {
				assert(rt.instanceTag.ti != null)
				result = checkIs(c, e, rt.instanceTag)
			} else if func.builtin == BuiltinFunction.as {
				assert(rt.instanceTag.ti != null)
				result = checkAs(c, e, rt.instanceTag)
			} else if func.builtin == BuiltinFunction.format {
				result = checkFormat(c, e, rt.instanceTag)
			} else if func.builtin == BuiltinFunction.min || func.builtin == BuiltinFunction.max {
				result = checkMinMax(c, e)
			} else if func.builtin == BuiltinFunction.xor {
				result = checkXor(c, e)
			} else if func.builtin == BuiltinFunction.sizeof {
				result = checkSizeof(c, e)
			} else if func.builtin == BuiltinFunction.compute_hash {
				result = checkComputeHash(c, e)
			} else if func.builtin == BuiltinFunction.default_value {
				result = checkDefaultValue(c, e)
			} else if func.builtin == BuiltinFunction.unchecked_index {
				return resolveUncheckedIndex(c, e)
			} else if func.builtin == BuiltinFunction.get_argc_argv {
				result = checkGetArgcArgv(c, e)
			} else {
				abandon()
			}
			recordTag(c, e, result)
			return ResolveResult { tag: result }
		}
		
		ta := cast(null, Array<Tag>)
		if func.typeParamList != null {
			ta = new Array<Tag>(func.typeParamList.count)
			if tae != null {
				if tae.args.count != ta.count {
					badTypeArgs(c, tae.openAngleBracket, ta.count, tae.args.count)
				}
				for a, i in tae.args {
					arg := resolveType(c, a, ResolveTypeOptions.none)
					if i < ta.count {
						ta[i] = arg
					}
				}
			}
		} else if tae != null {
			checkNoTypeArgs(c, tae)
		}
		
		bias := rt.instanceTag.ti != null ? 1 : 0
		argCount := e.args.count + bias
		
		if (func.flags & FunctionFlags.varArgs) == 0 {
			if func.params.count != argCount {
				badArgs(c, e.openParen, func.params.count, argCount)
			}
		} else {
			if func.params.count > argCount {
				c.errors.add(Error.at(c.unit, e.openParen.span, format("Expected at least {} args but got {} args", func.params.count, argCount)))
			} else if rt.instanceTag.ti != null && func.params.count == 0 {				
				c.errors.add(Error.at(c.unit, e.openParen.span, "Implicit arg must match a declared parameter, not a var arg parameter"))
			}
		}
		
		if rt.instanceTag.ti != null && func.params.count > 0 {
			arg := target.as(DotExpression).lhs
			from := rt.instanceTag
			to := func.params[0].tag
			if to.ti != null && (to.ti.flags & TypeFlags.ptr_) != 0 && from.ti != null && (from.ti.flags & TypeFlags.ptr_) == 0 {
				// Auto ref
				to = to.args[0]
			}
			if !assignMatch(c, from, arg, to, true, func.typeParamList, ta) {
				betterInfo := closeTag(to, func.typeParamList, ta)
				badImplicitArg(c, arg, from, betterInfo)
			}
		}
		
		count := min(func.params.count, argCount)
		i := bias
		while i < count {
			arg := e.args[i - bias]
			from := checkExpression(c, arg)
			to := func.params[i].tag
			if !assignMatch(c, from, arg, to, true, func.typeParamList, ta) {
				betterInfo := closeTag(to, func.typeParamList, ta)
				badArg(c, arg, from, betterInfo)
			}
			i += 1
		}
		
		while i < argCount {
			arg := e.args[i - bias]
			tag := checkExpression(c, arg)			
			if (func.flags & FunctionFlags.varArgs) != 0 && tag.ti == c.tags.string_.ti && !arg.is(StringExpression) {
				c.errors.add(Error.at(c.unit, RangeFinder.find(arg), "Expression of type string cannot be used as a var arg"))
			}
			i += 1
		}
		
		if ta != null {
			flags := Tag.argsAnyFlags(ta)
			if (flags & TypeFlags.missing) != 0 {
				if tae == null {
					badTypeArgInference(c, e.target)
				}
			} else if (flags & TypeFlags.typeParam) != 0 {
				if c.func.outgoingCalls == null {
					c.func.outgoingCalls = new List<Call>{}
				}
				c.func.outgoingCalls.add(new Call { from: c.func, to: func, ta: ta })
			} else {
				func.tas.tryAdd(ta)
			}
		}		
		
		result := closeTag(func.returnTag, func.typeParamList, ta)
		recordTag(c, e, result)
		e.ta = ta
		return ResolveResult { tag: result }
	}
	
	checkNoTypeArgs(c TypeCheckerContext, tae TypeArgsExpression) {
		if tae == null {
			return
		}
		for a in tae.args {
			resolveType(c, a, ResolveTypeOptions.none)
		}
		badTypeArgs(c, tae.openAngleBracket, 0, tae.args.count)
	}
	
	checkFunctionPointerCall(c TypeCheckerContext, e CallExpression, target Node, fn Tag) {
		if fn.ti != c.tags.funTi {
			c.errors.add(Error.at(c.unit, RangeFinder.find(target), "Expected: expression of type fun<>"))
			checkRemainingArgs(c, e, 0, false)
			return Tag{}
		}
		paramCount := fn.args.count - 1
		if paramCount != e.args.count {
			badArgs(c, e.openParen, paramCount, e.args.count)
		}
		count := min(paramCount, e.args.count)
		i := 0
		while i < count {
			arg := e.args[i]
			from := checkExpression(c, arg)
			to := fn.args[i]
			if !assign(c, from, arg, to) {
				badArg(c, arg, from, to)
			}
			i += 1
		}
		while i < e.args.count {
			checkExpression(c, e.args[i])
			i += 1
		}
		result := fn.args[fn.args.count - 1]		
		recordTag(c, e, result)
		return result
	}
	
	checkStructInitializerExpression(c TypeCheckerContext, e StructInitializerExpression) {
		tag := resolveType(c, e.target, ResolveTypeOptions.structInitializer)
		
		if tag.ti == null {
			for fie in e.args {
				checkExpression(c, fie.expr)
			}
			return Tag{}
		}
		if (tag.ti.flags & TypeFlags.struct_) == 0 {
			c.errors.add(Error.at(c.unit, RangeFinder.find(e.target), "Expected: struct type"))
			for fie in e.args {
				checkExpression(c, fie.expr)
			}
			return Tag{}
		}
		
		ti := tag.ti
		ta := tag.args
		if ti.typeParamList != null && ta == null {
			ta = new Array<Tag>(ti.typeParamList.count)
		}
		for fie in e.args {
			arg := fie.expr
			from := checkExpression(c, arg)
			name := fie.fieldName.value
			mem := ti.members.getOrDefault(name)
			if mem.is(FieldDef) {
				to := mem.as(FieldDef).tag
				if !assignMatch(c, from, arg, to, true, ti.typeParamList, ta) {
					betterInfo := closeTag(to, ti.typeParamList, ta)
					badArg(c, arg, from, betterInfo)
				}
			} else {
				c.errors.add(Error.at(c.unit, fie.fieldName.span, format("Undefined field: {}.{}", ti.name, fie.fieldName.value)))
			}
		}
		
		result := Tag { ti: ti, args: ta }
		
		if ta != null {
			flags := Tag.argsAnyFlags(ta)
			if (flags & TypeFlags.missing) != 0 {
				if !e.target.is(TypeArgsExpression) {
					badTypeArgInference(c, e.target)
				}
			} else if (flags & TypeFlags.typeParam) != 0 {
				if c.func.typeUsages == null {
					c.func.typeUsages = new Set.create<Tag>()
				}
				c.func.typeUsages.tryAdd(result)
			} else {
				ti.tas.tryAdd(ta)
			}
		}
		
		recordTag(c, e, result)
		return result
	}
	
	resolveIndexExpression(c TypeCheckerContext, e IndexExpression) {
		result := resolveIndex(c, e.target, e.arg)
		recordTag(c, e, result.tag)
		return result
	}
	
	resolveUncheckedIndex(c TypeCheckerContext, e CallExpression) {
		target := e.args.count > 0 ? e.args[0] : null
		arg := e.args.count > 1 ? e.args[1] : null
		result := resolveIndex(c, target, arg)
		checkRemainingArgs(c, e, 2, false)		
		recordTag(c, e, result.tag)
		return result
	}
	
	resolveIndex(c TypeCheckerContext, target Node, arg Node) {
		rt := resolveExpression(c, target, ResolveExpressionOptions.none)		
		element := Tag{}
		canAssign := false
		if rt.tag.ti != null {
			wrappedSeq := rt.tag
			seq := wrappedSeq.ti == c.tags.ptrTi ? wrappedSeq.args[0] : wrappedSeq
			if seq.ti == c.tags.arrayTi || seq.ti == c.tags.listTi {
				element = seq.args[0]
				canAssign = true
			} else if rt.tag.ti == c.tags.string_.ti {
				element = c.tags.char_
			} else if (seq.ti.flags & TypeFlags.indexable) != 0 {
				element = seq.args[0]
				canAssign = true
			} else {
				c.errors.add(Error.at(c.unit, RangeFinder.find(target), "Expected: expression of type Array, List or string"))
			}
		}
		argTag := checkExpression(c, arg)
		if argTag.ti != null {
			if (argTag.ti.flags & TypeFlags.intval) == 0 || argTag.ti.rank > 4 {
				c.errors.add(Error.at(c.unit, RangeFinder.find(arg), "Expected: expression of type int or uint"))
			}
		}
		
		return ResolveResult { tag: element, canAssign: canAssign }
	}
}
