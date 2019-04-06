# Muon reference

## String literal escape characters

Similar to C. TODO.

## Number literal suffixes

Integer literals without a suffix have type `int`. Floating point literals without a suffix have type `float`.  

Suffix | Type
-------|------
`_sb` | `sbyte`
`_b` | `byte`
`_s` | `short`
`_us` | `ushort`
`_u` | `uint`
`_L` | `long`
`_uL` | `ulong`
`_sz` | `ssize`
`_usz` | `usize`
`_d` | `double`

## Type attributes

#### `#RefType`
Applies to: struct types<br>
Tells the compiler to assume reference type notation for this type. Any occurrence of the type is treated as a pointer to the type, with one exception: struct initializers always produce a value, never a pointer. Example:
	
	Array<T> struct #RefType {
		...
	}

	foo(a Array<T>) {
		// a is a pointer to a struct

		b := Array<T> { ... }
		// b is a struct
	}

	bar(c $Array<T>) {
		// c is a struct ($ operator removes one layer of pointer indirection)
	}

#### `#Flags`
Applies to: enum types<br>
Marks the enum as a flags enum. Enum options without a value will be initialized to `previous_value << 1` (rather than `previous_value + 1`). Flags enum values may be combined using the `&` and `|` operators. 

## Function attributes

#### `#Foreign(name string)`
Marks the function as foreign. Calls to the function are compiled to calls to the foreign function specified by the name parameter. The function may not declare a body and must specify a return type. 

#### `#As(ctype string)`
Casts/converts the result of a foreign function from the specified ctype.

#### `#VarArgs`
Marks a foreign function as a function that takes a variable number of arguments.

## Parameter attributes

#### `#As(ctype string)`
Casts/converts the parameter of a foreign function to the specified ctype.

## Static field attributes

#### `#Mutable`
The static field is mutable (by default, static fields are constant, and cannot be modified).

#### `#ThreadLocal`
The static field is a thread-local. Each thread will get its own value.

#### `#Foreign(name string)`
Marks the static field as foreign. Usages of the static field will be compiled to references to the symbol specified by the name parameter. 

## Builtin functions

#### `abandon() void`
Abandons the program.

#### `assert(condition bool) void`
If condition is false, the program is abandoned.

#### `checked_cast(value, TargetType) TargetType`
TargetType must be an integer type.
Converts value to TargetType. If the value doesn't fit into TargetType, the program is abandoned.

#### `cast(value, TargetType) TargetType`
Casts value to TargetType. Performs numeric conversions (integers, floating point numbers), conversions between boolean types, conversions between enum values and integers and conversions from `null` to any pointer type. Values that don't fit into TargetType are truncated.

#### `pointer_cast(value, TargetType) TargetType`
TargetType must be a pointer type. Performs conversions between different pointer types.

#### `transmute(value, TargetType) TargetType`
Reinterprets the bits of value as the TargetType. If the type of value and TargetType have different sizes, the result is either truncated or extended with zeroes.

#### `is(value TaggedPointer, TargetType) bool`
Must be called using instance call syntax, i.e. `value.is(TargetType)`. 
Returns whether the value, which must be of a tagged pointer type, is an instance of TargetType.

#### `as(value TaggedPointer, TargetType) bool`
Must be called using instance call syntax, i.e. `value.as(TargetType)`. 
Converts the value, which must be of a tagged pointer type, to an instance of TargetType. If the value is not an instance of TargetType, the program is abandoned.

#### `min(a, b) T`
Returns the minimum of the two values. a and b must be numeric. The result type T is the unification of the types of a and b.

#### `max(a, b) T`
Returns the maximum of the two values. a and b must be numeric. The result type T is the unification of the types of a and b.

#### `sizeof(T) int`
Returns the size of the type T, in bytes.

#### `default_value(T) T`
Returns the default value of the type T.

#### `compute_hash(value T) uint`
Computes a hash code for value of type T, by calling the function `T.hash(value T)`.

#### `unchecked_index(seq IndexableType<T>, index U) T`
Performs the operation `seq[index]` without performing a bounds check. U is `int` or `uint`. Note: this builtin can also be used on the left hand side of an assignment expression, e.g. `unchecked_index(my_int_array, 2) = 3`.

#### `format(fmt StringLiteral, ...) string`
Takes the fmt string literal and replaces each placeholder `{}` with an argument, by calling the `writeTo` function for that argument. For example, `format("Four = {}", 2 + 2)` returns `Four = 4`, where the second argument is converted to a string by calling the function `int.writeTo`. Curly braces can be escaped by repeating them, e.g. `{{` is converted to a single `{` in the result string. The result string is allocated using `::currentAllocator`.
 
#### `get_argc_argv(argc *int, argv *pointer) void`
Note: will most likely be removed in the future.<br>
Sets `argc^` and `argv^` to the values that were passed at the start of the program.


## Unary operators

#### `operator^(*T) T`
Note: this is a postfix operator. Dereferences a pointer to a value and returns the value. Example:

	example(p *int) {
	 	val := p^
		// val is an int
	}

Mostly similar to C. TODO.

## Binary operators

Mostly similar to C. TODO.

## Operator precedence

Mostly similar to C. TODO.

## Type unification

Given integer types A and B, the unifying type T is defined as follows:

* sizeof(T) == max(sizeof(A), sizeof(B), 4)
* T is able to represent all values of A and B
* Prefer T to be a signed integer type, if possible

If no unifying type can be found for given types A and B, they are not 'unifiable'.


