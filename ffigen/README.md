# ffigen

Takes a .c/.h file and generates a corresponding .mu file with foreign interface declarations (a.k.a. bindings).

Ffigen uses libclang (from [LLVM](https://llvm.org/)) to iterate over all symbols in the .c/.h file. It processes all functions, structs, unions, enums, constants, globals and thread locals. To process simple `#define`s, and/or to customize which symbols are included in the output, see [rules file](#rules-file), below.

Some manual work may be needed to get the complete foreign function interface (it varies from library to library how easy this is), but you should be able to get most of the way there using ffigen.

If you use ffigen it would be great if you could let me know how it goes by [filing a bug](https://github.com/nickmqb/muon/issues). I'll use your feedback to guide [future enhancements](#future-enhancements).

## Getting started

1. Install libclang (which is part of [LLVM](https://llvm.org/)). Optionally, add the LLVM bin folder to your PATH.
2. Build using either: `mu --args ffigen_linux_macos.args` or `mu --args ffigen_windows.args`, depending on your platform.
3. Compile ffigen.c using your favorite C compiler. Make sure that the compiler can find the libclang .h and library (.so or .lib) files.
	* Example (Ubuntu, gcc): `mu --args ffigen_linux_macos.args && gcc -I/usr/lib/llvm-9/include -L/usr/lib/llvm-9/lib -o ffigen ffigen.c -lclang`
	* Example (Windows, msvc): `mu --args ffigen_windows.args && cl /Zi /I"c:\Program Files\LLVM\include" ffigen.c /link /libpath:"c:\Program Files\LLVM\lib" libclang.lib`

## Command line arguments

`--input [path]`: Input file, typically a .c or .h file.
`--rules [path]`: Rules file, see below.
`--output [path]`: .mu output file.
`--clang-arg [argument]`: An additional [argument to pass to clang](https://clang.llvm.org/docs/ClangCommandLineReference.html). This flag can be specified multiple times, once for each clang argument.
`--platform-agnostic`: If set, ffigen attempts to generate a platform agnostic output file. If this is not possible, ffigen emits placeholders that prevent compilation of the generated .mu file.

## Rules file

By default, ffigen maps all symbols in the input file. To exert more control over which symbols are mapped, a rules file can be used. When a rules file is specified, only symbols that match one ore more rules are included in the output. Additionally, a rules file can be used to specify how a symbol is mapped from C to Muon.

A rules file is a text file; each line represents a single rule. The syntax is as follows:

* `some_name`: Includes the symbol `some_name` in the output, and processes it according to its kind (function, struct, etc.) as detailed below.
* `some_function fun`: Includes the function named `some_function` in the output. Parameter and return types are also (recursively) processed and included in the output, if needed.
* `some_struct struct`: Includes the struct or union named `some_struct` in the output. Types of fields are also (recursively) processed and included in the output, if needed.
* `some_enum enum`: Includes the enum named `some_enum` in the output.
* `some_const const [some_muon_data_type] [cast]`: Includes the constant variable `some_const` _OR_ the preprocessor symbol `#define some_const ...` in the output. Only basic data types are allowed: integers, floating point numbers and C strings. In the case of a `#define`, `some_muon_data_type` must be used to specify the Muon target type for the symbol. Finally, the term `cast` can be used to force the conversion, if needed.
* `some_name var`: Includes the global variable or thread local variable `some_name` in the output. Only basic data types are allowed: integers, floating point numbers and C strings.
* `some_name skip`: Excludes the symbol `some_name` from the output. This is useful if we want to manually define a foreign interface for the symbol, but another rule indirectly causes the symbol to be included in the output. Note that the skip rule will only have an effect if it appears before the other rule that (indirectly) includes the symbol.
* `struct some_tag_name`, `union some_tag_name`, `enum some_tag_name`: In C, a struct/union/enum may be defined using just a tag name; this rule type allows us to target these. (In case of a clash between an identifier and a tag name, an additional C typedef can be used to work around the issue.)
* `// some comment`: these lines are ignored, as are lines consisting solely of whitespace.

Rule names may use the wilcard character `*` to match any sequence of zero or more characters. E.g. `libname_*` will match any symbol that starts with `libname_`.

Normally, a C `char *` is mapped to a Muon `*sbyte`. The keyword `prefer_cstring` may be used with `fun` and `struct` rule types to map a `char *` to a `cstring`, for that rule. If you use this feature, you must make sure that the string is not modified by the C library. This is because Muon allows string literals (which must not be modified) to be assigned to a `cstring`.

Naming conflicts should be rare, but most can be resolved by adding a `typedef` to your C file. ffigen will use the name of the last `typedef` it encounters. Alternatively, manually tweak the generated declaration.

### Example

To try the [example](example.mu), run: `ffigen --source example.h --rules example.rules --output example_ffi.mu`, then build using: `mu --args example.args`, and compile example.c with a C compiler.

For a larger example, have a look at [libclang.rules](libclang.rules), which is used to generate the foreign interface for libclang, which is used by ffigen itself! (example command line (Windows): `ffigen --source libclang.h --clang-arg -I"c:\Program Files\LLVM\include" --rules libclang.rules --output libclang_test.mu`)

## Future enhancements

* Compile-time sized arrays. Currently, fixed size array declarations are "unrolled".
* Struct fields that are arrays of anonymous structs. Currently, padding is generated to ensure the correct struct size.
* Global variables and constants with non-primitive types
* Type aliases for opaque pointers
* Function pointers with non standard calling conventions
* Improve union support. Currently, only the first union variant is mapped. Padding is generated to ensure the correct struct size.
* Make ffigen available as a library (libffigen) (strongly consider this if we find that rules files are not flexible enough).
* Generate architecture/platform agnostic definitions (e.g. map a machine word sized integer to a `ssize`/`usize` in Muon).
* Macros
* C++ support
