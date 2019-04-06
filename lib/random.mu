Random {
	// Note: state^ must not be zero!
	xorshift32(state *uint) {
		x := state^
		x = xor(x, x << 13)
		x = xor(x, x >> 17)
		x = xor(x, x << 5)
		state^ = x
		return x
	}
}
