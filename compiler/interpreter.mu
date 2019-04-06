EvalResult struct {
	tag Tag
	opaqueValue ulong
	type EvalResultType
}

EvalResultType enum {
	value
	defaultValue
	failed
	generateVar
	generateDefine
	generateForeign
}

Interpreter {
	computeStaticField(c GenerateContext, sf StaticFieldDef) {
		if (sf.flags & StaticFieldFlags.evaluated) != 0 {
			return
		}		
		prev := c.infoMap
		c.infoMap = sf.infoMap
		if (sf.flags & StaticFieldFlags.autoValue) != 0 {
			sf.evaluatedValue = EvalResult { tag: sf.tag, opaqueValue: sf.value }
		} else if (sf.flags & StaticFieldFlags.foreign) != 0 {
			sf.evaluatedValue = EvalResult { type: EvalResultType.generateForeign }
		} else if sf.initializeExpr == null {
			sf.evaluatedValue = EvalResult { tag: sf.tag, type: EvalResultType.defaultValue }
		} else {
			sf.evaluatedValue = evalExpression(c, sf.initializeExpr)
		}
		sf.flags |= StaticFieldFlags.evaluated
		c.infoMap = prev
	}
	
	evalExpression(c GenerateContext, e Node) EvalResult {
		match e {
			Token: return evalToken(c, e)
			NumberExpression: return evalNumberExpression(c, e)
			StringExpression: return evalStringExpression(c, e)
			DotExpression: return evalDotExpression(c, e)
			UnaryOperatorExpression: return evalUnaryOperatorExpression(c, e)
			BinaryOperatorExpression: return evalBinaryOperatorExpression(c, e)
			StructInitializerExpression: return evalStructInitializerExpression(c, e)
			default: return EvalResult { type: EvalResultType.failed }
		}
	}
	
	evalToken(c GenerateContext, token Token) {
		if token.type == TokenType.identifier {
			if token.value == "null" || token.value == "false" || token.value == "true" {
				return EvalResult { tag: c.infoMap.get(token).tag, type: EvalResultType.generateVar }
			}
			info := c.infoMap.get(token)
			mem := info.mem
			match mem {
				StaticFieldDef: {
					computeStaticField(c, mem)
					if mem.evaluatedValue.type == EvalResultType.value || mem.evaluatedValue.type == EvalResultType.defaultValue {
						return mem.evaluatedValue
					} else {
						return EvalResult { type: EvalResultType.failed }
					}
				}
				default | null: {
					return EvalResult { type: EvalResultType.failed }
				}
			}
		} else if token.type == TokenType.characterLiteral {
			return EvalResult { tag: c.tags.char_, type: EvalResultType.generateVar }
		} else {
			abandon()
		}		
	}
	
	evalNumberExpression(c GenerateContext, e NumberExpression) {
		if (e.tag.ti.flags & TypeFlags.intval) != 0 {
			return EvalResult { tag: e.tag, opaqueValue: e.opaqueValue }
		} else {
			return EvalResult { tag: e.tag, type: EvalResultType.generateVar }
		}
	}
	
	evalStringExpression(c GenerateContext, e StringExpression) {
		return EvalResult { tag: c.tags.string_, type: EvalResultType.generateDefine }
	}
	
	evalDotExpression(c GenerateContext, e DotExpression) {		
		info := c.infoMap.get(e)
		mem := info.mem
		match mem {
			StaticFieldDef: {
				computeStaticField(c, mem)					
				return mem.evaluatedValue
			}
			default | null: {
				return EvalResult { type: EvalResultType.failed }
			}
		}		
	}
	
	evalUnaryOperatorExpression(c GenerateContext, e UnaryOperatorExpression) {
		return EvalResult { type: EvalResultType.failed }
	}

	evalBinaryOperatorExpression(c GenerateContext, e BinaryOperatorExpression) {
		op := e.op.value
		lhs := c.infoMap.get(e.lhs).tag
		if (lhs.ti.flags & TypeFlags.enum_) != 0 {
			rhs := c.infoMap.get(e.rhs).tag
			if lhs.ti == rhs.ti {
				tag := c.infoMap.get(e).tag
				lv := evalExpression(c, e.lhs)
				rv := evalExpression(c, e.rhs)
				if lv.type == EvalResultType.value && rv.type == EvalResultType.value {
					if op == "|" {
						return EvalResult { tag: tag, opaqueValue: lv.opaqueValue | rv.opaqueValue }
					} else if op == "&" {
						return EvalResult { tag: tag, opaqueValue: lv.opaqueValue & rv.opaqueValue }
					}
				}
			}
		}
		
		return EvalResult { type: EvalResultType.failed }
	}
	
	evalStructInitializerExpression(c GenerateContext, e StructInitializerExpression) {
		if e.args.count == 0 {
			return EvalResult { tag: c.infoMap.get(e).tag, type: EvalResultType.defaultValue }
		}
		return EvalResult { type: EvalResultType.failed }
	}
}
