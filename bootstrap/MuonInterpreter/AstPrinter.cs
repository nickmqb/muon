using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MuonInterpreter {
    public class PrintState {
        public int Indent;
    }

    public static class AstPrinter {
        public static void PrintAny(PrintState s, object obj) {
            switch (obj) {
                case CodeUnit a: PrintCodeUnit(s, a); break;
                case NamespaceDef a: PrintNamespaceDef(s, a); break;
                case Attribute a: PrintAttribute(s, a); break;
                case FunctionDef a: PrintFunctionDef(s, a); break;
                case FieldDef a: PrintFieldDef(s, a); break;
                case StaticFieldDef a: PrintStaticFieldDef(s, a); break;
                case TaggedPointerOptionDef a: PrintTaggedPointerOptionDef(s, a); break;
                case TypeModifierExpression a: PrintTypeModifierExpression(s, a); break;
                case TypeArgsExpression a: PrintTypeArgsExpression(s, a); break;
                case BlockStatement a: PrintBlockStatement(s, a); break;
                case ExpressionStatement a: PrintExpressionStatement(s, a); break;
                case ReturnStatement a: PrintReturnStatement(s, a); break;
                case BreakStatement a: PrintBreakStatement(s, a); break;
                case ContinueStatement a: PrintContinueStatement(s, a); break;
                case IfStatement a: PrintIfStatement(s, a); break;
                case WhileStatement a: PrintWhileStatement(s, a); break;
                case ForEachStatement a: PrintForEachStatement(s, a); break;
                case ForIndexStatement a: PrintForIndexStatement(s, a); break;
                case MatchStatement a : PrintMatchStatement(s, a); break;
                case MatchCase  a: PrintMatchCase(s, a); break;
                case UnaryOperatorExpression a: PrintUnaryOperatorExpression(s, a); break;
                case PostfixUnaryOperatorExpression a: PrintPostfixUnaryOperatorExpression(s, a); break;
                case DotExpression a: PrintDotExpression(s, a); break;
                case BinaryOperatorExpression a: PrintBinaryOperatorExpression(s, a); break;
                case TernaryOperatorExpression a: PrintTernaryOperatorExpression(s, a); break;
                case CallExpression a: PrintCallExpression(s, a); break;
                case StructInitializerExpression a: PrintStructInitializerExpression(s, a); break;
                case IndexExpression a: PrintIndexExpresison(s, a); break;
                case Token a: PrintToken(s, a); break;
                case null: PrintLine(s, "null"); break;
                default: throw new ArgumentException();
            }
        }

        public static void PrintCodeUnit(PrintState s, CodeUnit u) {
            foreach (var it in u.Contents) {
                PrintAny(s, it);
            }
        }

        public static void PrintNamespaceDef(PrintState s, NamespaceDef a) {
            PrintLine(s, string.Format("NsDef: {0} {1}", a.Name.Value, a.Kind));
            Indent(s);
            PrintDescWithList(s, "Attributes", a.Attributes);
            PrintDescWithList(s, "Contents", a.Contents);
            UnIndent(s);
        }

        public static void PrintAttribute(PrintState s, Attribute a) {
            PrintDescWithToken(s, "Attribute", a.Name);
            Indent(s);
            PrintDescWithList(s, "Args", a.Args);
            UnIndent(s);
        }

        public static void PrintFunctionDef(PrintState s, FunctionDef a) {
            PrintDescWithToken(s, "FunctionDef", a.Name);
            Indent(s);
            PrintLine(s, "Params:");
            Indent(s);
            foreach (var p in a.Params) {
                PrintToken(s, p.Name);
                Indent(s);
                PrintAny(s, p.Type);
                UnIndent(s);
            }
            UnIndent(s);
            PrintDescWithAny(s, "ReturnType", a.ReturnType);
            PrintDescWithList(s, "Attributes", a.Attributes);
            PrintDescWithAny(s, "Body", a.Body);
            UnIndent(s);
        }

        public static void PrintFieldDef(PrintState s, FieldDef a) {
            PrintDescWithToken(s, "FieldDef", a.Name);
            Indent(s);
            PrintAny(s, a.Type);
            UnIndent(s);
        }

        public static void PrintStaticFieldDef(PrintState s, StaticFieldDef a) {
            PrintDescWithToken(s, "StaticFieldDef", a.Name);
            Indent(s);
            PrintDescWithAny(s, "Type", a.Type);
            UnIndent(s);
        }

        public static void PrintTaggedPointerOptionDef(PrintState s, TaggedPointerOptionDef a) {
            PrintDescWithToken(s, "TaggedPointerOptionDef", a.Name);
        }

        public static void PrintTypeModifierExpression(PrintState s, TypeModifierExpression a) {
            PrintDescWithToken(s, "TypeModifier", a.Modifier);
            Indent(s);
            PrintAny(s, a.Arg);
            UnIndent(s);
        }

        public static void PrintTypeArgsExpression(PrintState s, TypeArgsExpression a) {
            PrintDescWithAny(s, "TypeArgs", a.Target);
            Indent(s);
            foreach (var it in a.Args) {
                PrintAny(s, it);
            }
            UnIndent(s);
        }

        public static void PrintBlockStatement(PrintState s, BlockStatement a) {
            PrintLine(s, "BlockStatement");
            Indent(s);
            foreach (var it in a.Content) {
                PrintAny(s, it);
            }
            UnIndent(s);
        }

        public static void PrintExpressionStatement(PrintState s, ExpressionStatement a) {
            PrintLine(s, "ExpressionStatement");
            Indent(s);
            PrintAny(s, a.Expr);
            UnIndent(s);
        }

        public static void PrintReturnStatement(PrintState s, ReturnStatement a) {
            PrintLine(s, "ReturnStatement");
            Indent(s);
            PrintAny(s, a.Expr);
            UnIndent(s);
        }

        public static void PrintBreakStatement(PrintState s, BreakStatement a) {
            PrintLine(s, "BreakStatement");
        }

        public static void PrintContinueStatement(PrintState s, ContinueStatement a) {
            PrintLine(s, "ContinueStatement");
        }

        public static void PrintIfStatement(PrintState s, IfStatement a) {
            PrintLine(s, "IfStatement");
            Indent(s);
            PrintDescWithAny(s, "ConditionExpr", a.ConditionExpr);
            PrintDescWithAny(s, "IfBranch", a.IfBranch);
            PrintDescWithAny(s, "ElseBranch", a.ElseBranch);
            UnIndent(s);
        }

        public static void PrintWhileStatement(PrintState s, WhileStatement a) {
            PrintLine(s, "WhileStatement");
            Indent(s);
            PrintDescWithAny(s, "ConditionExpr", a.ConditionExpr);
            PrintDescWithAny(s, "Body", a.Body);
            UnIndent(s);
        }

        public static void PrintForEachStatement(PrintState s, ForEachStatement a) {
            PrintLine(s, "ForEachStatement");
            Indent(s);
            PrintDescWithAny(s, "IteratorVariable", a.IteratorVariable);
            PrintDescWithAny(s, "SequenceExpression", a.SequenceExpression);
            PrintDescWithAny(s, "Body", a.Body);
            UnIndent(s);
        }

        public static void PrintForIndexStatement(PrintState s, ForIndexStatement a) {
            PrintLine(s, "ForIndexStatement");
            Indent(s);
            PrintDescWithAny(s, "InitializerStatement", a.InitializerStatement);
            PrintDescWithAny(s, "ConditionExpr", a.ConditionExpr);
            PrintDescWithAny(s, "NextStatement", a.NextStatement);
            PrintDescWithAny(s, "Body", a.Body);
            UnIndent(s);
        }

        private static void PrintMatchStatement(PrintState s, MatchStatement a) {
            PrintLine(s, "MatchStatement");
            Indent(s);
            PrintDescWithAny(s, "Expr", a.Expr);
            PrintDescWithList(s, "Cases", a.Cases);
            UnIndent(s);
        }

        private static void PrintMatchCase(PrintState s, MatchCase a) {
            PrintLine(s, "MatchCase");
            Indent(s);
            PrintDescWithAny(s, "Name", a.Token);
            if (a.Second != null) {
                PrintDescWithAny(s, "Second", a.Second);
            }
            PrintDescWithAny(s, "Statement", a.Statement);
            UnIndent(s);
        }

        public static void PrintUnaryOperatorExpression(PrintState s, UnaryOperatorExpression a) {
            PrintLine(s, "UnaryOperatorExpression");
            Indent(s);
            PrintDescWithAny(s, "Op", a.Op);
            PrintDescWithAny(s, "Expr", a.Expr);
            UnIndent(s);
        }

        public static void PrintPostfixUnaryOperatorExpression(PrintState s, PostfixUnaryOperatorExpression a) {
            PrintLine(s, "PostfixUnaryOperatorExpression");
            Indent(s);
            PrintDescWithAny(s, "Op", a.Op);
            PrintDescWithAny(s, "Expr", a.Expr);
            UnIndent(s);
        }

        public static void PrintDotExpression(PrintState s, DotExpression a) {
            PrintLine(s, "DotExpression");
            Indent(s);
            PrintDescWithAny(s, "Lhs", a.Lhs);
            PrintDescWithAny(s, "Rhs", a.Rhs);
            UnIndent(s);
        }

        public static void PrintBinaryOperatorExpression(PrintState s, BinaryOperatorExpression a) {
            PrintLine(s, "BinaryOperatorExpression");
            Indent(s);
            PrintDescWithAny(s, "Op", a.Op);
            PrintDescWithAny(s, "Lhs", a.Lhs);
            PrintDescWithAny(s, "Rhs", a.Rhs);
            UnIndent(s);
        }

        public static void PrintTernaryOperatorExpression(PrintState s, TernaryOperatorExpression a) {
            PrintLine(s, "TernaryOperatorExpression");
            Indent(s);
            PrintDescWithAny(s, "ConditionExpr", a.ConditionExpr);
            PrintDescWithAny(s, "First", a.First);
            PrintDescWithAny(s, "Second", a.Second);
            UnIndent(s);
        }

        public static void PrintCallExpression(PrintState s, CallExpression a) {
            PrintLine(s, "CallExpression");
            Indent(s);
            PrintDescWithAny(s, "Target", a.Target);
            PrintDescWithList(s, "Args", a.Args);
            UnIndent(s);
        }

        public static void PrintStructInitializerExpression(PrintState s, StructInitializerExpression a) {
            PrintLine(s, "StructInitializerExpression");
            Indent(s);
            PrintDescWithAny(s, "Target", a.Target);
            PrintLine(s, "Args:");
            Indent(s);
            foreach (var it in a.Args) {
                PrintToken(s, it.FieldName);
                Indent(s);
                PrintAny(s, it.Expr);
                UnIndent(s);
            }
            UnIndent(s);
            UnIndent(s);
        }

        public static void PrintIndexExpresison(PrintState s, IndexExpression a) {
            PrintLine(s, "IndexExpression");
            Indent(s);
            PrintDescWithAny(s, "Target", a.Target);
            PrintDescWithAny(s, "Arg", a.Arg);
            UnIndent(s);
        }

        public static void PrintToken(PrintState s, Token t) {
            PrintLine(s, string.Format("{0} {1}", t.Value, t.Type));
        }

        public static void PrintDescWithToken(PrintState s, string desc, Token t) {
            PrintLine(s, string.Format("{0}: {1}", desc, t.Value));
        }

        public static void PrintDescWithAny(PrintState s, string desc, object obj) {
            PrintLine(s, desc + ":");
            Indent(s);
            PrintAny(s, obj);
            UnIndent(s);
        }

        public static void PrintDescWithList<T>(PrintState s, string desc, List<T> list) where T : class {
            PrintLine(s, desc + ":");
            if (list == null) {
                return;
            }
            Indent(s);
            foreach (var it in list) {
                PrintAny(s, it);
            }
            UnIndent(s);
        }

        public static void PrintLine(PrintState s, string line) {
            Console.Write(new string(' ', s.Indent));
            Console.WriteLine(line);
        }

        public static void Indent(PrintState s) {
            s.Indent += 2;
        }

        public static void UnIndent(PrintState s) {
            s.Indent -= 2;
        }
    }
}
