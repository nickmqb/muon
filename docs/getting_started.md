## Getting started

### Building the Muon compiler

1. Clone the repo.
2. Navigate to the `bootstrap` directory.
3. Use a C compiler to build the Muon compiler. You must use a 64-bit output target. For example:
	* GCC:
		* Run: `gcc -O3 -o mu mu.c`
	* MSVC:
		* Run: `cl -Ox mu.c`
		* Note that you must set up a 64-bit MSVC build environment first. E.g.: `"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x64`
		* Note that the .bat file may be in a different location depending on which version of MSVC you have installed.
	* Clang (Linux): 
		* Run: `clang -O3 -o mu mu.c`
	* Clang (Windows): 
		* Run: `clang -O3 -o mu.exe mu.c`

4. You now have a Muon compiler! The binary is called `mu` on Linux/macOS, `mu.exe` on Windows.
5. Move the binary to a location where it's easily accessible. From here on, we'll just refer to the binary as `mu`.

### Building and running: hello_world

1. Navigate to the `examples` directory.
2. Run `mu ../lib/core.mu hello_world.mu --output-file hello_world.c` (the first two arguments are Muon source files).
3. The compiler has generated hello_world.c. Use a C compiler to build, e.g.:
	* GCC: `gcc -o hello_world hello_world.c`
	* MSVC (assuming 64-bit environment): `cl hello_world.c` 
	* Clang (Linux): `clang -o hello_world hello_world.c`
	* Clang (Windows): `clang -o hello_world.exe hello_world.c` 
4. Run `hello_world`, and verify that it prints a message!
5. Tip: combine the Muon and C compilation steps using your shell's `&&` operator.

### Minimal core

In any Muon program you must always include [`lib/core.mu`](../lib/core.mu) as a source file. Everything else is optional!

### 32-bit output targets

To compile to a 32-bit target, use the `-m32` command line flag. E.g. to compile hello world as a 32-bit program: `mu -m32 --args hello_world.args && gcc -m32 -o hello_world hello_world.c`. Note that the C compiler must use the same output target (otherwise, a C compilation error will be generated).

### Args files

An args file is a text file that contains arguments for the Muon compiler, so you don't have to specify them all on the command line. You can instruct the compiler to use one as follows: `mu --args [path]`, e.g. `mu --args hello_world.args`
	
Multiple args files can be used, and you can still use any other flags too ([list of command line flags](command_line_flags.md)).

All [code examples](../examples) come with a .args file so you can easily build them. 

### Next steps

That covers the basics of the compiler! To learn more about the Muon programming language, check out [Muon by example](muon_by_example.md). 

### Tips & tricks

* If your program crashes, make sure that you have set `::currentAllocator` for the current thread, and that the allocator has not run out of memory.
 







