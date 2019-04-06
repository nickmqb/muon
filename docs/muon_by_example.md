# Muon by example

Note: this doc is about the language. See [getting started](getting_started.md) for more information about how to run the compiler.

Muon is fairly straightforward imperative programming language and should be easy to pick up for most programmers, especially if they already know either C, C++, C#, Java, Go, etc.

Let's dive in! :)

## Introduction

Let's start with a simple example: a guessing game. The game picks a random number between 1 and 100, and the user tries to guess it.

	// Guessing game
	main() {
		::currentAllocator = Memory.newArenaAllocator(16 * 1024)
		rs := time(null) // Initialize random seed
		num := cast(Random.xorshift32(ref rs) % 100 + 1, int)
		while true {
			Stdout.write("Your guess: ")
			input := Stdin.tryReadLine()
			if input.error != 0 {
				break
			}
			pr := int.tryParse(input.value)
			if !pr.hasValue {
				continue
			}
			guess := pr.value
			if guess < num {
				Stdout.writeLine("Try higher")
			} else if guess > num {
				Stdout.writeLine("Try lower")
			} else {
				Stdout.writeLine("You got it!")
				break
			}
		}
	}

	time(t *uint) uint #Foreign("time")

Some observations:

* Comments are marked with `//`.
* `main()` is the entry point of the program
* The `::` operator is used to access a member of the global namespace. `::currentAllocator` refers to the allocator for the current thread, which is defined in [`lib/core.mu`](lib/core.mu).
* `:=` is used to declare local variables; the type of the local variable is always inferred (and does not need to be specified)
* `if`, `else`, `while`, `break`, `continue` work like they do in most other imperative languages.
* The `.` operator is used for two purposes. The first one is struct field access, e.g. in `input.value`. The second one is namespace member access, e.g. in `Random.xorshift32` (`Random` is the namespace, `xorshift32` is the member).
* Statements are separated by newlines. Each statement must begin on a new line.
* Statement blocks are created *via indentation, i.e. using significant whitespace* (like in Python). In addition to that, redundant `{` and `}` are required. An advantage of this design decision is that it enables robust parse error recovery.

## Core types 

Type | Description
-----|-------------
`void` | Is used to indicate: no function return value
`sbyte` | 8-bit signed integer 
`byte` | 8-bit unsigned integer
`short` | 16-bit signed integer 
`ushort` | 16-bit unsigned integer
`int` | 32-bit signed integer 
`uint` | 32-bit unsigned integer
`long` | 64-bit signed integer 
`ulong` | 64-bit unsigned integer
`ssize` | 32-bit or 64-bit signed integer, depending on bitsize of target architecture 
`usize` | 32-bit or 64-bit unsigned integer, depending on bitsize of target architecture
`float` | 32-bit floating point number
`double` | 64-bit floating point number
`bool` | 8-bit boolean
`bool32` | 32-bit boolean
`char` | 8-bit character
`pointer` | raw pointer, 32-bit or 64-bit, depending on bitsize of target architecture
`*T` | pointer to a value of some type T
`$T` | value of T, where T uses reference type notation (see below)
`fun<A, B, .., Z>` | pointer to a function with parameter types A, B, etc., and return type Z
`string` | defined as: `string struct { dataPtr pointer; length int }`; dataPtr points to a UTF-8 encoded character sequence that should be regarded as immutable.
`cstring` | pointer to a c-style zero terminated string

## Local var mutation, `for`

Let's compute some Fibonacci numbers:

	main() {
		n := 7
		a := 1_u
		b := 1_u
		for i := 1; i < n {
			temp := a
			a += b
			b = temp
		}
		// alternatively, we could have counted down:
		// for i := n; i > 1; i -= 1 { ... }
		printf("%d\n", a)
	}

Locals can be mutated using the `=` operator, or via assignment versions of a binary operator, e.g. `+=`, `-=`, etc. 

A number suffix changes the type of a number literal. For example, the suffix `_u` denotes a `uint` (32-bit unsigned integer) literal. [View all suffixes](reference.md).

To apply a numeric binary operator (like `+`), the left- and right-hand types must be 'unifiable' (see [section 'Type unification' in reference](reference.md#type-unification)). `uint` and `int` are not unifiable, so if we were to change the initialization of b above to `b := 1` (an `int`), we'd get a compile error:

	Binary operator += cannot be applied to expressions of type uint and int
	-> fib_iterative.mu:9
	        a += b
	          ~~
	
	Cannot convert uint to int
	-> fib_iterative.mu:10
	        b = temp
	          ~


`for` works mostly like in other imperative languages. For convenience, the 3rd term can be omitted; in that case, the index variable is incremented by 1 at the end of each iteration of the loop. The index variable is scoped to the loop body. The variable can be omitted if you want to use an existing index variable, e.g.: `for ; i < n; i += 1 { ... }`

There is second kind of for loop for iterating over containers. See the section about arrays and lists, below. 

## Structs

	Vector2 struct {
		x int
		y int
	}

	main() {
		vec := Vector2 { x: 4, y: 3 }
		origin := Vector2{}
		sum := vec.x + vec.y
	}

Structs must specify a list of fields; each field must declare its type.

To create an instance of a struct, use a struct initializer (i.e. `NameOfStruct { ... }`). Any fields that are not explicitly initialized are set to zero. Instances are created on the stack, just like instances of primitive types.

The rules for struct memory layout in Muon are identical to the C struct layout rules. 

## Enums

	Color enum {
		red
		green
		blue = 10
	}

	Topping enum #Flags {
		sprinkles
		almonds
		chocolate
		coconut
	}

	main() {
		color := Color.green
		fav := Topping.almonds | Topping.chocolate
		num := cast(fav, uint)
	}

Enum options that do not specify a value (e.g. `Color.red`) are assigned a value automatically. The value starts at 0 and is incremented by 1 for each subsequent option.

Enums marked with the `#Flags` attribute follow a different scheme. The value starts at 1 and is left shifted by 1 bit for each subsequent option. Also, flags enum values can be combined using binary operators `&` and `|`.     

The backing store for an enum value is a `uint` (32-bit unsigned integer). Currently, this cannot be changed, but it will be possible in the future.

Check out the [reference](reference.md) for more details about builtin functions like `cast`.

## Functions

	multiply(a float, b float) {
		return a * b
	}

	// Explicit return type declaration
	fib(n int) int {
		return n > 1 ? fib(n - 1) + fib(n - 2) : 1
	}
	
	main() {
		num := multiply(5.0, 12.3)
		x := fib(5)
	}

Functions must declare zero or more parameters; each parameter must declare its type. The function's return type is declared after the parameter list. It can be usually be inferred and may therefore be omitted if desired. In some cases it is required, e.g. in the case of a recursive function.

## Namespaces

structs and enums are both special cases of namespaces:

	Foo {
		bar(name string) {
			return format("Yo, {}!", name)
		}

		// etc...
	}

This snippet declares the namespace `Foo` with the member function `bar`. The function can be called using `Foo.bar(...)`. Namespaces can be declared multiple times; every declaration is free to add new members (as long as each member name is unique within the namespace).

## UFCS

	Vector2 struct {
		x int
		y int

		dot(a Vector2, b Vector2) {
			return a.x * b.x + a.y * b.y
		}

		scale(vec *Vector2, f int) {
			vec.x *= f
			vec.y *= f
		}
	}

	main() {
		v := Vector2 { x: 2, y: 1 }
		w := Vector2 { x: 5, y: -2 }

		dot := Vector2.dot(v, w)
		alsoDot := v.dot(w)
		
		v.scale(2)
		Vector2.scale(ref v, 2) // Not an instance call, so must use `ref` operator to pass as reference
	}

Muon supports [uniform function call syntax](https://en.wikipedia.org/wiki/Uniform_Function_Call_Syntax), a.k.a. instance call syntax. Instance call syntax can be used with functions of which the type of the first parameter is the same as the containing namespace. The above example shows multiple ways to call the same function. Note that instance call syntax works even with functions that take a pointer, such as `Vector2.scale`, which takes a pointer to a `Vector2`. Muon will automatically pass a reference to the argument instead of the argument itself.

Important note: in such functions it is highly recommended to *not* let the first parameter escape the function (i.e. store it in a place where it may outlive the function call).    

## Constructor functions

	// continuing previous example

	Vector2 {
		cons(x int, y int) {
			return Vector2 { x: x, y: y }
		}
	}

	foo() {
		vec := Vector2(4, 5)
	}

For convenience, a struct may declare a constructor function `cons`. In the snippet above, the call `Vector2(4, 5)` is functionally equivalent to `Vector2.cons(4, 5)`.

Note: it is discouraged to create parameterless constructors because they are easily confused with the struct initializer. E.g. consider `Vector2()` vs `Vector2{}`.

## Strings, `StringBuilder`

In Muon, strings are immutable, non-nullable, UTF-8 encoded character sequences. A string is a struct, defined as follows:

	string struct {
		dataPtr pointer
		length int
	}

`dataPtr` points to the character sequence. `length` is the number of bytes (not the number of code points). `dataPtr` is allowed to be null only if `length` is 0. An unitialized string is equal to the empty string (`""`).

String literals are stored in the readonly section of the output binary, and therefore they don't require any allocations at runtime.

	main() {
		name := "DocBrown"
		
		prefix := name.slice(0, 3) // Slices are cheap, no copying involved!
		assert(prefix == "Doc") // true
		ch := prefix[2] // ch == 'c'
		
		//prefix[0] = 'd' // Would cause compile error if uncommented: strings are immutable

		::currentAllocator = Memory.newArenaAllocator(16 * 1024)

		sb := StringBuilder{}
		for i := 0; i < 10 {
			i.writeTo(ref sb)
			sb.write(" ")
		}

		Stdout.writeLine(sb.toString())
	}

Strings can be compared using comparison operators (e.g. `==`, `<`, etc.), which are overloaded.
 
To manipulate strings, the standard library provides various functions, such as `string.slice`, and a `StringBuilder` type that can be used as demonstrated above.

## Function pointers

	apply(f fun<int, char>, val int) {
		return f(val)
	}

	toChar(val int) {
		return transmute(val, char)
	}

	main() {
		fn := toChar
		// print is of type fun<int, char>
		ch := apply(fn, 65)
		assert(ch == 'A')

		print := Stdout.writeLine
		// print is of type fun<string, void>
		slice := string.slice
		// slice is of type fun<string, int, int, string>
	}

The type `fun<A, B, .., Z>` is used to represent a function pointer. The last type parameter is always the return type of the function. If there is no return type, the last type argument will be `void`.

## Constants, global variables, thread-local variables

	:pi = 3.14159265359
	:globalCounter #Mutable = 100

	byte {
		:maxValue = 255_b
	}

	Foo {
		:someFlag bool #Mutable
	}

	:currentAllocator IAllocator #ThreadLocal #Mutable

In Muon, constants and global variables are known as 'static fields'. Static fields can either be non-mutable (constant) or mutable (global/thread-local variable). If an initializer expression is provided, the type declaration of the static field may be omitted if desired.

The initializer expression is evaluated at compile time. Support for this is currently limited; this will be expanded in the future.

## Memory management, `IAllocator`, `new`

	// Defined in lib/core.mu:
	IAllocator struct {
		data pointer
		allocFn fun<pointer, ssize, pointer> // data, sizeInBytes, resultPtr
		reallocFn fun<pointer, pointer, ssize, ssize, ssize, pointer> 
			// data, userPtr, newSizeInBytes, prevSizeInBytes, copySizeInBytes, resultPtr
		freeFn fun<pointer, pointer, void> // data, userPtr
	}
	:currentAllocator IAllocator #ThreadLocal #Mutable

One of Muon's goals is to provide flexible memory management. Users may define their own allocators by populating an `IAllocator` struct and setting the `::currentAllocator` thread-local variable.

	Vector2 struct { ... }
		
	main() {
		::currentAllocator = Memory.heapAllocator()

		sb := StringBuilder{}
		sb.write("DeLorean") // StringBuilder.write uses ::currentAllocator to maintain a buffer
		
		vecPtr := new Vector2{} // Uses ::currentAllocator to allocate space for the Vector2
		intPtr := new 123 // Uses ::currentAllocator to allocate space for the int
		assert(intPtr^ == 123)
	}

In the above example, we use the `Memory.heapAllocator` from the standard library (which wraps `malloc`). Functions may use `::currentAllocator` to allocate space to carry out their purpose. Muon also provides a `new` operator, which allocates space for its argument using `::currentAllocator`, and returns a pointer to the newly allocated instance.

## Pointers, `ref`, `^`

	main() {
		val := 789
		intPtr := ref val // Take the address of val 
		// Type of intPtr is: *int

		raw := pointer_cast(intPtr, pointer) 
		// Type of raw is: pointer

		raw += 16 // Dangerous! raw now points somewhere else on the stack
		
		deref := intPtr^
		// Type of deref is: int

		assert(val == deref)
	}

Muon has two kinds of pointers: raw pointers, denoted by the `pointer` type, and typed pointers, denoted by `*T`, where T is a type. Pointers are always nullable.

Raw pointers can be modified via addition and subtraction.

Typed pointers can be dereferenced (using the `^` operator) and any value can be referenced (using the `ref` operator, a.k.a. addressof operator) to produce a typed pointer to the value.

## Reference type notation

The following two code snippets are functionally equivalent:

	Entity struct {
		// fields, etc.
		update(e *Entity) { ... }
		passByValue(e Entity) { ... }
	}

<br>

	Entity struct #RefType {
		// fields, etc.
		update(e Entity) { ... }
		passByValue(e $Entity) { ... }
	}

By using the `#RefType` attribute on a struct declaration, Muon will assume 'reference type notation' for the type. This means that any occurrence of the type name is assumed to represent a pointer to the type, rather than the type itself. In both examples, the parameter of `Entity.update` is a pointer.

To refer to the original type, Muon provides the `$` operator, which can be thought of as the inverse of the `*` operator (e.g. `$*int` == `int`). In both examples, the parameter of `Entity.passByValue` is a value. 

There is one exception: a struct initializer expression always produces a value, never a pointer, regardless of whether the type is marked as a `#RefType`.

Note: this is an experimental feature.

## Error handling, abandonment

Muon provides two ways to handle errors. The first option is via return values. The standard library provides `Maybe<T>` and `Result<T>` to help with this (see [`lib/basic.mu`](lib/basic.mu), where these are defined).

The second option is [abandonment](http://joeduffyblog.com/2016/02/07/the-error-model/). Abandonment means: giving up, and potentially letting the program recover at a high level. There are multiple ways in which abandonment can be triggered:

* `abandon()`
* `abandon(code int)`
* `assert(cond)` if cond is false
* `checked_cast(val, T)` if cast fails
* `val.as(T)` if cast fails
* `sequence[index]` if bounds check fails
* `match` statement, if there are no matches

`Maybe<T>` and `Result<T>` both provide an `unwrap` function, which can be used when fine grained error handling is not needed. The function checks for a value; if present, the value is returned, if not, the program is abandoned.

	toNum(s string) int {
		return int.tryParse(s).unwrap() // int.tryParse returns Maybe<int>, unwrap to get int
	}

To provide the most flexibility, only very little is implemented at the language level in terms of handling abandonment:

	// Defined in lib/core.mu:
	:abandonFn fun<int, void> #ThreadLocal #Mutable 

`abandonFn` is called upon abandonment. A program is free to set `abandonFn` as desired. Approaches may include terminating the process outright, logging the error/stack trace and then terminating, killing the thread but continuing the process, to even trying to salvage the abandoning thread.

Note that any function that is used for handling abandonment *must not* return control flow to the caller.

## Tagged pointers

	Shape tagged_pointer {
		*Cube
		*Sphere
		*Cylinder
	}

	Cube struct {
		volume int
	}

	Sphere struct {
		radius float
	}

	Cylinder struct {
		length double
	}

	main() {
		::currentAllocator = Memory.newArenaAllocator(16 * 1024)

		shape := cast(null, Shape)
		shape = new Cube { volume: 20 }

		x := shape.is(*Cube) // x == true
		y := shape.is(*Cylinder) // y == false
		//z := shape.is(*char) // Would cause compile error if uncommented

		cube := shape.as(*Cube)
		//sphere := shape.as(*Sphere) // Would abandon if uncommented
		//data := shape.as(*byte) // Would cause compile error if uncommented
		shape = null
		//cube2 := shape.as(*Cube) // Would abandon if uncommented
	}

A tagged pointer is a specific type of enum (discriminated union). It is defined as a struct consisting of a type id and a pointer. The tagged pointer declares a list of types that the tagged pointer is allowed to represent. A tagged pointer can also be `null` (type id == 0).

The builtin function `is` can be used to check whether the tagged pointer is of a specific type. The builtin function `as` can be used to convert a tagged pointer to the specific type. If the conversion fails, the program is abandoned.

Note: this is an experimental feature. It may later be replaced by a more general mechanism to construct discriminated unions.

## `match` statement

	// continuing previous example

	getInfo(sh Shape) {
		match sh {
			*Cube: return format("Cube, with volume {}", sh.volume)
			*Sphere: return format("Sphere, with radius {}", sh.radius)
			default: return "???" 
			null: return "null"
		}
	}

As an alternative to the `is` and `as` builtin functions, the `match` statement may be used to inspect a tagged pointer. If the match target is a local variable, and the target matches any of the given case types, the type of the variable is 'narrowed' inside the case block, allowing it be used as if its type is identical to the case type (and not a tagged pointer).

The `match` statement is similar to the `switch` statement in C-like languages, but there are some important differences. There is no fall through to the next case. The `default` keyword matches only non-null target values. The `null` keyword must be used to match null values. To combine default and null, use `null | default`. And finally, if the target value does not match any cases, the program is abandoned.

## Generic structs

	Maybe<T> struct {
		value T
		hasValue bool
	}

	main() {
		// Type argument can be omitted because it can be inferred
		name := Maybe { value: "Marty", hasValue: true }
		// type of s is: Maybe<string>

		// Type argument is not needed, but is allowed
		a := Maybe<float> { value: 1.21e9, hasValue: true}

		// Must specify type argument, cannot be inferred
		b := Maybe<int>{}
	}

A struct may declare one or more type parameters. This makes it a generic struct. The name of a type parameter must be a single uppercase character. When creating an instance of a generic struct, type arguments must be specified unless they can be inferred from the context (i.e. field initializer expressions).

## Generic functions

	Map {
		create<K, V>() {
			...
		}
	}

	Array {
		countOccurrences(items Array<T>) {
			map := Map.create<T, int>() // Type arguments are required
			for items {
				count := map.getOrDefault(it)
				map.addOrUpdate(it, count + 1)
			}
			return map
		}
	}

	main() {
		nums := Array.cons<int>(20) // Type argument is required, cannot be inferred from normal argument alone
		...
		map := nums.countOccurrences<int>() // Type argument is not needed, but is allowed
		map := nums.countOccurrences() // Equivalent to the previous line
	}

A function is generic if it takes one or more type parameters. The name of a type parameter must be a single uppercase character. In contrast to generic structs, a function does not need to explicitly declare all of its type parameters if the list of normal parameters refers to all generic type parameters. This can be seen in the example above. `Map.create` needs to explicitly specify its type parameter list, but `Array.countOccurences` does not need to do this, because it is clear from the first normal parameter that there is also a generic type parameter `T`.

When calling a generic function, type arguments must be specified unless they can be inferred from the normal arguments.

## Working with C libraries

	fgets(s pointer #As("char *"), size int, stream pointer #As("FILE *")) pointer #Foreign("fgets")

	add(a Vector2 #As("vector2"), b Vector2 #As("vector2")) Vector2 #As("vector2") #Foreign("vector_add")

	printf(fmt cstring) int #Foreign("printf") #VarArgs

	:stdin pointer #Foreign("stdin")

	main() {
		printf("%d + %d = %d\n", 2, 2, 5)
	}

Use the `#Foreign` attribute to declare a foreign function. The function may not specify a body and must declare a return type. Calls to the foreign function are compiled to a call to the specified foreign C function. You must manually make sure that the C function is defined in `external.h` (or other [include file](command_line_flags.md)), and that the linker can find the implementation of the C function. 

Some parameters may need to use the `#As` attribute to enable the Muon compiler to 'marshal' the corresponding argument; Muon does this by inserting a C-style cast for any pointer argument, and generating a C union for conversion of struct arguments. A valid C type must be specified. `#As` can also be used for marshaling the return type of a function.

Use the `#VarArgs` attribute to indicate that the foreign function takes more arguments than specified in the parameter list.

A static field can be marked as `#Foreign` too. Usages of the static field will be compiled to the specified symbol name.

Finally, the core type `cstring` can be used to ease working with foreign functions. A `cstring` represents a pointer to a zero terminated string (`char*`, in C). All string literals are generated with a terminating 0 byte, and they can be passed as an argument to a `cstring` parameter without any further conversion.

## Standard library

One of Muon's design principles is to require a very minimal core. A standard library is available, but is completely optional.

There's one caveat: some types in the standard library are used by the language. This includes the `StringBuilder` type and all container types. You can build without the standard library, but some language features may not be available. For example, the `format` builtin function will fail to work without a `StringBuilder`. However, you're free to provide your own implementation of `StringBuilder` as an alternative if you wish to do so.

The files that comprise the standard library are listed below. People that want to use the standard library in their projects are encouraged to have a look at the source (which is hopefully fairly readable) so they know the foundation on top of which they build.

File | Description
-----|-------------
[`lib/core.mu`](lib/core.mu) | Core type declarations. The only file that's always required.
[`lib/basic.mu`](lib/basic.mu) | String conversion functions, `StringBuilder`, `Maybe<T>`, `Result<T>`.
[`lib/containers.mu`](lib/containers.mu) | `Array<T>`, `List<T>`, `Set<T>`, `Map<K, V>`, `CustomSet<T>`, `CustomMap<K, V>`.
[`lib/string.mu`](lib/string.mu) | Various string functions.
[`lib/memory.mu`](lib/memory.mu) | `Memory.heapAllocator`, `ArenaAllocator`.
[`lib/sort.mu`](lib/sort.mu) | Basic merge sort implementation.
[`lib/stdio.mu`](lib/stdio.mu) | `Stdout`, `Stdin`, very basic file I/O.
[`lib/random.mu`](lib/random.mu) | Very basic random number generator. 

## Arrays and lists

	// In lib/containers.mu:
	Array<T> struct #RefType {
		dataPtr pointer
		count int
	}
	
	List<T> struct #RefType {
		dataPtr pointer
		count int
		capacity int
	}

<br>

	main() {
		::currentAllocator = Memory.newArenaAllocator(16 * 1024)

		arr := Array<int>(3)
		arr[0] = 1
		arr[1] = 2

		element := arr[1]
		arr[2] = 5

		element = unchecked_index(arr, 1) // Avoid bounds check
		unchecked_index(arr, 2) = 6 // Avoid bounds check

		slice := arr.slice(1, 3) // slice from 1->3 to create array with 2 elements 
		// type of slice is: Array<int>

		list := List<string>{}
		list.add("Biff") // List.add manages the buffer that stores the list's items
		list.add("Lorraine")
		list.removeIndexShift(0)
		// Only "Lorraine" remains in the list

		listSlice := list.slice(0, 1)
		// type of listSlice is: Array<string>
		// Be careful with list slices! As items are added to the list, the underlying buffer
		// may be reallocated, causing the slice to become invalid.

		sum := 0
		for x in arr {
			sum += x
		}
		for x, i in arr {
			sum += x
			// i is index (0, 1, 2)
		}
		for arr {
			sum += it
		}
	}

The standard library provides arrays and lists, which are defined in [`lib/containers.mu`](lib/containers.mu). Arrays and lists can be indexed using `[` and `]`. Indices are zero based. If the index is out of bounds, the program is abandoned. To avoid the bounds check, the builtin `unchecked_index` can be used.

Both arrays and lists can be sliced, producing an array.

All container types (including sets and maps, see below) can be iterated over using a for loop. The three for loops in the example above are functionally equivalent. A secondary loop variable may be specified which holds the index of the current element. If no loop variable is specified, the name `it` is used.  

## Sets and maps

	main() {
		::currentAllocator = Memory.newArenaAllocator(16 * 1024)

		set := Set.create<int>()
		set.add(1)
		//set.add(1) // Value already present, would abandon if uncommented
		set.tryAdd(1) // Returns false
		set.add(2)
		set.remove(1)
		x := set.contains(3) // x == false
	 	for val in set {
			...
		} 	

		map := Map.create<int, float>()
		map.add(1, 4)
		map.add(2, 8)
		// map.add(2, 9) // Key already present, would abandon if uncommented
		map.tryAdd(2, 7) // Returns false
		y := map.containsKey(2) // y == true
		for e in map {
			// type of e is: MapEntry<int, int>
			Stdout.writeLine(format("{} {}", e.key, e.value))
		}
	}

The standard library provides two set and two map implementations: `Set<T>`, `CustomSet<T>`, `Map<K, V>` and `CustomMap<K, V>`. See [`lib/containers.mu`](lib/containers.mu), where these types are defined, for a list of all functions that are provided. All of these types are backed by hash tables. `Set` and `Map` use the item/key type's `hash` and `equals ` functions, whereas `CustomSet` and `CustomMap` support the use of custom hash and equals functions. 

## Next steps

Thanks for reading this far! [Check out the reference](reference.md) for some further details.
