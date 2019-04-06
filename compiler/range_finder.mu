RangeFinderState struct #RefType {
	from int
	to int	
}

RangeFinder {
	find(a Node) {
		s := new RangeFinderState { from: int.maxValue, to: int.minValue }
		checkAny(s, a)
		assert(s.from <= s.to)
		return IntRange(s.from, s.to)
	}
	
	checkAny(s RangeFinderState, a Node) {
		match a {
			CodeUnit: checkCodeUnit(s, a)
			NamespaceDef: checkNamespaceDef(s, a)
			TypeParams: checkTypeParams(s, a)
			Attribute: checkAttribute(s, a)
			FunctionDef: checkFunctionDef(s, a)
			Param: checkParam(s, a)
			FieldDef: checkFieldDef(s, a)
			StaticFieldDef: checkStaticFieldDef(s, a)
			TaggedPointerOptionDef: checkTaggedPointerOptionDef(s, a)
			TypeModifierExpression: checkTypeModifierExpression(s, a)
			TypeArgsExpression: checkTypeArgsExpression(s, a)
			BlockStatement: checkBlockStatement(s, a)
			ExpressionStatement: checkExpressionStatement(s, a)
			ReturnStatement: checkReturnStatement(s, a)
			BreakStatement: checkBreakStatement(s, a)
			ContinueStatement: checkContinueStatement(s, a)
			IfStatement: checkIfStatement(s, a)
			WhileStatement: checkWhileStatement(s, a)
			ForEachStatement: checkForEachStatement(s, a)
			ForIndexStatement: checkForIndexStatement(s, a)
			MatchStatement: checkMatchStatement(s, a)
			MatchCase: checkMatchCase(s, a)
			UnaryOperatorExpression: checkUnaryOperatorExpression(s, a)
			PostfixUnaryOperatorExpression: checkPostfixUnaryOperatorExpression(s, a)
			DotExpression: checkDotExpression(s, a)
			BinaryOperatorExpression: checkBinaryOperatorExpression(s, a)
			TernaryOperatorExpression: checkTernaryOperatorExpression(s, a)
			CallExpression: checkCallExpression(s, a)
			StructInitializerExpression: checkStructInitializerExpression(s, a)
			FieldInitializerExpression: checkFieldInitializerExpression(s, a)
			IndexExpression: checkIndexExpression(s, a)
			ParenExpression: checkParenExpression(s, a)
			NumberExpression: checkNumberExpression(s, a)
			StringExpression: checkStringExpression(s, a)
			Token: checkToken(s, a)
		}
	}
	
	checkCodeUnit(s RangeFinderState, a CodeUnit) {
		for a.contents {
			checkAny(s, it)
		}
	}
	
	checkNamespaceDef(s RangeFinderState, a NamespaceDef) {
		checkToken(s, a.name)
		if a.typeParams != null {
			checkTypeParams(s, a.typeParams)
		}
		if a.attributes != null {
			checkAttributes(s, a.attributes)
		}
		if a.badTokens != null {
			for a.badTokens {
				checkToken(s, it)
			}
		}
		checkToken(s, a.openBrace)
		for a.contents {
			checkAny(s, it)
		}			
		checkToken(s, a.closeBrace)
	}
	
	checkTypeParams(s RangeFinderState, a TypeParams) {
		checkToken(s, a.openAngleBracket)
		for a.contents {
			checkToken(s, it)
		}
		checkToken(s, a.closeAngleBracket)
	}
	
	checkAttributes(s RangeFinderState, a List<Attribute>) {
		for a {
			checkAttribute(s, it)
		}
	}
	
	checkAttribute(s RangeFinderState, a Attribute) {
		checkToken(s, a.hash)
		checkToken(s, a.name)
		checkToken(s, a.openParen)
		if a.contents != null {
			for a.contents {
				checkAny(s, it)
			}
		}
		checkToken(s, a.closeParen)
	}
	
	checkFunctionDef(s RangeFinderState, a FunctionDef) {
		checkToken(s, a.name)
		if a.typeParams != null {
			checkTypeParams(s, a.typeParams)
		}
		checkToken(s, a.openParen)
		for a.paramContents {
			checkAny(s, it)
		}
		checkToken(s, a.closeParen)
		if a.returnType != null {
			checkAny(s, a.returnType)
		}
		if a.attributes != null {
			checkAttributes(s, a.attributes)
		}		
		if a.badTokens != null {
			for a.badTokens {
				checkToken(s, it)
			}
		}
		if a.body != null {
			checkBlockStatement(s, a.body)
		}
	}
	
	checkParam(s RangeFinderState, a Param) {
		checkToken(s, a.name)
		if a.type != null {
			checkAny(s, a.type)
		}
	}
	
	checkFieldDef(s RangeFinderState, a FieldDef) {
		checkToken(s, a.name)
		if a.type != null {
			checkAny(s, a.type)
		}
	}
	
	checkStaticFieldDef(s RangeFinderState, a StaticFieldDef) {
		checkToken(s, a.colon)
		checkToken(s, a.name)
		if a.type != null {
			checkAny(s, a.type)
		}
		if a.attributes != null {
			checkAttributes(s, a.attributes)
		}		
		checkToken(s, a.assign)
		if a.initializeExpr != null {
			checkAny(s, a.initializeExpr)
		}
	}
	
	checkTaggedPointerOptionDef(s RangeFinderState, a TaggedPointerOptionDef) {
		checkAny(s, a.type)
	}
	
	checkTypeModifierExpression(s RangeFinderState, a TypeModifierExpression) {
		checkToken(s, a.modifier)
		if a.arg != null {
			checkAny(s, a.arg)
		}
	}
	
	checkTypeArgsExpression(s RangeFinderState, a TypeArgsExpression) {
		checkAny(s, a.target)
		checkToken(s, a.openAngleBracket)
		for a.contents {
			checkAny(s, it)
		}
		checkToken(s, a.closeAngleBracket)
	}
	
	checkBlockStatement(s RangeFinderState, a BlockStatement) {
		checkToken(s, a.openBrace)
		for a.contents {
			checkAny(s, it)
		}
		checkToken(s, a.closeBrace)
	}
	
	checkExpressionStatement(s RangeFinderState, a ExpressionStatement) {
		checkAny(s, a.expr)
	}
	
	checkReturnStatement(s RangeFinderState, a ReturnStatement) {
		checkToken(s, a.keyword)
		if a.expr != null {
			checkAny(s, a.expr)
		}
	}
	
	checkBreakStatement(s RangeFinderState, a BreakStatement) {
		checkToken(s, a.keyword)
	}
	
	checkContinueStatement(s RangeFinderState, a ContinueStatement) {
		checkToken(s, a.keyword)
	}
	
	checkIfStatement(s RangeFinderState, a IfStatement) {
		checkToken(s, a.ifKeyword)
		if a.conditionExpr != null {
			checkAny(s, a.conditionExpr)
		}
		if a.badTokens != null {
			for a.badTokens {
				checkToken(s, it)
			}
		}
		if a.ifBranch != null {
			checkBlockStatement(s, a.ifBranch)
		}
		checkToken(s, a.elseKeyword)
		if a.elseBranch != null {
			checkAny(s, a.elseBranch)
		}
	}
	
	checkWhileStatement(s RangeFinderState, a WhileStatement) {
		checkToken(s, a.keyword)
		if a.conditionExpr != null {
			checkAny(s, a.conditionExpr)
		}
		if a.badTokens != null {
			for a.badTokens {
				checkToken(s, it)
			}
		}
		if a.body != null {
			checkBlockStatement(s, a.body)
		}
	}
	
	checkForEachStatement(s RangeFinderState, a ForEachStatement) {
		checkToken(s, a.keyword)
		checkToken(s, a.iteratorVariable)
		checkToken(s, a.comma)
		checkToken(s, a.indexIteratorVariable)
		checkToken(s, a.inKeyword)
		if a.sequenceExpr != null {
			checkAny(s, a.sequenceExpr)
		}
		if a.badTokens != null {
			for a.badTokens {
				checkToken(s, it)
			}
		}
		if a.body != null {
			checkBlockStatement(s, a.body)
		}
	}
	
	checkForIndexStatement(s RangeFinderState, a ForIndexStatement) {
		checkToken(s, a.keyword)
		if a.initializeStatement != null {
			checkExpressionStatement(s, a.initializeStatement)
		}
		checkToken(s, a.firstSemicolon)
		if a.conditionExpr != null {
			checkAny(s, a.conditionExpr)
		}
		checkToken(s, a.secondSemicolon)
		if a.nextStatement != null {
			checkAny(s, a.nextStatement)
		}
		if a.badTokens != null {
			for a.badTokens {
				checkToken(s, it)
			}
		}
		if a.body != null {
			checkBlockStatement(s, a.body)
		}
	}
	
	checkMatchStatement(s RangeFinderState, a MatchStatement) {
		checkToken(s, a.keyword)
		if a.expr != null {
			checkAny(s, a.expr)
		}
		if a.badTokens != null {
			for a.badTokens {
				checkToken(s, it)
			}
		}
		checkToken(s, a.openBrace)
		for a.contents {
			checkAny(s, it)
		}
		checkToken(s, a.closeBrace)
	}
	
	checkMatchCase(s RangeFinderState, a MatchCase) {
		checkAny(s, a.type)
		checkToken(s, a.or)
		checkToken(s, a.secondType)
		checkToken(s, a.colon)
		if a.statement != null {
			checkAny(s, a.statement)
		}
	}
	
	checkUnaryOperatorExpression(s RangeFinderState, a UnaryOperatorExpression) {
		checkToken(s, a.op)
		if a.expr != null {
			checkAny(s, a.expr)
		}
	}
	
	checkPostfixUnaryOperatorExpression(s RangeFinderState, a PostfixUnaryOperatorExpression) {
		if a.expr != null {
			checkAny(s, a.expr)
		}
		checkToken(s, a.op)
	}
	
	checkDotExpression(s RangeFinderState, a DotExpression) {
		checkAny(s, a.lhs)
		checkToken(s, a.dot)
		checkToken(s, a.rhs)
	}
	
	checkBinaryOperatorExpression(s RangeFinderState, a BinaryOperatorExpression) {
		checkAny(s, a.lhs)
		checkToken(s, a.op)
		if a.rhs != null {
			checkAny(s, a.rhs)
		}
	}
	
	checkTernaryOperatorExpression(s RangeFinderState, a TernaryOperatorExpression) {
		checkAny(s, a.conditionExpr)
		checkToken(s, a.question)
		if a.trueExpr != null {
			checkAny(s, a.trueExpr)
		}
		checkToken(s, a.colon)
		if a.falseExpr != null {
			checkAny(s, a.falseExpr)
		}
	}
	
	checkCallExpression(s RangeFinderState, a CallExpression) {
		checkAny(s, a.target)
		checkToken(s, a.openParen)
		for a.contents {
			checkAny(s, it)
		}
		checkToken(s, a.closeParen)
	}
	
	checkStructInitializerExpression(s RangeFinderState, a StructInitializerExpression) {
		checkAny(s, a.target)
		checkToken(s, a.openBrace)
		for a.contents {
			checkAny(s, it)
		}
		checkToken(s, a.closeBrace)
	}
	
	checkFieldInitializerExpression(s RangeFinderState, a FieldInitializerExpression) {
		checkToken(s, a.fieldName)
		checkToken(s, a.colon)
		if a.expr != null {
			checkAny(s, a.expr)
		}
	}
	
	checkIndexExpression(s RangeFinderState, a IndexExpression) {
		checkAny(s, a.target)
		checkToken(s, a.openBracket)
		if a.arg != null {
			checkAny(s, a.arg)
		}
		checkToken(s, a.closeBracket)
	}
	
	checkParenExpression(s RangeFinderState, a ParenExpression) {
		checkToken(s, a.openParen)
		if a.expr != null {
			checkAny(s, a.expr)
		}
		checkToken(s, a.closeParen)
	}
	
	checkNumberExpression(s RangeFinderState, a NumberExpression) {
		checkToken(s, a.token)
	}
	
	checkStringExpression(s RangeFinderState, a StringExpression) {
		checkToken(s, a.token)
	}

	checkToken(s RangeFinderState, token Token) {
		if token == null {
			return
		}
		s.from = min(s.from, token.span.from)
		s.to = max(s.to, token.span.to)
	}
}

