# ffigen

Takes a .c/.h file and generates a corresponding .mu file with foreign interface declarations (a.k.a. bindings).

Ffigen uses libclang (from [LLVM](https://llvm.org/)) to iterate over all symbols in the .c/.h file. To customize which symbols are included in the output, see [rules file](#rules-file), below.

Some manual work may be needed to get the complete foreign function interface (it varies from library to library how easy this is), but you should be able to get most of the way there using ffigen.

If you use ffigen it would be great if you could let me know how it goes by [filing a bug](https://github.com/nickmqb/muon/issues). I'll use your feedback to guide [future enhancements](#future-enhancements).

## Getting started

1. Install LLVM13. Optionally, add the LLVM bin folder to your PATH.
2. Build using either: `mu --args _app_linux_.args` or `mu --args _app_windows.args`, depending on your platform.
3. Compile ffigen.c using your favorite C compiler. Make sure that the compiler can find the libclang .h and library (.so or .lib) files.
	* Example (Ubuntu, gcc): `mu --args _app_linux_.args && gcc -I/usr/lib/llvm-13/include -L/usr/lib/llvm-13/lib -o ffigen ffigen.c -lclang`
	* Example (Windows, msvc): `mu --args _app_windows.args && cl /Zi /I"c:\Program Files\LLVM\include" ffigen.c /link /libpath:"c:\Program Files\LLVM\lib" libclang.lib`

## Command line arguments

* `--input [path]`: Input file, typically a .c or .h file.
* `--rules [path]`: Rules file, see below.
* `--output [path]`: .mu output file.
* `--clang-arg [argument]`: An additional [argument to pass to clang](https://clang.llvm.org/docs/ClangCommandLineReference.html). This flag can be specified multiple times, once for each clang argument.
* `--platform-agnostic`: If set, ffigen attempts to generate a platform agnostic output file. If this is not possible, ffigen emits placeholders that prevent compilation of the generated .mu file.

## Rules file

A rules file controls which symbols are mapped. A rules file is a text file; each line represents a single rule. The syntax of a rule is as follows:

`<symbol_name> [<symbol_kind>] [<args>] [skip]` ([square brackets] denote optional parts)

A rule causes the targeted symbol to be included in the output. Names may use the wilcard character `*` to match any sequence of zero or more characters. E.g. `libname_*` will match any symbol that starts with `libname_`. To target C tag names (e.g. `union foo { ... };`) prefix the name with the C keyword (e.g. `union foo`). A symbol_kind must not be specified in that case, as it will be inferred. If the symbol is a function, parameter and return types are recursively included. If the symbol is a struct/union, field types are recursively included.

If a symbol kind is specified, the targeted symbol(s) will only be included if they match the specified symbol kind. Possible symbol kinds are:
* `fun` (functions)
* `struct` (structs and unions)
* `enum`
* `const` (constants, preprocessor definitions and enum members)
* `var` (global variables)

Additional arguments may be specified depending on the symbol kind:

* `fun`: `<symbol_name> fun [prefer_cstring]`. Normally, a C `char *` is mapped to a Muon `*sbyte`. Use `prefer_cstring` to map a `char *` to a `cstring`. If you use this feature, you must make sure that the string is not modified by the C library. This is because Muon allows string literals (which must not be modified) to be assigned to a `cstring`.

* `const`: `<symbol_name> const [<muon_type>] [cast]`. `muon_type` denotes the Muon type that will be used for the symbol. Only basic data types are allowed: integers, floating point numbers and C strings. In the case of preprocessor definition, the type is required. The term `cast` can be used to force the conversion, if needed.

Finally, the term `skip` may be used to explicitly exclude the symbol from the output. This is useful if we want to manually define a foreign interface for the symbol, but another rule indirectly causes the symbol to be included in the output.

Naming conflicts should be rare, but most can be resolved by adding a `typedef` to your C file. ffigen will use the name of the last `typedef` it encounters that is also targeted by a rule. Alternatively, manually tweak the generated declaration.

Lines starting with `//` and lines consisting solely of whitespace are ignored.

### Example

To try the [example](example), from the example directory, run: `../ffigen --source example.h --rules example.rules --output example_ffi.mu`, then build using: `mu --args example.args`, and compile example.c with a C compiler.

For a larger example, have a look at [libclang.rules](bindings/libclang.rules), which is used to generate the foreign interface for libclang, which is used by ffigen itself! (example command line (Windows), from the bindings directory: `..\ffigen --source ..\external.h --clang-arg -I"c:\Program Files\LLVM\include" --rules libclang.rules --output libclang_test.mu`)

## Future enhancements

* Compile-time sized arrays. Currently, fixed size array declarations are "unrolled".
* Global variables and constants with non-primitive types
* Type aliases for opaque pointers
* Function pointers with non standard calling conventions
* Make ffigen available as a library (libffigen) (strongly consider this if we find that rules files are not flexible enough).
* Generate architecture/platform agnostic definitions (e.g. map a machine word sized integer to a `ssize`/`usize` in Muon).
* Macros
* C++ support
