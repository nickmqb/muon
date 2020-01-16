CGenerator {
	genBuiltin(c GenerateContext, fd FunctionDef, e CallExpression, implicitArg Node, sb StringBuilder) {
		if fd.builtin == BuiltinFunction.abandon {
			genAbandon(c, e, sb)
		} else if fd.builtin == BuiltinFunction.assert {
			genAssert(c, e, sb)
		} else if fd.builtin == BuiltinFunction.checked_cast {
			genCheckedCast(c, e, sb)
		} else if fd.builtin == BuiltinFunction.cast {
			genCast(c, e, sb)
		} else if fd.builtin == BuiltinFunction.pointer_cast {
			genPointerCast(c, e, sb)
		} else if fd.builtin == BuiltinFunction.transmute {
			genTransmute(c, e, sb)
		} else if fd.builtin == BuiltinFunction.is {
			genIs(c, e, implicitArg, sb)
		} else if fd.builtin == BuiltinFunction.as {
			genAs(c, e, implicitArg, sb)
		} else if fd.builtin == BuiltinFunction.format {
			genFormat(c, e, implicitArg, sb)
		} else if fd.builtin == BuiltinFunction.min {
			genMinMax(c, e, "<", sb)
		} else if fd.builtin == BuiltinFunction.max {
			genMinMax(c, e, ">", sb)
		} else if fd.builtin == BuiltinFunction.xor {
			genLiftingBinaryOperator(c, "^", e.args[0], e.args[1], sb, nodeTag(c, e))
		} else if fd.builtin == BuiltinFunction.sizeof {
			genSizeof(c, e, sb)
		} else if fd.builtin == BuiltinFunction.compute_hash {
			genComputeHash(c, e, sb)
		} else if fd.builtin == BuiltinFunction.default_value {
			genDefaultValue(c, e, sb)
		} else if fd.builtin == BuiltinFunction.unchecked_index {
			genIndex(c, e.args[0], e.args[1], nodeTag(c, e), false, sb)
		} else if fd.builtin == BuiltinFunction.get_argc_argv {
			genArgcArgv(c, e, sb)
		} else {
			writeFailure(sb)
		}
	}
	
	genUnreachable(c GenerateContext) {
		// Emit dummy return value to avoid compiler warning "not all code paths return a value"
		if c.function.returnTag.ti != c.tags.void_.ti {
			sb := new StringBuilder{}
			sb.write("return ")
			genTagDefaultValue(c, TypeChecker.closeTag(c.function.returnTag, c.function.typeParamList, c.variantTagArgs), sb)
			sb.write(";")
			c.out.writeLine(sb.toString())
		}
	}

	genConverted(c GenerateContext, e Node, sb StringBuilder, to Tag) {
		from := nodeTag(c, e)
		if to.ti == null {
			writeFailure(sb)
		} else if from.ti == to.ti {
			genExpression(c, e, sb)
		} else if (to.ti.flags & TypeFlags.boolval) != 0 {
			genExpression(c, e, sb)
		} else if (to.ti.flags & TypeFlags.anyNumber) != 0 {
			sb.write("(")
			writeTag(sb, to)
			sb.write(")(")
			genExpression(c, e, sb)
			sb.write(")")
		} else if to.ti == c.tags.cstring_.ti && from.ti == c.tags.string_.ti {
			sb.write("(cstring__)((")
			genExpression(c, e, sb)
			sb.write(").dataPtr__)")
		} else if (to.ti.flags & TypeFlags.taggedPointerEnum) != 0 {
			genTaggedPointerCreate(c, e, sb, from, to)			
		} else if from.ti == Tag.null_.ti {
			genExpression(c, e, sb)
		} else {
			writeFailure(sb)
		}
	}
	
	genTaggedPointerCreate(c GenerateContext, e Node, rb StringBuilder, from Tag, to Tag) {
		result := newLocal(c)
		sb := new StringBuilder{}
		writeTag(sb, to)
		sb.write(" ")
		sb.write(result)
		sb.write(";")
		c.out.writeLine(sb.toString())
		sb.clear()
		if from.ti != Tag.null_.ti {
			sb.write(result)
			sb.write(".dataPtr__ = (pointer__)(")
			genExpression(c, e, sb)
			sb.write(");")
			c.out.writeLine(sb.toString())
			sb.clear()
			sb.write(result)
			sb.write(".id__ = ")
			sb.write(result)
			sb.write(".dataPtr__ != null__ ? ")
			writeNs(sb, to.ti)
			sb.write("___")
			writeNestedTag(sb, from)
			sb.write(" : 0;")
			c.out.writeLine(sb.toString())
		} else {
			sb.write(result)
			sb.write(".dataPtr__ = null__;")
			c.out.writeLine(sb.toString())
			sb.clear()
			sb.write(result)
			sb.write(".id__ = 0;")
			c.out.writeLine(sb.toString())
		}
		rb.write(result)
	}
	
	genTagDefaultValue(c GenerateContext, tag Tag, sb StringBuilder) {
		if (tag.ti.flags & (TypeFlags.intval | TypeFlags.enum_)) != 0 {
			sb.write("0")
		} else if (tag.ti.flags & TypeFlags.floatval) != 0 {
			if tag.ti == c.tags.float_.ti {
				sb.write("0.0f")
			} else {
				sb.write("0.0")
			}
		} else if (tag.ti.flags & TypeFlags.string_) != 0 {
			sb.write("mu_____string0")
		} else if (tag.ti.flags & TypeFlags.char_) != 0 {
			sb.write("'\\0'")
		} else if (tag.ti.flags & TypeFlags.boolval) != 0 {
			sb.write("false__")
		} else if (tag.ti.flags & TypeFlags.taggedPointerEnum) != 0 {
			genTaggedPointerCreate(c, null, sb, Tag.null_, tag)
		} else if (tag.ti.flags & TypeFlags.anyPointer) != 0 {
			sb.write("null__")
		} else if (tag.ti.flags & TypeFlags.struct_) != 0 {
			genDefaultStructValue(c, tag, sb)
		} else {
			writeFailure(sb)
		}
	}
	
	genDefaultStructValue(c GenerateContext, tag Tag, rb StringBuilder) {
		sb := new StringBuilder{}
		var := newLocal(c)
		writeTag(sb, tag)
		sb.write(" ")
		sb.write(var)
		sb.write(";")
		c.out.writeLine(sb.toString())
		sb.clear()		
		sb.write("memset(&")
		sb.write(var)
		sb.write(", 0, sizeof(")
		writeTag(sb, tag)
		sb.write("));")
		c.out.writeLine(sb.toString())
		rb.write(var)
	}
	
	genAbandon(c GenerateContext, e CallExpression, sb StringBuilder) {
		sb.write("mu_____abandon(")
		if e.args.count > 0 {
			genConverted(c, e.args[0], sb, c.tags.int_)
		} else {
			sb.write("-1")
		}
		sb.write(")")
		if c.currentExpressionStatement != null && c.currentExpressionStatement.expr == e {
			c.emitUnreachable = true
		}
	}

	genAssert(c GenerateContext, e CallExpression, sb StringBuilder) {
		sb.write("mu_____assert(")
		genConverted(c, e.args[0], sb, c.tags.bool_)
		sb.write(")")
	}

	genCheckedCast(c GenerateContext, e CallExpression, rb StringBuilder) {
		from := nodeTag(c, e.args[0])
		to := nodeTag(c, e.args[1])
		if (from.ti.flags & TypeFlags.intval) != 0 {
			assert((to.ti.flags & TypeFlags.intval) != 0)
			sb := new StringBuilder{}
			temp := newLocal(c)
			writeTag(sb, from)
			sb.write(" ")
			sb.write(temp)
			sb.write(" = ")
			genExpression(c, e.args[0], sb)
			sb.write(";")
			c.out.writeLine(sb.toString())
			sb.clear()
			
			if (from.ti.flags & TypeFlags.unsigned) != 0 {
				// unsigned -> any
				sb.write("mu_____checkedcast(")
				sb.write(temp)
				sb.write(" <= (")
				writeTag(sb, from)
				sb.write(")(")
				genMaxValue(c, to, sb)
				sb.write("));")					
				c.out.writeLine(sb.toString())
			} else {				
				fromRank := from.ti.rank != 6 ? from.ti.rank : ((c.comp.flags & CompilationFlags.target32bit) == 0 ? 8 : 4)
				toRank := to.ti.rank != 6 ? to.ti.rank : ((c.comp.flags & CompilationFlags.target32bit) == 0 ? 8 : 4)
				if (to.ti.flags & TypeFlags.unsigned) != 0 {
					// signed -> unsigned
					if toRank >= fromRank {
						sb.write("mu_____checkedcast(0 <= ")
						sb.write(temp)
						sb.write(");")
						c.out.writeLine(sb.toString())						
					} else {
						unsigned := getUnsignedTag(c, from)
						sb.write("mu_____checkedcast(")
						sb.write("((")
						writeTag(sb, unsigned)
						sb.write(")")
						sb.write(temp)
						sb.write(") <= (")
						writeTag(sb, unsigned)
						sb.write(")(")
						genMaxValue(c, to, sb)
						sb.write("));")
						c.out.writeLine(sb.toString())						
					}
				} else {
					// signed -> signed
					if toRank < fromRank {
						sb.write("mu_____checkedcast(")
						sb.write(temp)
						sb.write(" + ((")
						writeTag(sb, from)
						sb.write(")")
						genMaxValue(c, to, sb)
						sb.write(") + 1 <= (")
						unsigned := getUnsignedTag(c, to)
						writeTag(sb, from)
						sb.write(")(")
						genMaxValue(c, unsigned, sb)
						sb.write("));")
						c.out.writeLine(sb.toString())
					}
				}
			}			
			rb.write("(")
			writeTag(rb, to)
			rb.write(")(")
			rb.write(temp)
			rb.write(")")			
		} else {
			genTaggedPointerCast(c, e.args[0], from, to, rb)
		}		
	}
	
	genMaxValue(c GenerateContext, tag Tag, sb StringBuilder) {
		if (tag.ti.flags & TypeFlags.unsigned) != 0 {
			if tag.ti == c.tags.ulong_.ti {
				sb.write("0xffffffffffffffffuLL")
			} else if tag.ti == c.tags.usize_.ti {
				if (c.comp.flags & CompilationFlags.target32bit) == 0 {
					sb.write("0xffffffffffffffffuLL")
				} else {
					sb.write("0xffffffffu")
				}
			} else if tag.ti == c.tags.uint_.ti {
				sb.write("0xffffffffu")
			} else if tag.ti == c.tags.ushort_.ti {
				sb.write("0xffff")
			} else if tag.ti == c.tags.byte_.ti {
				sb.write("0xff")
			} else {
				abandon()
			}
		} else {
			if tag.ti == c.tags.long_.ti {
				sb.write("0x7fffffffffffffffLL")
			} else if tag.ti == c.tags.ssize_.ti {
				if (c.comp.flags & CompilationFlags.target32bit) == 0 {
					sb.write("0x7fffffffffffffffuLL")
				} else {
					sb.write("0x7fffffffu")
				}
			} else if tag.ti == c.tags.int_.ti {
				sb.write("0x7fffffff")
			} else if tag.ti == c.tags.short_.ti {
				sb.write("0x7fff")
			} else if tag.ti == c.tags.sbyte_.ti {
				sb.write("0x7f")
			} else {
				abandon()
			}
		}
	}

	getUnsignedTag(c GenerateContext, tag Tag) {
		if tag.ti == c.tags.long_.ti {
			return c.tags.ulong_
		} else if tag.ti == c.tags.ssize_.ti {
			return c.tags.usize_
		} else if tag.ti == c.tags.int_.ti {
			return c.tags.uint_
		} else if tag.ti == c.tags.short_.ti {
			return c.tags.ushort_
		} else if tag.ti == c.tags.sbyte_.ti {
			return c.tags.byte_
		} 
		abandon()
	}
	
	genTaggedPointerCast(c GenerateContext, fromNode Node, from Tag, to Tag, rb StringBuilder) {
		sb := new StringBuilder{}
		temp := newLocal(c)
		writeTag(sb, from)
		sb.write(" ")
		sb.write(temp)
		sb.write(" = ")
		genExpression(c, fromNode, sb)
		sb.write(";")
		c.out.writeLine(sb.toString())
		sb.clear()
		
		sb.write("mu_____checkedcast(")
		sb.write(temp)
		sb.write(".id__ == ")
		writeNs(sb, from.ti)
		sb.write("___")
		writeNestedTag(sb, to)
		sb.write(");")
		c.out.writeLine(sb.toString())

		rb.write("(")
		writeTag(rb, to)
		rb.write(")(")
		rb.write(temp)
		rb.write(".dataPtr__)")
	}

	genCast(c GenerateContext, e CallExpression, sb StringBuilder) {
		to := nodeTag(c, e.args[1])
		if (to.ti.flags & TypeFlags.taggedPointerEnum) != 0 {
			from := nodeTag(c, e.args[0])
			genTaggedPointerCreate(c, e.args[0], sb, from, to)
		} else {
			sb.write("(")
			writeTag(sb, to)
			sb.write(")(")
			genExpression(c, e.args[0], sb)
			sb.write(")")
		}		
	}
	
	genBasicCast(c GenerateContext, e CallExpression, sb StringBuilder, to Tag) {
		sb.write("(")
		writeTag(sb, to)
		sb.write(")(")
		genExpression(c, e.args[0], sb)
		sb.write(")")
	}

	genPointerCast(c GenerateContext, e CallExpression, sb StringBuilder) {
		from := nodeTag(c, e.args[0])
		to := nodeTag(c, e.args[1])
		if (from.ti.flags & TypeFlags.taggedPointerEnum) != 0 {
			assert(to.ti == c.tags.pointer_.ti)
			sb.write("(")
			writeTag(sb, to)
			sb.write(")((")
			genExpression(c, e.args[0], sb)
			sb.write(").dataPtr__)")
		} else if from.ti == c.tags.string_.ti {
			sb.write("(")
			writeTag(sb, to)
			sb.write(")((")
			genExpression(c, e.args[0], sb)
			sb.write(").dataPtr__)")
		} else {
			sb.write("(")
			writeTag(sb, to)
			sb.write(")(")
			genExpression(c, e.args[0], sb)
			sb.write(")")
		}
	}

	genTransmute(c GenerateContext, e CallExpression, rb StringBuilder) {
		from := nodeTag(c, e.args[0])
		to := nodeTag(c, e.args[1])
		
		if (from.ti.flags & (TypeFlags.anyPointerExceptTaggedPointer | TypeFlags.char_)) != 0 && (to.ti.flags & TypeFlags.intval) != 0 {
			rb.write("(")
			writeTag(rb, to)
			if (from.ti.flags & (TypeFlags.char_)) != 0 {
				rb.write(")(unsigned char)(")
			} else {
				rb.write(")(uintptr_t)(")
			}
			genExpression(c, e.args[0], rb)
			rb.write(")")
			return
		} else if (to.ti.flags & (TypeFlags.anyPointerExceptTaggedPointer | TypeFlags.char_)) != 0 && (from.ti.flags & TypeFlags.intval) != 0 {
			genBasicCast(c, e, rb, to)
			return
		}
		
		sb := new StringBuilder{}
		
		temp := newLocal(c)
		sb.write("union { ")
		writeTag(sb, from)
		sb.write(" from; ")
		writeTag(sb, to)
		sb.write(" to; } ")
		sb.write(temp)
		sb.write(";")
		c.out.writeLine(sb.toString())
		sb.clear()
		
		// TODO: avoid call to memset if sizeof(from) >= sizeof(to)
		sb.write("memset(&")
		sb.write(temp)
		sb.write(", 0, sizeof(")
		sb.write(temp)
		sb.write("));")
		c.out.writeLine(sb.toString())
		sb.clear()

		sb.write(temp)
		sb.write(".from = ")
		genExpression(c, e.args[0], sb)
		sb.write(";")
		c.out.writeLine(sb.toString())
		
		rb.write(temp)
		rb.write(".to")
	}

	genIs(c GenerateContext, e CallExpression, implicitArg Node, sb StringBuilder) {	
		from := nodeTag(c, implicitArg)
		to := nodeTag(c, e.args[0])
		sb.write("(")
		genExpression(c, implicitArg, sb)
		sb.write(").id__ == ")
		writeNs(sb, from.ti)
		sb.write("___")
		writeNestedTag(sb, to)		
	}

	genAs(c GenerateContext, e CallExpression, implicitArg Node, sb StringBuilder) {
		assert(implicitArg != null)
		from := nodeTag(c, implicitArg)
		to := nodeTag(c, e.args[0])
		genTaggedPointerCast(c, implicitArg, from, to, sb)
	}

	genFormat(c GenerateContext, e CallExpression, implicitArg Node, rb StringBuilder) {
		formatStrNode := implicitArg != null ? implicitArg : e.args[0]
		formatStr := formatStrNode.as(StringExpression).evaluatedString

		sb := new StringBuilder{}
		builder := newLocal(c)
		sb.write("StringBuilder__ ")
		sb.write(builder)
		sb.write(";")
		c.out.writeLine(sb.toString())
		sb.clear()
		
		sb.write("memset(&")
		sb.write(builder)
		sb.write(", 0, sizeof(")
		sb.write(builder)
		sb.write("));")
		c.out.writeLine(sb.toString())
		sb.clear()
		
		arg := implicitArg != null ? 0 : 1
		slice := new StringBuilder{}
		i := 0
		while i < formatStr.length {
			ch := formatStr[i]
			if ch == '{' {
				i += 1
				if i < formatStr.length {
					next := formatStr[i]
					if next == '}' {
						a := e.args[arg]
						tag := nodeTag(c, a)

						genFormatSlice(c, builder, slice.toString())
						slice.clear()

						if tag.ti == c.tags.funTi || tag.ti == c.tags.ptrTi {
							sb.write("StringBuilder__writeChar__(&")
							sb.write(builder)
							sb.write(", '@');")
							c.out.writeLine(sb.toString())
							sb.clear()
							writeNs(sb, c.tags.pointer_.ti)
							sb.write("writeTo__((pointer__)(")
							genExpression(c, a, sb)
							sb.write("), &")
							sb.write(builder)
							sb.write(");")
						} else if tag.ti == c.tags.string_.ti {
							sb.write("StringBuilder__write__(&")
							sb.write(builder)
							sb.write(", ")
							genExpression(c, a, sb)
							sb.write(");")
						} else {
							// TODO: support generics
							writeNs(sb, tag.ti)
							sb.write("writeTo__(")
							genExpression(c, a, sb)
							sb.write(", &")
							sb.write(builder)
							sb.write(");")
						}
						c.out.writeLine(sb.toString())
						sb.clear()
						
						arg += 1
					} else if next == '{' {
						slice.writeChar(ch)
					} else {
						slice.writeChar(ch)
						slice.writeChar(next)						
					}					
				} else {
					slice.writeChar(ch)
				}
			} else {
				slice.writeChar(ch)
				if ch == '}' && i < formatStr.length - 1 && formatStr[i + 1] == '}' {
					i += 1
				}
			}
			i += 1
		}
		
		genFormatSlice(c, builder, slice.toString())
		
		rb.write("StringBuilder__compactToString__(&")
		rb.write(builder)
		rb.write(")")
	}
	
	genFormatSlice(c GenerateContext, builder string, slice string) {
		if slice.length == 0 {
			return
		}
		sb := new StringBuilder{}
		temp := newLocal(c)
		sb.write("string__ ")
		sb.write(temp)
		sb.write(" = { (pointer__)\"")
		writeUnescapedString(sb, slice)
		sb.write(format("\", {} }};", slice.length))
		c.out.writeLine(sb.toString())
		sb.clear()
		
		sb.write("StringBuilder__write__(&")
		sb.write(builder)
		sb.write(", ")
		sb.write(temp)
		sb.write(");")
		c.out.writeLine(sb.toString())
	}

	genMinMax(c GenerateContext, e CallExpression, op string, rb StringBuilder) {
		tag := nodeTag(c, e)
		sb := new StringBuilder{}
		
		first := newLocal(c)
		writeTag(sb, tag)
		sb.write(" ")
		sb.write(first)
		sb.write(" = ")
		genExpression(c, e.args[0], sb)
		sb.write(";")
		c.out.writeLine(sb.toString())
		sb.clear()
		
		second := newLocal(c)
		writeTag(sb, tag)
		sb.write(" ")
		sb.write(second)
		sb.write(" = ")
		genExpression(c, e.args[1], sb)
		sb.write(";")
		c.out.writeLine(sb.toString())
		
		rb.write("(")
		rb.write(first)
		rb.write(" ")
		rb.write(op)
		rb.write(" ")
		rb.write(second)
		rb.write(")")
		rb.write(" ? ")
		rb.write(first)
		rb.write(" : ")
		rb.write(second)
	}
	
	genSizeof(c GenerateContext, e CallExpression, sb StringBuilder) {
		tag := nodeTag(c, e.args[0])
		sb.write("sizeof(")
		writeTag(sb, tag)
		sb.write(")")
	}

	genComputeHash(c GenerateContext, e CallExpression, sb StringBuilder) {
		tag := nodeTag(c, e.args[0])
		if (tag.ti.flags & (TypeFlags.pointer_ | TypeFlags.fun_ | TypeFlags.ptr_)) != 0 {
			tag = c.tags.pointer_
		} else if (tag.ti.flags & TypeFlags.enum_) != 0 {
			tag = c.tags.uint_
		}
		// TODO: support generics
		writeNs(sb, tag.ti)
		sb.write("hash__(")
		genExpression(c, e.args[0], sb)
		sb.write(")")		
	}

	genDefaultValue(c GenerateContext, e CallExpression, sb StringBuilder) {
		tag := nodeTag(c, e.args[0])
		genTagDefaultValue(c, tag, sb)
	}
	
	genArgcArgv(c GenerateContext, e CallExpression, rb StringBuilder) {
		sb := new StringBuilder{}
		sb.write("*(")
		genConverted(c, e.args[0], sb, TypeChecker.getSingleArgTag(c.tags.ptrTi, c.tags.int_))
		sb.write(") = mu_____argc;")
		c.out.writeLine(sb.toString())
		sb.clear()
		sb.write("*(")
		genConverted(c, e.args[1], sb, TypeChecker.getSingleArgTag(c.tags.ptrTi, c.tags.pointer_))
		sb.write(") = mu_____argv;")
		c.out.writeLine(sb.toString())
	}
}
