Environment {
	getCommandLineArgs() {
		argc := 0
		argv := cast(null, pointer)
		get_argc_argv(ref argc, ref argv)
		cstrArray := Array<cstring> { dataPtr: argv, count: argc }
		result := new Array<string>(argc)
		for it, i in cstrArray {
			result[i] = string.from_cstring(it)
		}
		return result
	}
}
