CStdlib {
	printf(fmt cstring) int #Foreign("printf") #VarArgs
	:stdin pointer #Foreign("stdin")
	:stderr pointer #Foreign("stderr")
	fgets(s pointer #As("char *"), size int, stream pointer #As("FILE *")) pointer #Foreign("fgets")
	fopen(pathname cstring, mode cstring) pointer #Foreign("fopen")
	fread(ptr pointer, size usize, nmemb usize, stream pointer #As("FILE *")) usize #Foreign("fread")
	feof(stream pointer #As("FILE *")) int #Foreign("feof")
	fwrite(ptr pointer, size usize, nmemb usize, stream pointer #As("FILE *")) usize #Foreign("fwrite")
	fprintf(fp pointer #As("FILE *"), fmt cstring) int #Foreign("fprintf") #VarArgs
	fclose(stream pointer #As("FILE *")) int #Foreign("fclose")
}

Stdout {
	write(s string) {
		CStdlib.printf("%.*s", s.length, s.dataPtr)
	}

	writeLine(s string) {
		CStdlib.printf("%.*s\n", s.length, s.dataPtr)
	}
}

Stderr {
	write(s string) {
		CStdlib.fprintf(CStdlib.stderr, "%.*s", s.length, s.dataPtr)
	}

	writeLine(s string) {
		CStdlib.fprintf(CStdlib.stderr, "%.*s\n", s.length, s.dataPtr)
	}
}

Stdin {
	:tryReadLine_eof = 1
	:tryReadLine_ioError = 2
	
	tryReadLine() {
		rb := StringBuilder{}
		blockSize := 4096
		while true {
			rb.reserveForWrite(blockSize)
			from := rb.dataPtr + rb.count
			ptr := CStdlib.fgets(from, blockSize, CStdlib.stdin)
			if ptr == null {
				rb.compactToString() // This frees the StringBuilder's dataPtr
				if CStdlib.feof(CStdlib.stdin) != 0 {
					return Result.fromError<string>(tryReadLine_eof)
				} else {
					return Result.fromError<string>(tryReadLine_ioError)
				}
			}
			p := from
			while pointer_cast(p, *byte)^ != 0 {
				p += 1
			}
			len := checked_cast(p.subtractSigned(from), int)
			assert(0 < len && len < blockSize)
			lastChar := pointer_cast(from + len - 1, *char)^
			if lastChar == '\n' {
				len -= 1
				rb.count += len
				return Result.fromValue(rb.compactToString())
			} else {
				rb.count += len
				if len < blockSize - 1 {
					return Result.fromValue(rb.compactToString())
				}
			}
		}
	}
}

File {
	tryReadToStringBuilder(path string, out StringBuilder) {
		fp := CStdlib.fopen(path.alloc_cstring(), "rb")
		// TODO: free allocated path cstring
		if fp == null {
			return false
		}
		blockSize := 4096_u
		while true {
			out.reserveForWrite(cast(blockSize, int))
			read := CStdlib.fread(out.dataPtr + out.count, 1, blockSize, fp)
			if read > 0 {
				assert(read <= blockSize)
				out.count += checked_cast(read, int)
			} else {
				break
			}
		}		
		if CStdlib.feof(fp) == 0 {
			return false
		}
		if CStdlib.fclose(fp) != 0 {
			return false
		}
		return true
	}
	
	tryWriteString(path string, data string) {
		fp := CStdlib.fopen(path.alloc_cstring(), "wb")
		// TODO: free allocated path cstring
		if fp == null {
			return false
		}
		blockSize := 4096_u
		len := cast(data.length, uint)
		i := 0_u
		while i < len {
			size := min(blockSize, len - i)
			written := CStdlib.fwrite(data.dataPtr + i, 1, size, fp)
			if written > 0 {
				assert(written <= size)
				i += cast(written, uint)
			} else {
				return false
			}
		}
		if CStdlib.fclose(fp) != 0 {
			return false
		}
		return true
	}
}
