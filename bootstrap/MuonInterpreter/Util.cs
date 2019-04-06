using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MuonInterpreter {
    public static class Extensions {
        public static string Slice(this string s, int from, int to) {
            return s.Substring(from, to - from);
        }

        public static void SetSize<T>(this List<T> list, int size) {
            list.RemoveRange(size, list.Count - size);
        }

        public static void Update<K, V>(this Dictionary<K, V> dictionary, K key, V value) {
            if (!dictionary.ContainsKey(key)) {
                throw new KeyNotFoundException();
            }
            dictionary[key] = value;
        }

        public static void Debug(this InterpreterState state) {
            var funcName = string.Format("(in {0}.{1})", state.Current.Ns.Name, state.Current.Func.Name.Value);
            var unit = state.Current.Func.Unit;
            var statementIndex = RangeFinder.Find(state.Debug_CurrentStatement).From;
            System.Diagnostics.Debug.WriteLine(ErrorHelper.GetErrorDesc(unit.Filename, unit.Source, statementIndex, funcName));
        }
    }

    public struct IntRange {
        public int From;
        public int To;

        public IntRange(int from, int to) {
            From = from;
            To = to;
        }
    }

    public class UnreachableException : Exception {
    }
}
