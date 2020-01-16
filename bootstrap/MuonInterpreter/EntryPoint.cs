using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MuonInterpreter {
    class EntryPoint {
        static CodeUnit Parse(string path) {
            using (var reader = new StreamReader(path)) {
                var source = reader.ReadToEnd();
                return Parser.Parse(path, source);
            }            
        }

        static Program ParseCompiler(string rootPath) {
            var compilerSources = new[] {
                "lib/core.mu",
                "lib/basic.mu",
                "lib/containers.mu",
                "lib/string.mu",
                "lib/environment.mu",
                "lib/stdio.mu",
                "lib/memory.mu",
                "lib/sort.mu",
                "lib/range.mu",
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
                "compiler/command_line_args_parser.mu",
                "compiler/mu.mu",
            }.Select(p => Path.Combine(rootPath, p)).ToArray();
            var units = compilerSources.Select(p => Parse(p)).ToArray();
            return Linker.Link(units);
        }

        static object RunMain(Program program, string[] args) {
            var ins = new InterpreterState { Frames = new Stack<Frame>(), Locals = new List<LocalVariable>(), Top = program.Top, FakeCommandLineArgs = args };
            var main = (FunctionDef)program.Top.Members["main"];
            return Interpreter.EvalFunction(ins, main);
        }

        static void BootstrapCompiler(string rootPath) {
            var program = ParseCompiler(rootPath);
            var args = new[] { "binary_name", "--args", "mu.args" }.ToArray();
            Environment.CurrentDirectory = Path.Combine(rootPath, "compiler");
            RunMain(program, args);
        }

        static void CompileDemo(string rootPath) {
            var program = ParseCompiler(rootPath);

            var args = new[] { "binary_name" }.Concat(new[] {
                "lib/core.mu",
                "lib/basic.mu",
                "lib/containers.mu",
                "demo/demo6.mu",
            }.Select(p => Path.Combine(rootPath, p))).Concat(new[] {
                "--args", Path.Combine(rootPath, "vc_demo/demo.args"),
                "--max-errors", "100",
                "--output-file", Path.Combine(rootPath, "vc_demo/demo.c"),
                "--run-command", "[[demo.exe 13579]]",
            }).ToArray();

            RunMain(program, args);
        }

        static void Main(string[] args) {
            // Note: this interpreter has many limitations, and is only used for bootstrapping the compiler.

            BootstrapCompiler("../../../..");
            //CompileDemo();
        } 
    }
}
