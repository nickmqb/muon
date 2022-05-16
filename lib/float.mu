float {
	writeTo(val float, sb StringBuilder) {
		writeTo_formatted(val, sb, "%.9g")
	}

	writeTo_formatted(val double, sb StringBuilder, formatString cstring) {
		max := 64
		sb.reserveForWrite(max)
		// TODO: we probably want a locale independent way to convert floating point numbers
		size := double.snprintf_(sb.dataPtr + sb.count, cast(max, uint), formatString, val)
		assert(0 < size && size < max)
		sb.count += size
	}
}

double {
	writeTo(val double, sb StringBuilder) {
		writeTo_formatted(val, sb, "%.17g")
	}

	writeTo_formatted(val double, sb StringBuilder, formatString cstring) {
		max := 64
		sb.reserveForWrite(max)
		// TODO: we probably want a locale independent way to convert floating point numbers
		size := snprintf_(sb.dataPtr + sb.count, cast(max, uint), formatString, val)
		assert(0 < size && size < max)
		sb.count += size
	}

	snprintf_(str pointer #As("char *"), size usize, format cstring) int #Foreign("snprintf") #VarArgs
}
