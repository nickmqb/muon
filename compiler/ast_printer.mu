PrintState struct #RefType {
	indent int
}

AstPrinter {
	printAny(s PrintState, a Node) {
		match a {
			CodeUnit: printCodeUnit(s, a)
			NamespaceDef: printNamespaceDef(s, a)
			TypeParams: printTypeParams(s, a)
			Attribute: printAttribute(s, a)
			FunctionDef: printFunctionDef(s, a)
			FieldDef: printFieldDef(s, a)
			StaticFieldDef: printStaticFieldDef(s, a)
			TaggedPointerOptionDef: printTaggedPointerOptionDef(s, a)
			TypeModifierExpression: printTypeModifierExpression(s, a)
			TypeArgsExpression: printTypeArgsExpression(s, a)
			BlockStatement: printBlockStatement(s, a)
			ExpressionStatement: printExpressionStatement(s, a)
			ReturnStatement: printReturnStatement(s, a)
			BreakStatement: printBreakStatement(s, a)
			ContinueStatement: printContinueStatement(s, a)
			IfStatement: printIfStatement(s, a)
			WhileStatement: printWhileStatement(s, a)
			ForEachStatement: printForEachStatement(s, a)
			ForIndexStatement: printForIndexStatement(s, a)
			MatchStatement: printMatchStatement(s, a)
			MatchCase: printMatchCase(s, a)
			UnaryOperatorExpression: printUnaryOperatorExpression(s, a)
			PostfixUnaryOperatorExpression: printPostfixUnaryOperatorExpression(s, a)
			DotExpression: printDotExpression(s, a)
			BinaryOperatorExpression: printBinaryOperatorExpression(s, a)
			TernaryOperatorExpression: printTernaryOperatorExpression(s, a)
			CallExpression: printCallExpression(s, a)
			StructInitializerExpression: printStructInitializerExpression(s, a)
			IndexExpression: printIndexExpression(s, a)
			ParenExpression: printParenExpression(s, a)
			NumberExpression: printNumberExpression(s, a)
			StringExpression: printStringExpression(s, a)
			Token: printToken(s, a)
			null: printLine(s, "(null)")
		}
	}
	
	printCodeUnit(s PrintState, a CodeUnit) {
		for a.contents {
			printAny(s, it)
		}
	}
	
	printNamespaceDef(s PrintState, a NamespaceDef) {
		printLine(s, format("NamespaceDef: {} {}", a.name.value, a.kindToken != null ? a.kindToken.value : ""))		
		indent(s)
		printTypeParams(s, a.typeParams)
		printAttributes(s, a.attributes)
		printDescAnyList(s, "contents", a.contents)
		unIndent(s)
	}
	
	printTypeParams(s PrintState, a TypeParams) {
		if a == null {
			return
		}
		printDescTokenList(s, "typeParams", a.params)
	}
	
	printAttribute(s PrintState, a Attribute) {
		printDescToken(s, "Attribute", a.name)
		indent(s)
		printDescAnyList(s, "contents", a.contents)
		unIndent(s)
	}
	
	printAttributes(s PrintState, list List<Attribute>) {
		if list == null {
			return
		}
		printLine(s, "attributes:")
		for list {
			printAny(s, it)
		}
	}
	
	printFunctionDef(s PrintState, a FunctionDef) {
		printDescToken(s, "FunctionDef", a.name)
		indent(s)
		if a.typeParams != null {
			printDescTokenList(s, "typeParams", a.typeParams.params)
		}
		printLine(s, "params:")
		for p in a.params {
			printToken(s, p.name)
			indent(s)
			printAny(s, p.type)
			unIndent(s)
		}
		printDescAny(s, "returnType", a.returnType)
		printAttributes(s, a.attributes)
		printDescAny(s, "body", a.body)
		unIndent(s)
	}
	
	printFieldDef(s PrintState, a FieldDef) {
		printDescToken(s, "FieldDef", a.name)
		indent(s)
		printDescAny(s, "type", a.type)
		unIndent(s)
	}
	
	printStaticFieldDef(s PrintState, a StaticFieldDef) {
		printDescToken(s, "StaticFieldDef", a.name)
		indent(s)
		printDescAny(s, "type", a.type)
		printAttributes(s, a.attributes)
		printDescAny(s, "expr", a.initializeExpr)
		unIndent(s)
	}
	
	printTaggedPointerOptionDef(s PrintState, a TaggedPointerOptionDef) {
		printDescAny(s, "TaggedPointerOptionDef", a.type)
	}
	
	printTypeModifierExpression(s PrintState, a TypeModifierExpression) {
		printDescToken(s, "TypeModifier", a.modifier)
		indent(s)
		printDescAny(s, "arg", a.arg)
		unIndent(s)
	}
	
	printTypeArgsExpression(s PrintState, a TypeArgsExpression) {
		printLine(s, "TypeArgs")
		indent(s)
		printDescAny(s, "target", a.target)
		printDescAnyList(s, "args", a.args)
		unIndent(s)
	}
	
	printBlockStatement(s PrintState, a BlockStatement) {
		printDescAnyList(s, "BlockStatement", a.contents)
	}
	
	printExpressionStatement(s PrintState, a ExpressionStatement) {
		printDescAny(s, "ExpressionStatement", a.expr)
	}
	
	printReturnStatement(s PrintState, a ReturnStatement) {
		printDescAny(s, "ReturnStatement", a.expr)
	}
	
	printBreakStatement(s PrintState, a BreakStatement) {
		printLine(s, "BreakStatement")
	}
	
	printContinueStatement(s PrintState, a ContinueStatement) {
		printLine(s, "ContinueStatement")
	}
	
	printIfStatement(s PrintState, a IfStatement) {
		printLine(s, "IfStatement")
		indent(s)
		printDescAny(s, "conditionExpr", a.conditionExpr)
		printDescAny(s, "ifBranch", a.ifBranch)
		printDescAny(s, "elseBranch", a.elseBranch)
		unIndent(s)
	}
	
	printWhileStatement(s PrintState, a WhileStatement) {
		printLine(s, "WhileStatement")
		indent(s)
		printDescAny(s, "conditionExpr", a.conditionExpr)
		printDescAny(s, "body", a.body)
		unIndent(s)
	}
	
	printForEachStatement(s PrintState, a ForEachStatement) {
		printLine(s, "ForEachStatement")
		indent(s)
		printDescAny(s, "iteratorVariable", a.iteratorVariable)
		printDescAny(s, "indexIteratorVariable", a.indexIteratorVariable)
		printDescAny(s, "sequenceExpr", a.sequenceExpr)
		printDescAny(s, "body", a.body)
		unIndent(s)
	}
	
	printForIndexStatement(s PrintState, a ForIndexStatement) {
		printLine(s, "ForIndexStatement")
		indent(s)
		printDescAny(s, "initializeStatement", a.initializeStatement)
		printDescAny(s, "conditionExpr", a.conditionExpr)
		printDescAny(s, "nextStatement", a.nextStatement)
		printDescAny(s, "body", a.body)
		unIndent(s)
	}
	
	printMatchStatement(s PrintState, a MatchStatement) {
		printLine(s, "MatchStatement")
		indent(s)
		printDescAny(s, "expr", a.expr)
		printDescAnyList(s, "contents", a.contents)
		unIndent(s)
	}
	
	printMatchCase(s PrintState, a MatchCase) {
		printLine(s, "MatchCase")
		indent(s)
		printDescAny(s, "type", a.type)
		if a.secondType != null {
			printDescAny(s, "secondType", a.secondType)
		}
		printDescAny(s, "statement", a.statement)
		unIndent(s)
	}
	
	printUnaryOperatorExpression(s PrintState, a UnaryOperatorExpression) {
		printDescToken(s, "UnaryOperatorExpression", a.op)
		indent(s)
		printAny(s, a.expr)
		unIndent(s)
	}
	
	printPostfixUnaryOperatorExpression(s PrintState, a PostfixUnaryOperatorExpression) {
		printDescToken(s, "PostfixUnaryOperatorExpression", a.op)
		indent(s)
		printAny(s, a.expr)
		unIndent(s)
	}
	
	printDotExpression(s PrintState, a DotExpression) {
		printLine(s, "DotExpression")
		indent(s)
		printDescAny(s, "lhs", a.lhs)
		printDescAny(s, "rhs", a.rhs)
		unIndent(s)
	}
	
	printBinaryOperatorExpression(s PrintState, a BinaryOperatorExpression) {
		printDescToken(s, "BinaryOperatorExpression", a.op)
		indent(s)
		printDescAny(s, "lhs", a.lhs)
		printDescAny(s, "rhs", a.rhs)
		unIndent(s)
	}
	
	printTernaryOperatorExpression(s PrintState, a TernaryOperatorExpression) {
		printLine(s, "TernaryOperatorExpression")
		indent(s)
		printDescAny(s, "conditionExpr", a.conditionExpr)
		printDescAny(s, "trueExpr", a.trueExpr)
		printDescAny(s, "falseExpr", a.falseExpr)
		unIndent(s)
	}
	
	printCallExpression(s PrintState, a CallExpression) {
		printLine(s, "CallExpression")
		indent(s)
		printDescAny(s, "target", a.target)
		printDescAnyList(s, "args", a.args)
		unIndent(s)
	}
	
	printStructInitializerExpression(s PrintState, a StructInitializerExpression) {
		printLine(s, "StructInitializerExpression")
		indent(s)
		printDescAny(s, "target", a.target)
		printLine(s, "args")
		indent(s)
		for a.args {
			printDescAny(s, "fieldName", it.fieldName)
			printDescAny(s, "expr", it.expr)			
		}
		unIndent(s)
		unIndent(s)
	}
	
	printIndexExpression(s PrintState, a IndexExpression) {
		printLine(s, "IndexExpression")
		indent(s)
		printDescAny(s, "target", a.target)
		printDescAny(s, "arg", a.arg)
		unIndent(s)
	}
	
	printParenExpression(s PrintState, a ParenExpression) {
		printLine(s, "ParenExpression")
		indent(s)
		printDescAny(s, "expr", a.expr)
		unIndent(s)
	}

	printNumberExpression(s PrintState, a NumberExpression) {
		printDescToken(s, "NumberExpression", a.token)
	}
	
	printStringExpression(s PrintState, a StringExpression) {
		printDescToken(s, "StringExpression", a.token)
	}

	printToken(s PrintState, token Token) {
		printLine(s, token != null ? token.value : "(null)")
	}
	
	printDescToken(s PrintState, desc string, token Token) {
		printLine(s, format("{}: {}", desc, token != null ? token.value : "(null)"))
	}
	
	printDescAny(s PrintState, desc string, node Node) {
		printLine(s, format("{}:", desc))
		indent(s)
		printAny(s, node)
		unIndent(s)
	}
	
	printDescTokenList(s PrintState, desc string, list List<Token>) {
		printLine(s, format("{}:", desc))
		if list == null {
			return
		}
		indent(s)
		for list {
			printToken(s, it)
		}
		unIndent(s)
	}
	
	printDescAnyList(s PrintState, desc string, list List<Node>) {
		printLine(s, format("{}:", desc))
		if list == null {
			return
		}
		indent(s)
		for list {
			printAny(s, it)
		}
		unIndent(s)
	}

	printLine(s PrintState, text string) {
		Stdout.writeLine(format("{}{}", string.repeatChar(' ', s.indent), text))
	}
	
	indent(s PrintState) {
		s.indent += 2
	}
	
	unIndent(s PrintState) {
		s.indent -= 2
	}	
}
