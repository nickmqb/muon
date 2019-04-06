TypeChecker {
	badNamespaceHere(c TypeCheckerContext, e Node, ns Namespace) {
		c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Namespace is not valid here: {}", ns.toString())))
	}

	badTypeHere(c TypeCheckerContext, e Node, ti Namespace) {
		c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Type is not valid here: {}", ti.toString())))
	}
	
	badTagHere(c TypeCheckerContext, e Node, tag Tag) {
		c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Type is not valid here: {}", tag.toString())))
	}

	badLocalVar(c TypeCheckerContext, name string, err Node) {
		c.errors.add(Error.at(c.unit, RangeFinder.find(err), format("Variable is already defined: {}", name)))
	}
	
	badUnaryOp(c TypeCheckerContext, op Token, at Tag) {
		c.errors.add(Error.at(c.unit, op.span, format("Unary operator {} cannot be applied to expression of type {}", op.value, at.toString())))
	}
	
	badBinaryOp(c TypeCheckerContext, op Token, lhs Tag, rhs Tag) {
		c.errors.add(Error.at(c.unit, op.span, format("Binary operator {} cannot be applied to expressions of type {} and {}", op.value, lhs.toString(), rhs.toString())))
	}

	badConversion(c TypeCheckerContext, e Node, from Tag, to Tag) {
		c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Cannot convert {} to {}", from.toString(), to.toString())))
	}	
	
	badArg(c TypeCheckerContext, e Node, from Tag, to Tag) {
		c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Cannot convert {} to {}", from.toString(), to.toString())))
	}	

	badImplicitArg(c TypeCheckerContext, e Node, from Tag, to Tag) {
		c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Cannot convert implicit argument of type {} to {}", from.toString(), to.toString())))
	}	

	badTypeArgs(c TypeCheckerContext, e Node, expected int, actual int) {
		c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Expected {} type args but got {} type args", expected, actual)))
	}

	badArgs(c TypeCheckerContext, e Node, expected int, actual int) {
		c.errors.add(Error.at(c.unit, RangeFinder.find(e), format("Expected {} args but got {} args", expected, actual)))
	}

	badTypeArgInference(c TypeCheckerContext, e Node) {
		c.errors.add(Error.at(c.unit, RangeFinder.find(e), "The type arguments could not be inferred; specify them explicitly"))
	}
	
	redundantCast(c TypeCheckerContext, e Node) {
		c.errors.add(Error.at(c.unit, RangeFinder.find(e), "Cast is redundant"))
	}
	
	findTypeParamByNameOrNull(typeParamList List<Namespace>, name string) {
		for tp in typeParamList {
			if tp.name == name {
				return tp
			}
		}
		return null
	}
	
	findTypeParamIndex(typeParamList List<Namespace>, tp Namespace) {
		for it, i in typeParamList {
			if it == tp {
				return i
			}
		}
		return -1
	}

	getPtrTag(c TypeCheckerContext, tag Tag, ptrCount int) {
		for i := 0; i < ptrCount {
			tag = getSingleArgTag(c.tags.ptrTi, tag)
		}
		return tag
	}
	
	getSingleArgTag(ti Namespace, arg Tag) {
		args := new Array<Tag>(1)
		args[0] = arg
		return Tag { ti: ti, args: args }
	}
	
	closeTag(tag Tag, tps List<Namespace>, ta Array<Tag>) Tag {
		if tag.ti != null && (tag.ti.flags & TypeFlags.typeParam) != 0 {
			tpi := findTypeParamIndex(tps, tag.ti)
			return ta[tpi]
		}
		if tag.args == null {
			return tag
		}
		return Tag { ti: tag.ti, args: closeTagArgs(tag.args, tps, ta) }
	}
	
	closeTagArgs(args Array<Tag>, tps List<Namespace>, ta Array<Tag>) Array<Tag> {
		i := 0
		while i < args.count {
			a := args[i]
			closed := closeTag(a, tps, ta)
			if !Tag.equals(a, closed) {
				break
			}
			i += 1
		}
		if i == args.count {
			return args
		}	
		newArgs := new Array<Tag>(args.count)
		to := i
		while i < to {
			newArgs[i] = args[i]
			i += 1
		}
		while i < args.count {
			newArgs[i] = closeTag(args[i], tps, ta)
			i += 1
		}
		return newArgs
	}
		
	assign(c TypeCheckerContext, tag Tag, e Node, dest Tag) {
		if tag.ti == null || dest.ti == null {
			return true
		}
		if Tag.equals(tag, dest) {
			return true
		}
		if tag.ti == Tag.null_.ti && (dest.ti.flags & TypeFlags.anyPointer) != 0 {
			return true
		}		
		if canCoerce(c, tag, e, dest) {
			return true
		}
		return false
	}
	
	assignMatch(c TypeCheckerContext, tag Tag, e Node, dest Tag, top bool, tps List<Namespace>, ta Array<Tag>) bool {
		if tag.ti == null || dest.ti == null {
			return true
		}
		if (dest.ti.flags & TypeFlags.typeParam) != 0 {
			tpi := findTypeParamIndex(tps, dest.ti)
			assert(tpi >= 0)
			if ta[tpi].ti != null {
				if ta[tpi].ti == Tag.null_.ti && (tag.ti.flags & TypeFlags.anyPointer) != 0 {
					ta[tpi] = tag
					return true
				}
				dest = ta[tpi]
			} else {
				ta[tpi] = tag				
				return true
			}			
		}
		if tag.ti == dest.ti {
			if tag.args != null || dest.args != null {
				if tag.args.count != dest.args.count {
					return false
				}			
				for a, i in tag.args {
					if !assignMatch(c, a, null, dest.args[i], false, tps, ta) {
						return false
					}
				}
			}
			return true
		}
		if tag.ti == Tag.null_.ti && (dest.ti.flags & TypeFlags.anyPointer) != 0 {
			return true
		}		
		if top && canCoerce(c, tag, e, dest) {
			return true
		}
		return false
	}
	
	canCoerce(c TypeCheckerContext, tag Tag, e Node, dest Tag) {
		if (dest.ti.flags & TypeFlags.boolval) != 0 {
			return (tag.ti.flags & TypeFlags.boolval) != 0
		}
		if (dest.ti.flags & TypeFlags.cstring_) != 0 {
			return e.is(StringExpression)
		}
		if (dest.ti.flags & TypeFlags.floatval) != 0 {
			if (tag.ti.flags & TypeFlags.intval) != 0 {
				return true
			}			
			if (tag.ti.flags & TypeFlags.floatval) != 0 && dest.ti.rank >= tag.ti.rank {
				return true
			}
			return false
		}
		if (dest.ti.flags & TypeFlags.unsigned) != 0 {
			if (tag.ti.flags & TypeFlags.intval) == 0 {
				return false
			}
			if (tag.ti.flags & TypeFlags.unsigned) != 0 && dest.ti.rank >= tag.ti.rank {
				return true
			}
			if e.is(NumberExpression) && tag.ti == c.tags.int_.ti {
				num := e.as(NumberExpression)
				return transmute(num.opaqueValue, long) >= 0 && canFitUnsigned(num.opaqueValue, dest)
			}
			return false
		}
		if (dest.ti.flags & TypeFlags.intval) != 0 {
			if (tag.ti.flags & TypeFlags.intval) == 0 {
				return false
			}
			if (tag.ti.flags & TypeFlags.unsigned) == 0 && dest.ti.rank > tag.ti.rank {
				return true
			}
			if e.is(NumberExpression) && tag.ti == c.tags.int_.ti {
				num := e.as(NumberExpression)
				return canFitSigned(transmute(num.opaqueValue, long), dest)
			}
			return false
		}
		if dest.ti.taggedPointerOptions != null {
			return (tag.ti.flags & TypeFlags.anyPointer) != 0 && dest.ti.taggedPointerOptions.contains(tag)
		}
		return false
	}
	
	unify(c TypeCheckerContext, a Tag, ax Node, b Tag, bx Node, err Node) {
		if a.ti == null {
			return b
		}
		if b.ti == null {
			return a
		}
		if Tag.equals(a, b) {
			return a
		}
		if a.ti == Tag.null_.ti && (b.ti.flags & TypeFlags.anyPointer) != 0 {
			return b
		}
		if b.ti == Tag.null_.ti && (a.ti.flags & TypeFlags.anyPointer) != 0 {
			return a
		}
		if a.ti.taggedPointerOptions != null && (b.ti.flags & TypeFlags.anyPointerExceptTaggedPointer) != 0 && a.ti.taggedPointerOptions.contains(b) {
			return a
		}
		if b.ti.taggedPointerOptions != null && (a.ti.flags & TypeFlags.anyPointerExceptTaggedPointer) != 0 && b.ti.taggedPointerOptions.contains(a) {
			return b
		}
		tag := tryUnifyNumbers(c.tags, a, ax, b, bx)
		if tag.ti != null {
			return tag
		}
		c.errors.add(Error.at(c.unit, RangeFinder.find(err), format("Cannot unify {} and {}", a.toString(), b.toString())))
		return a
	}
	
	tryUnifyNumbers(t CommonTags, a Tag, ax Node, b Tag, bx Node) {
		if (a.ti.flags & TypeFlags.floatval) != 0 || (b.ti.flags & TypeFlags.floatval) != 0 {
			return (a.ti == t.double_.ti || b.ti == t.double_.ti) ? t.double_ : t.float_
		}
		return tryUnifyIntvals(t, a, ax, b, bx)
	}
	
	tryUnifyIntvals(t CommonTags, a Tag, ax Node, b Tag, bx Node) {
		if (a.ti.flags & TypeFlags.intval) == 0 || (b.ti.flags & TypeFlags.intval) == 0 {
			return Tag{}
		}
		if (a.ti.flags & TypeFlags.unsigned) != 0 {
			if (b.ti.flags & TypeFlags.unsigned) != 0 {
				if a.ti.rank >= b.ti.rank {
					return a.ti.rank >= 4 ? a : t.int_
				} else {
					return b.ti.rank >= 4 ? b : t.int_
				}
			} else {
				if b.ti.rank == 6 {
					if a.ti.rank < 4 {
						return b
					}
				} else if a.ti.rank < b.ti.rank {
					return b.ti.rank >= 4 ? b : t.int_
				} else if a.ti.rank < 4 {
					return t.int_
				}
			}			
		} else {
			if (b.ti.flags & TypeFlags.unsigned) != 0 {
				if a.ti.rank == 6 {
					if b.ti.rank < 4 {
						return a
					}
				} else if b.ti.rank < a.ti.rank {
					return a.ti.rank >= 4 ? a : t.int_
				} else if b.ti.rank < 4 {
					return t.int_
				}
			} else {
				if a.ti.rank >= b.ti.rank {
					return a.ti.rank >= 4 ? a : t.int_
				} else {
					return b.ti.rank >= 4 ? b : t.int_
				}					
			}			
		}			
		if b.ti == t.int_.ti && bx.is(NumberExpression) {
			if (a.ti.flags & TypeFlags.unsigned) != 0 {
				if transmute(bx.as(NumberExpression).opaqueValue, long) >= 0 && canFitUnsigned(bx.as(NumberExpression).opaqueValue, a) {
					return a
				}
			} else {
				if canFitSigned(transmute(bx.as(NumberExpression).opaqueValue, long), a) {
					return a
				}
			}
		}
		if a.ti == t.int_.ti && ax.is(NumberExpression) {
			if (b.ti.flags & TypeFlags.unsigned) != 0 {
				if transmute(ax.as(NumberExpression).opaqueValue, long) >= 0 && canFitUnsigned(ax.as(NumberExpression).opaqueValue, b) {
					return b
				}
			} else {
				if canFitSigned(transmute(ax.as(NumberExpression).opaqueValue, long), b) {
					return b
				}
			}
		}
		return Tag{}
	}
	
	canApplyCompareEqualsOperator(c TypeCheckerContext, a Tag, ax Node, b Tag, bx Node) {
		if Tag.equals(a, b) {
			return true
		}
		if a.ti == Tag.null_.ti && (b.ti.flags & TypeFlags.anyPointer) != 0 {
			return true
		}
		if b.ti == Tag.null_.ti && (a.ti.flags & TypeFlags.anyPointer) != 0 {
			return true
		}
		tag := tryUnifyIntvals(c.tags, a, ax, b, bx)
		if tag.ti != null {
			return true
		}
		if a.ti.taggedPointerOptions != null && (b.ti.flags & TypeFlags.anyPointerExceptTaggedPointer) != 0 && a.ti.taggedPointerOptions.contains(b) {
			return true
		}
		if b.ti.taggedPointerOptions != null && (a.ti.flags & TypeFlags.anyPointerExceptTaggedPointer) != 0 && b.ti.taggedPointerOptions.contains(a) {
			return true
		}
		if (a.ti.flags & TypeFlags.enum_) != 0 && (b.ti == c.tags.int_.ti || b.ti == c.tags.uint_.ti) && bx.is(NumberExpression) && bx.as(NumberExpression).tag.ti == b.ti && bx.as(NumberExpression).opaqueValue == 0 {
			return true
		}
		if (b.ti.flags & TypeFlags.enum_) != 0 && (a.ti == c.tags.int_.ti || a.ti == c.tags.uint_.ti) && ax.is(NumberExpression) && ax.as(NumberExpression).tag.ti == a.ti && ax.as(NumberExpression).opaqueValue == 0 {
			return true
		}
		return false
	}
	
	canApplyCompareOrderedOperator(c TypeCheckerContext, a Tag, ax Node, b Tag, bx Node) {
		tag := tryUnifyNumbers(c.tags, a, ax, b, bx)
		if tag.ti != null {
			return true
		}
		if (a.ti.flags & TypeFlags.string_) != 0 && (b.ti.flags & TypeFlags.string_) != 0 {
			return true
		}
		if (a.ti.flags & TypeFlags.pointer_) != 0 && (b.ti.flags & TypeFlags.pointer_) != 0 {
			return true
		}
		if a.ti == c.tags.char_.ti && b.ti == c.tags.char_.ti {
			return true
		}
		return false
	}

	applyBinaryOperator(c TypeCheckerContext, op string, a Tag, ax Node, b Tag, bx Node, err Token) {
		if a.ti == null || b.ti == null {
			return Tag{}
		}
		tag := Tag{}
		if op == "+" {
			if (a.ti.flags & TypeFlags.anyNumber) != 0 && (b.ti.flags & TypeFlags.anyNumber) != 0 {
				tag = tryUnifyNumbers(c.tags, a, ax, b, bx)
			} else if a.ti == c.tags.pointer_.ti && (b.ti.flags & TypeFlags.intval) != 0 {
				tag = c.tags.pointer_
			} else if (a.ti.flags & TypeFlags.intval) != 0 && b.ti == c.tags.pointer_.ti {
				tag = c.tags.pointer_
			} else if a.ti == c.tags.char_.ti && (b.ti.flags & TypeFlags.intval) != 0 {
				tag = c.tags.char_
			} else if (a.ti.flags & TypeFlags.intval) != 0 && b.ti == c.tags.char_.ti {
				tag = c.tags.char_
			}			
		} else if op == "-" {
			if (a.ti.flags & TypeFlags.anyNumber) != 0 && (b.ti.flags & TypeFlags.anyNumber) != 0 {
				tag = tryUnifyNumbers(c.tags, a, ax, b, bx)
			} else if a.ti == c.tags.pointer_.ti && (b.ti.flags & TypeFlags.intval) != 0 {
				tag = c.tags.pointer_
			} else if (a.ti.flags & TypeFlags.intval) != 0 && b.ti == c.tags.pointer_.ti {
				tag = c.tags.pointer_
			} else if a.ti == c.tags.char_.ti && (b.ti.flags & TypeFlags.intval) != 0 {
				tag = c.tags.char_
			} else if (a.ti.flags & TypeFlags.intval) != 0 && b.ti == c.tags.char_.ti {
				tag = c.tags.char_
			} else if a.ti == c.tags.char_.ti && b.ti == c.tags.char_.ti {
				tag = c.tags.int_
			}
		} else if op == "*" || op == "/" {
			if (a.ti.flags & TypeFlags.anyNumber) != 0 && (b.ti.flags & TypeFlags.anyNumber) != 0 {
				tag = tryUnifyNumbers(c.tags, a, ax, b, bx)
			}
		} else if op == "%" {
			tag = tryUnifyIntvals(c.tags, a, ax, b, bx)
		} else if op == "&" || op == "|" {
			if (a.ti.flags & TypeFlags.flagsEnum) != 0 && (b.ti.flags & TypeFlags.flagsEnum) != 0 && a.ti == b.ti {
				tag = a
			} else {
				tag = tryUnifyIntvals(c.tags, a, ax, b, bx)	
			}
		} else if op == "&&" || op == "||" {
			if (a.ti.flags & TypeFlags.boolval) != 0 && (b.ti.flags & TypeFlags.boolval) != 0 {
				tag = c.tags.bool_
			}
		} else if op == ">>" || op == "<<" {
			if (a.ti.flags & TypeFlags.intval) != 0 && (b.ti.flags & TypeFlags.intval) != 0 {
				if a.ti.rank >= 4 {
					tag = a
				} else if (a.ti.flags & TypeFlags.unsigned) != 0 {
					tag = c.tags.uint_
				} else {
					tag = c.tags.int_
				}
			}
		} else if op == "==" || op == "!=" {
			if !canApplyCompareEqualsOperator(c, a, ax, b, bx) {
				badBinaryOp(c, err, a, b)
			}
			return c.tags.bool_
		} else if op == ">" || op == "<" || op == ">=" || op == "<=" {
			if !canApplyCompareOrderedOperator(c, a, ax, b, bx) {
				badBinaryOp(c, err, a, b)
			}
			return c.tags.bool_
		}
		if tag.ti == null {
			badBinaryOp(c, err, a, b)
		}
		return tag
	}
	
	numberSuffixToTag(c TypeCheckerContext, suffix string) {
		if suffix == "sb" {
			return c.tags.sbyte_
		} else if suffix == "b" {
			return c.tags.byte_
		} else if suffix == "s" {
			return c.tags.short_
		} else if suffix == "us" {
			return c.tags.ushort_
		} else if suffix == "u" {
			return c.tags.uint_
		} else if suffix == "L" {
			return c.tags.long_
		} else if suffix == "uL" {
			return c.tags.ulong_
		} else if suffix == "sz" {
			return c.tags.ssize_
		} else if suffix == "usz" {
			return c.tags.usize_
		} else if suffix == "d" {
			return c.tags.double_
		} else {
			return Tag{}
		}
	}
	
	canFitUnsigned(value ulong, tag Tag) {
		if tag.ti.rank == 1 {
			return value <= 0xff
		} else if tag.ti.rank == 2 {
			return value <= 0xffff
		} else if tag.ti.rank <= 6 {
			return value <= 0xffffffff_uL
		} else {
			return true
		}		
	}

	canFitSigned(value long, tag Tag) {		
		if tag.ti.rank == 1 {
			return sbyte.minValue <= value && value <= sbyte.maxValue
		} else if tag.ti.rank == 2 {
			return short.minValue <= value && value <= short.maxValue
		} else if tag.ti.rank <= 6 {
			return int.minValue <= value && value <= int.maxValue
		} else {
			return true
		}		
	}
	
	getArgOfType(c TypeCheckerContext, e CallExpression, index int, dest Tag) {
		if index >= e.args.count {
			return Tag{}
		}
		arg := e.args[index]
		tag := checkExpression(c, arg)
		if !assign(c, tag, arg, dest) {
			badArg(c, arg, tag, dest)
			return Tag{}
		}
		return tag
	}
	
	getArgWithTypeFlags(c TypeCheckerContext, e CallExpression, index int, flags TypeFlags, allowNull bool, message string) {
		if index >= e.args.count {
			return Tag{}
		}
		arg := e.args[index]
		tag := checkExpression(c, arg)
		if tag.ti == null || ((tag.ti.flags & flags) != 0 || (tag.ti == Tag.null_.ti && allowNull)) {
			return tag
		}
		c.errors.add(Error.at(c.unit, RangeFinder.find(arg), message))
		return Tag{}
	}
	
	getTypeArg(c TypeCheckerContext, e CallExpression, index int) {
		return getTypeArgWithTypeFlags(c, e, index, TypeFlags.anyValue, "Expected: type")
	}
	
	getTypeArgWithTypeFlags(c TypeCheckerContext, e CallExpression, index int, flags TypeFlags, message string) {
		if index >= e.args.count {
			return Tag{}
		}
		arg := e.args[index]
		tag := resolveType(c, arg, ResolveTypeOptions.none)
		if tag.ti == null {			
			return tag
		}
		if (tag.ti.flags & flags) != 0 {
			recordTag(c, arg, tag) // Note: the actual tag of the expression would be typeof<tag>
			return tag
		}
		c.errors.add(Error.at(c.unit, RangeFinder.find(arg), message))
		return Tag{}
	}

	checkRemainingArgs(c TypeCheckerContext, e CallExpression, index int, implicitArg bool) {
		for i := index; i < e.args.count {
			checkExpression(c, e.args[i])
		}
		if index == e.args.count {
			return true
		}
		bias := implicitArg ? 1 : 0
		badArgs(c, e.openParen, index + bias, e.args.count + bias)
		return false
	}
	
	checkAbandon(c TypeCheckerContext, e CallExpression) {
		if e.args.count == 0 {
			return c.tags.void_
		}
		cond := getArgOfType(c, e, 0, c.tags.int_)
		checkRemainingArgs(c, e, 1, false)
		return c.tags.void_
	}

	checkAssert(c TypeCheckerContext, e CallExpression) {
		cond := getArgOfType(c, e, 0, c.tags.bool_)
		checkRemainingArgs(c, e, 1, false)
		return c.tags.void_
	}
	
	checkCheckedCast(c TypeCheckerContext, e CallExpression) {
		from := getArgWithTypeFlags(c, e, 0, TypeFlags.intval | TypeFlags.taggedPointerEnum, false, "Expected: expression of integer or tagged pointer type")
		if from.ti == null || (from.ti.flags & TypeFlags.intval) != 0 {
			to := getTypeArgWithTypeFlags(c, e, 1, TypeFlags.intval, "Expected: integer type")
			if !checkRemainingArgs(c, e, 2, false) || from.ti == null || to.ti == null {
				return to
			}
			if from.ti == to.ti {
				redundantCast(c, e.openParen)
			} else if canCoerce(c, from, null, to) {
				c.errors.add(Error.at(c.unit, e.openParen.span, "checked_cast will always succeed; use a normal cast instead"))
			}
			return to
		} else {
			to := getTypeArg(c, e, 1)
			if !checkRemainingArgs(c, e, 2, false) || from.ti == null || to.ti == null {
				return to
			}
			if !from.ti.taggedPointerOptions.contains(to) {
				badConversion(c, e.args[0], from, to)
				return Tag{}
			}
			return to			
		}
	}
	
	checkCast(c TypeCheckerContext, e CallExpression) {
		from := getArgWithTypeFlags(c, e, 0, TypeFlags.intval | TypeFlags.floatval | TypeFlags.boolval | TypeFlags.enum_ | TypeFlags.anyPointer, true, "Expected: expression of number, bool, enum or pointer type")
		if from.ti == null {
			to := getTypeArg(c, e, 1)
			checkRemainingArgs(c, e, 2, false)
			return to
		} else if (from.ti.flags & TypeFlags.intval) != 0 {
			to := getTypeArgWithTypeFlags(c, e, 1, TypeFlags.intval | TypeFlags.floatval | TypeFlags.enum_, "Expected: number or enum type")
			if !checkRemainingArgs(c, e, 2, false) || from.ti == null || to.ti == null {
				return to
			}
			if from.ti == to.ti {
				redundantCast(c, e.openParen)
			} else if (to.ti.flags & TypeFlags.enum_) != 0 {
				if !assign(c, from, e.args[0], c.tags.uint_) {
					badConversion(c, e.args[0], from, c.tags.uint_)
				}
			}
			return to
		} else if (from.ti.flags & TypeFlags.floatval) != 0 {
			to := getTypeArgWithTypeFlags(c, e, 1, TypeFlags.intval | TypeFlags.floatval, "Expected: number type")
			if !checkRemainingArgs(c, e, 2, false) || to.ti == null {
				return to
			}
			if from.ti == to.ti {
				redundantCast(c, e.openParen)
			}
			return to
		} else if (from.ti.flags & TypeFlags.boolval) != 0 {
			to := getTypeArgWithTypeFlags(c, e, 1, TypeFlags.boolval, "Expected: boolean type")
			if !checkRemainingArgs(c, e, 2, false) || to.ti == null {
				return to
			}
			if from.ti == to.ti {
				redundantCast(c, e.openParen)
			}
			return to
		} else if (from.ti.flags & TypeFlags.enum_) != 0 {
			to := getTypeArgWithTypeFlags(c, e, 1, TypeFlags.intval, "Expected: uint")
			if !checkRemainingArgs(c, e, 2, false) || to.ti == null {
				return to
			}
			if from.ti == to.ti {
				redundantCast(c, e.openParen)
			}
			if to.ti != c.tags.uint_.ti {
				c.errors.add(Error.at(c.unit, RangeFinder.find(e.args[1]), "Expected: uint"))
			}
			return to
		} else if from.ti == Tag.null_.ti {
			to := getTypeArgWithTypeFlags(c, e, 1, TypeFlags.anyPointer, "Expected: pointer type")
			checkRemainingArgs(c, e, 2, false)
			return to
		} else if (from.ti.flags & TypeFlags.taggedPointerEnum) != 0 {
			to := getTypeArg(c, e, 1)
			if !checkRemainingArgs(c, e, 2, false) || to.ti == null {
				return to
			}
			if from.ti == to.ti {
				redundantCast(c, e.openParen)
			} else {
				c.errors.add(Error.at(c.unit, RangeFinder.find(e.args[0]), "Must use either checked_cast or pointer_cast for tagged pointer"))
			}
			return to
		} else if (from.ti.flags & TypeFlags.anyPointer) != 0 {
			to := getTypeArgWithTypeFlags(c, e, 1, TypeFlags.taggedPointerEnum, "Expected: tagged pointer type; or, use pointer_cast")
			if !checkRemainingArgs(c, e, 2, false) || to.ti == null {
				return to
			}
			if !to.ti.taggedPointerOptions.contains(from) {
				badConversion(c, e.args[0], from, to)
			}		
			return to
		} else {
			abandon()
		}
	}

	checkPointerCast(c TypeCheckerContext, e CallExpression) {
		from := getArgWithTypeFlags(c, e, 0, TypeFlags.anyPointer | TypeFlags.string_, true, "Expected: expression of pointer type or string literal")
		if from.ti == null || (from.ti.flags & TypeFlags.taggedPointerEnum) == 0 {
			to := getTypeArgWithTypeFlags(c, e, 1, TypeFlags.anyPointer, "Expected: pointer type")
			if !checkRemainingArgs(c, e, 2, false) || from.ti == null || to.ti == null {
				return to
			}
			if Tag.equals(from, to) {
				redundantCast(c, e.openParen)
			} else if (to.ti.flags & TypeFlags.taggedPointerEnum) != 0 && !to.ti.taggedPointerOptions.contains(from) {
				badConversion(c, e.args[0], from, to)
			}
			return to
		} else if from.ti == c.tags.string_.ti {
			if !e.args[0].is(StringExpression) {
				c.errors.add(Error.at(c.unit, RangeFinder.find(e.args[0]), "Expected: string literal"))
			}
			to := getTypeArgWithTypeFlags(c, e, 1, TypeFlags.pointer_ | TypeFlags.cstring_, "Expected: pointer or cstring")
			checkRemainingArgs(c, e, 2, false)
			return to
		} else {
			to := getTypeArgWithTypeFlags(c, e, 1, TypeFlags.pointer_, "Expected: pointer")
			checkRemainingArgs(c, e, 2, false)
			return to
		}
	}

	checkTransmute(c TypeCheckerContext, e CallExpression) {
		from := getArgWithTypeFlags(c, e, 0, TypeFlags.anyTransmutableValue, true, "Expected: expression of transmutable type")
		to := getTypeArgWithTypeFlags(c, e, 1, TypeFlags.anyTransmutableValue, "Expected: transmutable type")
		if !checkRemainingArgs(c, e, 2, false) || from.ti == null || to.ti == null {
			return to
		}
		if Tag.equals(from, to) {
			c.errors.add(Error.at(c.unit, RangeFinder.find(e), "transmute is redundant"))
		}
		return to
	}

	checkIs(c TypeCheckerContext, e CallExpression, from Tag) {
		to := getTypeArg(c, e, 0)
		if !checkRemainingArgs(c, e, 1, true) || to.ti == null {
			return c.tags.bool_
		}
		if (from.ti.flags & TypeFlags.ptr_) != 0 {
			from = from.args[0]
		}
		if from.ti == Tag.null_.ti || !from.ti.taggedPointerOptions.contains(to) {
			badConversion(c, e.args[0], from, to)
		}
		return c.tags.bool_
	}
	
	checkAs(c TypeCheckerContext, e CallExpression, from Tag) {
		to := getTypeArg(c, e, 0)
		if !checkRemainingArgs(c, e, 1, true) || to.ti == null {
			return Tag{}
		}
		if (from.ti.flags & TypeFlags.ptr_) != 0 {
			from = from.args[0]
		}
		if from.ti == Tag.null_.ti {
			if (to.ti.flags & TypeFlags.anyPointer) == 0 {
				badConversion(c, e.args[0], from, to)
				return Tag{}
			}
			return to
		} else if (from.ti.flags & TypeFlags.taggedPointerEnum) != 0 {
			if !from.ti.taggedPointerOptions.contains(to) {
				badConversion(c, e.args[0], from, to)
				return Tag{}
			}
		} else {
			if (to.ti.flags & TypeFlags.taggedPointerEnum) == 0 || !to.ti.taggedPointerOptions.contains(from) {
				badConversion(c, e.args[0], from, to)
				return Tag{}
			}		
		}
		return to
	}
	
	checkFormat(c TypeCheckerContext, e CallExpression, from Tag) {
		// TODO: parse format string and make sure that it is consistent with the number of arguments
		index := 0
		if from.ti == null {
			if e.args.count == 0 {
				c.errors.add(Error.at(c.unit, e.openParen.span, "Expected 1 or more args but got 0 args"))
				return c.tags.string_
			}
			fmtArg := e.args[0]
			fmt := checkExpression(c, fmtArg)
			if fmt.ti == null || !fmtArg.is(StringExpression) {
				c.errors.add(Error.at(c.unit, RangeFinder.find(fmtArg), "Expected: string literal"))
			}
			index = 1
		}
		for i := index; i < e.args.count {
			a := e.args[i]
			checkExpression(c, a)
		}
		return c.tags.string_
	}
	
	checkMinMax(c TypeCheckerContext, e CallExpression) {
		lhs := getArgWithTypeFlags(c, e, 0, TypeFlags.anyNumber, false, "Expected: expression of number type")
		rhs := getArgWithTypeFlags(c, e, 1, TypeFlags.anyNumber, false, "Expected: expression of number type")
		if !checkRemainingArgs(c, e, 2, false) || lhs.ti == null || rhs.ti == null {
			return lhs.ti != null ? lhs : rhs
		}
		result := tryUnifyNumbers(c.tags, lhs, e.args[0], rhs, e.args[1])
		if result.ti == null {
			c.errors.add(Error.at(c.unit, e.openParen.span, format("Function cannot be applied to expressions of type {} and {}", lhs.toString(), rhs.toString())))
		}
		return result		
	}
	
	checkXor(c TypeCheckerContext, e CallExpression) {
		lhs := getArgWithTypeFlags(c, e, 0, TypeFlags.intval, false, "Expected: expression of integer type")
		rhs := getArgWithTypeFlags(c, e, 1, TypeFlags.intval, false, "Expected: expression of integer type")
		if !checkRemainingArgs(c, e, 2, false) || lhs.ti == null || rhs.ti == null {
			return lhs.ti != null ? lhs : rhs
		}
		result := tryUnifyIntvals(c.tags, lhs, e.args[0], rhs, e.args[1])
		if result.ti == null {
			c.errors.add(Error.at(c.unit, e.openParen.span, format("Function cannot be applied to expressions of type {} and {}", lhs.toString(), rhs.toString())))
		}
		return result		
	}

	checkSizeof(c TypeCheckerContext, e CallExpression) {
		type := getTypeArg(c, e, 0)
		checkRemainingArgs(c, e, 1, false)
		return c.tags.int_
	}
	
	checkComputeHash(c TypeCheckerContext, e CallExpression) {
		arg := getArgWithTypeFlags(c, e, 0, TypeFlags.anyValue, false, "Expected: non-null value")
		checkRemainingArgs(c, e, 1, false)
		return c.tags.uint_
	}

	checkDefaultValue(c TypeCheckerContext, e CallExpression) {
		type := getTypeArg(c, e, 0)
		checkRemainingArgs(c, e, 1, false)
		return type
	}
	
	checkGetArgcArgv(c TypeCheckerContext, e CallExpression) {
		c.comp.flags |= CompilationFlags.useArgcArgv
		argc := getArgOfType(c, e, 0, getSingleArgTag(c.tags.ptrTi, c.tags.int_))
		argv := getArgOfType(c, e, 1, getSingleArgTag(c.tags.ptrTi, c.tags.pointer_))
		checkRemainingArgs(c, e, 2, false)
		return c.tags.void_
	}
}



