//tab_size=4
PathFinderState struct #RefType {
    targetIndex int
    path List<Node>
    done bool
}

PathFinder {
    find(unit CodeUnit, index int) {
        s := ref PathFinderState { targetIndex: index, path: new List<Node>{} }
        checkCodeUnit(s, unit)
        assert(s.done)
        return s.path
    }

    push(s PathFinderState, a Node) {
        if !s.done {
            s.path.add(a)
        }
    }

    pop(s PathFinderState) {
        if !s.done { 
            s.path.setCountChecked(s.path.count - 1)
        }
    }

	checkAny(s PathFinderState, a Node) {
		match a {
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
	
	checkCodeUnit(s PathFinderState, a CodeUnit) {
		for a.contents {
			checkAny(s, it)
		}
	}
	
	checkNamespaceDef(s PathFinderState, a NamespaceDef) {
        push(s, a)
		checkToken(s, a.name)
		if a.typeParams != null {
			checkTypeParams(s, a.typeParams)
		}
		checkToken(s, a.kindToken)
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
        pop(s)
	}
	
	checkTypeParams(s PathFinderState, a TypeParams) {
        push(s, a)
		checkToken(s, a.openAngleBracket)
		for a.contents {
			checkToken(s, it)
		}
		checkToken(s, a.closeAngleBracket)
        pop(s)
	}
	
	checkAttributes(s PathFinderState, a List<Attribute>) {
        for a {
			checkAttribute(s, it)
		}
	}
	
	checkAttribute(s PathFinderState, a Attribute) {
        push(s, a)
		checkToken(s, a.hash)
		checkToken(s, a.name)
		checkToken(s, a.openParen)
		if a.contents != null {
			for a.contents {
				checkAny(s, it)
			}
		}
		checkToken(s, a.closeParen)
        pop(s)
	}
	
	checkFunctionDef(s PathFinderState, a FunctionDef) {
        push(s, a)
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
        pop(s)
	}
	
	checkParam(s PathFinderState, a Param) {
        push(s, a)
		checkToken(s, a.name)
		if a.type != null {
			checkAny(s, a.type)
		}
		if a.attributes != null {
			checkAttributes(s, a.attributes)
		}
        pop(s)
	}
	
	checkFieldDef(s PathFinderState, a FieldDef) {
        push(s, a)
		checkToken(s, a.name)
		if a.type != null {
			checkAny(s, a.type)
		}
        pop(s)
	}
	
	checkStaticFieldDef(s PathFinderState, a StaticFieldDef) {
        push(s, a)
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
        pop(s)
	}
	
	checkTaggedPointerOptionDef(s PathFinderState, a TaggedPointerOptionDef) {
        push(s, a)
		checkAny(s, a.type)
        pop(s)
	}
	
	checkTypeModifierExpression(s PathFinderState, a TypeModifierExpression) {
        push(s, a)
		checkToken(s, a.modifier)
		if a.arg != null {
			checkAny(s, a.arg)
		}
        pop(s)
	}
	
	checkTypeArgsExpression(s PathFinderState, a TypeArgsExpression) {
        push(s, a)
		checkAny(s, a.target)
		checkToken(s, a.openAngleBracket)
		for a.contents {
			checkAny(s, it)
		}
		checkToken(s, a.closeAngleBracket)
        pop(s)
	}
	
	checkBlockStatement(s PathFinderState, a BlockStatement) {
        push(s, a)
		checkToken(s, a.openBrace)
		for a.contents {
			checkAny(s, it)
		}
		checkToken(s, a.closeBrace)
        pop(s)
	}
	
	checkExpressionStatement(s PathFinderState, a ExpressionStatement) {
        push(s, a)
		checkAny(s, a.expr)
        pop(s)
	}
	
	checkReturnStatement(s PathFinderState, a ReturnStatement) {
        push(s, a)
		checkToken(s, a.keyword)
		if a.expr != null {
			checkAny(s, a.expr)
		}
        pop(s)
	}
	
	checkBreakStatement(s PathFinderState, a BreakStatement) {
        push(s, a)
		checkToken(s, a.keyword)
        pop(s)
	}
	
	checkContinueStatement(s PathFinderState, a ContinueStatement) {
        push(s, a)
		checkToken(s, a.keyword)
        pop(s)
	}
	
	checkIfStatement(s PathFinderState, a IfStatement) {
        push(s, a)
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
        pop(s)
	}
	
	checkWhileStatement(s PathFinderState, a WhileStatement) {
        push(s, a)
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
        pop(s)
	}
	
	checkForEachStatement(s PathFinderState, a ForEachStatement) {
        push(s, a)
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
        pop(s)
	}
	
	checkForIndexStatement(s PathFinderState, a ForIndexStatement) {
        push(s, a)
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
        pop(s)
	}
	
	checkMatchStatement(s PathFinderState, a MatchStatement) {
        push(s, a)
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
        pop(s)
	}
	
	checkMatchCase(s PathFinderState, a MatchCase) {
        push(s, a)
		checkAny(s, a.type)
		checkToken(s, a.or)
		checkToken(s, a.secondType)
		checkToken(s, a.colon)
		if a.statement != null {
			checkAny(s, a.statement)
		}
        pop(s)
	}
	
	checkUnaryOperatorExpression(s PathFinderState, a UnaryOperatorExpression) {
        push(s, a)
		checkToken(s, a.op)
		if a.expr != null {
			checkAny(s, a.expr)
		}
        pop(s)
	}
	
	checkPostfixUnaryOperatorExpression(s PathFinderState, a PostfixUnaryOperatorExpression) {
        push(s, a)
		if a.expr != null {
			checkAny(s, a.expr)
		}
		checkToken(s, a.op)
        pop(s)
	}
	
	checkDotExpression(s PathFinderState, a DotExpression) {
        push(s, a)
		checkAny(s, a.lhs)
		checkToken(s, a.dot)
		checkToken(s, a.rhs)
        pop(s)
	}
	
	checkBinaryOperatorExpression(s PathFinderState, a BinaryOperatorExpression) {
        push(s, a)
		checkAny(s, a.lhs)
		checkToken(s, a.op)
		if a.rhs != null {
			checkAny(s, a.rhs)
		}
        pop(s)
	}
	
	checkTernaryOperatorExpression(s PathFinderState, a TernaryOperatorExpression) {
        push(s, a)
		checkAny(s, a.conditionExpr)
		checkToken(s, a.question)
		if a.trueExpr != null {
			checkAny(s, a.trueExpr)
		}
		checkToken(s, a.colon)
		if a.falseExpr != null {
			checkAny(s, a.falseExpr)
		}
        pop(s)
	}
	
	checkCallExpression(s PathFinderState, a CallExpression) {
        push(s, a)
		checkAny(s, a.target)
		checkToken(s, a.openParen)
		for a.contents {
			checkAny(s, it)
		}
		checkToken(s, a.closeParen)
        pop(s)
	}
	
	checkStructInitializerExpression(s PathFinderState, a StructInitializerExpression) {
        push(s, a)
		checkAny(s, a.target)
		checkToken(s, a.openBrace)
		for a.contents {
			checkAny(s, it)
		}
		checkToken(s, a.closeBrace)
        pop(s)
	}
	
	checkFieldInitializerExpression(s PathFinderState, a FieldInitializerExpression) {
        push(s, a)
		checkToken(s, a.fieldName)
		checkToken(s, a.colon)
		if a.expr != null {
			checkAny(s, a.expr)
		}
        pop(s)
	}
	
	checkIndexExpression(s PathFinderState, a IndexExpression) {
        push(s, a)
		checkAny(s, a.target)
		checkToken(s, a.openBracket)
		if a.arg != null {
			checkAny(s, a.arg)
		}
		checkToken(s, a.closeBracket)
        pop(s)
	}
	
	checkParenExpression(s PathFinderState, a ParenExpression) {
        push(s, a)
		checkToken(s, a.openParen)
		if a.expr != null {
			checkAny(s, a.expr)
		}
		checkToken(s, a.closeParen)
        pop(s)
	}
	
	checkNumberExpression(s PathFinderState, a NumberExpression) {
        push(s, a)
		checkToken(s, a.token)
        pop(s)
	}
	
	checkStringExpression(s PathFinderState, a StringExpression) {
        push(s, a)
		checkToken(s, a.token)
        pop(s)
	}

	checkToken(s PathFinderState, token Token) {
		if token == null {
			return
		}
        if token.outerSpan.from <= s.targetIndex && s.targetIndex <= token.outerSpan.to {
            if s.targetIndex < token.outerSpan.to || (s.targetIndex == token.span.to && token.type == TokenType.identifier) {
                push(s, token)
                s.done = true
            }
        }
	}
}