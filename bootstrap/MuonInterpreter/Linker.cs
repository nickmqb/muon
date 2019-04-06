using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MuonInterpreter {
    public class Program {
        public Namespace Top;
    }

    public class Namespace {
        public string Name;
        public Dictionary<string, object> Members;
        public NamespaceKind Kind;
        public bool IsRefType;
        public bool IsFlagsEnum;
        public long NextEnumValue;
    }

    public class Linker {
        public static Program Link(CodeUnit[] units) {
            var result = new Program { Top = new Namespace { Name = "top__", Members = new Dictionary<string, object>() } };
            foreach (var u in units) {
                AddUnit(result, u);
            }
            SetInternal(result, "int", "parse");
            SetInternal(result, "long", "toString");
            SetInternal(result, "char", "toString");
            SetInternal(result, "string", "slice");
            SetInternal(result, "Stdout", "writeLine");
            SetInternal(result, "Environment", "getCommandLineArgs");
            SetInternal(result, "Environment", "runCommandSync");
            SetInternal(result, "Environment", "exit");
            SetInternal(result, "Debug", "break");
            SetInternal(result, "File", "tryReadToStringBuilder");
            SetInternal(result, "File", "tryWriteString");
            SetInternal(result, "StringBuilder", "write");
            SetInternal(result, "StringBuilder", "writeChar");
            SetInternal(result, "StringBuilder", "toString");
            SetInternal(result, "StringBuilder", "compactToString");
            SetInternal(result, "StringBuilder", "clear");
            SetInternal(result, "Array", "cons");
            SetInternal(result, "Array", "stableSort");
            SetInternal(result, "List", "add");
            SetInternal(result, "List", "clear");
            SetInternal(result, "List", "setCountChecked");
            SetInternal(result, "List", "slice");
            SetInternal(result, "Set", "create");
            SetInternal(result, "Set", "add");
            SetInternal(result, "Set", "tryAdd");
            SetInternal(result, "Set", "contains");
            SetInternal(result, "Set", "remove");
            SetInternal(result, "Set", "clear");
            SetInternal(result, "CustomSet", "create");
            SetInternal(result, "CustomSet", "add");
            SetInternal(result, "CustomSet", "tryAdd");
            SetInternal(result, "CustomSet", "contains");
            SetInternal(result, "CustomSet", "remove");
            SetInternal(result, "CustomSet", "clear");
            SetInternal(result, "Map", "create");
            SetInternal(result, "Map", "add");
            SetInternal(result, "Map", "tryAdd");
            SetInternal(result, "Map", "addOrUpdate");
            SetInternal(result, "Map", "update");
            SetInternal(result, "Map", "get");
            SetInternal(result, "Map", "getOrDefault");
            SetInternal(result, "Map", "maybeGet");
            SetInternal(result, "Map", "clear");
            SetInternal(result, "Map", "remove");
            SetInternal(result, "Memory", "newArenaAllocator");
            SetInternal(result, "CpuTimeStopwatch", "start");
            SetInternal(result, "CpuTimeStopwatch", "elapsed");
            return result;
        }

        public static void AddUnit(Program p, CodeUnit u) {
            foreach (var it in u.Contents) {
                AddItem(p.Top, it);
            }
        }

        public static void AddItem(Namespace parent, object item) {
            switch (item) {
                case FunctionDef f: parent.Members.Add(f.Name.Value, f); break;
                case StaticFieldDef f: {
                        parent.Members.Add(f.Name.Value, f);
                        if (f.IsEnumOption && f.InitializerExpr == null) {
                            f.Value = parent.NextEnumValue;
                            if (parent.IsFlagsEnum) {
                                parent.NextEnumValue *= 2;
                            } else {
                                parent.NextEnumValue += 1;
                            }
                            f.IsInitialized = true;
                        }
                        break;
                    }
                case FieldDef f: parent.Members.Add(f.Name.Value, f); break;
                case TaggedPointerOptionDef v: break;
                case NamespaceDef nd: {
                        Namespace ns;
                        object nsObject;
                        if (!parent.Members.TryGetValue(nd.Name.Value, out nsObject)) {
                            ns = new Namespace { Name = nd.Name.Value, Kind = nd.Kind, Members = new Dictionary<string, object>() };
                            parent.Members.Add(nd.Name.Value, ns);
                        } else {
                            ns = (Namespace)nsObject;
                            if (ns.Kind != NamespaceKind.Default && nd.Kind != NamespaceKind.Default) {
                                throw new InvalidOperationException("Cannot merge namespace declarations");
                            }
                            if (ns.Kind == NamespaceKind.Default) {
                                ns.Kind = nd.Kind;
                            }
                        }
                        nd.Ns = ns;
                        if (nd.Attributes != null) { 
                            foreach (var a in nd.Attributes) {
                                if (a.Name.Value == "RefType") {
                                    ns.IsRefType = true;
                                }
                                if (a.Name.Value == "Flags") {
                                    ns.IsFlagsEnum = true;
                                    ns.NextEnumValue = 1;
                                }
                            }
                        }
                        foreach (var it in nd.Contents) {
                            AddItem(ns, it);
                        }
                        break;
                    }
                default: throw new InvalidOperationException();
            }
        }

        public static void SetInternal(Program p, string namespaceName, string funcName) {
            if (!p.Top.Members.TryGetValue(namespaceName, out object nsObject)) {
                return;
            }
            var ns = (Namespace)nsObject;
            if (!ns.Members.TryGetValue(funcName, out object memberObject)) {
                return;
            }
            var func = (FunctionDef)memberObject;
            func.InternalName = string.Format("{0}.{1}", namespaceName, funcName);
        }
    }
}
