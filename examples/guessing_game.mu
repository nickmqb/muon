time(t *uint) uint #Foreign("time")

main() {
	::currentAllocator = Memory.newArenaAllocator(16 * 1024)
	rs := time(null)
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
