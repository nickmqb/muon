IntRange struct {
	from int
	to int
	
	cons(from int, to int) {
		return IntRange { from: from, to: to }
	}
}	

