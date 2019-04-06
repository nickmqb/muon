printf(fmt cstring) int #Foreign("printf") #VarArgs

main() {
	n := 7
	a := 1_u
	b := 1_u
	for i := 1; i < n {	
		temp := a
		a += b
		b = temp
	}	
	printf("%d\n", a)
}
