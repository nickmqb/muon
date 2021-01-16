Location struct {
	unit CodeUnit
	span IntRange
}

CodeInfoHelper {
	getMemberName(node Node) {
		match node {
			FunctionDef: {					
				return node.name.value
			}
			FieldDef: {
				return node.name.value
			}
			StaticFieldDef: {
				return node.name.value
			}
			Namespace: {
				return node.name
			}
		}
	}

	getMemberLocation(node Node) {
		match node {
			FunctionDef: {			
				if node.builtin == BuiltinFunction.none {
					return Location { unit: node.unit, span: node.name.span }
				} else {
					return Location{}
				}				
			}
			FieldDef: {
				return Location { unit: node.unit, span: node.name.span }
			}
			StaticFieldDef: {
				return Location { unit: node.unit, span: node.name.span }
			}
			Namespace: {
				def := node.primaryDef
				return Location { unit: def.unit, span: def.name.span }
			}
		}
	}

	findTypeDefinition(tag Tag, type Node, token Token) {
		while (tag.ti.flags & TypeFlags.ptr_) != 0 {
			tag = tag.args[0]
		}
		if tag.ti == null {
			return Location{}
		}
		def := tag.ti.primaryDef
		match type {
			Token: {
				if type == token {
					return Location { unit: def.unit, span: def.name.span }
				}
			}
			TypeModifierExpression: {
				// TODO
			}
			TypeArgsExpression: {
				if type.target == token {
					return Location { unit: def.unit, span: def.name.span }
				}
				// TODO
			}
			UnaryOperatorExpression: {
				// TODO
			}
		}
		return Location{}
	}

	findDefinition(path List<Node>) {
		if path.count == 0 {
			return Location{}
		}
		
		token := path[path.count - 1].as(Token)
		if token.type != TokenType.identifier {
			return Location{}
		}

		i := 0
		while path[i].is(NamespaceDef) {
			i += 1
		}

		nsDef := i > 0 ? path[i - 1].as(NamespaceDef) : null

		if nsDef != null && token == nsDef.name {
			// Cycle through all defs
			ns := nsDef.ns
			j := 0
			while j < ns.defs.count && ns.defs[j] != nsDef {
				j += 1
			}
			nsDef = ns.defs[(j + 1) % ns.defs.count]
			return Location { unit: nsDef.unit, span: nsDef.name.span }
		}

		infoMap := cast(null, Map<Node, NodeInfo>)

		node := path[i]
		match node {
			FunctionDef: {
				func := node
				if token == func.name {
					return getMemberLocation(func)
				}
				infoMap = func.infoMap
				next := path[i + 1]
				for p in func.params {
					if next == p {
						if token == p.name {
							return Location { unit: func.unit, span: p.name.span }
						} else if p.tag.ti != null {
							return findTypeDefinition(p.tag, p.type, token)
						}
					}
				}
				if next == func.returnType && func.returnTag.ti != null {
					return findTypeDefinition(func.returnTag, func.returnType, token)
				}
			}
			StaticFieldDef: {
				staticField := node
				if token == staticField.name {
					return getMemberLocation(node)
				}
				next := path[i + 1]
				if next == staticField.type && staticField.tag.ti != null {
					return findTypeDefinition(staticField.tag, staticField.type, token)
				}
				infoMap = node.infoMap
			}
			FieldDef: {
				field := node
				if token == field.name {
					return getMemberLocation(field)
				}
				next := path[i + 1]
				if next == field.type && field.tag.ti != null {
					return findTypeDefinition(field.tag, field.type, token)
				}
				return Location{}
			}
			default: {
				return Location{}
			}
		}

		j := path.count - 2
		while j >= 0 && path[j].is(TypeArgsExpression) {
			j -= 1
		}

		parent := path[j]
		
		match parent {
			DotExpression: {
				dot := parent
				if dot.rhs == token {
					info := infoMap.getOrDefault(dot)
					if info.mem != null {
						return getMemberLocation(info.mem)	
					}
				}
			}
			UnaryOperatorExpression: {
				un := parent
				if un.op.value == "::" {
					info := infoMap.getOrDefault(un)
					if info.mem != null {
						return getMemberLocation(info.mem)
					}
				}
			}
			StructInitializerExpression: {
				next := path[j + 1]
				if next == parent.target {
					info := infoMap.getOrDefault(parent)
					if info.tag.ti != null {
						return findTypeDefinition(info.tag, parent.target, token)
					}				
				}
			}
			default: {
			}
		}

		// TODO
		// resolve bad syntax, e.g. single, out-of-context, type name token?
		// parameter usages
		// local var declarations + usages

		info := infoMap.getOrDefault(token)
		if info.mem != null {
			return getMemberLocation(info.mem)
		}

		return Location{}
	}

	findSymbols(comp Compilation, query string) {
		out := new List<Node>{}
		findSymbols_(comp.top, query, out)
		return out
	}

	findSymbols_(ns Namespace, query string, out List<Node>) {
		for ns.members {
			name := it.key		
			member := it.value	
			if name.startsWith_ignoreCase(query) {
				out.add(member)
			}
			if member.is(Namespace) {
				findSymbols_(member.as(Namespace), query, out)
			}
		}
	}
}