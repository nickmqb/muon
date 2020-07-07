using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MuonInterpreter {
    public class ParserState {
        public string Source;
        public CodeUnit Unit;
        public int Index;
        public Token Token;
        public int AngleBracketLevel;
        public bool ForeignAttribute;
    }

    public class ParseException : Exception {
        public ParseException(string message) : base(message) {
        }
    }

    public class Parser {
        public static CodeUnit Parse(string filename, string source) {
            var s = new ParserState { Source = source + "\0", Index = 0 };
            var unit = new CodeUnit { Filename = filename, Source = s.Source, Contents = new List<object>() };
            s.Unit = unit;
            ReadToken(s);
            while (s.Token.Type != TokenType.End) {
                if (s.Token.Type == TokenType.Identifier) {
                    var id = s.Token;
                    ReadToken(s);
                    if (s.Token.Type == TokenType.OpenBrace || s.Token.Type == TokenType.Identifier) {
                        unit.Contents.Add(ParseNamespaceTail(s, id));
                    } else if (s.Token.Type == TokenType.OpenParen) {
                        unit.Contents.Add(ParseFunctionTail(s, null, id));
                    } else if (s.Token.Type == TokenType.OpenAngleBracket) {
                        if (IsProbablyANamespace(id.Value)) {
                            unit.Contents.Add(ParseNamespaceTail(s, id));
                        } else {
                            unit.Contents.Add(ParseFunctionTail(s, null, id));
                        }
                    } else {
                        Expected(s, "(, { or <");
                    }
                } else if (s.Token.Type == TokenType.Colon) {
                    unit.Contents.Add(ParseStaticField(s, null));
                } else {
                    Expected(s, "Top-level declaration");
                }
            }
            return unit;
        }

        public static NamespaceDef ParseNamespaceTail(ParserState s, Token name) {
            var ns = new NamespaceDef { Name = name, Unit = s.Unit, Contents = new List<object>() };
            ns.TypeParams = TryParseTypeParams(s);
            if (s.Token.Type == TokenType.Identifier) {
                if (s.Token.Value == "struct") {
                    ns.Kind = NamespaceKind.Struct;
                } else if (s.Token.Value == "enum") {
                    ns.Kind = NamespaceKind.Enum;
                } else if (s.Token.Value == "tagged_pointer") {
                    ns.Kind = NamespaceKind.TaggedPointerEnum;
                } else {
                    Expected(s, "struct, enum, tagged_pointer or {");
                }
                ReadToken(s);
            }
            ns.Attributes = TryParseAttributes(s);
            ParseTokenWithType(s, TokenType.OpenBrace);
            while (s.Token.Type != TokenType.CloseBrace) {
                if (s.Token.Type == TokenType.Identifier) {
                    var id = s.Token;
                    ReadToken(s);
                    if (s.Token.Type == TokenType.OpenParen || s.Token.Type == TokenType.OpenAngleBracket) {
                        ns.Contents.Add(ParseFunctionTail(s, ns, id));
                    } else if (ns.Kind == NamespaceKind.Struct) {
                        ns.Contents.Add(ParseFieldTail(s, id));
                    } else if (ns.Kind == NamespaceKind.Enum) {
                        ns.Contents.Add(ParseEnumMemberTail(s, id, ns));
                    } else if (ns.Kind == NamespaceKind.TaggedPointerEnum) {
                        ns.Contents.Add(ParseTaggedPointerEnumMemberTail(s, id));
                    } else {
                        Error(s, "Invalid namespace member declaration");
                    }
                } else if (s.Token.Type == TokenType.Colon) {
                    ns.Contents.Add(ParseStaticField(s, ns));
                } else {
                    Expected(s, "Namespace member declaration");
                }
            }
            ParseTokenWithType(s, TokenType.CloseBrace);
            return ns;
        }

        public static TypeParams TryParseTypeParams(ParserState s) {
            if (s.Token.Type != TokenType.OpenAngleBracket) {
                return null;
            }
            ReadToken(s);
            var result = new TypeParams { Params = new List<Token>() };
            while (true) {
                result.Params.Add(ParseTokenWithType(s, TokenType.Identifier));
                if (s.Token.Type == TokenType.CloseAngleBracket) {
                    break;
                }
                ParseTokenWithType(s, TokenType.Comma);
            }
            ParseTokenWithType(s, TokenType.CloseAngleBracket);
            return result;
        }

        public static List<Attribute> TryParseAttributes(ParserState s) {
            if (s.Token.Type != TokenType.Hash) {
                return null;
            }
            var result = new List<Attribute>();
            while (s.Token.Type == TokenType.Hash) {
                result.Add(ParseAttribute(s));
            }
            return result;
        }

        public static Attribute ParseAttribute(ParserState s) {
            ParseTokenWithType(s, TokenType.Hash);
            var id = ParseTokenWithType(s, TokenType.Identifier);
            if (id.Value == "Foreign") {
                s.ForeignAttribute = true;
            }
            var result = new Attribute { Name = id, Args = new List<object>() };
            if (s.Token.Type != TokenType.OpenParen) {
                return result;
            }
            ReadToken(s);
            while (s.Token.Type != TokenType.CloseParen) {
                result.Args.Add(ParseExpression(s, 0, true));
                if (s.Token.Type == TokenType.CloseParen) {
                    break;
                }
                ParseTokenWithType(s, TokenType.Comma);
            }
            ParseTokenWithType(s, TokenType.CloseParen);
            return result;
        }

        public static FunctionDef ParseFunctionTail(ParserState s, NamespaceDef parent, Token name) {
            var func = new FunctionDef { Name = name, Unit = s.Unit, Parent = parent, Params = new List<Param>() };
            func.TypeParams = TryParseTypeParams(s);
            ParseTokenWithType(s, TokenType.OpenParen);
            while (s.Token.Type != TokenType.CloseParen) {
                func.Params.Add(ParseParam(s));
                if (s.Token.Type == TokenType.CloseParen) {
                    break;
                }
                ParseTokenWithType(s, TokenType.Comma);
            }
            ParseTokenWithType(s, TokenType.CloseParen);
            if (s.Token.Type == TokenType.Identifier || (s.Token.Type == TokenType.Operator && (s.Token.Value == "*" || s.Token.Value == "$" || s.Token.Value == "::"))) {
                func.ReturnType = ParseType(s);
            }
            s.ForeignAttribute = false;
            func.Attributes = TryParseAttributes(s);
            if (!s.ForeignAttribute) { 
                func.Body = ParseBlockStatement(s);
            }
            return func;
        }

        public static Param ParseParam(ParserState s) {
            var id = ParseTokenWithType(s, TokenType.Identifier);
            var type = ParseType(s);
            TryParseAttributes(s);
            return new Param { Name = id, Type = type };
        }

        public static FieldDef ParseFieldTail(ParserState s, Token name) {
            var type = ParseType(s);
            return new FieldDef { Name = name, Type = type };
        }

        public static StaticFieldDef ParseStaticField(ParserState s, NamespaceDef parent) {
            ParseTokenWithType(s, TokenType.Colon);
            var id = ParseTokenWithType(s, TokenType.Identifier);
            var def = new StaticFieldDef { Name = id, Parent = parent };
            if (s.Token.Type == TokenType.Identifier || (s.Token.Type == TokenType.Operator && (s.Token.Value == "*" || s.Token.Value == "$" || s.Token.Value == "::"))) {
                def.Type = ParseType(s);
            }
            def.Attributes = TryParseAttributes(s);
            if (s.Token.Type == TokenType.Operator && s.Token.Value == "=") {
                ReadToken(s);
                def.InitializerExpr = ParseExpression(s, 0, true);
            }
            return def;
        }

        public static StaticFieldDef ParseEnumMemberTail(ParserState s, Token name, NamespaceDef parent) {
            var def = new StaticFieldDef { Name = name, IsEnumOption = true, Parent = parent };
            if (s.Token.Type == TokenType.Operator && s.Token.Value == "=") {
                ReadToken(s);
                def.InitializerExpr = ParseExpression(s, 0, true);
            }
            return def;
        }

        public static TaggedPointerOptionDef ParseTaggedPointerEnumMemberTail(ParserState s, Token name) {
            var def = new TaggedPointerOptionDef { Name = name };
            if (s.Token.Type == TokenType.Operator && s.Token.Value == "=") {
                ReadToken(s);
                ParseExpression(s, 0, true);
            }
            return def;
        }

        public static object ParseType(ParserState s) {
            object result = null;
            if (s.Token.Type == TokenType.Operator && (s.Token.Value == "*" || s.Token.Value == "$" || s.Token.Value == "::")) {
                var mod = s.Token;
                ReadToken(s);
                result = new TypeModifierExpression { Modifier = mod, Arg = ParseTypeModifiers(s) };
            } else {
                result = ParseTokenWithType(s, TokenType.Identifier);
            }
            if (s.Token.Type == TokenType.OpenAngleBracket) {
                return ParseTypeArgsExpressionTail(s, result);
            } else {
                return result;
            }
        }

        public static object ParseTypeModifiers(ParserState s) {
            if (s.Token.Type == TokenType.Operator && (s.Token.Value == "*" || s.Token.Value == "$" || s.Token.Value == "::")) {
                var mod = s.Token;
                ReadToken(s);
                return new TypeModifierExpression { Modifier = mod, Arg = ParseTypeModifiers(s) };
            } else {
                return ParseTokenWithType(s, TokenType.Identifier);
            }
        }

        public static TypeArgsExpression ParseTypeArgsExpressionTail(ParserState s, object target) {
            s.AngleBracketLevel += 1;
            var tae = new TypeArgsExpression { Target = target, Args = new List<object>() };
            ReadToken(s);
            while (true) {
                tae.Args.Add(ParseType(s));
                if (s.Token.Type == TokenType.CloseAngleBracket) {
                    break;
                }
                ParseTokenWithType(s, TokenType.Comma);
            }
            ParseTokenWithType(s, TokenType.CloseAngleBracket);
            s.AngleBracketLevel -= 1;
            return tae;
        }

        public static object ParseStatement(ParserState s) {
            if (s.Token.Type == TokenType.OpenBrace) {
                return ParseBlockStatement(s);
            }
            if (s.Token.Type == TokenType.Identifier) {
                if (s.Token.Value == "if") {
                    return ParseIfStatement(s);
                } else if (s.Token.Value == "while") {
                    return ParseWhileStatement(s);
                } else if (s.Token.Value == "for") {
                    return ParseForStatement(s);
                } else if (s.Token.Value == "match") {
                    return ParseMatchStatement(s);
                } else if (s.Token.Value == "return") {
                    return ParseReturnStatement(s);
                } else if (s.Token.Value == "break") {
                    var keyword = s.Token;
                    ReadToken(s);
                    return new BreakStatement { Keyword = keyword };
                } else if (s.Token.Value == "continue") {
                    var keyword = s.Token;
                    ReadToken(s);
                    return new ContinueStatement { Keyword = keyword };
                } else {
                    return ParseExpressionStatement(s, true);
                }
            }
            return ParseExpressionStatement(s, true);
        }

        public static BlockStatement ParseBlockStatement(ParserState s) {
            var result = new BlockStatement { Content = new List<object>() };
            ParseTokenWithType(s, TokenType.OpenBrace);
            while (s.Token.Type != TokenType.CloseBrace) {
                result.Content.Add(ParseStatement(s));
            }
            ParseTokenWithType(s, TokenType.CloseBrace);
            return result;
        }

        private static ExpressionStatement ParseExpressionStatement(ParserState s, bool allowStructInitializer) {
            return new ExpressionStatement { Expr = ParseExpression(s, 0, allowStructInitializer) };
        }

        private static ReturnStatement ParseReturnStatement(ParserState s) {
            var keyword = s.Token;
            ReadToken(s);
            for (int i = keyword.Span.To; i < s.Token.Span.From; i++) {
                if (s.Source[i] == '\n') {
                    return new ReturnStatement();
                }
            }
            return new ReturnStatement { Expr = ParseExpression(s, 0, true) };
        }

        private static IfStatement ParseIfStatement(ParserState s) {
            ReadToken(s);
            var result = new IfStatement { ConditionExpr = ParseExpression(s, 0, false) };
            result.IfBranch = ParseBlockStatement(s);
            if (s.Token.Type == TokenType.Identifier && s.Token.Value == "else") {
                ReadToken(s);
                result.ElseBranch = ParseStatement(s);
            }
            return result;
        }

        private static WhileStatement ParseWhileStatement(ParserState s) {
            ReadToken(s);
            var result = new WhileStatement { ConditionExpr = ParseExpression(s, 0, false) };
            result.Body = ParseBlockStatement(s);
            return result;
        }

        private static object ParseForStatement(ParserState s) {
            ReadToken(s);
            if (s.Token.Type == TokenType.Semicolon) {
                return ParseForIndexStatementTail(s, null);
            } else if (s.Token.Type == TokenType.Identifier) {
                var id = s.Token;
                ReadToken(s);
                if (s.Token.Type == TokenType.Identifier && s.Token.Value == "in") {
                    ReadToken(s);
                    var st = new ForEachStatement { IteratorVariable = id, SequenceExpression = ParseExpression(s, 0, false) };
                    st.Body = ParseBlockStatement(s);
                    return st;
                } else if (s.Token.Type == TokenType.Comma) {
                    ReadToken(s);
                    var indexId = ParseTokenWithType(s, TokenType.Identifier);
                    if (s.Token.Type != TokenType.Identifier || s.Token.Value != "in") {
                        Expected(s, "in");
                    }
                    ReadToken(s);
                    var st = new ForEachStatement { IteratorVariable = id, IndexIteratorVariable = indexId, SequenceExpression = ParseExpression(s, 0, false) };
                    st.Body = ParseBlockStatement(s);
                    return st;
                } else if (s.Token.Type == TokenType.Operator && s.Token.Value == ":=") {
                    return ParseForIndexStatementTail(s, id);
                } else {
                    var st = new ForEachStatement();
                    st.SequenceExpression = ParseExpressionTail(s, id, 0, false);
                    st.Body = ParseBlockStatement(s);
                    return st;
                }
            } else {
                var st = new ForEachStatement();
                st.SequenceExpression = ParseExpression(s, 0, false);
                st.Body = ParseBlockStatement(s);
                return st;
            }
        }

        private static ForIndexStatement ParseForIndexStatementTail(ParserState s, Token id) {
            var result = new ForIndexStatement();
            if (id != null) {
                var initExpr = new BinaryOperatorExpression { Lhs = id, Op = s.Token };
                ReadToken(s);
                initExpr.Rhs = ParseExpression(s, 0, false);
                result.InitializerStatement = new ExpressionStatement { Expr = initExpr };                
            }
            ParseTokenWithType(s, TokenType.Semicolon);
            result.ConditionExpr = ParseExpression(s, 0, false);
            if (s.Token.Type == TokenType.Semicolon || id == null) {
                ParseTokenWithType(s, TokenType.Semicolon);
                result.NextStatement = ParseExpressionStatement(s, false);
            }
            result.Body = ParseBlockStatement(s);
            return result;
        }

        private static MatchStatement ParseMatchStatement(ParserState s) {
            var result = new MatchStatement { Cases = new List<MatchCase>() };
            ReadToken(s);
            result.Expr = ParseExpression(s, 0, false);
            ParseTokenWithType(s, TokenType.OpenBrace);
            while (s.Token.Type != TokenType.CloseBrace) {
                result.Cases.Add(ParseMatchCase(s));
            }
            ParseTokenWithType(s, TokenType.CloseBrace);
            return result;
        }

        private static MatchCase ParseMatchCase(ParserState s) {
            var result = new MatchCase();
            result.Token = ParseTokenWithType(s, TokenType.Identifier);
            if (s.Token.Type == TokenType.Operator && s.Token.Value == "|" && (result.Token.Value == "null" || result.Token.Value == "default")) {
                ReadToken(s);
                result.Second = ParseTokenWithType(s, TokenType.Identifier);
            }
            ParseTokenWithType(s, TokenType.Colon);
            result.Statement = ParseStatement(s);
            return result;
        }

        public static object ParseExpression(ParserState s, int minLevel, bool allowStructInitializer) {
            return ParseExpressionTail(s, ParseExpressionLeaf(s, allowStructInitializer), minLevel, allowStructInitializer);
        }

        public static object ParseExpressionLeaf(ParserState s, bool allowStructInitializer) {
            if (s.Token.Type == TokenType.Identifier) {
                if (s.Token.Value != "new" && s.Token.Value != "ref") {
                    var result = s.Token;
                    ReadToken(s);
                    return result;
                } else {
                    var result = new UnaryOperatorExpression { Op = s.Token };
                    ReadToken(s);
                    result.Expr = ParseExpression(s, 25, allowStructInitializer);
                    return result;
                }
            } else if (s.Token.Type == TokenType.NumberLiteral) {
                var result = s.Token;
                ReadToken(s);
                return result;
            } else if (s.Token.Type == TokenType.StringLiteral) {
                var result = s.Token;
                ReadToken(s);
                return result;
            } else if (s.Token.Type == TokenType.CharacterLiteral) {
                var result = s.Token;
                ReadToken(s);
                return result;
            } else if (s.Token.Type == TokenType.Operator && (s.Token.Value == "*" || s.Token.Value == "$" || s.Token.Value == "::")) {
                return ParseType(s);
            } else if (s.Token.Type == TokenType.Operator && (s.Token.Value == "-" || s.Token.Value == "!" || s.Token.Value == "~")) {
                var result = new UnaryOperatorExpression { Op = s.Token };
                ReadToken(s);
                result.Expr = ParseExpression(s, 25, allowStructInitializer);
                return result;
            } else if (s.Token.Type == TokenType.OpenParen) {
                ReadToken(s);
                var result = ParseExpression(s, 0, true);
                ParseTokenWithType(s, TokenType.CloseParen);
                return result;
            } else {
                Expected(s, "Expression");
                throw new UnreachableException();
            }
        }

        public static object ParseExpressionTail(ParserState s, object lhs, int minLevel, bool allowStructInitializer) {
            while (true) {
                if (s.Token.Type == TokenType.OpenParen && minLevel <= 25) {
                    var result = new CallExpression { Target = lhs, Args = new List<object>() };
                    ReadToken(s);
                    while (s.Token.Type != TokenType.CloseParen) {
                        result.Args.Add(ParseExpression(s, 0, true));
                        if (s.Token.Type == TokenType.CloseParen) {
                            break;
                        }
                        ParseTokenWithType(s, TokenType.Comma);
                    }
                    ParseTokenWithType(s, TokenType.CloseParen);
                    lhs = result;
                } else if (s.Token.Type == TokenType.OpenBracket && minLevel <= 25) {
                    var result = new IndexExpression { Target = lhs };
                    ReadToken(s);
                    result.Arg = ParseExpression(s, 0, true);
                    ParseTokenWithType(s, TokenType.CloseBracket);
                    lhs = result;
                } else if (s.Token.Type == TokenType.OpenAngleBracket && (lhs is Token || lhs is DotExpression) && minLevel <= 25) {
                    if (lhs is Token) { 
                        var token = (Token)lhs;
                        if (IsProbablyANamespace(token.Value)) {
                            lhs = ParseTypeArgsExpressionTail(s, token);
                        } else {
                            s.Token.Type = TokenType.Operator;
                        }
                    } else {
                        var e = (DotExpression)lhs;
                        var exLhs = e.Lhs;
                        if (exLhs is Token && IsProbablyANamespace(((Token)exLhs).Value)) {
                            lhs = ParseTypeArgsExpressionTail(s, e);
                        } else {
                            s.Token.Type = TokenType.Operator;
                        }
                    }
                } else if (s.Token.Type == TokenType.OpenBrace && minLevel <= 25 && allowStructInitializer) {
                    if ((lhs is Token && ((Token)lhs).Type == TokenType.Identifier) || lhs is TypeModifierExpression || lhs is TypeArgsExpression) {
                        var result = new StructInitializerExpression { Target = lhs, Args = new List<FieldInitializerExpression>() };
                        ReadToken(s);
                        while (s.Token.Type != TokenType.CloseBrace) {
                            var fie = new FieldInitializerExpression { FieldName = ParseTokenWithType(s, TokenType.Identifier) };
                            ReadToken(s);
                            fie.Expr = ParseExpression(s, 0, true);
                            result.Args.Add(fie);
                            if (s.Token.Type == TokenType.CloseBrace) {
                                break;
                            }
                            ParseTokenWithType(s, TokenType.Comma);
                        }
                        ParseTokenWithType(s, TokenType.CloseBrace);
                        lhs = result;
                    } else {
                        return lhs;
                    }
                } else if (s.Token.Type == TokenType.CloseAngleBracket) {
                    s.Token.Type = TokenType.Operator;
                } else if (s.Token.Type == TokenType.Operator) {
                    var level = GetBindingLevel(s.Token.Value);
                    if (level < minLevel) {
                        return lhs;
                    }
                    if (s.Token.Value == "?") {
                        var result = new TernaryOperatorExpression { ConditionExpr = lhs };
                        ReadToken(s);
                        result.First = ParseExpression(s, 10, allowStructInitializer);
                        ParseTokenWithType(s, TokenType.Colon);
                        result.Second = ParseExpression(s, 10, allowStructInitializer);
                        lhs = result;
                    } else if (s.Token.Value == "^") {
                        var result = new PostfixUnaryOperatorExpression { Expr = lhs };
                        result.Op = s.Token;
                        ReadToken(s);
                        lhs = result;
                    } else if (s.Token.Value == ".") {
                        var result = new DotExpression { Lhs = lhs };
                        ReadToken(s);
                        if (s.Token.Type == TokenType.Identifier) {
                            result.Rhs = s.Token;
                            ReadToken(s);
                        }
                        lhs = result;
                    } else if (level >= 0) {
                        var result = new BinaryOperatorExpression { Lhs = lhs };
                        result.Op = s.Token;
                        ReadToken(s);
                        result.Rhs = ParseExpression(s, level + 1, allowStructInitializer);
                        lhs = result;
                    } else {
                        return lhs;
                    }
                } else {
                    return lhs;
                }
            }
        }

        public static int GetBindingLevel(string op) {
            if (op == "." || op == "^") {
                return 25;
            } else if (op == "*" || op == "/" || op == "%" || op == "<<" || op == ">>" || op == "&") {
                return 20;
            } else if (op == "+" || op == "-" || op == "|") {
                return 19;
            } else if (op == "==" || op == "!=" || op == "<" || op == ">" || op == "<=" || op == ">=") {
                return 18;
            } else if (op == "&&") {
                return 17;
            } else if (op == "||") {
                return 16;
            } else if (op == "?") {
                return 10;
            } else if (op == "=" || (op.Length == 2 && op[1] == '=') || (op.Length == 3 && op[2] == '=')) {
                return 0;
            }
            return -1;
        }

        public static Token ParseTokenWithType(ParserState s, TokenType type) {
            if (s.Token.Type != type) {
                Expected(s, type.ToString());
            }
            var result = s.Token;
            ReadToken(s);
            return result;
        }

        public static void ReadToken(ParserState s) {
            char ch;
            while (true) { 
                ch = s.Source[s.Index];
                while (char.IsWhiteSpace(ch)) {
                    s.Index += 1;
                    ch = s.Source[s.Index];
                }
                if (ch == '/' && s.Source[s.Index + 1] == '/') {
                    while (s.Source[s.Index] != '\n') {
                        s.Index += 1;
                    }
                } else {
                    break;
                }
            }
            var from = s.Index;
            if (ch == '\0') {
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.End);
            } else if (ch == ',') {
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.Comma);
            } else if (ch == ';') {
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.Semicolon);
            } else if (ch == ':') {
                s.Index += 1;
                ch = s.Source[s.Index];
                if (ch == '=' || ch == ':') {
                    s.Index += 1;
                    FinishToken(s, from, s.Index, TokenType.Operator);
                } else { 
                    FinishToken(s, from, s.Index, TokenType.Colon);
                }
            } else if (ch == '(') {
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.OpenParen);
            } else if (ch == ')') {
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.CloseParen);
            } else if (ch == '{') {
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.OpenBrace);
            } else if (ch == '}') {
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.CloseBrace);
            } else if (ch == '[') {
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.OpenBracket);
            } else if (ch == ']') {
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.CloseBracket);
            } else if (ch == '<') {
                s.Index += 1;
                ch = s.Source[s.Index];
                if (ch == '=') {
                    s.Index += 1;
                    FinishToken(s, from, s.Index, TokenType.Operator);
                } else if (ch == '<') {
                    s.Index += 1;
                    ch = s.Source[s.Index];
                    if (ch == '=') {
                        s.Index += 1;
                    }
                    FinishToken(s, from, s.Index, TokenType.Operator);
                } else { 
                    FinishToken(s, from, s.Index, TokenType.OpenAngleBracket);
                }
            } else if (ch == '>') {
                s.Index += 1;
                ch = s.Source[s.Index];
                if (s.AngleBracketLevel > 0) {
                    FinishToken(s, from, s.Index, TokenType.CloseAngleBracket);
                } else if (ch == '=') {
                    s.Index += 1;
                    FinishToken(s, from, s.Index, TokenType.Operator);
                } else if (ch == '>') {
                    s.Index += 1;
                    ch = s.Source[s.Index];
                    if (ch == '=') {
                        s.Index += 1;
                    }
                    FinishToken(s, from, s.Index, TokenType.Operator);
                } else {
                    FinishToken(s, from, s.Index, TokenType.CloseAngleBracket);
                }                
            } else if (ch == '#') {
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.Hash);
            } else if (ch == '^') {
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.Operator);
            } else if (ch == '"') {
                s.Index += 1;
                ch = s.Source[s.Index];
                var valueBuilder = new StringBuilder();
                while (ch != '"') {
                    if (ch == '\\') {
                        valueBuilder.Append(ReadEscapedChar(s));
                    } else if (ch == '\n' || ch == '\r' || ch == '\0') {
                        Expected(s, "\"");
                    } else {
                        valueBuilder.Append(ch);
                        s.Index += 1;
                    }
                    ch = s.Source[s.Index];
                }
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.StringLiteral);
                s.Token.AdditionalInfo = valueBuilder.ToString();
            } else if (ch == '\'') {
                s.Index += 1;
                ch = s.Source[s.Index];
                var valueBuilder = new StringBuilder();
                while (ch != '\'') {
                    if (ch == '\\') {
                        valueBuilder.Append(ReadEscapedChar(s));
                    } else if (ch == '\n' || ch == '\r' || ch == '\0') {
                        Expected(s, "'");
                    } else {
                        valueBuilder.Append(ch);
                        s.Index += 1;
                    }
                    ch = s.Source[s.Index];
                }
                s.Index += 1;
                FinishToken(s, from, s.Index, TokenType.CharacterLiteral);
                if (valueBuilder.Length != 1) {
                    ErrorAt(s, from, "Invalid character literal");
                }
                s.Token.AdditionalInfo = valueBuilder[0];
            } else if (char.IsDigit(ch) || ch == '-') {
                var prevCh = ch;
                s.Index += 1;
                ch = s.Source[s.Index];
                if (prevCh == '0' && ch == 'x') {
                    s.Index += 1;
                    ch = s.Source[s.Index];
                    var valueFrom = s.Index;
                    while (IsHexDigit(ch)) {
                        s.Index += 1;
                        ch = s.Source[s.Index];
                    }
                    var suffix = TryReadNumberSuffix(s);
                    FinishToken(s, from, s.Index, TokenType.NumberLiteral);
                    s.Token.AdditionalInfo = long.Parse(s.Source.Slice(valueFrom, s.Index - suffix.Length), System.Globalization.NumberStyles.HexNumber);
                } else if (prevCh == '-' && !char.IsDigit(ch)) {
                    if (ch == '=') { 
                        s.Index += 1;
                    }
                    FinishToken(s, from, s.Index, TokenType.Operator);
                } else { 
                    while (char.IsDigit(ch)) {
                        s.Index += 1;
                        ch = s.Source[s.Index];
                    }
                    var suffix = TryReadNumberSuffix(s);
                    FinishToken(s, from, s.Index, TokenType.NumberLiteral);
                    s.Token.AdditionalInfo = long.Parse(s.Source.Slice(from, s.Index - suffix.Length));
                }
            } else if (IsIdentifierChar(ch)) {
                s.Index += 1;
                ch = s.Source[s.Index];
                while (IsIdentifierChar(ch)) {
                    s.Index += 1;
                    ch = s.Source[s.Index];
                }
                FinishToken(s, from, s.Index, TokenType.Identifier);
            } else if (IsOperatorChar(ch)) {
                s.Index += 1;
                ch = s.Source[s.Index];
                while (IsOperatorChar(ch)) {
                    s.Index += 1;
                    ch = s.Source[s.Index];
                }
                FinishToken(s, from, s.Index, TokenType.Operator);
            } else {
                ErrorAt(s, s.Index, "Invalid token");
            }
        }

        public static bool IsIdentifierChar(char ch) {
            return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_';
        }

        public static bool IsHexDigit(char ch) {
            return (ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f') || (ch >= '0' && ch <= '9');
        }

        public static bool IsOperatorChar(char ch) {
            return ch == '.' || ch == '=' || ch == '>' || ch == '<' || ch == '*' || ch == '/' || ch == '%' || ch == '+' || ch == '-' || ch == '&' || ch == '|' || ch == '!' || ch == '~' || ch == '^' || ch == '$' || ch == '?';
        }

        public static bool IsProbablyANamespace(string name) {
            return char.IsUpper(name[0]) || name == "fun";
        }

        public static char ReadEscapedChar(ParserState s) {
            if (s.Source[s.Index] != '\\') {
                throw new InvalidOperationException();
            }
            s.Index += 1;
            var ch = s.Source[s.Index];
            switch (ch) {
                case '0': { s.Index += 1; return '\0'; }
                case 't': { s.Index += 1; return '\t'; }
                case 'n': { s.Index += 1; return '\n'; }
                case 'r': { s.Index += 1; return '\r'; }
                case '\\': { s.Index += 1; return '\\'; }
                case '"': { s.Index += 1; return '"'; }
                case '\'': { s.Index += 1; return '\''; }
                case 'x': { 
                    s.Index += 1;
                    var valueFrom = s.Index;
                    s.Index += 2;                        
                    return (char)int.Parse(s.Source.Slice(valueFrom, s.Index), System.Globalization.NumberStyles.HexNumber);
                }
            }
            ErrorAt(s, s.Index, "Invalid escape sequence");
            throw new UnreachableException();
        }

        public static string TryReadNumberSuffix(ParserState s) {
            var ch = s.Source[s.Index];
            if (ch != '_') {
                return "";
            }
            var from = s.Index;
            s.Index += 1;
            ch = s.Source[s.Index];
            while (ch == 's' || ch == 'b' || ch == 'u' || ch == 'L' || ch == 'z' || ch == 'd') {
                s.Index += 1;
                ch = s.Source[s.Index];
            }
            return s.Source.Slice(from, s.Index);
        }

        public static void FinishToken(ParserState s, int from, int to, TokenType type) {
            s.Token = new Token { Type = type, Span = new IntRange(from, to), Value = s.Source.Slice(from, to) };
        }

        public static void ErrorAt(ParserState s, int index, string message) {
            throw new ParseException(ErrorHelper.GetErrorDesc(s.Unit.Filename, s.Source, index, message));
        }

        public static void Error(ParserState s, string message) {
            ErrorAt(s, s.Token.Span.From, message);
        }

        public static void Expected(ParserState s, string message) {
            ErrorAt(s, s.Token.Span.From, "Expected: " + message);
        }
    }
}
