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
			// TODO: avoid "magic" names here
			if sf.name.value == "_32bit" {
				sf.evaluatedValue = EvalResult { tag: c.tags.bool_, opaqueValue: (c.comp.flags & CompilationFlags.target32bit) != 0 ? 1_u : 0_u }
			} else {
				sf.evaluatedValue = EvalResult { type: EvalResultType.generateForeign }
			}
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
			TernaryOperatorExpression: return evalTernaryOperatorExpression(c, e)
			StructInitializerExpression: return evalStructInitializerExpression(c, e)
			CallExpression: return evalCallExpression(c, e)
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
	
	evalTernaryOperatorExpression(c GenerateContext, e TernaryOperatorExpression) {
		cond := evalExpression(c, e.conditionExpr)
		if cond.type != EvalResultType.value {
			return EvalResult { type: EvalResultType.failed }
		}
		tv := evalExpression(c, e.trueExpr)
		fv := evalExpression(c, e.falseExpr)
		if tv.type != EvalResultType.value || fv.type != EvalResultType.value {
			return EvalResult { type: EvalResultType.failed }
		}
		return cond.opaqueValue != 0 ? tv : fv
	}

	evalStructInitializerExpression(c GenerateContext, e StructInitializerExpression) {
		if e.args.count == 0 {
			return EvalResult { tag: c.infoMap.get(e).tag, type: EvalResultType.defaultValue }
		}
		return EvalResult { type: EvalResultType.failed }
	}

	evalCallExpression(c GenerateContext, e CallExpression) {
		target := e.target
		if target.is(TypeArgsExpression) {
			target = target.as(TypeArgsExpression).target
		}
		targetInfo := c.infoMap.get(target)
		if !targetInfo.mem.is(FunctionDef) {
			return EvalResult { type: EvalResultType.failed }
		}		
		fd := targetInfo.mem.as(FunctionDef)
		if fd.builtin == BuiltinFunction.cast {
			return evalCast(c, e)
		}
		return EvalResult { type: EvalResultType.failed }
	}
	
	evalCast(c GenerateContext, e CallExpression) {
		val := evalExpression(c, e.args[0])
		if val.type != EvalResultType.value {
			return EvalResult { type: EvalResultType.failed }
		}
		from := val.tag
		to := c.infoMap.get(e.args[1]).tag
		if (from.ti.flags & TypeFlags.intval) == 0 || (to.ti.flags & TypeFlags.intval) == 0 {
			return EvalResult { type: EvalResultType.failed }
		}
		toRank := to.ti.rank != 6 ? to.ti.rank : ((c.comp.flags & CompilationFlags.target32bit) == 0 ? 8 : 4)
		if (to.ti.flags & TypeFlags.unsigned) != 0 {
			return EvalResult { tag: to, opaqueValue: val.opaqueValue & rankToMask(toRank) }
		} else {
			return EvalResult { tag: to, opaqueValue: maskAndSignExtend(val.opaqueValue, rankToMask(toRank)) }
		}
		return val
	}

	rankToMask(rank int) {
		if rank == 8 {
			return ulong.maxValue
		} else if rank == 4 {
			return uint.maxValue
		} else if rank == 2 {
			return ushort.maxValue
		} else if rank == 1 {
			return byte.maxValue
		}
		abandon()
	}

	maskAndSignExtend(val ulong, mask ulong) {
		val &= mask
		signMask := (mask >> 1) + 1
		if (val & signMask) != 0 {
			val |= ~mask
		}
		return val
	}
}
