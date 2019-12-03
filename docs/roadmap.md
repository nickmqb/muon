## Roadmap

### Language features

* Statically sized arrays (i.e. size of array is known at compile time)
* Large arrays (64 bit element count)
* Nested namespaces, imports, type aliases; improved symbol resolution rules
* Container initializers (e.g. `nums := Array [1, 2, 3]`)
* Lambda functions
* Compile time evaluation of expressions and functions
* Custom enum backing type (currently fixed to `uint`)
* Checked integer arithmetic (via `checked` keyword)
* Use numbers, strings, characters with `match` statement; match expressions
* Multiple statements per line with `;`
* Single line blocks (e.g. `if x { ... }`)
* Variable redeclarations (e.g. `x := ""; x ::= 1`)
* Delayed type inference (e.g. `x := ---; x = 2`)
* Optional function parameters with a default value
* Functions with variable number of arguments
* Unicode character type; support full unicode character range
* Fully general container iteration (currently container types are hardcoded in compiler)
* Sequences: allow the use of constructs like filter/map with the performance of a for loop
* `#Export` attribute to customize visibility (mainly for library authors)
* `defer` statement
* Operator overloading
* Discriminated unions
* Builtin serialization of any type
* labels, `goto` statement
* Closures
* Meta-programming via plugin API for the compiler

### Code generation

* LLVM backend
* x86 backend (maybe, non-optimizing backend, fast compilation)
* WASM backend (maybe)
* Code reachability analysis
* Tree shaking (remove unused functions from binary)
* Generic function deduplication (merge identical variants)
* Function inlining (never, hint, always)
* Define memory aliasing model
* SIMD support
* Inline asm support
* Incremental compilation
* Support more platforms and architectures

### C interop

* Auto-generate foreign declarations from .h files
* Auto-generate .h file for .mu files
* Support c unions
* Support custom calling conventions 

### Standard library

* Reduce dependency on libc (remove completely on Windows)
* Basic abandonment handlers (e.g. print stack trace)
* Platform independent math functions, floating point printing/parsing
* Platform independent file I/O
* Platform independent threads, locks, channels (basic producer/consumer)
* Platform independent unicode string manipulation
* Platform independent time measurement
* More allocators
* Provide wrappers for good libraries for date/time handling, network I/O (TCP, UDP, HTTP, HTTPS)
* Provide wrappers for common libraries, such as various OS APIs, OpenGL, DirectX, Vulkan, SDL, etc.

### Tests & docs

* Full test coverage of the compiler
* Benchmarks and performance comparisons with other languages
* Document all behavior, including all platform specific behavior
* Document the entire standard library

### Tools

* REPL
* Hot reloading
* Debugger
* Profiler
* More extensions for popular editors (in addition to the [VS Code extension](https://github.com/nickmqb/vscode-muon))
