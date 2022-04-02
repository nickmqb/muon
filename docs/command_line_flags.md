## `mu` command line flags

* `[path]`: a source file, to be included in the compilation.
* `--args [path]`: read additional command line flags from the specified file.
* `--output-file [path]`: the path of the generated C file. Defaults to `out.c`.
* `--include-file [path]`: the compiler emits a single `#include` statement at the top of the generated C file. This flag controls which file is #included. Defaults to `external.h`.
* `--footer-file [path]`: optionally emit a single `#include` statement at the bottom of the generated C file.
* `-m64`: use 64-bit output target; this is the default.
* `-m32`: use 32-bit output target.
* `--build-command [command]`: run the command after successful generation of the C file.
* `--run-command [command]`: run the command after successful completion of the build command.
* `--max-errors [N]`: print at most N errors. Defaults to 25.
* `--no-entry-point`: omit the function `int main(...) { ... }` from the generated C file.
* `--print-stats`: print timing info and other compilation statistics.
* `--version`: print compiler version.   

To escape the spaces in any argument, surround `"it with quotes"`. Alternatively, inside args files, use `[[double brackets]]`.
