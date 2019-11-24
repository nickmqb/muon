Path {
    fromFileUri(s string) {
        assert(s.startsWith(filePrefix))
        rb := StringBuilder{}
        for i := filePrefix.length; i < s.length {
            ch := s[i]
            if ch == '%' {
                rb.writeChar(transmute(long.tryParseHex(s.slice(i + 1, i + 3)).unwrap(), char))
                i += 2
            } else {
                rb.writeChar(ch)
            }
        }
        return rb.toString()
    }

    toFileUri(s string) {
        rb := StringBuilder{}
        rb.write(filePrefix)
        for i := 0; i < s.length {
            ch := s[i]
            if isLetterOrDigit(ch) || ch == '.' || ch == '/' || ch == '_' || ch == '-' {
                rb.writeChar(ch)
            } else if ch == '\\' {
                rb.writeChar('/')
            } else {
                rb.write("%")
                ulong.writeHexTo(transmute(ch, uint), ref rb)
            }
        }
        return rb.toString()
    }

    isLetterOrDigit(ch char) {
        return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')
    }		

    combine(a string, b string) {
        if a == "" {
            return b
        } else if b == "" {
            return a
        }
        return format("{}/{}", a, b)
    }

    getDirectoryName(path string) {
        pp := ParsedPath.fromString(path)
        pp.parts.removeIndexShift(pp.parts.count - 1)
        return pp.toString()
    }

    simplify(s string) {
        pp := ParsedPath.fromString(s)
        pp.simplify()
        return pp.toString()
    }
}

ParsedPath struct {
    parts List<string>

    fromString(s string) {
        parts := new List<string>{}
        from := 0
        for i := 0; i < s.length {
            ch := s[i]
            if ch == '/' || ch == '\\' {
                parts.add(s.slice(from, i))
                from = i + 1
            }
        }
        parts.add(s.slice(from, s.length))
        return ParsedPath { parts: parts }
    }

    simplify(pp *ParsedPath) {
        parts := pp.parts
        j := 0
        for i := 0; i < parts.count {
            part := parts[i]
            if part == ".." {
                assert(j > 0)
                j -= 1
            } else {
                if i != j {
                    parts[j] = parts[i]
                }
                j += 1
            }            
        }
        parts.setCountChecked(j)
    }

    toString(pp *ParsedPath) {
        rb := StringBuilder{}
        insertSep := false
        for p in pp.parts {
            if insertSep {
                rb.writeChar('/')
            } else {
                insertSep = true
            }
            rb.write(p)
        }
        return rb.toString()
    }
}
