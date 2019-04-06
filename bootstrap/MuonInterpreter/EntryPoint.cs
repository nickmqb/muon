using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MuonInterpreter {
    class EntryPoint {
        const string Root = "D:/muon/";

        static CodeUnit Parse(string path) {
            using (var reader = new StreamReader(path)) {
                var source = reader.ReadToEnd();
                return Parser.Parse(path, source);
            }            
        }

        static Program ParseCompiler() {
            var compilerSources = new[] {
                "lib/core.mu",
                "lib/basic.mu",
                "lib/containers.mu",
                "lib/string.mu",
                "lib/environment.mu",
                "lib/stdio.mu",
                "lib/memory.mu",
                "lib/sort.mu",
                "compiler/ast.mu",
                "compiler/ast_printer.mu",
                "compiler/range_finder.mu",
                "compiler/type_checker_first_pass.mu",
                "compiler/type_checker.mu",
                "compiler/type_checker_builtin.mu",
                "compiler/parser.mu",
                "compiler/expander.mu",
                "compiler/interpreter.mu",
                "compiler/c_generator.mu",
                "compiler/c_generator_builtin.mu",
                "compiler/args_parser.mu",
                "compiler/cpu_time_stopwatch.mu",
                "compiler/mu.mu",
            }.Select(p => Root + p).ToArray();
            var units = compilerSources.Select(p => Parse(p)).ToArray();
            return Linker.Link(units);
        }

        static object RunMain(Program program, string[] args) {
            var ins = new InterpreterState { Frames = new Stack<Frame>(), Locals = new List<LocalVariable>(), Top = program.Top, FakeCommandLineArgs = args };
            var main = (FunctionDef)program.Top.Members["main"];
            return Interpreter.EvalFunction(ins, main);
        }

        static void BootstrapCompiler() {
            var program = ParseCompiler();
            var args = new[] { "binary_name", "--args", "mu.args" }.ToArray();
            Environment.CurrentDirectory = Root + "compiler";
            RunMain(program, args);
        }

        static void CompileDemo() {
            var program = ParseCompiler();

            var args = new[] { "binary_name" }.Concat(new[] {
                "lib/core.mu",
                "lib/basic.mu",
                "lib/containers.mu",
                "demo/demo6.mu",
            }.Select(p => Root + p)).Concat(new[] {
                "--args", Root + "vc_demo/demo.args",
                "--max-errors", "100",
                "--output-file", Root + "vc_demo/demo.c",
                "--run-command", "[[demo.exe 13579]]",
            }).ToArray();

            RunMain(program, args);
        }

        static void Main(string[] args) {
            // Note: this interpreter has many limitations, and is only used for bootstrapping the compiler.

            BootstrapCompiler();
            //CompileDemo();
        } 
    }
}
