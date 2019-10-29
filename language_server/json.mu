JsonReaderState struct #RefType {
    source string
    index int
    token JsonToken
    valueBuilder StringBuilder
}

JsonToken struct {
    type JsonTokenType
    value string
}

JsonTokenType enum {
    openBrace
    closeBrace
    openBracket
    closeBracket
    colon
    comma
    stringLiteral
    otherLiteral
}

JsonValue tagged_pointer {
    Map<string, JsonValue>
    List<JsonValue>
    *string
    *JsonOtherValue
}

JsonOtherValue struct {
    value string
}

Json {
    parse(source string) {
        s := new JsonReaderState { source: source, index: 0, valueBuilder: new StringBuilder{} }
        readToken(s)
        return parseObject(s)
    }

    parseValue(s JsonReaderState) JsonValue {
        if s.token.type == JsonTokenType.openBrace {
            return parseObject(s)
        } else if s.token.type == JsonTokenType.openBracket {
            return parseArray(s)
        } else if s.token.type == JsonTokenType.stringLiteral {
            value := s.token.value
            readToken(s)
            return new value
        } else if s.token.type == JsonTokenType.otherLiteral {
            value := s.token.value
            readToken(s)
            return new JsonOtherValue { value: value }
        }
        abandon()
    }

    parseObject(s JsonReaderState) Map<string, JsonValue> {
        result := new Map.create<string, JsonValue>()
        accept(s, JsonTokenType.openBrace)
        parseSep := false
        while s.token.type != JsonTokenType.closeBrace {
            if parseSep {
                accept(s, JsonTokenType.comma)
            } else {
                parseSep = true
            }
            key := readStringLiteral(s)
            accept(s, JsonTokenType.colon)
            value := parseValue(s)
            result.add(key, value)            
        }
        // TODO: Fix hack, add sentinel?
        assert(s.token.type == JsonTokenType.closeBrace)
        if s.index < s.source.length {
            readToken(s)
        }
        return result
    }    

    parseArray(s JsonReaderState) List<JsonValue> {
        result := new List<JsonValue>{}
        accept(s, JsonTokenType.openBracket)
        parseSep := false
        while s.token.type != JsonTokenType.closeBracket {
            if parseSep {
                accept(s, JsonTokenType.comma)
            } else {
                parseSep = true
            }
            result.add(parseValue(s))
        }
        accept(s, JsonTokenType.closeBracket)
        return result
    }

    accept(s JsonReaderState, type JsonTokenType) {
        assert(s.token.type == type)
        readToken(s)
    }

    readStringLiteral(s JsonReaderState) {
        assert(s.token.type == JsonTokenType.stringLiteral)
        value := s.token.value
        readToken(s)
        return value
    }

    readToken(s JsonReaderState) {
        ch := s.source[s.index]
        while ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
            s.index += 1
            ch = s.source[s.index]
        }
        if ch == '{' {
            s.token = JsonToken { type: JsonTokenType.openBrace }
            s.index += 1
        } else if ch == '}' {
            s.token = JsonToken { type: JsonTokenType.closeBrace }
            s.index += 1
        } else if ch == '[' {
            s.token = JsonToken { type: JsonTokenType.openBracket }
            s.index += 1
        } else if ch == ']' {
            s.token = JsonToken { type: JsonTokenType.closeBracket }
            s.index += 1
        } else if ch == ':' {
            s.token = JsonToken { type: JsonTokenType.colon }
            s.index += 1
        } else if ch == ',' {
            s.token = JsonToken { type: JsonTokenType.comma }
            s.index += 1
        } else if ch == '"' {
            s.index += 1
            ch = s.source[s.index]
            s.valueBuilder.clear()
            while true {
                if ch == '"' {
                    s.token = JsonToken { type: JsonTokenType.stringLiteral, value: s.valueBuilder.toString() }
                    s.index += 1
                    break
                } else if ch == '\\' {
                    s.index += 1
                    s.valueBuilder.writeChar(readEscapeSequence(s))
                } else {
                    s.valueBuilder.writeChar(ch)
                    s.index += 1
                }
                ch = s.source[s.index]
            }
        } else {
            from := s.index
            while (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '-' || ch == '+' || ch == '.' {
                s.index += 1
                ch = s.source[s.index]
            }
            assert(s.index > from)
            s.token = JsonToken { type: JsonTokenType.otherLiteral, value: s.source.slice(from, s.index) }
        }
    }

    readEscapeSequence(s JsonReaderState) {
        from := s.index
        ch := s.source[s.index]
        if ch == '"' {
            s.index += 1
            return '"'
        } else if ch == '\\' {
            s.index += 1
            return '\\'
        } else if ch == '/' {
            s.index += 1
            return '/'
        } else if ch == 'n' {
            s.index += 1
            return '\n'
        } else if ch == 'r' {
            s.index += 1
            return '\r'
        } else if ch == 't' {
            s.index += 1
            return '\t'
        } else if ch == 'u' {
            s.index += 1
            ch = s.source[s.index]
            chars := 0
            while chars < 4 && isHexDigit(ch) {
                s.index += 1
                chars += 1
                ch = s.source[s.index]
            }
            // TODO: convert to utf-8
            assert(chars == 4)
            return transmute(long.tryParseHex(s.source.slice(s.index - 4, s.index)).unwrap(), char)
        }
        abandon()
    }

    isHexDigit(ch char) {
        return (ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f') || (ch >= '0' && ch <= '9')
    }

    escapeString(s string) {
        rb := StringBuilder{}
        for i := 0; i < s.length {
            ch := s[i]
            code := transmute(ch, uint)
            if ch == '"' {
                rb.write("\\\"")
            } else if ch == '\\' {
                rb.write("\\\\")
            } else if ch == '\r' {
                rb.write("\\r")
            } else if ch == '\n' {
                rb.write("\\n")
            } else if ch == '\t' {
                rb.write("\\t")
            } else if 32 <= code && code < 127 {
                rb.writeChar(ch)
            } else {
                rb.write("\\u00")
                ulong.writeHexTo(code, ref rb)
            }
        }
        return rb.toString()
    }
}
