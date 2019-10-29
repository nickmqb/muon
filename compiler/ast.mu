Node tagged_pointer {
	CodeUnit
	NamespaceDef
	TypeParams	
	Attribute
	FunctionDef
	Param
	FieldDef
	StaticFieldDef
	TaggedPointerOptionDef
	TypeModifierExpression
	TypeArgsExpression
	BlockStatement
	ExpressionStatement
	ReturnStatement
	BreakStatement
	ContinueStatement
	IfStatement
	WhileStatement
	ForEachStatement
	ForIndexStatement
	MatchStatement
	MatchCase
	UnaryOperatorExpression
	PostfixUnaryOperatorExpression
	DotExpression
	BinaryOperatorExpression
	TernaryOperatorExpression
	CallExpression
	StructInitializerExpression
	FieldInitializerExpression
	IndexExpression
	ParenExpression
	NumberExpression
	StringExpression
	Token
	Namespace // TODO: Remove
	
	hash(n Node) {
		return cast(transmute(pointer_cast(n, pointer), usize) >> 3, uint)
	}
}

Error struct {
	unit CodeUnit
	span IntRange
	text string
	
	at(unit CodeUnit, span IntRange, text string) {
		assert(span.from <= span.to)
		return Error { unit: unit, span: span, text: text }
	}

	atIndex(unit CodeUnit, index int, text string) {
		return Error { unit: unit, span: IntRange(index, index), text: text }
	}
}

NodeInfo struct {
	tag Tag
	mem Node
}

CodeUnit struct #RefType {
	path string
	id int
	source string
	contents List<Node>
}

NamespaceDef struct #RefType {
	unit CodeUnit
	name Token
	typeParams TypeParams
	kindToken Token
	attributes List<Attribute>
	badTokens List<Token>
	openBrace Token
	contents List<Node>
	closeBrace Token
	// Non-AST
	kind NamespaceKind
	ns Namespace
}

NamespaceKind enum {
	default_
	struct_
	enum_
	taggedPointerEnum
}

TypeParams struct #RefType {
	openAngleBracket Token
	params List<Token>
	contents List<Token>
	closeAngleBracket Token
}

Attribute struct #RefType {
	hash Token
	name Token
	openParen Token
	args List<Node>
	contents List<Node>
	closeParen Token
}

FunctionDef struct #RefType {
	unit CodeUnit
	name Token
	typeParams TypeParams
	openParen Token
	params List<Param>
	paramContents List<Node>
	closeParen Token
	returnType Node
	attributes List<Attribute>
	badTokens List<Token>
	body BlockStatement
	// Non-AST
	ns Namespace
	flags FunctionFlags
	typeParamList List<Namespace>
	foreignName string
	returnTag Tag
	builtin BuiltinFunction
	tas CustomSet<Array<Tag>>
	outgoingCalls List<Call>
	typeUsages Set<Tag>
	infoMap Map<Node, NodeInfo>
	marshalReturnType string
}

Call struct #RefType {
	from FunctionDef
	to FunctionDef
	ta Array<Tag>
}

FunctionFlags enum #Flags {
	returnsValue
	foreign
	isDeterminingReturnType
	hasFinalReturnType
	requireExplicitReturnType
	marshalReturnType
	varArgs
}

BuiltinFunction enum {
	none
	abandon
	assert
	checked_cast
	cast
	pointer_cast
	transmute
	is
	as
	format
	min
	max
	xor
	sizeof
	compute_hash
	default_value
	unchecked_index
	get_argc_argv
}

Param struct #RefType {
	name Token
	type Node	
	attributes List<Attribute>
	// Non-AST
	tag Tag
	flags ParamFlags
	marshalType string
}

ParamFlags enum #Flags {
	marshalType
}

FieldDef struct #RefType {
	unit CodeUnit
	name Token
	type Node
	// Non-AST
	ns Namespace
	tag Tag
}

StaticFieldDef struct #RefType {
	unit CodeUnit
	colon Token
	name Token
	type Node
	attributes List<Attribute>
	assign Token
	initializeExpr Node
	flags StaticFieldFlags
	// Non-AST
	ns Namespace
	tag Tag
	value uint
	infoMap Map<Node, NodeInfo>
	evaluatedValue EvalResult	
	foreignName string
}

StaticFieldFlags enum #Flags {
	isEnumOption
	autoValue
	foreign
	mutable
	threadLocal
	isChecking
	hasFinalType
	cycle
	evaluated
}

TaggedPointerOptionDef struct #RefType {
	type Node
}

TypeModifierExpression struct #RefType {
	modifier Token
	arg Node
}

TypeArgsExpression struct #RefType {
	target Node
	openAngleBracket Token
	args List<Node>
	contents List<Node>
	closeAngleBracket Token
}

BlockStatement struct #RefType {
	openBrace Token
	contents List<Node>
	closeBrace Token
}

ExpressionStatement struct #RefType {
	expr Node
}

ReturnStatement struct #RefType {
	keyword Token
	expr Node
}

BreakStatement struct #RefType {
	keyword Token
}

ContinueStatement struct #RefType {
	keyword Token
}

IfStatement struct #RefType {
	ifKeyword Token
	conditionExpr Node
	badTokens List<Token>
	ifBranch BlockStatement
	elseKeyword Token
	elseBranch Node // IfStatement | BlockStatement
}

WhileStatement struct #RefType {
	keyword Token
	conditionExpr Node
	badTokens List<Token>
	body BlockStatement
}

ForEachStatement struct #RefType {
	keyword Token
	iteratorVariable Token
	comma Token
	indexIteratorVariable Token
	inKeyword Token
	sequenceExpr Node
	badTokens List<Token>
	body BlockStatement
}

ForIndexStatement struct #RefType {
	keyword Token
	initializeStatement ExpressionStatement
	firstSemicolon Token
	conditionExpr Node
	secondSemicolon Token
	nextStatement Node
	badTokens List<Token>
	body BlockStatement
}

MatchStatement struct #RefType {
	keyword Token
	expr Node
	badTokens List<Token>
	openBrace Token
	cases List<MatchCase>
	contents List<Node>
	closeBrace Token
}

MatchCase struct #RefType {
	type Node
	or Token
	secondType Token
	colon Token
	statement Node
	// Non-AST
	flags MatchCaseFlags
	tag Tag
}

MatchCaseFlags enum #Flags {
	null_
	default_
}

UnaryOperatorExpression struct #RefType {
	op Token
	expr Node
}

PostfixUnaryOperatorExpression struct #RefType {
	expr Node
	op Token
}

DotExpression struct #RefType {
	dot Token
	lhs Node
	rhs Token
}

BinaryOperatorExpression struct #RefType {
	op Token
	lhs Node
	rhs Node
}

TernaryOperatorExpression struct #RefType {
	conditionExpr Node
	question Token
	trueExpr Node
	colon Token
	falseExpr Node
}

CallExpression struct #RefType {
	target Node
	openParen Token
	args List<Node>
	contents List<Node>
	closeParen Token
	// Non-AST
	ta Array<Tag>
}

StructInitializerExpression struct #RefType {
	target Node
	openBrace Token
	args List<FieldInitializerExpression>
	contents List<Node>
	closeBrace Token
}

FieldInitializerExpression struct #RefType {
	fieldName Token
	colon Token
	expr Node
}

IndexExpression struct #RefType {
	target Node
	openBracket Token
	arg Node
	closeBracket Token
}

ParenExpression struct #RefType {
	openParen Token
	expr Node
	closeParen Token
}

NumberExpression struct #RefType {
	token Token
	valueSpan IntRange
	flags NumberFlags	
	tag Tag
	opaqueValue ulong
}

StringExpression struct #RefType {
	token Token
	evaluatedString string
	id int
}

Token struct #RefType {
	type TokenType
	value string
	span IntRange
	outerSpan IntRange
	indent int
}

IntRange struct {
	from int
	to int
	
	cons(from int, to int) {
		return IntRange { from: from, to: to }
	}
}	

TokenType enum {
	identifier
	numberLiteral
	stringLiteral
	characterLiteral
	operator
	openParen
	closeParen
	openBrace
	closeBrace
	openBracket
	closeBracket
	openAngleBracket
	closeAngleBracket
	comma
	semicolon
	colon
	hash
	end
	invalid
}

NumberFlags enum #Flags {
	intval = 1
	floatval = 2
	hex = 4
	invalid = 8
}
