using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MuonInterpreter {
    public static class RangeFinder {
        public class RangeFinderState {
            public int From;
            public int To;
        }

        public static IntRange Find(object a) {
            var s = new RangeFinderState { From = int.MaxValue, To = int.MinValue };
            CheckAny(s, a);
            if (s.From > s.To) {
                throw new InvalidOperationException();
            }
            return new IntRange { From = s.From, To = s.To };
        }

        public static void CheckAny(RangeFinderState s, object obj) {
            switch (obj) {
                case CodeUnit a: CheckCodeUnit(s, a); break;
                case NamespaceDef a: CheckNamespaceDef(s, a); break;
                case Attribute a: CheckAttribute(s, a); break;
                case FunctionDef a: CheckFunctionDef(s, a); break;
                case FieldDef a: CheckFieldDef(s, a); break;
                case StaticFieldDef a: CheckStaticFieldDef(s, a); break;
                case TaggedPointerOptionDef a: CheckTaggedPointerOptionDef(s, a); break;
                case TypeModifierExpression a: CheckTypeModifierExpression(s, a); break;
                case TypeArgsExpression a: CheckTypeArgsExpression(s, a); break;
                case BlockStatement a: CheckBlockStatement(s, a); break;
                case ExpressionStatement a: CheckExpressionStatement(s, a); break;
                case ReturnStatement a: CheckReturnStatement(s, a); break;
                case BreakStatement a: CheckBreakStatement(s, a); break;
                case ContinueStatement a: CheckContinueStatement(s, a); break;
                case IfStatement a: CheckIfStatement(s, a); break;
                case WhileStatement a: CheckWhileStatement(s, a); break;
                case ForEachStatement a: CheckForEachStatement(s, a); break;
                case ForIndexStatement a: CheckForIndexStatement(s, a); break;
                case MatchStatement a: CheckMatchStatement(s, a); break;
                case MatchCase a: CheckMatchCase(s, a); break;
                case UnaryOperatorExpression a: CheckUnaryOperatorExpression(s, a); break;
                case PostfixUnaryOperatorExpression a: CheckPostfixUnaryOperatorExpression(s, a); break;
                case DotExpression a: CheckDotExpression(s, a); break;
                case BinaryOperatorExpression a: CheckBinaryOperatorExpression(s, a); break;
                case TernaryOperatorExpression a: CheckTernaryOperatorExpression(s, a); break;
                case CallExpression a: CheckCallExpression(s, a); break;
                case StructInitializerExpression a: CheckStructInitializerExpression(s, a); break;
                case IndexExpression a: CheckIndexExpresison(s, a); break;
                case Token a: CheckToken(s, a); break;
                case null: break;
                default: throw new ArgumentException();
            }
        }

        public static void CheckCodeUnit(RangeFinderState s, CodeUnit a) {
            CheckList(s, a.Contents);
        }

        public static void CheckNamespaceDef(RangeFinderState s, NamespaceDef a) {
            CheckList(s, a.Contents);
        }

        public static void CheckAttribute(RangeFinderState s, Attribute a) {
            CheckToken(s, a.Name);
            CheckList(s, a.Args);
        }

        public static void CheckFunctionDef(RangeFinderState s, FunctionDef a) {
            CheckToken(s, a.Name);
            foreach (var p in a.Params) {
                CheckToken(s, p.Name);
                CheckAny(s, p.Type);
            }
            CheckAny(s, a.ReturnType);
            CheckList(s, a.Attributes);
            CheckAny(s, a.Body);
        }

        public static void CheckFieldDef(RangeFinderState s, FieldDef a) {
            CheckToken(s, a.Name);
            CheckAny(s, a.Type);
        }

        public static void CheckStaticFieldDef(RangeFinderState s, StaticFieldDef a) {
            CheckAny(s, a.Name);
            CheckAny(s, a.Type);
            CheckList(s, a.Attributes);
            CheckAny(s, a.InitializerExpr);
        }

        public static void CheckTaggedPointerOptionDef(RangeFinderState s, TaggedPointerOptionDef a) {
            CheckAny(s, a.Name);
        }

        public static void CheckTypeModifierExpression(RangeFinderState s, TypeModifierExpression a) {
            CheckToken(s, a.Modifier);
            CheckAny(s, a.Arg);
        }

        public static void CheckTypeArgsExpression(RangeFinderState s, TypeArgsExpression a) {
            CheckAny(s, a.Target);
            foreach (var it in a.Args) {
                CheckAny(s, it);
            }
        }

        public static void CheckBlockStatement(RangeFinderState s, BlockStatement a) {
            foreach (var it in a.Content) {
                CheckAny(s, it);
            }
        }

        public static void CheckExpressionStatement(RangeFinderState s, ExpressionStatement a) {
            CheckAny(s, a.Expr);
        }

        public static void CheckReturnStatement(RangeFinderState s, ReturnStatement a) {
            CheckAny(s, a.Expr);
        }

        public static void CheckBreakStatement(RangeFinderState s, BreakStatement a) {
            CheckToken(s, a.Keyword);
        }

        public static void CheckContinueStatement(RangeFinderState s, ContinueStatement a) {
            CheckToken(s, a.Keyword);
        }

        public static void CheckIfStatement(RangeFinderState s, IfStatement a) {
            CheckAny(s, a.ConditionExpr);
            CheckAny(s, a.IfBranch);
            CheckAny(s, a.ElseBranch);
        }

        public static void CheckWhileStatement(RangeFinderState s, WhileStatement a) {
            CheckAny(s, a.ConditionExpr);
            CheckAny(s, a.Body);
        }

        public static void CheckForEachStatement(RangeFinderState s, ForEachStatement a) {
            CheckToken(s, a.IteratorVariable);
            CheckAny(s, a.SequenceExpression);
            CheckAny(s, a.Body);
        }

        public static void CheckForIndexStatement(RangeFinderState s, ForIndexStatement a) {
            CheckAny(s, a.InitializerStatement);
            CheckAny(s, a.ConditionExpr);
            CheckAny(s, a.NextStatement);
            CheckAny(s, a.Body);
        }

        private static void CheckMatchStatement(RangeFinderState s, MatchStatement a) {
            CheckAny(s, a.Expr);
            CheckList(s, a.Cases);
        }

        private static void CheckMatchCase(RangeFinderState s, MatchCase a) {
            CheckAny(s, a.Token);
            CheckAny(s, a.Second);
            CheckAny(s, a.Statement);
        }

        public static void CheckUnaryOperatorExpression(RangeFinderState s, UnaryOperatorExpression a) {
            CheckToken(s, a.Op);
            CheckAny(s, a.Expr);
        }

        public static void CheckPostfixUnaryOperatorExpression(RangeFinderState s, PostfixUnaryOperatorExpression a) {
            CheckAny(s, a.Expr);
            CheckToken(s, a.Op);
        }

        public static void CheckDotExpression(RangeFinderState s, DotExpression a) {
            CheckAny(s, a.Lhs);
            CheckAny(s, a.Rhs);
        }

        public static void CheckBinaryOperatorExpression(RangeFinderState s, BinaryOperatorExpression a) {
            CheckAny(s, a.Lhs);
            CheckToken(s, a.Op);
            CheckAny(s, a.Rhs);
        }

        public static void CheckTernaryOperatorExpression(RangeFinderState s, TernaryOperatorExpression a) {
            CheckAny(s, a.ConditionExpr);
            CheckAny(s, a.First);
            CheckAny(s, a.Second);
        }

        public static void CheckCallExpression(RangeFinderState s, CallExpression a) {
            CheckAny(s, a.Target);
            CheckList(s, a.Args);
        }

        public static void CheckStructInitializerExpression(RangeFinderState s, StructInitializerExpression a) {
            CheckAny(s, a.Target);
            foreach (var it in a.Args) {
                CheckToken(s, it.FieldName);
                CheckAny(s, it.Expr);
            }
        }

        public static void CheckIndexExpresison(RangeFinderState s, IndexExpression a) {
            CheckAny(s, a.Target);
            CheckAny(s, a.Arg);
        }

        public static void CheckToken(RangeFinderState s, Token t) {
            if (t == null) {
                return;
            }
            s.From = Math.Min(s.From, t.Span.From);
            s.To = Math.Max(s.To, t.Span.To);
        }

        public static void CheckList<T>(RangeFinderState s, List<T> list) where T : class {
            foreach (var it in list) {
                CheckAny(s, it);
            }
        }
    }
}