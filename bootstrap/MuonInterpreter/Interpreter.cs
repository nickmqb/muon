using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MuonInterpreter {
    public class InterpreterState {
        public Stack<Frame> Frames;
        public Frame Current;
        public List<LocalVariable> Locals;
        public int FirstLocalIndex;
        public Namespace Top;
        public object Debug_CurrentStatement;
        public string[] FakeCommandLineArgs;
    }

    public struct Frame {
        public Namespace Ns;
        public FunctionDef Func;
        public int FirstLocalIndex;

        public override string ToString() {
            return Ns.Name + "." + Func.Name.Value;
        }
    }

    public class LocalVariable {
        public string Name;
        public object Value;
    }

    public struct BoundFunction {
        public FunctionDef Func;
        public object Instance;
    }

    public struct BoundBuiltinFunction {
        public BuiltinFunction Func;
        public object Instance;
    }

    public struct FunctionWithTypeArgs {
        public FunctionDef Func;
        public TypeArgsExpression TypeArgs;
    }

    public struct BoundField {
        public object Instance;
        public FieldDef Field;
    }

    public struct BoundElement {
        public object Instance;
        public long Index;
    }

    public struct RunStatementResult {
        public bool ShouldBreak;
        public bool ShouldContinue;
        public bool ShouldReturn;
        public object ReturnValue;
    }

    public enum BuiltinFunction {
        Identity = 0,
        Assert = 1,
        As = 2,
        Is = 3,
        Format = 4,
        Transmute = 5,
        Min = 6,
        Max = 7,
        Cast = 8,
    }

    public class Interpreter {
        public static object EvalFunction(InterpreterState s, FunctionDef func, TypeArgsExpression typeArgs = null) {
            s.Current = new Frame { Func = func, Ns = func.Parent != null ? func.Parent.Ns : s.Top, FirstLocalIndex = s.FirstLocalIndex };
            if (func.InternalName != null) {
                return EvalInternalFunction(s, func, typeArgs);
            }
            var res = RunBlockStatement(s, func.Body);
            if (res.ShouldReturn) {
                return res.ReturnValue;
            }
            if (res.ShouldBreak || res.ShouldContinue) {
                throw new InvalidOperationException("break or continue is not allowed here");
            }
            return null;
        }

        public static RunStatementResult RunStatement(InterpreterState s, object statement) {
            s.Debug_CurrentStatement = statement;
            switch (statement) {
                case BlockStatement st: return RunBlockStatement(s, st);
                case ExpressionStatement st: return RunExpressionStatement(s, st);
                case ReturnStatement st: return RunReturnStatement(s, st);
                case BreakStatement st: return RunBreakStatement(s, st);
                case ContinueStatement st: return RunContinueStatement(s, st);
                case IfStatement st: return RunIfStatement(s, st);
                case WhileStatement st: return RunWhileStatement(s, st);
                case ForEachStatement st: return RunForEachStatement(s, st);
                case ForIndexStatement st: return RunForIndexStatement(s, st);
                case MatchStatement st: return RunMatchStatement(s, st);
                default: throw new InvalidOperationException();
            }
        }

        private static RunStatementResult RunBreakStatement(InterpreterState s, BreakStatement st) {
            return new RunStatementResult { ShouldBreak = true };
        }

        private static RunStatementResult RunContinueStatement(InterpreterState s, ContinueStatement st) {
            return new RunStatementResult { ShouldContinue = true };
        }

        private static RunStatementResult RunIfStatement(InterpreterState s, IfStatement st) {
            if ((bool)EvalExpression(s, st.ConditionExpr)) {
                return RunStatement(s, st.IfBranch);
            } else if (st.ElseBranch != null) {
                return RunStatement(s, st.ElseBranch);
            }
            return new RunStatementResult();
        }

        private static RunStatementResult RunWhileStatement(InterpreterState s, WhileStatement st) {
            while ((bool)EvalExpression(s, st.ConditionExpr)) {
                var res = RunStatement(s, st.Body);
                if (res.ShouldReturn) {
                    return res;
                }
                if (res.ShouldBreak) {
                    return new RunStatementResult();
                }
            }
            return new RunStatementResult();
        }

        private static RunStatementResult RunForEachStatement(InterpreterState s, ForEachStatement st) {
            var prevLocalsCount = s.Locals.Count;
            AddLocalVar(s, st.IteratorVariable != null ? st.IteratorVariable.Value : "it", null);
            LocalVariable loopIndexVariable = null;
            if (st.IndexIteratorVariable != null) {
                loopIndexVariable = AddLocalVar(s, st.IndexIteratorVariable.Value, (long)0);
            }
            var seq = EvalExpression(s, st.SequenceExpression);
            if (seq is object[] || seq is List<object> || seq is HashSet<object>) {
                foreach (var it in (IEnumerable<object>)seq) {
                    s.Locals[prevLocalsCount].Value = it;
                    var res = RunStatement(s, st.Body);
                    if (res.ShouldReturn) {
                        s.Locals.SetSize(prevLocalsCount);
                        return res;
                    }
                    if (res.ShouldBreak) {
                        s.Locals.SetSize(prevLocalsCount);
                        return new RunStatementResult();
                    }
                    if (loopIndexVariable != null) {
                        loopIndexVariable.Value = ((long)loopIndexVariable.Value) + 1;
                    }
                }
            } else {
                var dict = ((Map)seq).Dict;
                var mapEntryType = (Namespace)s.Top.Members["MapEntry"];
                foreach (var p in dict) {
                    var e = (Dictionary<string, object>)CreateInstance(s, mapEntryType);
                    e["key"] = p.Key;
                    e["value"] = p.Value;
                    s.Locals[prevLocalsCount].Value = e;
                    var res = RunStatement(s, st.Body);
                    if (res.ShouldReturn) {
                        s.Locals.SetSize(prevLocalsCount);
                        return res;
                    }
                    if (res.ShouldBreak) {
                        s.Locals.SetSize(prevLocalsCount);
                        return new RunStatementResult();
                    }
                    if (loopIndexVariable != null) {
                        loopIndexVariable.Value = ((long)loopIndexVariable.Value) + 1;
                    }
                }
            }
            s.Locals.SetSize(prevLocalsCount);
            return new RunStatementResult();
        }

        private static RunStatementResult RunForIndexStatement(InterpreterState s, ForIndexStatement st) {
            var prevLocalsCount = s.Locals.Count;
            LocalVariable loopVariable = null;
            if (st.InitializerStatement != null) {
                var res = RunStatement(s, st.InitializerStatement);
                if (res.ShouldReturn || res.ShouldBreak || res.ShouldContinue) {
                    throw new InvalidOperationException();
                }
                loopVariable = GetLocalVar(s, ((Token)((BinaryOperatorExpression)st.InitializerStatement.Expr).Lhs).Value);
            }            
            while ((bool)EvalExpression(s, st.ConditionExpr)) {
                var res = RunStatement(s, st.Body);
                if (res.ShouldReturn) {
                    s.Locals.SetSize(prevLocalsCount);
                    return res;
                }
                if (res.ShouldBreak) {
                    s.Locals.SetSize(prevLocalsCount);
                    return new RunStatementResult();
                }
                if (st.NextStatement != null) {
                    res = RunStatement(s, st.NextStatement);
                    if (res.ShouldReturn || res.ShouldBreak || res.ShouldContinue) {
                        throw new InvalidOperationException();
                    }
                } else {
                    loopVariable.Value = ((long)loopVariable.Value) + 1;
                }
            }
            s.Locals.SetSize(prevLocalsCount);
            return new RunStatementResult();
        }

        public static RunStatementResult RunMatchStatement(InterpreterState s, MatchStatement st) {
            if (!st.IsInitialized) {
                foreach (var cs in st.Cases) {
                    if (cs.Token.Value == "null" || (cs.Second != null && cs.Second.Value == "null")) {
                        st.NullCase = cs;
                    }
                    if (cs.Token.Value == "default" || (cs.Second != null && cs.Second.Value == "default")) {
                        st.DefaultCase = cs;
                    }
                }
                st.IsInitialized = true;
            }
            var value = EvalExpression(s, st.Expr);
            if (value == null) {
                if (st.NullCase == null) {
                    throw new InvalidOperationException("No match");
                }
                return RunStatement(s, st.NullCase.Statement);
            }
            var typename = GetTypeOfInstance(s, value).Name;
            foreach (var cs in st.Cases) {
                if (cs.Token.Value == typename) {
                    return RunStatement(s, cs.Statement);
                }
            }
            if (st.DefaultCase == null) {
                throw new InvalidOperationException("No match");
            }
            return RunStatement(s, st.DefaultCase.Statement);
        }
        
        public static RunStatementResult RunBlockStatement(InterpreterState s, BlockStatement st) {
            var prevLocalsCount = s.Locals.Count;
            foreach (var cst in st.Content) {
                var res = RunStatement(s, cst);
                if (res.ShouldReturn || res.ShouldBreak || res.ShouldContinue) {
                    s.Locals.SetSize(prevLocalsCount);
                    return res;
                }
            }
            s.Locals.SetSize(prevLocalsCount);
            return new RunStatementResult();
        }

        public static RunStatementResult RunExpressionStatement(InterpreterState s, ExpressionStatement st) {
            EvalExpression(s, st.Expr);
            return new RunStatementResult();
        }

        public static RunStatementResult RunReturnStatement(InterpreterState s, ReturnStatement st) {
            return new RunStatementResult { ShouldReturn = true, ReturnValue = st.Expr != null ? EvalExpression(s, st.Expr) : null };
        }

        public static object EvalExpression(InterpreterState s, object expr) {
            switch (expr) {
                case Token t: return EvalToken(s, t);
                case UnaryOperatorExpression e: return EvalUnaryOperatorExpression(s, e);
                case DotExpression e: return EvalDotExpression(s, e);
                case BinaryOperatorExpression e: return EvalBinaryOperatorExpression(s, e);
                case TernaryOperatorExpression e : return EvalTernaryOperatorExpression(s, e);
                case CallExpression e: return EvalCallExpression(s, e);
                case StructInitializerExpression e: return EvalStructInitializerExpression(s, e);
                case IndexExpression e: return EvalIndexExpression(s, e);
                default: throw new InvalidOperationException();
            }
        }

        public static object EvalToken(InterpreterState s, Token t) {
            if (t.Type == TokenType.StringLiteral || t.Type == TokenType.NumberLiteral || t.Type == TokenType.CharacterLiteral) {
                return t.AdditionalInfo;
            } else if (t.Type == TokenType.Identifier) {
                if (t.Value == "true") {
                    return true;
                } else if (t.Value == "false") {
                    return false;
                } else if (t.Value == "null") {
                    return null;
                }
                var local = GetLocalVar(s, t.Value);
                if (local != null) {
                    return local.Value;
                }
                if (!s.Current.Ns.Members.TryGetValue(t.Value, out object member)) {
                    member = s.Top.Members[t.Value];
                }
                if (member is Namespace) {
                    return member;
                }
                var sf = (StaticFieldDef)member;
                EnsureStaticFieldInitialized(s, sf);
                return sf.Value;
            }
            throw new InvalidOperationException();
        }

        public static object EvalUnaryOperatorExpression(InterpreterState s, UnaryOperatorExpression e) {
            switch (e.Op.Value) {
                case "!": return !(bool)EvalExpression(s, e.Expr);
                case "-": return -(long)EvalExpression(s, e.Expr);
                case "~": return ~(long)EvalExpression(s, e.Expr);
                case "new": return EvalExpression(s, e.Expr); // Ignore
                case "ref": return EvalExpression(s, e.Expr); // Ignore
                default: throw new InvalidOperationException();
            }
        }

        public static object EvalDotExpression(InterpreterState s, DotExpression e) {
            var lhs = EvalExpression(s, e.Lhs);
            var memberName = e.Rhs.Value;
            if (lhs is Namespace) {
                var mem = ((Namespace)lhs).Members[memberName];
                if (mem is StaticFieldDef) { 
                    var sf = (StaticFieldDef)mem;
                    EnsureStaticFieldInitialized(s, sf);
                    return sf.Value;
                } else if (mem is FunctionDef) {
                    return "fun<>__not__implemented";
                } else {
                    throw new InvalidOperationException();
                }
            }
            switch (memberName) {
                case "length": {
                        switch (lhs) {
                            case string a: return (long)a.Length;
                        }
                        break;
                    }
                case "count": {
                        switch (lhs) {
                            case object[] a: return (long)a.Length;
                            case List<object> a: return (long)a.Count;
                            case HashSet<object> a: return (long)a.Count;
                            case Map a: return (long)a.Dict.Count;
                        }
                        break;
                    }
            }
            return ((Dictionary<string, object>)lhs)[memberName];
        }

        public static object EvalBinaryOperatorExpression(InterpreterState s, BinaryOperatorExpression e) {
            switch (e.Op.Value) {
                case "=":
                case "+=":
                case "-=":
                case "*=":
                case "/=":
                case "%=":
                case "&=":
                case "|=":
                case "&&=":
                case "||=": {
                        var target = ResolveAssignTarget(s, e.Lhs);
                        var val = EvalExpression(s, e.Rhs);
                        Assign(s, e.Op.Value, target, val);
                        return null;
                    }
                case ":=": {
                        var variableName = ((Token)e.Lhs).Value;
                        AddLocalVar(s, variableName, EvalExpression(s, e.Rhs));
                        return null;
                    }
                case "+": return (long)EvalExpression(s, e.Lhs) + (long)EvalExpression(s, e.Rhs);
                case "-": {
                        var lhs = EvalExpression(s, e.Lhs);
                        switch (lhs) {
                            case char a: return (long)(a - (char)EvalExpression(s, e.Rhs));
                            case long a: return a - (long)EvalExpression(s, e.Rhs);
                            default: throw new InvalidOperationException();
                        }
                    }
                case "*": return (long)EvalExpression(s, e.Lhs) * (long)EvalExpression(s, e.Rhs);
                case "/": return (long)EvalExpression(s, e.Lhs) / (long)EvalExpression(s, e.Rhs);
                case "%": return (long)EvalExpression(s, e.Lhs) % (long)EvalExpression(s, e.Rhs);
                case "&": return (long)EvalExpression(s, e.Lhs) & (long)EvalExpression(s, e.Rhs);
                case "|": return (long)EvalExpression(s, e.Lhs) | (long)EvalExpression(s, e.Rhs);
                case "&&": return (bool)EvalExpression(s, e.Lhs) && (bool)EvalExpression(s, e.Rhs);
                case "||": return (bool)EvalExpression(s, e.Lhs) || (bool)EvalExpression(s, e.Rhs);
                case "==": return EvalCompareEqualsExpression(s, e);
                case "!=": return !EvalCompareEqualsExpression(s, e);
                case "<": return EvalCompareOrderedExpression(s, e);
                case ">": return EvalCompareOrderedExpression(s, e);
                case "<=": return EvalCompareOrderedExpression(s, e);
                case ">=": return EvalCompareOrderedExpression(s, e);
                default: throw new InvalidOperationException();
            }
        }

        public static bool EvalCompareEqualsExpression(InterpreterState s, BinaryOperatorExpression e) {
            var lhs = EvalExpression(s, e.Lhs);
            var rhs = EvalExpression(s, e.Rhs);
            if (rhs == null) {
                return lhs == null;
            }
            switch (lhs) {
                case string a: return string.Equals(a, (string)rhs);
                case long a: return a == (long)rhs;
                case bool a: return a == (bool)rhs;
                case char a: return a == (char)rhs;
                case Dictionary<string, object> a: {
                        var type = (Namespace)a["__type__"];
                        if (!type.IsRefType) {
                            throw new InvalidOperationException("Cannot compare struct values");
                        }
                        return a == rhs;
                    }
                case null: return rhs == null;
                default: throw new InvalidOperationException();
            }
        }

        public static bool EvalCompareOrderedExpression(InterpreterState s, BinaryOperatorExpression e) {
            var lhs = EvalExpression(s, e.Lhs);
            var rhs = EvalExpression(s, e.Rhs);
            if (lhs is ulong) {
                lhs = (long)(ulong)lhs;
            }
            if (rhs is ulong) {
                rhs = (long)(ulong)rhs;
            }
            int cmp;
            switch (lhs) {
                case string a: { cmp = string.Compare(a, (string)rhs); break; }
                case long a: { cmp = LongCompare(a, (long)rhs); break; }
                case char a: { cmp = CharCompare(a, (char)rhs); break; }
                default: throw new InvalidOperationException();
            }
            var op = e.Op.Value;
            switch (op) {
                case "<": return cmp < 0;
                case ">": return cmp > 0;
                case "<=": return cmp <= 0;
                case ">=": return cmp >= 0;
                default: throw new InvalidOperationException();
            }
        }

        public static int LongCompare(long a, long b) {
            if (a < b) {
                return -1;
            } else if (a > b) {
                return 1;
            } 
            return 0;
        }

        public static int CharCompare(char a, char b) {
            if (a < b) {
                return -1;
            } else if (a > b) {
                return 1;
            }
            return 0;
        }

        public static object EvalTernaryOperatorExpression(InterpreterState s, TernaryOperatorExpression e) {
            if ((bool)EvalExpression(s, e.ConditionExpr)) {
                return EvalExpression(s, e.First);
            } else {
                return EvalExpression(s, e.Second);
            }
        }

        public static object EvalCallExpression(InterpreterState s, CallExpression e) {
            var target = ResolveCallTarget(s, e.Target);
            FunctionDef func;
            var hasFirstArg = false;
            var firstArg = (object)null;
            var typeArgs = (TypeArgsExpression)null;
            switch (target) {
                case FunctionDef f: { func = f; break; }
                case BoundFunction f: { func = f.Func; hasFirstArg = true; firstArg = f.Instance; break; }
                case FunctionWithTypeArgs f: { func = f.Func; typeArgs = f.TypeArgs; break; }
                case BuiltinFunction.Identity: return EvalIdentity(s, e);
                case BuiltinFunction.Assert: return EvalAssert(s, e);
                case BuiltinFunction.Format: return EvalFormat(s, e);
                case BuiltinFunction.Transmute: return EvalTransmute(s, e);
                case BuiltinFunction.Min: return EvalMin(s, e);
                case BuiltinFunction.Max: return EvalMax(s, e);
                case BuiltinFunction.Cast: return EvalCast(s, e);
                case BoundBuiltinFunction bbf: {
                        switch (bbf.Func) {
                            case BuiltinFunction.As: return EvalAs(s, bbf.Instance, e);
                            case BuiltinFunction.Is: return EvalIs(s, bbf.Instance, e);
                            default: throw new InvalidOperationException();
                        }
                    }
                default: throw new InvalidOperationException();
            }
            var bias = hasFirstArg ? 1 : 0;
            var argCount = e.Args.Count + bias;
            if (func.Params.Count != argCount) {
                throw new InvalidOperationException(string.Format("Expected {0} arguments but got {1} arguments", func.Params.Count, argCount));
            }
            var prevFirstLocal = s.FirstLocalIndex;
            var prevCurrentLocal = s.Locals.Count;
            if (hasFirstArg) {
                s.Locals.Add(new LocalVariable { Name = func.Params[0].Name.Value, Value = firstArg });
            }
            for (int i = 0; i < e.Args.Count; i++) {
                s.Locals.Add(new LocalVariable { Name = func.Params[i + bias].Name.Value, Value = EvalExpression(s, e.Args[i]) });
            }
            s.FirstLocalIndex = prevCurrentLocal;
            s.Frames.Push(s.Current);
            var savedStatement = s.Debug_CurrentStatement;
            s.Debug_CurrentStatement = null;
            var result = EvalFunction(s, func, typeArgs);
            s.Debug_CurrentStatement = savedStatement;
            s.Current = s.Frames.Pop();
            s.Locals.SetSize(s.FirstLocalIndex);
            s.FirstLocalIndex = prevFirstLocal;
            return result;
        }

        public static object EvalStructInitializerExpression(InterpreterState s, StructInitializerExpression e) {
            var typename = GetTypename(e.Target);
            var type = (Namespace)s.Top.Members[typename];
            var inst = CreateInstance(s, type);
            if (e.Args.Count == 0) {
                return inst;
            }
            var result = (Dictionary<string, object>)inst;
            foreach (var fie in e.Args) {
                result.Update(fie.FieldName.Value, EvalExpression(s, fie.Expr));
            }
            return result;
        }

        public static object EvalIndexExpression(InterpreterState s, IndexExpression e) {
            var seq = EvalExpression(s, e.Target);
            var index = (int)(long)EvalExpression(s, e.Arg);
            switch (seq) {
                case string a: return a[index];
                case object[] a: return a[index];
                case List<object> a: return a[index];
                default: throw new InvalidOperationException();
            }
        }

        public static object ResolveCallTarget(InterpreterState s, object expr) {
            switch (expr) {
                case Token t: {
                        var local = GetLocalVar(s, t.Value);
                        if (local != null) {
                            return local.Value;
                        }
                        if (!s.Current.Ns.Members.TryGetValue(t.Value, out object member) || (member is FieldDef)) {
                            s.Top.Members.TryGetValue(t.Value, out member);
                        }
                        if (member is Namespace) {
                            var ns = (Namespace)member;
                            if (ns.Kind == NamespaceKind.TaggedPointerEnum) {
                                return BuiltinFunction.Identity;
                            } else { 
                                return GetConstructor(ns);
                            }
                        } else if (member != null) { 
                            return member;
                        }
                        if (t.Value == "assert") {
                            return BuiltinFunction.Assert;
                        } else if (t.Value == "format") {
                            return BuiltinFunction.Format;
                        } else if (t.Value == "transmute") {
                            return BuiltinFunction.Transmute;
                        } else if (t.Value == "min") {
                            return BuiltinFunction.Min;
                        } else if (t.Value == "max") {
                            return BuiltinFunction.Max;
                        } else if (t.Value == "cast") {
                            return BuiltinFunction.Cast;
                        }
                        throw new InvalidOperationException();
                    }
                case DotExpression e: {
                        var lhs = EvalExpression(s, e.Lhs);
                        var memberName = e.Rhs.Value;
                        if (lhs is Namespace) {
                            return ((Namespace)lhs).Members[memberName];
                        }
                        if (memberName == "as") {
                            return new BoundBuiltinFunction { Func = BuiltinFunction.As, Instance = lhs };
                        } else if (memberName == "is") {
                            return new BoundBuiltinFunction { Func = BuiltinFunction.Is, Instance = lhs };
                        }
                        var type = GetTypeOfInstance(s, lhs);
                        var func = (FunctionDef)type.Members[memberName];
                        return new BoundFunction { Instance = lhs, Func = func };
                    }
                case TypeArgsExpression e: {
                        if (e.Target is DotExpression) {
                            var func = (FunctionDef)ResolveCallTarget(s, e.Target);
                            return new FunctionWithTypeArgs { Func = func, TypeArgs = e };
                        }
                        var typename = GetTypename(e.Target);
                        var type = (Namespace)s.Top.Members[typename];
                        return new FunctionWithTypeArgs { Func = GetConstructor(type), TypeArgs = e };
                    }
                default: throw new InvalidOperationException();
            }
        }

        public static FunctionDef GetConstructor(Namespace type) {
            if (type.Kind != NamespaceKind.Struct) {
                throw new InvalidOperationException();
            }
            return (FunctionDef)type.Members["cons"];
        }

        public static object ResolveAssignTarget(InterpreterState s, object expr) {
            switch (expr) {
                case Token t: {
                        var local = GetLocalVar(s, t.Value);
                        if (local != null) {
                            return local;
                        }
                        if (s.Current.Ns.Members.TryGetValue(t.Value, out object member) && !(member is FieldDef)) {
                            return member;
                        }
                        return s.Top.Members[t.Value];
                    }
                case TypeModifierExpression e: {
                        if (e.Modifier.Value != "::") {
                            throw new InvalidOperationException();
                        }
                        return s.Top.Members[((Token)e.Arg).Value];
                    }
                case DotExpression e: {
                        var lhs = EvalExpression(s, e.Lhs);
                        if (lhs is Namespace) {
                            return ((Namespace)lhs).Members[e.Rhs.Value];
                        }
                        var type = GetTypeOfInstance(s, lhs);
                        var field = (FieldDef)type.Members[e.Rhs.Value];
                        return new BoundField { Instance = lhs, Field = field };
                    }
                case IndexExpression e: {
                        var target = EvalExpression(s, e.Target);
                        var index = (long)EvalExpression(s, e.Arg);
                        return new BoundElement { Instance = target, Index = index };
                    }
                default: throw new InvalidOperationException();
            }
        }

        public static void Assign(InterpreterState s, string op, object target, object val) {
            switch (target) {
                case LocalVariable local: {
                        switch (op) {
                            case "=": { local.Value = val; break; }
                            case "+=": { local.Value = (long)local.Value + (long)val; break; }
                            case "-=": { local.Value = (long)local.Value - (long)val; break; }
                            case "*=": { local.Value = (long)local.Value * (long)val; break; }
                            case "/=": { local.Value = (long)local.Value / (long)val; break; }
                            case "%=": { local.Value = (long)local.Value % (long)val; break; }
                            case "&=": { local.Value = (long)local.Value & (long)val; break; }
                            case "|=": { local.Value = (long)local.Value | (long)val; break; }
                            case "&&=": { local.Value = (bool)local.Value && (bool)val; break; }
                            case "||=": { local.Value = (bool)local.Value || (bool)val; break; }
                            default: throw new InvalidOperationException();
                        }
                        break;
                    }
                case BoundField bf: {
                        var dict = (Dictionary<string, object>)bf.Instance;
                        var fieldName = bf.Field.Name.Value;
                        switch (op) {
                            case "=": { dict.Update(fieldName, val); break; }
                            case "+=": { dict.Update(fieldName, (long)dict[fieldName] + (long)val); break; }
                            case "-=": { dict.Update(fieldName, (long)dict[fieldName] - (long)val); break; }
                            case "*=": { dict.Update(fieldName, (long)dict[fieldName] * (long)val); break; }
                            case "/=": { dict.Update(fieldName, (long)dict[fieldName] / (long)val); break; }
                            case "%=": { dict.Update(fieldName, (long)dict[fieldName] % (long)val); break; }
                            case "&=": { dict.Update(fieldName, (long)dict[fieldName] & (long)val); break; }
                            case "|=": { dict.Update(fieldName, (long)dict[fieldName] | (long)val); break; }
                            case "&&=": { dict.Update(fieldName, (bool)dict[fieldName] && (bool)val); break; }
                            case "||=": { dict.Update(fieldName, (bool)dict[fieldName] || (bool)val); break; }
                            default: throw new InvalidOperationException();
                        }
                        break;
                    }
                case BoundElement be: {
                        var index = (int)be.Index;
                        switch (be.Instance) {
                            case object[] a: {
                                    switch (op) {
                                        case "=": { a[index] = val; break; }
                                        case "+=": { a[index] = (long)a[index] + (long)val; break; }
                                        case "-=": { a[index] = (long)a[index] - (long)val; break; }
                                        default: throw new InvalidOperationException();
                                    }
                                    break;
                                }
                            case List<object> a: {
                                    switch (op) {
                                        case "=": { a[index] = val; break; }
                                        case "+=": { a[index] = (long)a[index] + (long)val; break; }
                                        case "-=": { a[index] = (long)a[index] - (long)val; break; }
                                        default: throw new InvalidOperationException();
                                    }
                                    break;
                                }
                            default: throw new InvalidOperationException();
                        }
                        break;
                    }
                case StaticFieldDef sf: {
                        sf.IsInitialized = true;
                        switch (op) {
                            case "=": { sf.Value = val; break; }
                            default: throw new InvalidOperationException();
                        }
                        break;
                    }
                default: throw new InvalidOperationException();
            }
        }

        public static Namespace GetTypeOfInstance(InterpreterState s, object value) {
            switch (value) {
                case long a: return (Namespace)s.Top.Members["long"];
                case string a: return (Namespace)s.Top.Members["string"];
                case char a: return (Namespace)s.Top.Members["char"];
                case bool a: return (Namespace)s.Top.Members["bool"];
                case Dictionary<string, object> a: return (Namespace)a["__type__"];
                case StringBuilder a: return (Namespace)s.Top.Members["StringBuilder"];
                case object[] a: return (Namespace)s.Top.Members["Array"];
                case List<object> a: return (Namespace)s.Top.Members["List"];
                case HashSet<object> a: return (Namespace)s.Top.Members["Set"];
                case Map a: return (Namespace)s.Top.Members["Map"];
                default: throw new InvalidOperationException();
            }
        }

        public static object CreateInstance(InterpreterState s, Namespace type) {
            if (type.Name == "StringBuilder") {
                return new StringBuilder();
            }
            if (type.Name == "Array") {
                throw new InvalidOperationException("Must use Array.cons to create an Array instance");
            }
            if (type.Name == "List") {
                return new List<object>();
            }
            if (type.Name == "Set") {
                throw new InvalidOperationException("Must use Set.create to create a Set instance");
            }
            if (type.Name == "Map") {
                throw new InvalidOperationException("Must use Map.create to create a Map instance");
            }
            var result = new Dictionary<string, object>();
            result["__type__"] = type;
            foreach (var p in type.Members) {
                if (p.Value is FieldDef) {
                    var fd = (FieldDef)p.Value;
                    result[fd.Name.Value] = GetDefaultValue(s, GetTypename(fd.Type));
                }
            }
            return result;
        }

        public static string GetTypename(object typeExpr) {
            switch (typeExpr) {
                case Token t: return t.Value;
                case TypeModifierExpression tme: return ((Token)tme.Arg).Value;
                case TypeArgsExpression tae: return ((Token)tae.Target).Value;
                default: throw new InvalidOperationException();
            }
        }

        public static object GetDefaultValue(InterpreterState s, string typename) {
            switch (typename) {
                case "int": return (long)0;
                case "uint": return (long)0;
                case "long": return (long)0;
                case "ulong": return (ulong)0;
                case "string": return "";
                case "pointer": return null;
                case "double": return (double)0;
                case "bool": return false;
                case "char": return '\0';
                default: {
                        if (s.Top.Members.TryGetValue(typename, out object typeObject)) {
                            var type = (Namespace)typeObject;
                            if (type.Kind == NamespaceKind.Struct) {
                                if (!type.IsRefType) {
                                    return CreateInstance(s, type);
                                } else {
                                    return null;
                                }
                            } else if (type.Kind == NamespaceKind.Enum) {
                                return (long)0;
                            } else if (type.Kind == NamespaceKind.TaggedPointerEnum) {
                                return null;
                            } else {
                                throw new InvalidOperationException();
                            }
                        } else if (typename.Length == 1 && char.IsUpper(typename[0])) {
                            return null; // Generic type, just return null and hope for the best.
                        } else {
                            throw new InvalidOperationException();
                        }
                    }
            }
        }

        public static void EnsureStaticFieldInitialized(InterpreterState s, StaticFieldDef sf) {
            if (sf.IsInitialized) {
                return;                
            }
            if (sf.InitializerExpr != null) {
                var pushedFrame = false;
                var sfNs = sf.Parent != null ? sf.Parent.Ns : s.Top;
                if (s.Current.Ns != sfNs) {
                    s.Frames.Push(s.Current);
                    s.Current = new Frame { Ns = sfNs };
                    pushedFrame = true;
                }
                sf.Value = EvalExpression(s, sf.InitializerExpr);
                if (pushedFrame) {
                    s.Current = s.Frames.Pop();
                }
            } else if (sf.Type != null) {
                sf.Value = GetDefaultValue(s, GetTypename(sf.Type));
            }
            sf.IsInitialized = true;
        }

        public static LocalVariable AddLocalVar(InterpreterState s, string name, object value) {
            for (var i = s.FirstLocalIndex; i < s.Locals.Count; i++) {
                if (s.Locals[i].Name == name) {
                    throw new InvalidOperationException("Variable is already defined");
                }
            }
            var local = new LocalVariable { Name = name, Value = value };
            s.Locals.Add(local);
            return local;
        }

        public static LocalVariable GetLocalVar(InterpreterState s, string name) {
            for (var i = s.FirstLocalIndex; i < s.Locals.Count; i++) {
                if (s.Locals[i].Name == name) {
                    return s.Locals[i];
                }
            }
            return null;
        }

        public static object EvalInternalFunction(InterpreterState s, FunctionDef func, TypeArgsExpression typeArgs) {
            switch (func.InternalName) {
                case "int.parse": {
                        return (long)int.Parse((string)s.Locals[s.FirstLocalIndex].Value);
                    }
                case "long.toString": {
                        return ((long)s.Locals[s.FirstLocalIndex].Value).ToString();
                    }
                case "char.toString": {
                        return ((char)s.Locals[s.FirstLocalIndex].Value).ToString();
                    }
                case "string.slice": {
                        var str = (string)s.Locals[s.FirstLocalIndex].Value;
                        var from = (int)(long)(s.Locals[s.FirstLocalIndex + 1].Value);
                        var to = (int)(long)(s.Locals[s.FirstLocalIndex + 2].Value);
                        return str.Slice(from, to);
                    }
                case "Stdout.writeLine": {
                        Console.WriteLine((string)s.Locals[s.FirstLocalIndex].Value);
                        return null;
                    }
                case "Environment.getCommandLineArgs": {
                        return s.FakeCommandLineArgs.Select(a => (object)a).ToArray();
                    }
                case "Environment.runCommandSync": {
                        // TODO: Fix extremely hacky code
                        var cmd = (string)s.Locals[s.FirstLocalIndex].Value;
                        if (cmd[0] == '"' && cmd[cmd.Length - 1] == '"') {
                            cmd = cmd.Slice(1, cmd.Length - 1);
                        }
                        var p = new System.Diagnostics.Process();
                        var exeIndex = cmd.IndexOf(".exe");
                        if (exeIndex < 0) {
                            throw new InvalidOperationException();
                        }
                        exeIndex += 4;
                        if (cmd[exeIndex] == '"') {
                            exeIndex += 1;
                        }
                        p.StartInfo.FileName = cmd.Slice(0, exeIndex);
                        p.StartInfo.Arguments = cmd.Slice(exeIndex, cmd.Length);
                        p.StartInfo.UseShellExecute = false;
                        p.StartInfo.RedirectStandardOutput = true;
                        p.StartInfo.RedirectStandardError = true;
                        p.OutputDataReceived += (sender, args) => Console.WriteLine(args.Data);
                        if (!p.Start()) {
                            throw new InvalidOperationException();
                        }
                        p.BeginOutputReadLine();
                        p.BeginErrorReadLine();
                        p.WaitForExit();                        
                        return (long)p.ExitCode;
                    }
                case "Environment.exit": {
                        var exitCode = (long)s.Locals[s.FirstLocalIndex].Value;
                        Environment.Exit((int)exitCode);
                        return null;
                    }
                case "Debug.break": {
                        System.Diagnostics.Debugger.Break();
                        return null;
                    }
                case "File.tryReadToStringBuilder": {
                        var path = (string)s.Locals[s.FirstLocalIndex].Value;
                        var out_ = (StringBuilder)s.Locals[s.FirstLocalIndex + 1].Value;
                        using (var reader = new System.IO.StreamReader(path)) {
                            out_.Append(reader.ReadToEnd());
                        }
                        return true;
                    }
                case "File.tryWriteString": {
                        var path = (string)s.Locals[s.FirstLocalIndex].Value;
                        var contents = (string)s.Locals[s.FirstLocalIndex + 1].Value;
                        using (var writer = new System.IO.StreamWriter(path)) {
                            writer.Write(contents);
                        }
                        return true;
                    }
                case "StringBuilder.write": {
                        var self = (StringBuilder)s.Locals[s.FirstLocalIndex].Value;
                        var value = (string)s.Locals[s.FirstLocalIndex + 1].Value;
                        self.Append(value);
                        return null;
                    }
                case "StringBuilder.writeChar": {
                        var self = (StringBuilder)s.Locals[s.FirstLocalIndex].Value;
                        var value = (char)s.Locals[s.FirstLocalIndex + 1].Value;
                        self.Append(value);
                        return null;
                    }
                case "StringBuilder.toString": {
                        var self = (StringBuilder)s.Locals[s.FirstLocalIndex].Value;                        
                        return self.ToString();
                    }
                case "StringBuilder.compactToString": {
                        var self = (StringBuilder)s.Locals[s.FirstLocalIndex].Value;
                        return self.ToString();
                    }
                case "StringBuilder.clear": {
                        var self = (StringBuilder)s.Locals[s.FirstLocalIndex].Value;
                        self.Clear();
                        return null;
                    }
                case "Array.cons": {
                        if (typeArgs.Args.Count != 1) {
                            throw new InvalidOperationException();
                        }
                        var elementTypename = GetTypename(typeArgs.Args[0]);
                        var result = new object[(int)(long)s.Locals[s.FirstLocalIndex].Value];
                        for (int i = 0; i < result.Length; i++) {
                            result[i] = GetDefaultValue(s, elementTypename);
                        }
                        return result;
                    }
                case "Array.stableSort": {
                        var self = (object[])s.Locals[s.FirstLocalIndex].Value;
                        // Ignore
                        return null;
                    }
                case "List.add": {
                        var self = (List<object>)s.Locals[s.FirstLocalIndex].Value;
                        var item = s.Locals[s.FirstLocalIndex + 1].Value;
                        self.Add(item);
                        return null;
                    }
                case "List.setCountChecked": {
                        var self = (List<object>)s.Locals[s.FirstLocalIndex].Value;
                        var count = (int)(long)(s.Locals[s.FirstLocalIndex + 1].Value);
                        self.RemoveRange(count, self.Count - count);
                        return null;
                    }
                case "List.clear": {
                        var self = (List<object>)s.Locals[s.FirstLocalIndex].Value;
                        self.Clear();
                        return null;
                    }
                case "List.slice": {
                        var self = (List<object>)s.Locals[s.FirstLocalIndex].Value;
                        var from = (int)(long)(s.Locals[s.FirstLocalIndex + 1].Value);
                        var to = (int)(long)(s.Locals[s.FirstLocalIndex + 2].Value);
                        var result = new object[to - from];
                        for (int i = 0; i < result.Length; i++) {
                            result[i] = self[i - from];
                        }
                        return result;
                    }
                case "Set.create":
                case "CustomSet.create": {
                        if (typeArgs.Args.Count != 1) {
                            throw new InvalidOperationException();
                        }
                        var valueTypename = GetTypename(typeArgs.Args[0]);
                        if (valueTypename == "string") {
                            return new HashSet<object>(new StringComparer());
                        } else if (valueTypename == "int") {
                            return new HashSet<object>(new LongComparer());
                        } else if (valueTypename == "Tag") {
                            return new HashSet<object>(new TagComparer());
                        } else if (valueTypename == "Array") { // This is really just a huge hack
                            return new HashSet<object>(new TagArgsComparer());
                        } else {
                            return new HashSet<object>();
                        }
                    }
                case "Set.add":
                case "CustomSet.add": {
                        var self = (HashSet<object>)s.Locals[s.FirstLocalIndex].Value;
                        var value = s.Locals[s.FirstLocalIndex + 1].Value;
                        if (!self.Add(value)) {
                            throw new InvalidOperationException("Already present");
                        }
                        return null;
                    }
                case "Set.tryAdd":
                case "CustomSet.tryAdd": {
                        var self = (HashSet<object>)s.Locals[s.FirstLocalIndex].Value;
                        var value = s.Locals[s.FirstLocalIndex + 1].Value;
                        return self.Add(value);
                    }
                case "Set.contains":
                case "CustomSet.contains": {
                        var self = (HashSet<object>)s.Locals[s.FirstLocalIndex].Value;
                        var value = s.Locals[s.FirstLocalIndex + 1].Value;
                        return self.Contains(value);
                    }
                case "Set.remove":
                case "CustomSet.remove": {
                        var self = (HashSet<object>)s.Locals[s.FirstLocalIndex].Value;
                        var value = s.Locals[s.FirstLocalIndex + 1].Value;
                        if (!self.Remove(value)) {
                            throw new InvalidOperationException("Not found");
                        }
                        return null;
                    }
                case "Set.clear":
                case "CustomSet.clear": {
                        var self = (HashSet<object>)s.Locals[s.FirstLocalIndex].Value;
                        self.Clear();
                        return null;
                    }
                case "Map.create": {
                        if (typeArgs.Args.Count != 2) {
                            throw new InvalidOperationException();
                        }
                        var keyTypename = GetTypename(typeArgs.Args[0]);
                        var valueTypename = GetTypename(typeArgs.Args[1]);
                        if (keyTypename == "string") {
                            return new Map { Dict = new Dictionary<object, object>(new StringComparer()), ValueTypename = valueTypename };
                        } else if (keyTypename == "int") {
                            return new Map { Dict = new Dictionary<object, object>(new LongComparer()), ValueTypename = valueTypename };
                        } else {
                            return new Map { Dict = new Dictionary<object, object>(), ValueTypename = valueTypename };
                        }
                    }
                case "Map.add": {
                        var self = (Map)s.Locals[s.FirstLocalIndex].Value;
                        var key = s.Locals[s.FirstLocalIndex + 1].Value;
                        var value = s.Locals[s.FirstLocalIndex + 2].Value;
                        self.Dict.Add(key, value);
                        return null;
                    }
                case "Map.tryAdd": {
                        var self = (Map)s.Locals[s.FirstLocalIndex].Value;
                        var key = s.Locals[s.FirstLocalIndex + 1].Value;
                        var value = s.Locals[s.FirstLocalIndex + 2].Value;
                        if (!self.Dict.ContainsKey(key)) {
                            self.Dict.Add(key, value);
                            return true;
                        } else { 
                            return false;
                        }
                    }
                case "Map.addOrUpdate": {
                        var self = (Map)s.Locals[s.FirstLocalIndex].Value;
                        var key = s.Locals[s.FirstLocalIndex + 1].Value;
                        var value = s.Locals[s.FirstLocalIndex + 2].Value;
                        self.Dict[key] = value;
                        return null;
                    }
                case "Map.update": {
                        var self = (Map)s.Locals[s.FirstLocalIndex].Value;
                        var key = s.Locals[s.FirstLocalIndex + 1].Value;
                        var value = s.Locals[s.FirstLocalIndex + 2].Value;
                        if (!self.Dict.ContainsKey(key)) {
                            throw new InvalidOperationException();
                        }
                        self.Dict[key] = value;
                        return null;
                    }
                case "Map.get": {
                        var self = (Map)s.Locals[s.FirstLocalIndex].Value;
                        var key = s.Locals[s.FirstLocalIndex + 1].Value;
                        if (!self.Dict.TryGetValue(key, out object value)) {
                            throw new InvalidOperationException();
                        }
                        return value;
                    }
                case "Map.getOrDefault": {
                        var self = (Map)s.Locals[s.FirstLocalIndex].Value;
                        var key = s.Locals[s.FirstLocalIndex + 1].Value;
                        if (!self.Dict.TryGetValue(key, out object value)) {
                            switch (self.ValueTypename) {
                                case "string": return "";
                                case "int":
                                case "long": {
                                        return (long)0;
                                    }
                                default: return null;
                            }
                        }
                        return value;
                    }
                case "Map.maybeGet": {
                        var self = (Map)s.Locals[s.FirstLocalIndex].Value;
                        var key = s.Locals[s.FirstLocalIndex + 1].Value;
                        var maybe = (Dictionary<string, object>)CreateInstance(s, (Namespace)s.Top.Members["Maybe"]);
                        if (self.Dict.TryGetValue(key, out object value)) {
                            maybe["value"] = value;
                            maybe["hasValue"] = true;
                        }
                        return maybe;
                    }
                case "Map.remove": {
                        var self = (Map)s.Locals[s.FirstLocalIndex].Value;
                        var key = s.Locals[s.FirstLocalIndex + 1].Value;
                        if (!self.Dict.Remove(key)) {
                            throw new InvalidOperationException("Not found");
                        }
                        return null;
                    }
                case "Map.clear": {
                        var self = (Map)s.Locals[s.FirstLocalIndex].Value;
                        self.Dict.Clear();
                        return null;
                    }
                case "Memory.newArenaAllocator": {
                        return null;
                    }
                case "CpuTimeStopwatch.start": {
                        return null;
                    }
                case "CpuTimeStopwatch.elapsed": {
                        return (double)0;
                    }
                default: throw new ArgumentException();
            }
        }

        public class StringComparer : IEqualityComparer<object> {
            public new bool Equals(object x, object y) {
                return string.Equals((string)x, (string)y);
            }

            public int GetHashCode(object obj) {
                return ((string)obj).GetHashCode();
            }
        }

        public class LongComparer : IEqualityComparer<object> {
            public new bool Equals(object x, object y) {
                return (long)x == (long)y;
            }

            public int GetHashCode(object obj) {
                return ((long)obj).GetHashCode();
            }
        }

        public class TagComparer : IEqualityComparer<object> {
            public new bool Equals(object x, object y) {
                return Static_Equals(x, y);
            }

            public static bool Static_Equals(object x, object y) {
                var a = (Dictionary<string, object>)x;
                var b = (Dictionary<string, object>)y;
                if (a["ti"] != b["ti"]) {
                    return false;
                }
                return Static_ArgsEquals(a["args"], b["args"]);
            }

            public static bool Static_ArgsEquals(object x, object y) {
                var aArgs = (object[])x;
                var bArgs = (object[])y;
                if (aArgs == null && bArgs == null) {
                    return true;
                }
                if (aArgs == null || bArgs == null) {
                    return false;
                }
                if (aArgs.Length != bArgs.Length) {
                    return false;
                }
                for (int i = 0; i < aArgs.Length; i++) {
                    if (!Static_Equals(aArgs[i], bArgs[i])) {
                        return false;
                    }
                }
                return true;
            }

            public int GetHashCode(object obj) {
                return Static_GetHashCode(obj);
            }

            public static int Static_GetHashCode(object obj) {
                var x = (Dictionary<string, object>)obj;
                var ti = (Dictionary<string, object>)x["ti"];
                return ((string)ti["name"]).GetHashCode();
            }
        }

        public class TagArgsComparer : IEqualityComparer<object> {
            public new bool Equals(object x, object y) {
                return TagComparer.Static_ArgsEquals(x, y);
            }

            public int GetHashCode(object obj) {
                var args = (object[])obj;
                int hash = 0;
                foreach (var tag in args) {
                    hash ^= TagComparer.Static_GetHashCode(tag);
                    hash <<= 5;
                }
                return hash;
            }
        }

        public static object EvalIdentity(InterpreterState s, CallExpression e) {
            if (e.Args.Count != 1) {
                throw new InvalidOperationException();
            }
            return EvalExpression(s, e.Args[0]);
        }

        public static object EvalAssert(InterpreterState s, CallExpression e) {
            if (e.Args.Count != 1) {
                throw new InvalidOperationException();
            }
            if (!(bool)EvalExpression(s, e.Args[0])) {
                throw new InvalidOperationException("Assertion failed");
            }
            return null;
        }

        public static object EvalAs(InterpreterState s, object lhs, CallExpression e) {
            if (e.Args.Count != 1) {
                throw new InvalidOperationException();
            }
            var lhsType = GetTypeOfInstance(s, lhs);
            var rhsType = (Namespace)EvalExpression(s, e.Args[0]);
            if (lhsType != rhsType) {
                throw new InvalidOperationException("Invalid cast");
            }
            return lhs;
        }

        public static object EvalIs(InterpreterState s, object lhs, CallExpression e) {
            if (e.Args.Count != 1) {
                throw new InvalidOperationException();
            }
            if (lhs == null) {
                return false;
            }
            var lhsType = GetTypeOfInstance(s, lhs);
            var rhsType = (Namespace)EvalExpression(s, e.Args[0]);
            return lhsType == rhsType;
        }

        public static object EvalFormat(InterpreterState s, CallExpression e) {
            if (e.Args.Count < 1) {
                throw new InvalidOperationException();
            }
            var rb = new StringBuilder();
            var formatString = (string)EvalExpression(s, e.Args[0]);
            var arg = 1;
            var i = 0;
            while (i < formatString.Length) {
                var ch = formatString[i];
                if (ch == '{') {
                    i += 1;
                    ch = formatString[i];
                    if (ch == '}') {
                        var val = EvalExpression(s, e.Args[arg]);
                        switch (val) {
                            case char a: { rb.Append(a); break; }
                            case bool a: { rb.Append(a ? "true" : "false"); break; }
                            case long a: { rb.Append(a); break; }
                            case ulong a: { rb.Append(a); break; }
                            case string a: { rb.Append(a); break; }
                            default: throw new InvalidOperationException();
                        }
                        arg += 1;
                    } else if (ch == '{') {
                        rb.Append('{');
                    } else {
                        throw new InvalidOperationException("Invalid format string");
                    }                    
                } else if (ch == '}') {
                    i += 1;
                    ch = formatString[i];
                    if (ch == '}') {
                        rb.Append(ch);
                    } else {
                        throw new InvalidOperationException("Invalid format string");
                    }
                } else {
                    rb.Append(ch);
                }
                i += 1;
            }
            if (arg < e.Args.Count) {
                throw new InvalidOperationException("Too many arguments");
            }
            return rb.ToString();
        }

        public static object EvalTransmute(InterpreterState s, CallExpression e) {
            if (e.Args.Count != 2) {
                throw new InvalidOperationException();
            }
            var value = EvalExpression(s, e.Args[0]);
            var targetType = (Namespace)EvalExpression(s, e.Args[1]);
            switch (targetType.Name) {
                case "int": return (long)(char)value;
                case "char": return (char)(long)value;
                case "long": return value;
                case "ulong": return value;
                default: throw new InvalidOperationException();
            }
        }

        public static object EvalMin(InterpreterState s, CallExpression e) {
            if (e.Args.Count != 2) {
                throw new InvalidOperationException();
            }
            var lhs = (long)EvalExpression(s, e.Args[0]);
            var rhs = (long)EvalExpression(s, e.Args[1]);
            return Math.Min(lhs, rhs);
        }

        public static object EvalMax(InterpreterState s, CallExpression e) {
            if (e.Args.Count != 2) {
                throw new InvalidOperationException();
            }
            var lhs = (long)EvalExpression(s, e.Args[0]);
            var rhs = (long)EvalExpression(s, e.Args[1]);
            return Math.Max(lhs, rhs);
        }

        public static object EvalCast(InterpreterState s, CallExpression e) {
            if (e.Args.Count != 2) {
                throw new InvalidOperationException();
            }
            return EvalExpression(s, e.Args[0]);
        }
    }

    public class Map {
        public Dictionary<object, object> Dict;
        public string ValueTypename;
    }
}
