:CXChildVisit_Break int #Foreign("CXChildVisit_Break")
:CXChildVisit_Continue int #Foreign("CXChildVisit_Continue")
:CXChildVisit_Recurse int #Foreign("CXChildVisit_Recurse")
:CXCursor_FunctionDecl int #Foreign("CXCursor_FunctionDecl")
:CXCursor_EnumDecl int #Foreign("CXCursor_EnumDecl")
:CXCursor_CXXMethod int #Foreign("CXCursor_CXXMethod")
:CXCursor_FieldDecl int #Foreign("CXCursor_FieldDecl")
:CXCursor_ParmDecl int #Foreign("CXCursor_ParmDecl")
:CXCursor_TypedefDecl int #Foreign("CXCursor_TypedefDecl")
:CXCursor_StructDecl int #Foreign("CXCursor_StructDecl")
:CXCursor_UnionDecl int #Foreign("CXCursor_UnionDecl")
:CXCursor_VarDecl int #Foreign("CXCursor_VarDecl")
:CXCursor_MacroDefinition int #Foreign("CXCursor_MacroDefinition")
:CXCursor_InclusionDirective int #Foreign("CXCursor_InclusionDirective")
:CXCursor_Namespace int #Foreign("CXCursor_Namespace")
:CXCursor_TranslationUnit int #Foreign("CXCursor_TranslationUnit")
:CXCursor_EnumConstantDecl int #Foreign("CXCursor_EnumConstantDecl")
:CXCursor_UnexposedDecl int #Foreign("CXCursor_UnexposedDecl")
:CXTranslationUnit_DetailedPreprocessingRecord uint #Foreign("CXTranslationUnit_DetailedPreprocessingRecord")

:CXType_Void int #Foreign("CXType_Void")
:CXType_Short int #Foreign("CXType_Short")
:CXType_UShort int #Foreign("CXType_UShort")
:CXType_Int int #Foreign("CXType_Int")
:CXType_UInt int #Foreign("CXType_UInt")
:CXType_Long int #Foreign("CXType_Long")
:CXType_ULong int #Foreign("CXType_ULong")
:CXType_LongLong int #Foreign("CXType_LongLong")
:CXType_ULongLong int #Foreign("CXType_ULongLong")
:CXType_Char_S int #Foreign("CXType_Char_S")
:CXType_Char_U int #Foreign("CXType_Char_U")
:CXType_UChar int #Foreign("CXType_UChar")
:CXType_SChar int #Foreign("CXType_SChar")
:CXType_Float int #Foreign("CXType_Float")
:CXType_Double int #Foreign("CXType_Double")
:CXType_LongDouble int #Foreign("CXType_LongDouble")
:CXType_Typedef int #Foreign("CXType_Typedef")
:CXType_Pointer int #Foreign("CXType_Pointer")
:CXType_Record int #Foreign("CXType_Record")
:CXType_Enum int #Foreign("CXType_Enum")
:CXType_FunctionProto int #Foreign("CXType_FunctionProto")
:CXType_FunctionNoProto int #Foreign("CXType_FunctionNoProto")
:CXType_ConstantArray int #Foreign("CXType_ConstantArray")
:CXType_IncompleteArray int #Foreign("CXType_IncompleteArray")

:CXToken_Punctuation int #Foreign("CXToken_Punctuation")
:CXToken_Keyword int #Foreign("CXToken_Keyword")
:CXToken_Identifier int #Foreign("CXToken_Identifier")
:CXToken_Literal int #Foreign("CXToken_Literal")
:CXToken_Comment int #Foreign("CXToken_Comment")

:CXEval_Int int #Foreign("CXEval_Int")
:CXEval_Float int #Foreign("CXEval_Float")
:CXEval_StrLiteral int #Foreign("CXEval_StrLiteral")

CXString struct {
	data pointer
	private_flags uint
}

CXCursor struct {
	kind int
	xdata int
	data0 pointer
	data1 pointer
	data2 pointer
}

CXType struct {
	kind int
	data0 pointer
	data1 pointer
}

CXToken struct {
	int_data0 int
	int_data1 int
	int_data2 int
	int_data3 int
	ptr_data pointer
}

CXSourceLocation struct {
	data0 pointer
	data1 pointer
	int_data uint
}

CXSourceRange struct {
	data0 pointer
	data1 pointer
	begin_int_data uint
	end_int_data uint
}

CXEvalResult struct #RefType {
	unused_ int
}

CXUnsavedFile struct {
	filename cstring
	contents cstring
	length uint // TODO: Will not work on 64-bit unix!
}

clang_createIndex(excludeDeclarationsFromPCH int, displayDiagnostics int) pointer #Foreign("clang_createIndex")
clang_parseTranslationUnit(
	CIdx pointer,
	source_filename cstring,
	command_line_args *cstring #As("const char *const *"),
	num_command_line_args int,
	unsaved_files *CXUnsavedFile #As("struct CXUnsavedFile *"),
	num_unsaved_files uint,
	options uint) pointer #Foreign("clang_parseTranslationUnit")
clang_getTranslationUnitCursor(translationUnit pointer #As("CXTranslationUnit")) CXCursor #As("CXCursor") #Foreign("clang_getTranslationUnitCursor")
clang_visitChildren(parent CXCursor #As("CXCursor"), visitor pointer #As("CXCursorVisitor"), client_data pointer) uint #Foreign("clang_visitChildren")
clang_getCursorKind(cursor CXCursor #As("CXCursor")) int #Foreign("clang_getCursorKind")
clang_getCursorSpelling(cursor CXCursor #As("CXCursor")) CXString #As("CXString") #Foreign("clang_getCursorSpelling")
clang_getCString(string_ CXString #As("CXString")) cstring #Foreign("clang_getCString")
clang_getCursorKindSpelling(Kind int) CXString #As("CXString") #Foreign("clang_getCursorKindSpelling")
clang_getCursorType(C CXCursor #As("CXCursor")) CXType #As("CXType") #Foreign("clang_getCursorType")
clang_getTypeSpelling(CT CXType #As("CXType")) CXString #As("CXString") #Foreign("clang_getTypeSpelling")
clang_getCanonicalType(T CXType #As("CXType")) CXType #As("CXType") #Foreign("clang_getCanonicalType")
clang_getCursorDisplayName(cursor CXCursor #As("CXCursor")) CXString #As("CXString") #Foreign("clang_getCursorDisplayName")
clang_getTypedefDeclUnderlyingType(C CXCursor #As("CXCursor")) CXType #As("CXType") #Foreign("clang_getTypedefDeclUnderlyingType")
clang_getCursorResultType(C CXCursor #As("CXCursor")) CXType #As("CXType") #Foreign("clang_getCursorResultType")
clang_Cursor_getNumArguments(C CXCursor #As("CXCursor")) int #Foreign("clang_Cursor_getNumArguments")
clang_Cursor_getArgument(C CXCursor #As("CXCursor"), i uint) CXCursor #As("CXCursor") #Foreign("clang_Cursor_getArgument")
clang_Type_getNamedType(T CXType #As("CXType")) CXType #As("CXType") #Foreign("clang_Type_getNamedType") // for structs
clang_getPointeeType(T CXType #As("CXType")) CXType #As("CXType") #Foreign("clang_getPointeeType")
clang_getTypedefName(CT CXType #As("CXType")) CXString #As("CXString") #Foreign("clang_getTypedefName")
clang_isConstQualifiedType(T CXType #As("CXType")) uint #Foreign("clang_isConstQualifiedType")
clang_Type_visitFields(T CXType #As("CXType"), visitor pointer #As("CXFieldVisitor"), client_data pointer #As("CXClientData")) uint #Foreign("clang_Type_visitFields")
clang_getCursorLexicalParent(cursor CXCursor #As("CXCursor")) CXCursor #As("CXCursor") #Foreign("clang_getCursorLexicalParent")
clang_getCursorLocation(cursor CXCursor #As("CXCursor")) CXSourceLocation #As("CXSourceLocation") #Foreign("clang_getCursorLocation")
clang_getFileLocation(location CXSourceLocation #As("CXSourceLocation"), file *pointer, line *uint, column *uint, offset *uint) void #Foreign("clang_getFileLocation")
clang_getFileName(SFile pointer #As("CXFile")) CXString #As("CXString") #Foreign("clang_getFileName")
clang_Cursor_Evaluate(C CXCursor #As("CXCursor")) CXEvalResult #Foreign("clang_Cursor_Evaluate")
clang_EvalResult_getKind(E CXEvalResult #As("CXEvalResult")) int #Foreign("clang_EvalResult_getKind")
clang_EvalResult_getAsInt(E CXEvalResult #As("CXEvalResult")) int #Foreign("clang_EvalResult_getAsInt")
clang_Cursor_getOffsetOfField(C CXCursor #As("CXCursor")) long #Foreign("clang_Cursor_getOffsetOfField")
clang_Type_getSizeOf(T CXType #As("CXType")) long #Foreign("clang_Type_getSizeOf")
clang_getTypeDeclaration(T CXType #As("CXType")) CXCursor #As("CXCursor") #Foreign("clang_getTypeDeclaration")
clang_equalCursors(c0 CXCursor #As("CXCursor"), c1 CXCursor #As("CXCursor")) uint #Foreign("clang_equalCursors")
clang_getNumElements(T CXType #As("CXType")) long #Foreign("clang_getNumElements")
clang_getArrayElementType(T CXType #As("CXType")) CXType #As("CXType") #Foreign("clang_getArrayElementType")
clang_getEnumConstantDeclValue(C CXCursor #As("CXCursor")) long #Foreign("clang_getEnumConstantDeclValue")
clang_getNumDiagnostics(Unit pointer #As("CXTranslationUnit")) uint #Foreign("clang_getNumDiagnostics")
clang_getDiagnostic(Unit pointer #As("CXTranslationUnit"), Index uint) pointer #Foreign("clang_getDiagnostic")
clang_getDiagnosticSpelling(diagnostic pointer) CXString #As("CXString") #Foreign("clang_getDiagnosticSpelling")
clang_getCursorExtent(c CXCursor #As("CXCursor")) CXSourceRange #As("CXSourceRange") #Foreign("clang_getCursorExtent")
clang_tokenize(TU pointer #As("CXTranslationUnit"), Range CXSourceRange #As("CXSourceRange"), Tokens **CXToken #As("CXToken **"), NumTokens *uint) void #Foreign("clang_tokenize")
clang_getTokenSpelling(translationUnit pointer #As("CXTranslationUnit"), token CXToken #As("CXToken")) CXString #As("CXString") #Foreign("clang_getTokenSpelling")
clang_getTokenKind(token CXToken #As("CXToken")) int #Foreign("clang_getTokenKind")
clang_Cursor_isMacroFunctionLike(C CXCursor #As("CXCursor")) uint #Foreign("clang_Cursor_isMacroFunctionLike")
clang_EvalResult_isUnsignedInt(E CXEvalResult #As("CXEvalResult")) uint #Foreign("clang_EvalResult_isUnsignedInt")
clang_EvalResult_getAsLongLong(E CXEvalResult #As("CXEvalResult")) long #Foreign("clang_EvalResult_getAsLongLong")
clang_EvalResult_getAsUnsigned(E CXEvalResult #As("CXEvalResult")) ulong #Foreign("clang_EvalResult_getAsUnsigned")
clang_EvalResult_getAsDouble(E CXEvalResult #As("CXEvalResult")) double #Foreign("clang_EvalResult_getAsDouble")
clang_EvalResult_getAsStr(E CXEvalResult #As("CXEvalResult")) cstring #As("const char*") #Foreign("clang_EvalResult_getAsStr")
clang_getDiagnosticLocation(diagnostic pointer) CXSourceLocation #As("CXSourceLocation") #Foreign("clang_getDiagnosticLocation")
clang_Cursor_isAnonymousRecordDecl(C CXCursor #As("CXCursor")) uint #Foreign("clang_Cursor_isAnonymousRecordDecl")
clang_Cursor_isAnonymous(C CXCursor #As("CXCursor")) uint #Foreign("clang_Cursor_isAnonymous")
clang_Cursor_isBitField(C CXCursor #As("CXCursor")) uint #Foreign("clang_Cursor_isBitField")
clang_Cursor_isVariadic(C CXCursor #As("CXCursor")) uint #Foreign("clang_Cursor_isVariadic")
