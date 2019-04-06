## `mu` command line flags

List of all command line flags. Note: `[brackets]` are used as a placeholder.

* `[path]`: a source file, to be included in the compilation.
* `--args [path]`: read additional command line flags from the specified file.
* `--output_file [path]`: the path of the generated C file. Defaults to `out.c`.
* `--include_file [path]`: the compiler emits a single `#include` statement at the top of the generated C file. This flag controls which file is #included. Defaults to `external.h`.
* `--build_command [command]`: run the command after successful generation of the C file.
* `--run_command [command]`: run the command after successful completion of the build command.
* `--max_errors [N]`: print at most N errors. Defaults to 25.
* `--no_entry_point`: omit the function `int main(...) { ... }` from the generated C file.
* `--print_stats`: print timing info and other compilation statistics.
* `--version`: print compiler version.   

To escape the spaces in any argument, surround `"it with quotes"`. Alternatively, inside args files, use `[[double brackets]]`.
