using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MuonInterpreter {
    public static class ErrorHelper {
        public static string GetErrorDesc(string filename, string source, int index, string message) {
            var li = IndexToLocationInfo(source, index);
            var numTabs = li.Line.Slice(0, li.Column).Count(ch => ch == '\t');
            var indent = li.Column - numTabs + 4 * numTabs;
            return string.Format("{0}:{1}\n{2}\n{3}\n{4}", filename, li.LineNumber, li.Line.Replace("\t", "    "), new string(' ', indent) + "^", message);
        }

        public class LocationInfo {
            public int LineNumber;
            public int Column;
            public string Line;
        }

        public static LocationInfo IndexToLocationInfo(string source, int index) {
            var lines = 0;
            var lineStart = 0;
            var i = 0;
            for (; i < index; i++) {
                var ch = source[i];
                if (ch == '\n') {
                    lines += 1;
                    lineStart = i + 1;
                }
            }
            i = index;
            var lineEnd = 0;
            while (true) {
                var ch = source[i];
                if (ch == '\n' || ch == '\r' || ch == '\0') {
                    lineEnd = i;
                    break;
                }
                i += 1;
            }
            return new LocationInfo { LineNumber = lines + 1, Column = index - lineStart, Line = source.Slice(lineStart, lineEnd) };
        }
    }
}
