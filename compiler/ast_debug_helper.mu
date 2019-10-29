AstDebugHelper {
	nodeToString(a Node) {
		match a {
			CodeUnit: return "CodeUnit"
			NamespaceDef: return format("NamespaceDef: {}", a.name.value)
			TypeParams: return "TypeParams"
			Attribute: return format("Attribute: {}", a.name.value)
			FunctionDef: return format("FunctionDef: {}", a.name.value)
			Param: return format("Param: {}", a.name.value)
			FieldDef: return format("FieldDef: {}", a.name.value)
			StaticFieldDef: return format("StaticFieldDef: {}", a.name.value)
			TaggedPointerOptionDef: return "TaggedPointerOptionDef"
			TypeModifierExpression: return "TypeModifierExpression"
			TypeArgsExpression: return "TypeArgsExpression"
			BlockStatement: return "BlockStatement"
			ExpressionStatement: return "ExpressionStatement"
			ReturnStatement: return "ReturnStatement"
			BreakStatement: return "BreakStatement"
			ContinueStatement: return "ContinueStatement"
			IfStatement: return "IfStatement"
			WhileStatement: return "WhileStatement"
			ForEachStatement: return "ForEachStatement"
			ForIndexStatement: return "ForIndexStatement"
			MatchStatement: return "MatchStatement"
			MatchCase: return "MatchCase"
			UnaryOperatorExpression: return "UnaryOperatorExpression"
			PostfixUnaryOperatorExpression: return "PostfixUnaryOperatorExpression"
			DotExpression: return "DotExpression"
			BinaryOperatorExpression: return "BinaryOperatorExpression"
			TernaryOperatorExpression: return "TernaryOperatorExpression"
			CallExpression: return "CallExpression"
			StructInitializerExpression: return "StructInitializerExpression"
			FieldInitializerExpression: return "FieldInitializerExpression"
			IndexExpression: return "IndexExpression"
			ParenExpression: return "ParenExpression"
			NumberExpression: return "NumberExpression"
			StringExpression: return "StringExpression"
			Token: return a.value
			null: return "(null)"
		}
	}
}
