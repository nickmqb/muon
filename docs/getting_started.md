## Getting started

### Building the Muon compiler

1. Clone the repo.
2. Navigate to the `bootstrap` directory.
3. Use a C compiler to build the Muon compiler. You can choose between a 32-bit or 64-bit output target (use `mu32.c` or `mu64.c`). Your choice does not affect the functionality of the compiler. However, the 32-bit version may be (slightly) faster. For example:
	* GCC (32-bit): 
		* Run: `gcc -m32 -O3 -o mu mu32.c`
		* You may have to install 32-bit output target support for GCC. E.g. on Ubuntu: `apt-get install gcc-multilib`
	* GCC (64-bit):
		* Run: `gcc -O3 -o mu mu64.c`
	* MSVC (32-bit):
		* Run: `cl -Ox mu32.c`
		* Note that you must set up a MSVC build environment first. E.g.: `"C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvarsall.bat" x86`
		* Note that the .bat file may be in a different location depending on which version of MSVC you have installed.
	* Clang (Linux, 32-bit): 
		* Run: `clang -m32 -O3 -o mu mu32.c`
	* Clang (Linux, 64-bit): 
		* Run: `clang -O3 -o mu mu64.c`
	* Clang (Windows, 32-bit): 
		* Run: `clang -m32 -O3 -o mu.exe mu32.c`

4. You now have a Muon compiler! The binary is called `mu` on Linux/macOS, `mu.exe` on Windows.
5. Move the binary to a location where it's easily accessible. From here on, we'll just refer to the binary as `mu`.

### Building and running: hello_world

1. Navigate to the `examples` directory.
2. Run `mu ../lib/core.mu hello_world.mu --output-file hello_world.c` (the first two arguments are Muon source files).
3. The compiler has generated hello_world.c. Use a C compiler to build, e.g.:
	* GCC: `gcc -m32 -o hello_world hello_world.c`
	* MSVC (assuming 32-bit environment): `cl hello_world.c` 
	* Clang (Linux): `clang -m32 -o hello_world hello_world.c`
	* Clang (Windows): `clang -m32 -o hello_world.exe hello_world.c` 
4. Run `hello_world`, and verify that it prints a message!
5. Tip: combine the Muon and C compilation steps using your shell's `&&` operator.

### Minimal core

In any Muon program you must always include [`lib/core.mu`](../lib/core.mu) as a source file. Everything else is optional!

### 64-bit output targets

To compile to a 64-bit target, use the `-m64` command line flag. E.g. to compile hello world as a 64-bit program: `mu -m64 --args hello_world.args && gcc -m64 -o hello_world hello_world.c`. Note that the C compiler must use the same output target (otherwise, a C compilation error will be generated).

### Args files

An args file is a text file that contains arguments for the Muon compiler, so you don't have to specify them all on the command line. You can instruct the compiler to use one as follows: `mu --args [path]`, e.g. `mu --args hello_world.args`
	
Multiple args files can be used, and you can still use any other flags too ([list of command line flags](command_line_flags.md)).

All [code examples](../examples) come with a .args file so you can easily build them. 

### Next steps

That covers the basics of the compiler! To learn more about the Muon programming language, check out [Muon by example](muon_by_example.md). 

### Tips & tricks

* If your program crashes, make sure that you have set `::currentAllocator` for the current thread, and that the allocator has not run out of memory.
 







