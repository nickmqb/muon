using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MuonInterpreter {
    public class CodeUnit {
        public string Filename;
        public string Source;
        public List<object> Contents;
    }

    public class NamespaceDef {
        public CodeUnit Unit;
        public Token Name;
        public TypeParams TypeParams;
        public NamespaceKind Kind;
        public List<Attribute> Attributes;
        public List<object> Contents;
        public Namespace Ns;
    }

    public class TypeParams {
        public List<Token> Params;
    }

    public class Attribute {
        public Token Name;
        public List<object> Args;
    }

    public class FunctionDef {
        public CodeUnit Unit;
        public NamespaceDef Parent;
        public Token Name;
        public TypeParams TypeParams;
        public List<Param> Params;
        public object ReturnType;
        public List<Attribute> Attributes;
        public BlockStatement Body;
        public string InternalName;
    }

    public class Param {
        public Token Name;
        public object Type;
    }

    public class FieldDef {
        public Token Name;
        public object Type;
    }

    public class StaticFieldDef {
        public NamespaceDef Parent;
        public Token Name;
        public object Type;
        public List<Attribute> Attributes;
        public object InitializerExpr;
        public bool IsEnumOption;
        public object Value; // Used by Interpreter
        public bool IsInitialized; // Used by Interpreter
    }

    public class TaggedPointerOptionDef {
        public Token Name;
    }

    public class TypeModifierExpression {
        public Token Modifier;
        public object Arg;
    }

    public class TypeArgsExpression {
        public object Target;
        public List<object> Args;
    }

    public class BlockStatement {
        public List<object> Content;
    }

    public class ExpressionStatement {
        public object Expr;
    }

    public class ReturnStatement {
        public object Expr;
    }

    public class BreakStatement {
        public Token Keyword;
    }

    public class ContinueStatement {
        public Token Keyword;
    }

    public class IfStatement {
        public object ConditionExpr;
        public BlockStatement IfBranch;
        public object ElseBranch;
    }

    public class WhileStatement {
        public object ConditionExpr;
        public BlockStatement Body;
    }

    public class ForEachStatement {
        public Token IteratorVariable;
        public Token IndexIteratorVariable;
        public object SequenceExpression;
        public BlockStatement Body;
    }

    public class ForIndexStatement {
        public ExpressionStatement InitializerStatement;
        public object ConditionExpr;
        public object NextStatement;
        public BlockStatement Body;
    }

    public class MatchStatement {
        public object Expr;
        public List<MatchCase> Cases;
        public bool IsInitialized; // Used by Interpreter
        public MatchCase NullCase; // Used by Interpreter
        public MatchCase DefaultCase; // Used by Interpreter
    }

    public class MatchCase {
        public Token Token;
        public Token Second;
        public object Statement;
    }

    public class UnaryOperatorExpression {
        public Token Op;
        public object Expr;
    }

    public class PostfixUnaryOperatorExpression {
        public object Expr;
        public Token Op;
    }

    public class DotExpression {
        public object Lhs;
        public Token Rhs;
    }

    public class BinaryOperatorExpression {
        public Token Op;
        public object Lhs;
        public object Rhs;
    }

    public class TernaryOperatorExpression {
        public object ConditionExpr;
        public object First;
        public object Second;
    }

    public class CallExpression {
        public object Target;
        public List<object> Args;
    }

    public class StructInitializerExpression {
        public object Target;
        public List<FieldInitializerExpression> Args;
    }

    public class FieldInitializerExpression {
        public Token FieldName;
        public object Expr;
    }

    public class IndexExpression {
        public object Target;
        public object Arg;
    }

    public class Token {
        public TokenType Type;
        public string Value;
        public IntRange Span;
        public object AdditionalInfo;
    }

    public enum NamespaceKind {
        Default,
        Struct,
        Enum,
        TaggedPointerEnum
    }

    public enum TokenType {
        Identifier,
        NumberLiteral,
        StringLiteral,
        CharacterLiteral,
        Operator,
        OpenParen,
        CloseParen,
        OpenBrace,
        CloseBrace,
        OpenBracket,
        CloseBracket,
        OpenAngleBracket,
        CloseAngleBracket,
        Comma,
        Semicolon,
        Colon,
        Hash,
        End
    }

}
