float {
	writeTo(val float, sb StringBuilder) {
		double.writeTo(val, sb)
	}
}

double {
	writeTo(val double, sb StringBuilder) {
		max := 64
		sb.reserveForWrite(max)
		// TODO: we probably want a locale independent way to convert floating point numbers
		size := snprintf_(sb.dataPtr + sb.count, cast(max, uint), "%.17g", val)
		assert(0 < size && size < max)
		sb.count += size
	}

	snprintf_(str pointer #As("char *"), size usize, format cstring) int #Foreign("snprintf") #VarArgs
}
