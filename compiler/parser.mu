IndentMode enum {
	none
	tabs
	spaces
	mixed
}

ParseCommaListState enum {
	start
	expectValue
	expectComma
}

ParserState struct #RefType {
	source string
	index int
	unit CodeUnit
	token Token
	lineStart int
	indent int
	tabSize int
	indentMode IndentMode
	angleBracketLevel int
	errors List<Error>
	numberValueSpan IntRange
	numberFlags NumberFlags
	prevTokenTo int
	lastBadToken Token
	lastBadTokenErrorIndex int
	parseOpenBrace_closeBrace Token // Workaround for C# interpreter limitation
	function FunctionDef
	evaluatedString StringBuilder
}

Parser {
	:sameLine = int.maxValue
	
	// Note: the last character of `source` must be '\0' ("sentinel value").
	// Syntax errors are added to `errors`.
	parse(source string, errors List<Error>) {
		unit := new CodeUnit { source: source, contents: new List<Node>{} }
		
		s := new ParserState { source: source, unit: unit, tabSize: 4, errors: errors, token: new Token{}, evaluatedString: new StringBuilder{} }
		
		checkTabSizeDirective(s)
		
		readToken(s)
		while s.token.type != TokenType.end {
			if s.token.indent == 0 {
				if s.token.type == TokenType.identifier {
					id := s.token
					readToken(s)
					typeParams := tryParseTypeParams(s)
					if s.token.indent > 0 && s.token.type == TokenType.openParen {
						unit.contents.add(parseFunctionTail(s, id, typeParams))
					} else {
						unit.contents.add(parseNamespaceTail(s, id, typeParams))
					}
				} else if s.token.type == TokenType.colon {
					parseStaticField(s, unit.contents)
				} else {
					badToken(s, "Expected: top-level declaration")
				}
				endLine(s, unit.contents)
			} else {
				badToken(s, "Incorrect indentation: top-level declaration may not be indented")
				endLine(s, unit.contents)
			}
		}
		
		return unit
	}
	
	tryParseTypeParams(s ParserState) {
		if !(s.token.indent > s.indent && s.token.type == TokenType.openAngleBracket) {
			return null
		}
		result := new TypeParams { openAngleBracket: s.token, params: new List<Token>{}, contents: new List<Token>{} }
		s.angleBracketLevel = 1
		readToken(s)
		state := ParseCommaListState.start
		while s.token.indent == sameLine && s.token.type != TokenType.closeAngleBracket {
			if state != ParseCommaListState.expectComma {
				if s.token.type == TokenType.identifier {
					result.params.add(s.token)
					result.contents.add(s.token)
					readToken(s)
					state = ParseCommaListState.expectComma
				} else {
					result.contents.add(s.token)
					badToken(s, "Expected: type parameter")
				}
			} else {
				if s.token.type == TokenType.comma {
					result.contents.add(s.token)
					readToken(s)
				} else {
					expected(s, ",")
				}
				state = ParseCommaListState.expectValue
			}
		}		
		if state == ParseCommaListState.start {
			expected(s, "identifier")
		}
		if s.token.indent == sameLine && s.token.type == TokenType.closeAngleBracket {
			result.closeAngleBracket = s.token
			readToken(s)
		} else {
			expected(s, ">")
		}
		s.angleBracketLevel = 0
		return result
	}
	
	parseNamespaceTail(s ParserState, name Token, nsTypeParams TypeParams) NamespaceDef {
		nd := new NamespaceDef { unit: s.unit, name: name, typeParams: nsTypeParams, contents: new List<Node>{} }
		
		if s.token.indent > s.indent && s.token.type == TokenType.identifier {
			if s.token.value == "struct" {
				nd.kindToken = s.token
				nd.kind = NamespaceKind.struct_
				readToken(s)
			} else if s.token.value == "enum" {
				nd.kindToken = s.token
				nd.kind = NamespaceKind.enum_
				readToken(s)
			} else if s.token.value == "tagged_pointer" {
				nd.kindToken = s.token
				nd.kind = NamespaceKind.taggedPointerEnum
				readToken(s)
			}
		}
		
		nd.attributes = tryParseAttributes(s)
		
		while s.token.indent == sameLine && s.token.type != TokenType.openBrace {
			if nd.badTokens == null {
				nd.badTokens = new List<Token>{}
			}
			nd.badTokens.add(s.token)
			badToken(s, "Unexpected tokens(s)")
		}
		
		nd.openBrace = parseOpenBrace(s, nd.contents)
		if s.parseOpenBrace_closeBrace != null {
			nd.closeBrace = s.parseOpenBrace_closeBrace
			return nd
		}
		
		contentIndent := s.token.indent
		while s.token.indent > s.indent {
			if s.token.type == TokenType.closeBrace {
				nd.contents.add(s.token)
				badToken(s, "Incorrect indentation: must match indentation of open brace, ignoring")
				endLine(s, nd.contents)
			} else if s.token.indent != contentIndent {
				nd.contents.add(s.token)
				badToken(s, "Incorrect indentation: must match indentation of first declaration in block")
				endLine(s, nd.contents)
			} else {
				prev := s.indent
				s.indent = s.token.indent
				if s.token.type == TokenType.identifier {
					id := s.token
					readToken(s)
					isNested := s.token.indent >= s.indent && s.token.type == TokenType.openBrace
					isNested ||= s.token.indent > s.indent && s.token.type == TokenType.identifier && (s.token.value == "struct" || s.token.value == "enum" || s.token.value == "tagged_pointer")
					// TODO: Allow tagged pointer enums to declare generic functions with an explicit type parameter list
					if s.token.indent > s.indent && s.token.type == TokenType.openAngleBracket && nd.kind != NamespaceKind.taggedPointerEnum {
						typeParams := tryParseTypeParams(s)
						if s.token.indent > s.indent && s.token.type == TokenType.openParen {
							nd.contents.add(parseFunctionTail(s, id, typeParams))
						} else {
							s.errors.add(Error.at(s.unit, id.span, "Nested namespace is not yet supported"))
							nd.contents.add(parseNamespaceTail(s, id, typeParams))
						}
					} else if s.token.indent > s.indent && s.token.type == TokenType.openParen {
						nd.contents.add(parseFunctionTail(s, id, null))
					} else if nd.kind == NamespaceKind.struct_ && !isNested {
						nd.contents.add(parseFieldTail(s, id))
					} else if nd.kind == NamespaceKind.enum_ && !isNested {
						nd.contents.add(parseEnumMemberTail(s, id))
					} else if nd.kind == NamespaceKind.taggedPointerEnum && !isNested {
						nd.contents.add(parseTaggedPointerOptionTail(s, id))
					} else {
						s.errors.add(Error.at(s.unit, id.span, "Nested namespace is not yet supported"))
						nd.contents.add(parseNamespaceTail(s, id, null))
					}
				} else if s.token.type == TokenType.colon {
					parseStaticField(s, nd.contents)
				} else if nd.kind == NamespaceKind.taggedPointerEnum && s.token.type == TokenType.operator && (s.token.value == "*" || s.token.value == "$" || s.token.value == "::") {
					nd.contents.add(parseTaggedPointerOptionTail(s, null))
				} else {
					nd.contents.add(s.token)
					badToken(s, "Expected: namespace member declaration")
				}
				endLine(s, nd.contents)
				s.indent = prev
			}
		}
		
		nd.closeBrace = parseCloseBrace(s)
		
		return nd
	}
	
	tryParseAttributes(s ParserState) {
		if !(s.token.indent > s.indent && s.token.type == TokenType.hash) {
			return null
		}
		result := new List<Attribute>{}
		while s.token.indent > s.indent && s.token.type == TokenType.hash 
				&& s.index == s.token.span.to && isIdentifierStartChar(s.source[s.index]) {
			result.add(parseAttribute(s))
		}
		return result
	}
	
	parseAttribute(s ParserState) {
		hash := s.token
		readToken(s)
		id := s.token
		assert(id.indent == sameLine && id.type == TokenType.identifier)
		readToken(s)
		result := new Attribute { hash: hash, name: id }
		if s.token.indent <= s.indent || s.token.type != TokenType.openParen {
			return result
		}
		
		result.openParen = s.token
		readToken(s)
		result.args = new List<Node>{}
		result.contents = new List<Node>{}
		
		state := ParseCommaListState.start
		while s.token.indent > s.indent && s.token.type != TokenType.closeParen {
			if state != ParseCommaListState.expectComma {
				arg := tryParseExpression(s, 0, true)
				if arg != null {
					result.args.add(arg)
					result.contents.add(arg)
					state = ParseCommaListState.expectComma
				} else {
					result.contents.add(s.token)
					badToken(s, "Expected: expression")
				}
			} else {
				if s.token.type == TokenType.comma {
					result.contents.add(s.token)
					readToken(s)
				} else {
					expected(s, ",")
				}
				state = ParseCommaListState.expectValue
			}
		}
		if state == ParseCommaListState.expectValue {
			expected(s, "expression")
		}
		
		if s.token.indent >= s.indent && s.token.type == TokenType.closeParen {
			result.closeParen = s.token
			readToken(s)
		} else {
			expected(s, ")")
		}
		return result
	}
	
	parseFunctionTail(s ParserState, id Token, typeParams TypeParams) {
		fd := new FunctionDef { unit: s.unit, name: id, typeParams: typeParams, openParen: s.token, params: new List<Param>{}, paramContents: new List<Node>{} }
		readToken(s)
		
		state := ParseCommaListState.start
		while s.token.indent > s.indent && s.token.type != TokenType.closeParen {
			if state != ParseCommaListState.expectComma {
				if s.token.type == TokenType.identifier {
					p := parseParam(s)
					fd.params.add(p)
					fd.paramContents.add(p)
					state = ParseCommaListState.expectComma
				} else {
					fd.paramContents.add(s.token)
					badToken(s, "Expected: parameter declaration")
				}
			} else {
				if s.token.type == TokenType.comma {
					fd.paramContents.add(s.token)
					readToken(s)
				} else {
					expected(s, ",")
				}
				state = ParseCommaListState.expectValue
			}
		}
		if state == ParseCommaListState.expectValue {
			expected(s, "parameter declaration")
		}

		if s.token.indent > s.indent && s.token.type == TokenType.closeParen {
			fd.closeParen = s.token
			readToken(s)
		} else {
			expected(s, ")")
		}
		
		fd.returnType = tryParseType(s)		
		fd.attributes = tryParseAttributes(s)
		
		while s.token.indent == sameLine && s.token.type != TokenType.openBrace {
			if fd.badTokens == null {
				fd.badTokens = new List<Token>{}
			}
			fd.badTokens.add(s.token)
			badToken(s, "Unexpected token(s)")
		}
		
		if s.token.indent < s.indent || (s.token.indent == s.indent && s.token.type != TokenType.openBrace) {
			return fd
		}
		
		s.function = fd
		fd.body = parseBlockStatement(s)
		return fd
	}
	
	parseParam(s ParserState) {
		p := new Param { name: s.token }
		readToken(s)
		type := tryParseType(s)
		if type != null {
			p.type = type
		} else {
			expected(s, "parameter type")
		}
		p.attributes = tryParseAttributes(s)
		return p
	}
	
	parseStaticField(s ParserState, out List<Node>) {	
		colon := s.token
		readToken(s)

		if s.token.indent <= s.indent {
			expected(s, "identifier")
			out.add(colon)
			return
		}
		if s.token.type != TokenType.identifier {
			out.add(colon)
			out.add(s.token)
			badToken(s, "Expected: identifier")
			return
		}
		
		sf := new StaticFieldDef { unit: s.unit, colon: colon, name: s.token }
		out.add(sf)
		readToken(s)
		sf.type = tryParseType(s)
		sf.attributes = tryParseAttributes(s)
		
		if s.token.indent <= s.indent || s.token.type != TokenType.operator || s.token.value != "=" {
			return
		}

		sf.assign = s.token
		readToken(s)
		
		sf.initializeExpr = tryParseExpression(s, 0, true)
		if sf.initializeExpr == null {
			expected(s, "expression")
		}		
	}

	parseFieldTail(s ParserState, name Token) {
		fd := new FieldDef { unit: s.unit, name: name }
		type := tryParseType(s)
		if type != null {
			fd.type = type
		} else {
			expected(s, "field type")
		}
		return fd
	}

	parseEnumMemberTail(s ParserState, name Token) {
		sf := new StaticFieldDef { unit: s.unit, name: name }
		sf.flags |= StaticFieldFlags.isEnumOption

		if s.token.indent <= s.indent || s.token.type != TokenType.operator || s.token.value != "=" {
			sf.flags |= StaticFieldFlags.autoValue
			return sf
		}

		sf.assign = s.token
		readToken(s)
		
		sf.initializeExpr = tryParseExpression(s, 0, true)
		if sf.initializeExpr == null {
			expected(s, "expression")
		}		

		return sf
	}

	parseTaggedPointerOptionTail(s ParserState, id Token) {
		type := cast(null, Node)
		if id != null {
			type = parseTypeTail(s, id)
		} else {
			first := s.token
			firstIndent := s.token.indent
			first.indent = sameLine
			type = tryParseType(s)
			first.indent = firstIndent
			assert(type != null)
		}
		return new TaggedPointerOptionDef { type: type }
	}
	
	parseOpenBrace(s ParserState, contents List<Node>) {
		s.parseOpenBrace_closeBrace = null
		if s.token.type == TokenType.openBrace {
			result := s.token
			if s.token.indent == s.indent || s.token.indent == sameLine {
				readToken(s)
			} else {
				badToken(s, "Incorrect indentation: must match indentation of previous line")
			}			
			if s.token.type == TokenType.closeBrace && (s.token.indent == s.indent || s.token.indent == sameLine) {
				s.parseOpenBrace_closeBrace = s.token
				readToken(s)
				return result
			}
			endLine(s, contents)
			return result
		} else {
			expected(s, "{")
			return null
		}
	}
	
	parseCloseBrace(s ParserState) {
		if s.token.type == TokenType.closeBrace {
			if s.token.indent == s.indent {
				result := s.token
				readToken(s)
				return result
			} else {
				s.errors.add(Error.atIndex(s.unit, s.token.span.from, "Incorrect indentation: close brace must be indented more"))
				return null
			}
		} else {
			expectedAt(s, s.token.span.from, "}")
			return null
		}
	}
	
	tryParseType(s ParserState) Node {
		if s.token.indent <= s.indent {
			return null
		}
		result := cast(null, Node)
		if s.token.type == TokenType.identifier {
			result = s.token
			readToken(s)
		} else if s.token.type == TokenType.operator && (s.token.value == "*" || s.token.value == "$") {
			mod := s.token
			readToken(s)
			result = new TypeModifierExpression { modifier: mod, arg: parseTypeModifiers(s) }
		} else if s.token.type == TokenType.operator && s.token.value == "::" {
			e := new UnaryOperatorExpression { op: s.token }
			readToken(s)
			if s.token.indent == sameLine && s.token.type == TokenType.identifier {
				e.expr = cast(s.token, Node)
				readToken(s)
			} else {
				expected(s, "type name")
			}
			result = cast(e, Node)
		} else {
			return null
		}
		if s.token.indent == sameLine && s.token.type == TokenType.openAngleBracket {
			return parseTypeArgsExpressionTail(s, result)
		} else {
			return result
		}
	}
	
	parseTypeTail(s ParserState, id Token) Node {
		if s.token.indent == sameLine && s.token.type == TokenType.openAngleBracket {
			return parseTypeArgsExpressionTail(s, id)
		} else {
			return cast(id, Node)
		}
	}
	
	parseTypeModifiers(s ParserState) Node {
		if s.token.indent == sameLine && s.token.type == TokenType.identifier {
			id := s.token
			readToken(s)
			return id
		} else if s.token.indent == sameLine && s.token.type == TokenType.operator && (s.token.value == "*" || s.token.value == "$") {
			mod := s.token
			readToken(s)
			return new TypeModifierExpression { modifier: mod, arg: parseTypeModifiers(s) }			
		} else if s.token.indent == sameLine && s.token.type == TokenType.operator && s.token.value == "::" {
			e := new UnaryOperatorExpression { op: s.token }
			readToken(s)
			if s.token.indent == sameLine && s.token.type == TokenType.identifier {
				e.expr = cast(s.token, Node)
				readToken(s)
			} else {
				expected(s, "type name")
			}
			return e
		} else {
			expected(s, "type name")
			return null
		}
	}

	parseTypeArgsExpressionTail(s ParserState, target Node) {
		result := new TypeArgsExpression { target: target, openAngleBracket: s.token, args: new List<Node>{}, contents: new List<Node>{} }
		s.angleBracketLevel += 1
		readToken(s)
		state := ParseCommaListState.start
		while s.token.indent == sameLine && s.token.type != TokenType.closeAngleBracket {
			if state != ParseCommaListState.expectComma {
				arg := tryParseType(s)
				if arg != null {
					result.args.add(arg)
					result.contents.add(arg)					
					state = ParseCommaListState.expectComma
				} else {
					result.contents.add(s.token)
					badToken(s, "Expected: type argument")
				}
			} else {
				if s.token.type == TokenType.comma {
					result.contents.add(s.token)
					readToken(s)
				} else {
					expected(s, ",")
				}
				state = ParseCommaListState.expectValue
			}
		}
		if state != ParseCommaListState.expectComma {
			expected(s, "type argument")
		}
		if s.token.indent == sameLine && s.token.type == TokenType.closeAngleBracket {
			result.closeAngleBracket = s.token
			readToken(s)
		} else {
			expected(s, ">")
		}
		s.angleBracketLevel -= 1
		return result
	}
	
	canParseTypeArgsExpressionTail(s ParserState) {
		level := 1
		index := s.index
		state := ParseCommaListState.start
		while true {
			ch := s.source[index]
			if ch == '\0' || ch == '\r' || ch == '\n' {
				return false
			} else if ch == ' ' || ch == '\t' {
				index += 1
				continue
			}
			if state != ParseCommaListState.expectComma {
				if ch == '*' || ch == '$' {
					index += 1
				} else if ch == ':' && s.source[index + 1] == ':' {
					index += 2
				} else if isIdentifierStartChar(ch) {
					index += 1
					ch = s.source[index]
					while isIdentifierChar(ch) {
						index += 1
						ch = s.source[index]
					}
					while ch == ' ' || ch == '\t' {
						index += 1
						ch = s.source[index]
					}
					if ch == '<' {
						level += 1
						index += 1
						state = ParseCommaListState.start
					} else {
						state = ParseCommaListState.expectComma
					}
				} else {
					return false
				}
			} else {
				if ch == ',' {
					index += 1
					state = ParseCommaListState.expectValue
				} else if ch == '>' {
					index += 1
					level -= 1
					if level == 0 {
						break
					}
				} else {
					return false
				}			
			}
		}
		return true
	}
	
	parseBlockStatement(s ParserState) BlockStatement {
		contents := new List<Node>{}
		openBrace := parseOpenBrace(s, contents)
		if s.parseOpenBrace_closeBrace != null {
			return new BlockStatement { openBrace: openBrace, contents: contents, closeBrace: s.parseOpenBrace_closeBrace }
		}
		
		contentIndent := s.token.indent
		while s.token.indent > s.indent {
			if s.token.type == TokenType.closeBrace {
				contents.add(s.token)
				badToken(s, "Incorrect indentation: must match indentation of open brace, ignoring")
				endLine(s, contents)
			} else if s.token.indent != contentIndent {
				contents.add(s.token)
				badToken(s, "Incorrect indentation: must match indentation of first statement in block")
				endLine(s, contents)
			} else {
				prev := s.indent
				s.indent = s.token.indent
				if s.token.type == TokenType.identifier {
					if s.token.value == "return" {
						contents.add(parseReturnStatement(s, true))
					} else if s.token.value == "break" {
						contents.add(new BreakStatement { keyword: s.token })
						readToken(s)
					} else if s.token.value == "continue" {
						contents.add(new ContinueStatement { keyword: s.token })
						readToken(s)
					} else if s.token.value == "if" {
						contents.add(parseIfStatement(s))
					} else if s.token.value == "while" {
						contents.add(parseWhileStatement(s))
					} else if s.token.value == "for" {
						contents.add(parseForStatement(s))
					} else if s.token.value == "match" {
						contents.add(parseMatchStatement(s))
					} else {
						st := tryParseExpressionStatement(s, true)
						if st != null {
							contents.add(st)
						} else {
							contents.add(s.token)
							badToken(s, "Expected: statement")
						}
					}
				} else if s.token.type == TokenType.openBrace {
					st := parseBlockStatement(s)
					assert(st != null)
					contents.add(st)
				} else {
					st := tryParseExpressionStatement(s, true)
					if st != null {
						contents.add(st)
					} else {
						contents.add(s.token)
						badToken(s, "Expected: statement")
					}
				}
				endLine(s, contents)
				s.indent = prev
			}
		}
		
		closeBrace := parseCloseBrace(s)
		if openBrace != null || contents.count > 0 || closeBrace != null {
			return new BlockStatement { openBrace: openBrace, contents: contents, closeBrace: closeBrace }
		} else {
			return null
		}
	}
	
	tryParseInlineStatement(s ParserState, allowStructInitializer bool) Node {
		if s.token.indent <= s.indent {
			return null
		}
		if s.token.type == TokenType.identifier && s.token.value == "return" {
			return parseReturnStatement(s, allowStructInitializer)
		} else if s.token.type == TokenType.openBrace {
			return parseBlockStatement(s)
		} else {
			return tryParseExpressionStatement(s, allowStructInitializer)
		}
	}
	
	tryParseExpressionStatement(s ParserState, allowStructInitializer bool) {
		first := s.token
		saveIndent := first.indent
		first.indent = sameLine
		expr := tryParseExpression(s, 0, allowStructInitializer)
		first.indent = saveIndent		
		if expr == null {
			return null
		}
		return new ExpressionStatement { expr: expr }
	}
	
	parseReturnStatement(s ParserState, allowStructInitializer bool) {
		st := new ReturnStatement { keyword: s.token }
		readToken(s)
		st.expr = tryParseExpression(s, 0, allowStructInitializer)
		if st.expr != null {
			s.function.flags |= FunctionFlags.returnsValue
		}
		return st
	}
	
	parseIfStatement(s ParserState) Node {
		st := new IfStatement { ifKeyword: s.token }
		readToken(s)
		st.conditionExpr = tryParseExpression(s, 0, false)
		if s.token.indent == sameLine && s.token.type != TokenType.openBrace {
			st.badTokens = new List<Token>{}
			while s.token.indent == sameLine && s.token.type != TokenType.openBrace {
				st.badTokens.add(s.token)
				badToken(s, st.conditionExpr != null ? "Unexpected token(s)" : "Expected: expression")
			}
		} else if st.conditionExpr == null {
			expected(s, "expression")
		}
		st.ifBranch = parseBlockStatement(s)
		if s.token.type == TokenType.identifier && s.token.value == "else" && (s.token.indent == s.indent || s.token.indent == sameLine) {
			st.elseKeyword = s.token
			readToken(s)
			if s.token.type == TokenType.identifier && s.token.value == "if" && s.token.indent == sameLine {
				st.elseBranch = parseIfStatement(s)
			} else {
				st.elseBranch = parseBlockStatement(s)
			}
		}
		return st
	}
	
	parseWhileStatement(s ParserState) {
		st := new WhileStatement { keyword: s.token }
		readToken(s)
		st.conditionExpr = tryParseExpression(s, 0, false)
		if s.token.indent == sameLine && s.token.type != TokenType.openBrace {
			st.badTokens = new List<Token>{}
			while s.token.indent == sameLine && s.token.type != TokenType.openBrace {
				st.badTokens.add(s.token)
				badToken(s, st.conditionExpr != null ? "Unexpected token(s)" : "Expected: expression")
			}
		} else if st.conditionExpr == null {
			expected(s, "expression")
		}
		st.body = parseBlockStatement(s)
		return st
	}
	
	parseForStatement(s ParserState) Node {
		keyword := s.token
		readToken(s)
		if s.token.indent <= s.indent {
			return new ForEachStatement { keyword: keyword }
		}
		if s.token.type == TokenType.semicolon {
			return parseForIndexStatementTail(s, keyword, null)
		} else if s.token.type == TokenType.identifier {
			id := s.token
			readToken(s)
			if s.token.indent <= s.indent {
				expected(s, "{")
				return new ForEachStatement { keyword: keyword, sequenceExpr: id }
			} else if s.token.type == TokenType.operator && s.token.value == ":=" {
				return parseForIndexStatementTail(s, keyword, id)
			} else {
				st := new ForEachStatement { keyword: keyword }
				if s.token.type == TokenType.identifier && s.token.value == "in" {
					st.iteratorVariable = id
					st.inKeyword = s.token
					readToken(s)
					st.sequenceExpr = tryParseExpression(s, 0, false)
					if st.sequenceExpr == null {
						expected(s, "expression")
					}
					return parseForEachStatementTail(s, st)
				} else if s.token.type == TokenType.comma {
					st.iteratorVariable = id
					st.comma = s.token
					readToken(s)
					if s.token.indent > s.indent && s.token.type == TokenType.identifier {
						st.indexIteratorVariable = s.token
						readToken(s)
					} else {
						expected(s, "identifier")
					}
					if s.token.indent > s.indent && s.token.type == TokenType.identifier && s.token.value == "in" {
						st.inKeyword = s.token
						readToken(s)
					} else {
						expected(s, "in")
					}
					st.sequenceExpr = tryParseExpression(s, 0, false)
					if st.sequenceExpr == null {
						expected(s, "expression")
					}
					return parseForEachStatementTail(s, st)
				} else {
					st.sequenceExpr = parseExpressionTail(s, id, 0, false)
					return parseForEachStatementTail(s, st)
				}
			}
		} else {
			st := new ForEachStatement { keyword: keyword }
			st.sequenceExpr = tryParseExpression(s, 0, false)
			if st.sequenceExpr == null {
				expected(s, "expression")
			}
			return parseForEachStatementTail(s, st)
		}
	}
	
	parseForEachStatementTail(s ParserState, st ForEachStatement) {
		if s.token.indent == sameLine && s.token.type != TokenType.openBrace {
			st.badTokens = new List<Token>{}
			while s.token.indent == sameLine && s.token.type != TokenType.openBrace {
				st.badTokens.add(s.token)
				badToken(s, "Unexpected token(s)")
			}
		}
		st.body = parseBlockStatement(s)
		return st
	}
	
	parseForIndexStatementTail(s ParserState, keyword Token, id Token) {
		st := new ForIndexStatement { keyword: keyword }
		if id != null {
			initExpr := new BinaryOperatorExpression { lhs: id, op: s.token }
			readToken(s)
			initExpr.rhs = tryParseExpression(s, 0, false)
			if initExpr.rhs == null {
				expected(s, "expression")
			}
			st.initializeStatement = new ExpressionStatement { expr: initExpr }
		}
		if s.token.indent > s.indent && s.token.type == TokenType.semicolon {
			st.firstSemicolon = s.token
			readToken(s)
		} else {
			expected(s, ";")
		}
		st.conditionExpr = tryParseExpression(s, 0, false)
		if st.conditionExpr == null {
			expected(s, "expression")
		}
		if s.token.indent > s.indent && s.token.type == TokenType.semicolon {
			st.secondSemicolon = s.token
			readToken(s)
			st.nextStatement = tryParseInlineStatement(s, false)
			if st.nextStatement == null {
				expected(s, "statement")
			}
		} else if id == null {
			expected(s, ";")
		}
		if s.token.indent == sameLine && s.token.type != TokenType.openBrace {
			st.badTokens = new List<Token>{}
			while s.token.indent == sameLine && s.token.type != TokenType.openBrace {
				st.badTokens.add(s.token)
				badToken(s, "Unexpected token(s)")
			}
		}
		st.body = parseBlockStatement(s)
		return st
	}
	
	parseMatchStatement(s ParserState) {
		st := new MatchStatement { keyword: s.token, cases: new List<MatchCase>{}, contents: new List<Node>{} }
		readToken(s)
		st.expr = tryParseExpression(s, 0, false)
		if st.expr == null {
			expected(s, "expression")
		}
		if s.token.indent == sameLine && s.token.type != TokenType.openBrace {
			st.badTokens = new List<Token>{}
			while s.token.indent == sameLine && s.token.type != TokenType.openBrace {
				st.badTokens.add(s.token)
				badToken(s, "Unexpected token(s)")
			}
		}
		
		openBrace := parseOpenBrace(s, st.contents)
		if s.parseOpenBrace_closeBrace != null {
			st.closeBrace = s.parseOpenBrace_closeBrace
			return st
		}
		
		contentIndent := s.token.indent
		while s.token.indent > s.indent {
			if s.token.type == TokenType.closeBrace {
				st.contents.add(s.token)
				badToken(s, "Incorrect indentation: must match indentation of open brace, ignoring")
				endLine(s, st.contents)
			} else if s.token.indent != contentIndent {
				st.contents.add(s.token)
				badToken(s, "Incorrect indentation: must match indentation of first match case in block")
				endLine(s, st.contents)
			} else {
				prev := s.indent
				s.indent = s.token.indent
				case := tryParseMatchCase(s)
				if case != null {
					st.cases.add(case)
					st.contents.add(case)
				} else {
					st.contents.add(s.token)
					badToken(s, "Expected: type name, default or null")
				}
				endLine(s, st.contents)
				s.indent = prev
			}
		}
		
		st.closeBrace = parseCloseBrace(s)
		return st		
	}

	tryParseMatchCase(s ParserState) {
		first := s.token
		savedIndent := first.indent
		first.indent = sameLine
		type := tryParseType(s)
		first.indent = savedIndent
		if type == null {
			return null
		}
		
		case := new MatchCase { type: type }
		if type.is(Token) && type.as(Token).type == TokenType.identifier && (type.as(Token).value == "null" || type.as(Token).value == "default") {
			case.flags |= getMatchCaseFlags(type.as(Token).value)
			if s.token.indent > s.indent && s.token.type == TokenType.operator && s.token.value == "|" {
				case.or = s.token
				readToken(s)
				if s.token.indent > s.indent && s.token.type == TokenType.identifier {
					case.secondType = s.token
					if s.token.value == "null" {
						if type.as(Token).value == "null" {
							s.errors.add(Error.at(s.unit, s.token.span, "Expected: default"))
						}
					} else if s.token.value == "default" {
						if type.as(Token).value == "default" {
							s.errors.add(Error.at(s.unit, s.token.span, "Expected: null"))
						}
					} else {
						s.errors.add(Error.at(s.unit, s.token.span, "Expected: null or default"))
					}
					case.flags |= getMatchCaseFlags(s.token.value)
					readToken(s)
				} else {
					expected(s, "null or default")
				}				
			}			
		}
		
		if s.token.indent > s.indent && s.token.type == TokenType.colon {
			case.colon = s.token
			readToken(s)
		} else {
			expected(s, ":")
		}
		
		case.statement = tryParseInlineStatement(s, true)
		if case.statement == null {
			expected(s, "statement")
		}

		return case
	}
	
	getMatchCaseFlags(id string) {
		if id == "null" {
			return MatchCaseFlags.null_
		} else if id == "default" {
			return MatchCaseFlags.default_
		}
		return cast(0_u, MatchCaseFlags)
	}
	
	tryParseExpression(s ParserState, minLevel int, allowStructInitializer bool) Node {
		leaf := tryParseExpressionLeaf(s, allowStructInitializer)
		if leaf == null {
			return null
		}
		return parseExpressionTail(s, leaf, minLevel, allowStructInitializer)
	}
	
	tryParseExpressionLeaf(s ParserState, allowStructInitializer bool) Node {
		if s.token.indent <= s.indent {
			return null
		}
		if s.token.type == TokenType.identifier {
			if s.token.value != "new" && s.token.value != "ref" {
				result := s.token
				readToken(s)
				return result
			} else {
				result := new UnaryOperatorExpression { op: s.token }
				readToken(s)
				result.expr = tryParseExpression(s, 25, allowStructInitializer)
				return result
			}			
		} else if s.token.type == TokenType.numberLiteral {
			result := new NumberExpression { token: s.token, valueSpan: s.numberValueSpan, flags: s.numberFlags }
			readToken(s)
			return result
		} else if s.token.type == TokenType.characterLiteral {
			result := s.token
			readToken(s)
			return result
		} else if s.token.type == TokenType.stringLiteral {
			result := new StringExpression { token: s.token, evaluatedString: s.evaluatedString.toString() }
			readToken(s)
			return result
		} else if s.token.type == TokenType.operator && (s.token.value == "*" || s.token.value == "$") {
			return tryParseType(s)
		} else if s.token.type == TokenType.operator && s.token.value == "::" {
			result := new UnaryOperatorExpression { op: s.token }
			readToken(s)
			if s.token.indent > s.indent && s.token.type == TokenType.identifier {
				result.expr = cast(s.token, Node)
				readToken(s)
			} else {
				expected(s, "identifier")
			}
			return result
		} else if s.token.type == TokenType.operator && (s.token.value == "-" || s.token.value == "!" || s.token.value == "~") {
			result := new UnaryOperatorExpression { op: s.token }
			readToken(s)
			result.expr = tryParseExpression(s, 25, allowStructInitializer)
			return result
		} else if s.token.type == TokenType.openParen {
			result := new ParenExpression { openParen: s.token }
			readToken(s)
			result.expr = tryParseExpression(s, 0, true)
			if result.expr == null {
				expected(s, "expression")
			}
			if s.token.indent >= s.indent && s.token.type == TokenType.closeParen {
				result.closeParen = s.token
				readToken(s)
			} else {
				expected(s, ")")
			}
			return result
		} else {
			return null
		}		
	}
	
	parseExpressionTail(s ParserState, lhs Node, minLevel int, allowStructInitializer bool) Node {
		while true {
			if s.token.indent <= s.indent {
				return lhs
			}
			if s.token.type == TokenType.openParen && minLevel <= 25 {
				result := new CallExpression { target: lhs, openParen: s.token, args: new List<Node>{}, contents: new List<Node>{} }
				readToken(s)
				state := ParseCommaListState.start
				while s.token.indent > s.indent && s.token.type != TokenType.closeParen {
					if state != ParseCommaListState.expectComma {
						arg := tryParseExpression(s, 0, true)
						if arg != null {
							result.args.add(arg)
							result.contents.add(arg)
							state = ParseCommaListState.expectComma
						} else {
							result.contents.add(s.token)
							badToken(s, "Expected: expression")
						}
					} else {
						if s.token.type == TokenType.comma {
							result.contents.add(s.token)
							readToken(s)
						} else {
							expected(s, ",")
						}
						state = ParseCommaListState.expectValue
					}
				}
				if state == ParseCommaListState.expectValue {
					expected(s, "expression")
				}
				if s.token.indent >= s.indent && s.token.type == TokenType.closeParen {
					result.closeParen = s.token
					readToken(s)
				} else {
					expected(s, ")")
				}
				lhs = cast(result, Node)
			} else if s.token.type == TokenType.openBracket && minLevel <= 25 {
				result := new IndexExpression { target: lhs, openBracket: s.token }
				readToken(s)
				result.arg = tryParseExpression(s, 0, true)
				if result.arg == null {
					expected(s, "expression")
				}
				if s.token.indent >= s.indent && s.token.type == TokenType.closeBracket {
					result.closeBracket = s.token
					readToken(s)
				} else {
					expected(s, "]")
				}
				lhs = cast(result, Node)
			} else if s.token.type == TokenType.openAngleBracket && minLevel <= 25 {
				if ((lhs.is(Token) && lhs.as(Token).type == TokenType.identifier) || lhs.is(DotExpression)) && canParseTypeArgsExpressionTail(s) {
					lhs = cast(parseTypeArgsExpressionTail(s, lhs), Node)
				} else {
					s.token.type = TokenType.operator
				}
			} else if s.token.type == TokenType.openBrace && minLevel <= 25 && allowStructInitializer {
				if (lhs.is(Token) && lhs.as(Token).type == TokenType.identifier) || lhs.is(TypeModifierExpression) || lhs.is(TypeArgsExpression) {
					result := new StructInitializerExpression { target: lhs, openBrace: s.token, args: new List<FieldInitializerExpression>{}, contents: new List<Node>{} }
					readToken(s)
					state := ParseCommaListState.start
					while s.token.indent > s.indent && s.token.type != TokenType.closeBrace {
						if state != ParseCommaListState.expectComma {
							if s.token.type == TokenType.identifier {
								fi := parseFieldInitializerExpression(s)
								result.args.add(fi)
								result.contents.add(fi)
								state = ParseCommaListState.expectComma
							} else {
								result.contents.add(s.token)
								badToken(s, "Expected: field initializer expression")
							}
						} else {
							if s.token.type == TokenType.comma {
								result.contents.add(s.token)
								readToken(s)
							} else {
								expected(s, ",")
							}
							state = ParseCommaListState.expectValue
						}
					}
					// Note: trailing comma is allowed.
					if s.token.indent >= s.indent && s.token.type == TokenType.closeBrace {
						result.closeBrace = s.token
						readToken(s)
					} else {
						expected(s, "}")
					}
					lhs = cast(result, Node)
				} else {
					return lhs
				}
			} else if s.token.type == TokenType.operator {
				level := getBindingLevel(s.token.value)
				if level < minLevel {
					return lhs
				}
				if s.token.value == "?" {
					result := new TernaryOperatorExpression { conditionExpr: lhs, question: s.token }
					readToken(s)
					result.trueExpr = tryParseExpression(s, 10, allowStructInitializer)
					if result.trueExpr != null {
						if s.token.indent > s.indent && s.token.type == TokenType.colon {
							result.colon = s.token
							readToken(s)
							result.falseExpr = tryParseExpression(s, 10, allowStructInitializer)
							if result.falseExpr == null {
								expected(s, "expression")
							}							
						} else {
							expected(s, ":")
						}
					} else {
						expected(s, "expression")
					}
					lhs = cast(result, Node)
				} else if s.token.value == "^" {
					result := new PostfixUnaryOperatorExpression { expr: lhs, op: s.token }
					readToken(s)
					lhs = cast(result, Node)
				} else if s.token.value == "." {
					result := new DotExpression { lhs: lhs, dot: s.token }
					readToken(s)
					if s.token.indent > s.indent && s.token.type == TokenType.identifier {
						result.rhs = s.token
						readToken(s)
					} else {
						expected(s, "identifier")
					}
					lhs = cast(result, Node)
				} else {
					result := new BinaryOperatorExpression { lhs: lhs, op: s.token }
					readToken(s)
					result.rhs = tryParseExpression(s, level + 1, allowStructInitializer)
					if result.rhs == null {
						expected(s, "expression")
					}
					lhs = cast(result, Node)
				}
			} else {
				return lhs
			}
		}
	}
	
	parseFieldInitializerExpression(s ParserState) {
		result := new FieldInitializerExpression { fieldName: s.token }
		readToken(s)
		if s.token.indent <= s.indent || s.token.type != TokenType.colon {
			expected(s, ":")
			return result
		}
		result.colon = s.token
		readToken(s)
		result.expr = tryParseExpression(s, 0, true)
		if result.expr == null {
			expected(s, "expression")
		}
		return result		
	}
	
	getBindingLevel(op string) {
		if op == "." || op == "^" {
			return 25
		} else if op == "*" || op == "/" || op == "%" {
			return 20
		} else if op == "+" || op == "-" {
			return 19
		} else if op == "<<" || op == ">>" {
			return 18
		} else if op == "<" || op == ">" || op == "<=" || op == ">=" {
			return 17
		} else if op == "==" || op == "!=" {
			return 16
		} else if op == "&" {
			return 15
		} else if op == "|" {
			return 14
		} else if op == "&&" {
			return 13
		} else if op == "||" {
			return 12
		} else if op == "?" {
			return 10
		} else if op == "=" || (op.length == 2 && op[1] == '=') || (op.length == 3 && op[2] == '=') {
			return 0
		}
		return -1
	}
	
	endLine(s ParserState, badTokens List<Node>) {
		while s.token.indent == sameLine {
			badTokens.add(s.token)
			badToken(s, "Tokens must be moved to the next line")
		}
	}
	
	badToken(s ParserState, text string) {
		markBadToken(s, s.token, text)
		readToken(s)
	}
	
	markBadToken(s ParserState, token Token, text string) {
		if s.lastBadToken != null && s.lastBadToken.outerSpan.to == token.outerSpan.from {
			s.errors[s.lastBadTokenErrorIndex].span.to = token.span.to
		} else {
			s.errors.add(Error.at(s.unit, token.span, text))
			s.lastBadTokenErrorIndex = s.errors.count - 1
		}
		s.lastBadToken = token
	}
	
	expected(s ParserState, text string) {
		expectedAt(s, s.prevTokenTo, text)
	}
	
	expectedAt(s ParserState, index int, text string) {
		s.errors.add(Error.atIndex(s.unit, index, format("Expected: {}", text)))
	}
	
	checkTabSizeDirective(s ParserState) {
		prefix := "//tab_size="
		if !s.source.startsWith(prefix) {
			return
		}		
		from := prefix.length
		to := from
		while isDigit(s.source[to]) {
			to += 1
		}
		chars := to - from
		if chars == 1 || chars == 2 {
			tabSize := cast(long.tryParse(s.source.slice(from, to)).unwrap(), int)
			if 1 <= tabSize && tabSize <= 16 {
				s.tabSize = tabSize
				s.indentMode = IndentMode.mixed
			}
		}
	}
	
	readToken(s ParserState) {
		outerFrom := s.index
		indent := 0
		while true {
			ch := s.source[s.index]
			tabs := 0
			spaces := 0
			if s.index == s.lineStart {
				while true {
					if ch == '\t' {
						tabs += 1
					} else if ch == ' ' || ch == '\r' {
						spaces += 1
					} else {
						break
					}
					s.index += 1
					ch = s.source[s.index]
				}
				indent = tabs * s.tabSize + spaces
			} else {
				while ch == '\t' || ch == ' ' || ch == '\r' {
					s.index += 1
					ch = s.source[s.index]
				}
				indent = sameLine
			}
			if (ch == '/' && s.source[s.index + 1] == '/') {
				s.index += 2
				ch = s.source[s.index]
				while ch != '\n' && ch != '\0' {
					s.index += 1
					ch = s.source[s.index]
				}
			} else if ch == '\n' {
				s.index += 1
				s.lineStart = s.index
			} else {
				if indent < sameLine {
					if s.indentMode == IndentMode.tabs {
						if spaces > 0 {
							mixingTabsSpaces(s)
						}
					} else if s.indentMode == IndentMode.spaces {
						if tabs > 0 {
							mixingTabsSpaces(s)
						}
					} else if s.indentMode == IndentMode.none {
						if tabs > 0 && spaces == 0 {
							s.indentMode = IndentMode.tabs
						} else if spaces > 0 && tabs == 0 {
							s.indentMode = IndentMode.spaces
						} else if spaces > 0 && tabs > 0 {
							mixingTabsSpaces(s)
						}
					}
				}
				break
			}
		}
		from := s.index
		ch := s.source[s.index]
		if ch == '\0' {
			s.index += 1
			s.prevTokenTo = s.token.span.to
			s.token = new Token {
				type: TokenType.end, 
				value: s.source.slice(from, s.index),
				indent: 0,
				span: IntRange(from, s.index),
				outerSpan: IntRange(outerFrom, s.index)
			}
		} else if ch == ',' {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.comma)
		} else if ch == ';' {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.semicolon)
		} else if ch == ':' {
			s.index += 1
			ch = s.source[s.index]
			if ch == '=' || ch == ':' {
				s.index += 1
				finishToken(s, outerFrom, from, indent, TokenType.operator)
			} else {
				finishToken(s, outerFrom, from, indent, TokenType.colon)
			}
		} else if ch == '(' {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.openParen)
		} else if ch == ')' {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.closeParen)
		} else if ch == '{' {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.openBrace)
		} else if ch == '}' {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.closeBrace)
		} else if ch == '[' {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.openBracket)
		} else if ch == ']' {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.closeBracket)
		} else if ch == '<' {
			s.index += 1
			ch = s.source[s.index]
			if ch == '=' {
				s.index += 1
				finishToken(s, outerFrom, from, indent, TokenType.operator)	
			} else if ch == '<' {
				s.index += 1
				ch = s.source[s.index]
				if ch == '=' {
					s.index += 1
				}
				finishToken(s, outerFrom, from, indent, TokenType.operator)		
			} else {
				finishToken(s, outerFrom, from, indent, TokenType.openAngleBracket)
			}
		} else if ch == '>' {
			s.index += 1
			ch = s.source[s.index]
			if ch == '=' {
				s.index += 1
				finishToken(s, outerFrom, from, indent, TokenType.operator)	
			} else if ch == '>' && s.source[s.index + 1] == '=' {
				s.index += 2
				finishToken(s, outerFrom, from, indent, TokenType.operator)	
			} else if s.angleBracketLevel > 0 {
				finishToken(s, outerFrom, from, indent, TokenType.closeAngleBracket)
			} else {
				if ch == '>' {
					s.index += 1
				}
				finishToken(s, outerFrom, from, indent, TokenType.operator)	
			}
		} else if ch == '#' {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.hash)
		} else if ch == '^' {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.operator)
		} else if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '_' {
			s.index += 1
			ch = s.source[s.index]
			while isIdentifierChar(ch) {
				s.index += 1
				ch = s.source[s.index]
			}
			finishToken(s, outerFrom, from, indent, TokenType.identifier)
		} else if ch == '"' {
			s.index += 1
			ch = s.source[s.index]
			s.evaluatedString.clear()
			while true {
				if ch == '\\' {
					s.evaluatedString.writeChar(readEscapeSequence(s))
				} else if ch == '\n' || ch == '\r' || ch == '\0' {
					s.errors.add(Error.atIndex(s.unit, s.index, "Expected: \""))
					break
				} else if ch == '"' {
					s.index += 1
					break
				} else {
					s.evaluatedString.writeChar(ch)
					s.index += 1
				}
				ch = s.source[s.index]
			}
			finishToken(s, outerFrom, from, indent, TokenType.stringLiteral)
		} else if ch == '\'' {
			s.index += 1
			ch = s.source[s.index]
			chars := 0
			while true {
				if ch == '\\' {
					readEscapeSequence(s)
					chars += 1
				} else if ch == '\n' || ch == '\r' || ch == '\0' {
					s.errors.add(Error.atIndex(s.unit, s.index, "Expected: '"))
					break
				} else if ch == '\'' {
					s.index += 1
					if chars != 1 {
						s.errors.add(Error.at(s.unit, IntRange(from, s.index), "Invalid character literal"))
					}
					break
				} else {
					s.index += 1
					chars += 1
				}
				ch = s.source[s.index]
			}
			finishToken(s, outerFrom, from, indent, TokenType.characterLiteral)
		} else if ch == '-' || ch == '.' || (ch >= '0' && ch <= '9') {
			prevCh := ch
			s.index += 1
			ch = s.source[s.index]
			if prevCh == '0' && ch == 'x' {
				s.index += 1
				finishHexNumber(s, outerFrom, from, indent)
			} else if prevCh == '.' {
				if !isDigit(ch) {
					finishToken(s, outerFrom, from, indent, TokenType.operator)
				} else {
					s.index -= 1
					finishFloatNumber(s, outerFrom, from, indent)
				}
			} else if prevCh == '-' {
				if !isDigit(ch) {
					if ch == '=' {
						s.index += 1
					}
					finishToken(s, outerFrom, from, indent, TokenType.operator)
				} else {
					finishNumber(s, outerFrom, from, indent)
				}
			} else {
				finishNumber(s, outerFrom, from, indent)
			}			
		} else if ch == '=' {
			s.index += 1
			ch = s.source[s.index]
			if ch == '=' {
				s.index += 1
			}
			finishToken(s, outerFrom, from, indent, TokenType.operator)
		} else if ch == '~' || ch == '$' || ch == '?' {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.operator)
		} else if ch == '*' || ch == '/' || ch == '%' || ch == '+' || ch == '!' {			
			s.index += 1
			ch = s.source[s.index]
			if ch == '=' {
				s.index += 1
			}
			finishToken(s, outerFrom, from, indent, TokenType.operator)
		} else if ch == '&' {
			s.index += 1
			ch = s.source[s.index]
			if ch == '&' {
				s.index += 1
				ch = s.source[s.index]
			}
			if ch == '=' {
				s.index += 1
			}
			finishToken(s, outerFrom, from, indent, TokenType.operator)
		} else if ch == '|' {
			s.index += 1
			ch = s.source[s.index]
			if ch == '|' {
				s.index += 1
				ch = s.source[s.index]
			}
			if ch == '=' {
				s.index += 1
			}
			finishToken(s, outerFrom, from, indent, TokenType.operator)
		} else {
			s.index += 1
			finishToken(s, outerFrom, from, indent, TokenType.invalid)
		}
	}
	
	mixingTabsSpaces(s ParserState) {
		s.errors.add(Error.at(s.unit, IntRange(s.lineStart, s.index),
			"Mixing tabs and spaces is not allowed; to fix, add //tab_size=N at the top of the source file"))
	}
	
	finishToken(s ParserState, outerFrom int, from int, indent int, type TokenType) {
		to := s.index
		ch := s.source[s.index]
		while ch == ' ' || ch == '\t' || ch == '\r' {
			s.index += 1
			ch = s.source[s.index]
		}
		if ch == '\n' {
			s.index += 1
			s.lineStart = s.index
		}
		s.prevTokenTo = s.token.span.to
		s.token = new Token {
			type: type, 
			value: s.source.slice(from, to),
			indent: indent,
			span: IntRange(from, to),
			outerSpan: IntRange(outerFrom, s.index)
		}
	}
	
	readEscapeSequence(s ParserState) {
		from := s.index
		s.index += 1
		ch := s.source[s.index]
		if ch == '0' {
			s.index += 1
			return '\0'
		} else if ch == 't' {
			s.index += 1
			return '\t'
		} else if ch == 'r' {
			s.index += 1
			return '\r'
		} else if ch == 'n' {
			s.index += 1
			return '\n'
		} else if ch == '\\' {
			s.index += 1
			return '\\'
		} else if ch == '\'' {
			s.index += 1
			return '\''
		} else if ch == '"' {
			s.index += 1
			return '"'
		} else if ch == 'x' {
			s.index += 1
			ch = s.source[s.index]
			chars := 0
			while chars < 2 && isHexDigit(ch) {
				s.index += 1
				chars += 1
				ch = s.source[s.index]
			}
			if chars == 2 {
				return transmute(long.tryParseHex(s.source.slice(s.index - 2, s.index)).unwrap(), char)
			} else {
				s.errors.add(Error.at(s.unit, IntRange(from, s.index), "Invalid escape sequence"))
				return '\\'
			}			
		} else {
			to := s.index
			if ch != '\n' && ch != '\r' && ch != '\0' {
				to += 1
			}
			s.errors.add(Error.at(s.unit, IntRange(from, to), "Invalid escape sequence"))
			return '\\'
		}
	}
	
	finishHexNumber(s ParserState, outerFrom int, from int, indent int) {
		valueFrom := s.index
		ch := s.source[s.index]
		digits := 0
		while isHexDigit(ch) {
			s.index += 1
			ch = s.source[s.index]
			digits += 1
		}
		s.numberValueSpan = IntRange(valueFrom, s.index)
		s.numberFlags = NumberFlags.intval | NumberFlags.hex
		readNumberSuffix(s)
		if digits == 0 {
			s.errors.add(Error.at(s.unit, IntRange(from, s.index), "Invalid hexadecimal number literal"))
			s.numberFlags |= NumberFlags.invalid
		}
		finishToken(s, outerFrom, from, indent, TokenType.numberLiteral)
	}
	
	finishNumber(s ParserState, outerFrom int, from int, indent int) {
		ch := s.source[s.index]
		while isDigit(ch) {
			s.index += 1
			ch = s.source[s.index]
		}
		if ch == '.' || ch == 'e' || ch == 'E' {
			s.index = from
			finishFloatNumber(s, outerFrom, from, indent)
			return
		}
		s.numberValueSpan = IntRange(from, s.index)
		s.numberFlags = NumberFlags.intval
		readNumberSuffix(s)
		finishToken(s, outerFrom, from, indent, TokenType.numberLiteral)
	}
	
	finishFloatNumber(s ParserState, outerFrom int, from int, indent int) {
		beforeDot := 0
		hasDot := false
		afterDot := 0
		hasExp := false
		afterExp := 0
		ch := s.source[s.index]
		if ch == '-' {
			s.index += 1
			ch = s.source[s.index]
		}
		while isDigit(ch) {
			s.index += 1
			ch = s.source[s.index]
			beforeDot += 1
		}
		if ch == '.' {
			hasDot = true
			s.index += 1
			ch = s.source[s.index]
			while isDigit(ch) {
				s.index += 1
				ch = s.source[s.index]
				afterDot += 1
			}
		}
		if ch == 'e' || ch == 'E' {
			hasExp = true
			s.index += 1
			ch = s.source[s.index]			
			if ch == '-' {
				s.index += 1
				ch = s.source[s.index]
			} else if ch == '+' {
				s.index += 1
				ch = s.source[s.index]
			}
			while isDigit(ch) {
				s.index += 1
				ch = s.source[s.index]
				afterExp += 1
			}
		}
		s.numberValueSpan = IntRange(from, s.index)
		s.numberFlags = NumberFlags.floatval
		readNumberSuffix(s)
		if (beforeDot + afterDot) == 0 || (hasDot && afterDot == 0) || (hasExp && afterExp == 0) {
			s.errors.add(Error.at(s.unit, IntRange(from, s.index), "Invalid floating point number literal"))
			s.numberFlags |= NumberFlags.invalid
		}
		finishToken(s, outerFrom, from, indent, TokenType.numberLiteral)
	}

	readNumberSuffix(s ParserState) {
		ch := s.source[s.index]
		if ch != '_' {
			return
		}
		s.index += 1
		ch = s.source[s.index]
		while isIdentifierChar(ch) {
			s.index += 1
			ch = s.source[s.index]
		}		
	}
	
	isIdentifierStartChar(ch char) {
		return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '_'
	}

	isIdentifierChar(ch char) {
		return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_'
	}

	isDigit(ch char) {
		return ch >= '0' && ch <= '9'
	}

	isHexDigit(ch char) {
		return (ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f') || (ch >= '0' && ch <= '9')
	}		
	
	isAssignOp(op string) {
		return op == "=" || (op.length == 2 && op[1] == '=' && op[0] != '=' && op[0] != '!') || (op.length == 3 && op[2] == '=')
	}
}