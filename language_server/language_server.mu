exit(code int) void #Foreign("exit")
:stderr pointer #Foreign("stderr")
:stdout pointer #Foreign("stdout")
fprintf(fp pointer #As("FILE *"), fmt cstring) int #Foreign("fprintf") #VarArgs
fflush(fp pointer #As("FILE *")) int #Foreign("fflush")

Stdin {
    readBytesAsString(numBytes int) {
        if numBytes == 0 {
            return ""
        }
        buffer := ::currentAllocator.alloc(numBytes)
        read := fread(buffer, 1, checked_cast(numBytes, uint), stdin)
        assert(read == cast(numBytes, uint))
        return string.from(buffer, numBytes)
    }
}

Stderr {
    write(s string) {
        fprintf(stderr, "%.*s", s.length, s.dataPtr)
    }

    writeLine(s string) {
        fprintf(stderr, "%.*s\n", s.length, s.dataPtr)
    }
}

:debugSocket TcpSocket #Mutable
:newLine Maybe<string> #Mutable

debugMessage(s string) {
    if debugSocket != null {
        debugSocket.sendString(s)
    }
    Stderr.write(s)
    fflush(stderr)
}

abandonHandler(code int) {
    DebugBreak()
    debugMessage("Abandoned\n")
    exit(1)
}

Position struct {
    line int
    character int

    fromJson(obj Map<string, JsonValue>) {
        line := int.tryParse(obj.get("line").as(*JsonOtherValue)^.value).unwrap()
        character := int.tryParse(obj.get("character").as(*JsonOtherValue)^.value).unwrap()
        return Position { line: line, character: character }
    }
}

Range struct {
    start Position
    end Position

    fromJson(obj Map<string, JsonValue>) {
        start := Position.fromJson(obj.get("start").as(Map<string, JsonValue>))
        end := Position.fromJson(obj.get("end").as(Map<string, JsonValue>))
        return Range { start: start, end: end }
    }

    toJson(this Range) {
        return format("{{\"start\":{{\"line\":{},\"character\":{}}},\"end\":{{\"line\":{},\"character\":{}}}}}", this.start.line, this.start.character, this.end.line, this.end.character)
    }
}

Document struct #RefType {
    absPath string
    path string
    text List<char>
    lineStart List<int>
    unit CodeUnit
    hasDiagnostics bool
}

Workspace struct #RefType {
    documents List<Document>
    compileArgs CompileArgs
    latestComp Compilation
    //latestCompMarker pointer
}

updateLineMap(doc Document) {
    doc.lineStart.clear()
    doc.lineStart.add(0)
    i := 0
    while i < doc.text.count {
        ch := doc.text[i]
        i += 1
        if ch == '\n' {
            doc.lineStart.add(i)
        }
    }
}

string {
    trimRight(s string) {
        index := s.length
        while index > 0 {
            ch := s[index - 1]
            if !(ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
                break
            }
            index -= 1
        }
        return s.slice(0, index)
    }
}

List {
    copyAsString(list List<char>) {
        return string.alloc(list.dataPtr, list.count)
    }

    insertString(list List<char>, s string, index int) {
        assert(s.length >= 0)
        assert(0 <= index && index <= list.count)
        newSize := CheckedMath.addPositiveInt(list.count, s.length)
        list.reserve(newSize)
        memmove(list.dataPtr + index + s.length, list.dataPtr + index, cast(list.count - index, uint))
        memcpy(list.dataPtr + index, s.dataPtr, cast(s.length, uint))
        list.count += s.length
    }

    removeSlice(list List<char>, from int, to int) {
        assert(0 <= from && from <= to && to <= list.count)
        memmove(list.dataPtr + from, list.dataPtr + to, cast(list.count - to, uint))
        list.count -= (to - from)
    }
}

tryFindDocumentByAbsPath(docs List<Document>, absPath string) {
    for d in docs {
        if d.absPath == absPath {
            return d
        }
    }
    return null
}

findDocumentByUnit(docs List<Document>, unit CodeUnit) {
    for d in docs {
        if d.unit == unit {
            return d
        }
    }
    abandon()
}

posToIndex(doc Document, line int, character int) {    
    return doc.lineStart[line] + character
}

indexToPos(doc Document, index int) {
    line := 1
    while line < doc.lineStart.count && index >= doc.lineStart[line] {
        line += 1
    }
    return Position { line: line - 1, character: index - doc.lineStart[line - 1] }
}

compile(ws Workspace) {
    prev := Memory.pushAllocator(::compilationAllocator.iAllocator_escaping())
    ::compilationAllocator.restoreState(::compilationAllocator.from)

    comp := new Compilation { units: new List<CodeUnit>{}, errors: new List<Error>{} }
    ws.latestComp = comp

    for d, id in ws.documents {
        unit := Parser.parse(d.text.copyAsString(), comp.errors)
        unit.path = d.path
        unit.id = id
        comp.units.add(unit)
        d.unit = unit
    }

    tcc := TypeCheckerFirstPass.createContext(comp)
    if !TypeCheckerFirstPass.check(tcc) {
        return
    }
    TypeChecker.check(tcc)
    if !ws.compileArgs.noEntryPoint {
        TypeChecker.checkHasEntryPoint(tcc)
    }
    
    Memory.restoreAllocator(prev)

    debugMessage(format("Sources compiled: {}\n", ws.documents.count))
}

sendDiagnostics(ws Workspace) {
    assert(ws.latestComp != null)

    debugMessage(format("Sending diagnostics: {} errors\n", ws.latestComp.errors.count))

    diags := Map.create<Document, List<string>>()
    for e in ws.latestComp.errors {
        doc := findDocumentByUnit(ws.documents, e.unit)
        span := e.span
        range := Range { start: indexToPos(doc, span.from), end: indexToPos(doc, span.to) }
        diag := format("{{\"range\": {}, \"message\": \"{}\"}}", range.toJson(), Json.escapeString(e.text))
        list := diags.getOrDefault(doc)
        if list == null {
            list = new List<string>{}
            diags.add(doc, list)
        }
        list.add(diag)
    }

    for e in diags {
        doc := e.key
        list := e.value
        arr := ref list.slice(0, list.count)
        doc.hasDiagnostics = true
        notification := format("{{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{{\"uri\":\"{}\",\"diagnostics\":[{}]}}}}", Path.toFileUri(doc.absPath), string.join(", ", arr))
        sendMessage(notification)
    }

    for doc in ws.documents {
        if doc.hasDiagnostics && diags.getOrDefault(doc) == null {
            doc.hasDiagnostics = false
            notification := format("{{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{{\"uri\":\"{}\",\"diagnostics\":[]}}}}", Path.toFileUri(doc.absPath))
            sendMessage(notification)
        }
    }
}

sendMessage(s string) {
    msg := format("Content-Length: {}{}{}{}", s.length, newLine.unwrap(), newLine.unwrap(), s)
    fprintf(stdout, "%.*s", msg.length, msg.dataPtr)
    fprintf(stderr, "%.*s", msg.length, msg.dataPtr)
    assert(fflush(stdout) == 0)
}

handleInitialize(obj Map<string, JsonValue>, ws Workspace, args ServerArgs) {
    params := obj.get("params").as(Map<string, JsonValue>)

    prev := Memory.pushAllocator(::documentAllocator.iAllocator_escaping())

    rootPath := params.get("rootPath").as(*string)^
    sourceRootPath := Path.combine(rootPath, Path.getDirectoryName(args.argsPath))
    
    errors := new List<ArgsParserError>{}
    compileArgs := ArgsParser.parseArgsFile(args.argsPath, errors)
    ws.compileArgs = compileArgs

    ws.documents = new List<Document>{}
    for si in compileArgs.sources {
        text := new List<char>{}
        text.insertString(si.source, 0)
        text.add(transmute(0, char))

        doc := new Document {
            path: si.path,
            absPath: Path.simplify(Path.combine(sourceRootPath, si.path)),
            text: text,
            lineStart: new List<int>{}
        }

        updateLineMap(doc)
        ws.documents.add(doc)
    }

    Memory.restoreAllocator(prev)

    compile(ws)

    response := "{\"jsonrpc\":\"2.0\",\"id\":0,\"result\":{\"capabilities\":{\"textDocumentSync\":2,\"definitionProvider\": true,\"workspaceSymbolProvider\":true}}}"
    //response := "{\"jsonrpc\":\"2.0\",\"id\":0,\"error\":{\"code\":-32603,\"message\":\"internal server err\"}}"
    sendMessage(response)

    sendDiagnostics(ws)
}

handleDocumentOpen(obj Map<string, JsonValue>, ws Workspace) {
    params := obj.get("params").as(Map<string, JsonValue>)
    textDocument := params.get("textDocument").as(Map<string, JsonValue>)
    uri := textDocument.get("uri").as(*string)^
    path := Path.fromFileUri(uri)
    doc := tryFindDocumentByAbsPath(ws.documents, path)
    if doc == null {
        debugMessage(format("Ignoring document: {}\n", path))
        return
    }

    newText := textDocument.get("text").as(*string)^

    prev := Memory.pushAllocator(::documentAllocator.iAllocator_escaping())
    doc.text.clear()
    doc.text.insertString(newText, 0)
    doc.text.add(transmute(0, char))
    updateLineMap(doc)
    Memory.restoreAllocator(prev)

    compile(ws)
    
    debugMessage(format("Loaded document: {}\n", path))
}

handleDocumentChange(obj Map<string, JsonValue>, ws Workspace) {
    params := obj.get("params").as(Map<string, JsonValue>)
    textDocument := params.get("textDocument").as(Map<string, JsonValue>)
    uri := textDocument.get("uri").as(*string)^
    path := Path.fromFileUri(uri)
    doc := tryFindDocumentByAbsPath(ws.documents, path)
    if doc == null {
        return
    }

    contentChanges := params.get("contentChanges").as(List<JsonValue>)

    prev := Memory.pushAllocator(::documentAllocator.iAllocator_escaping())
    for ccval in contentChanges {
        cc := ccval.as(Map<string, JsonValue>)
        range := Range.fromJson(cc.get("range").as(Map<string, JsonValue>))
        text := cc.get("text").as(*string)^
        fromIndex := doc.lineStart[range.start.line] + range.start.character
        toIndex := doc.lineStart[range.end.line] + range.end.character
        doc.text.removeSlice(fromIndex, toIndex)
        doc.text.insertString(text, fromIndex)
    }
    updateLineMap(doc)
    Memory.restoreAllocator(prev)

    compile(ws)
    sendDiagnostics(ws)
}

handleGoToDefinition(obj Map<string, JsonValue>, ws Workspace) {
    id := int.tryParse(obj.get("id").as(*JsonOtherValue)^.value).unwrap()
    params := obj.get("params").as(Map<string, JsonValue>)
    textDocument := params.get("textDocument").as(Map<string, JsonValue>)
    uri := textDocument.get("uri").as(*string)^
    path := Path.fromFileUri(uri)
    doc := tryFindDocumentByAbsPath(ws.documents, path)
    if doc == null {
        return
    }

    pos := Position.fromJson(params.get("position").as(Map<string, JsonValue>))
    index := posToIndex(doc, pos.line, pos.character)
    ap := PathFinder.find(doc.unit, index)
    debugMessage("-- Path --\n")
    for seg in ap {
        debugMessage(format("{}\n", AstDebugHelper.nodeToString(seg)))
    }
    def := CodeInfoHelper.findDefinition(ap)
    if def.unit != null {
        defDoc := findDocumentByUnit(ws.documents, def.unit)
        defUri := Path.toFileUri(defDoc.absPath)
        r0 := indexToPos(defDoc, def.span.from)
        r1 := indexToPos(defDoc, def.span.to)
        rangeJson := Range { start: r0, end: r1 }.toJson()
        response := format("{{\"jsonrpc\":\"2.0\",\"id\":{},\"result\":{{\"uri\":\"{}\",\"range\":{}}}}}", id, defUri, rangeJson)
        sendMessage(response)
    } else {
        response := format("{{\"jsonrpc\":\"2.0\",\"id\":{},\"result\":null}}", id)
        sendMessage(response)
    }
}

compareMatch(a Node, b Node) {
    return string.compare_ignoreCase(CodeInfoHelper.getMemberName(a), CodeInfoHelper.getMemberName(b))
}

handleFindSymbol(obj Map<string, JsonValue>, ws Workspace) {
    id := int.tryParse(obj.get("id").as(*JsonOtherValue)^.value).unwrap()
    params := obj.get("params").as(Map<string, JsonValue>)
    query := params.get("query").as(*string)^
    comp := ws.latestComp
    matches := CodeInfoHelper.findSymbols(comp, query)
    matches.stableSort(compareMatch)
    matches.setCountChecked(min(matches.count, 25))

    out := List<string>{}
    for m in matches {
        name := CodeInfoHelper.getMemberName(m)
        loc := CodeInfoHelper.getMemberLocation(m)
        type := getMemberType(m)
        fullNamespace := getFullNamespace(comp, getNamespace(m))
        doc := findDocumentByUnit(ws.documents, loc.unit)
        r0 := indexToPos(doc, loc.span.from)
        r1 := indexToPos(doc, loc.span.to)
        range := Range { start: r0, end: r1 }
        location := format("{{\"uri\":\"{}\",\"range\":{}}}", Path.toFileUri(doc.absPath), range.toJson())
        out.add(format("{{\"name\":\"{}\",\"kind\":{},\"location\":{},\"containerName\":\"{}\"}}", Json.escapeString(name), type, location, Json.escapeString(fullNamespace)))
    }
    
    response := format("{{\"jsonrpc\":\"2.0\",\"id\":{},\"result\":[{}]}}", id, string.join(",", ref out.slice(0, out.count)))
    sendMessage(response)
}

getMemberType(mem Node) {
    match mem {
        FunctionDef: return 12
        FieldDef: return 8
        StaticFieldDef: {
            if (mem.flags & StaticFieldFlags.isEnumOption) != 0 {
                return 22
            } else if (mem.flags & StaticFieldFlags.mutable) != 0 {
                return 13
            } else {
                return 14
            }
        }
        Namespace: {
            if mem.kind == NamespaceKind.struct_ {
                if (mem.flags & TypeFlags.refType) != 0 {
                    return 5
                } else {
                    return 23
                }
            } else if mem.kind == NamespaceKind.enum_ {
                return 10
            } else if mem.kind == NamespaceKind.taggedPointerEnum {
                return 23
            } else {
                return 3
            }        
        }
    }
}

getNamespace(mem Node) {
    match mem {
        FunctionDef: return mem.ns
        FieldDef: return mem.ns
        StaticFieldDef: return mem.ns
        Namespace: return mem.parent
    }
}

getFullNamespace(comp Compilation, ns Namespace) {
    segments := List<Namespace>{}
    while ns != comp.top {
        segments.add(ns)
        ns = ns.parent
    }
    rb := StringBuilder{}
    for i := segments.count - 1; i >= 0; i -= 1 {
        rb.write(segments[i].name)
        if i > 0 {
            rb.write(".")
        }
    }
    return rb.toString()
}

ArenaAllocator {
    debugInfo(a ArenaAllocator) {
        capacity := cast(a.to.subtractSigned(a.from), long)
        used := cast(a.current.subtractSigned(a.from), long)
        return format("{}k ({}%)", used / 1024, used * 100 / capacity)
    }
}

TrackingHeapAllocator struct #RefType {
    bytesAllocated long

    alloc(a TrackingHeapAllocator, numBytes ssize) {
        a.bytesAllocated += numBytes
        return Memory.heapAllocFn(null, numBytes)
    }

    realloc(a TrackingHeapAllocator, ptr pointer, newSizeInBytes ssize, prevSizeInBytes ssize, copySizeInBytes ssize) {
        a.bytesAllocated += newSizeInBytes
        a.bytesAllocated -= prevSizeInBytes
        return Memory.heapReallocFn(null, ptr, newSizeInBytes, prevSizeInBytes, copySizeInBytes)
    }

    iAllocator_escaping(a TrackingHeapAllocator) {
        return IAllocator {
            data: pointer_cast(a, pointer),
            allocFn: pointer_cast(TrackingHeapAllocator.alloc, fun<pointer, ssize, pointer>),
            reallocFn: pointer_cast(TrackingHeapAllocator.realloc, fun<pointer, pointer, ssize, ssize, ssize, pointer>),
        }
    }

    debugInfo(a TrackingHeapAllocator) {
        return format("{}k", a.bytesAllocated / 1024)
    }
}

:documentAllocator TrackingHeapAllocator #ThreadLocal #Mutable
:compilationAllocator ArenaAllocator #ThreadLocal #Mutable

main() {
    ::currentAllocator = Memory.heapAllocator()
    tempAlloc := new ArenaAllocator(16 * 1024 * 1024)
    ::currentAllocator = tempAlloc.iAllocator_escaping()

    ::abandonFn = abandonHandler

    Tag.static_init()

    argsArray := Environment.getCommandLineArgs()
    argsString := string.join(" ", ref argsArray.slice(1, argsArray.count))
    errors := new List<ArgsParserError>{}
    args := ServerArgsParser.parse(argsString, errors)
    
    if errors.count > 0 {
        for e in errors {
            Stderr.writeLine(e.text)
        }
        return
    }

    if args.debugPort != 0 {
        TcpSocket.static_init()
        ::debugSocket = new TcpSocket.localClient(checked_cast(args.debugPort, ushort))
    }

    debugMessage("============== Starting server ==============\n")
    
    ::currentAllocator = Memory.heapAllocator()
    ::documentAllocator = new TrackingHeapAllocator{}
    ::compilationAllocator = new ArenaAllocator(64 * 1024 * 1024)
    ::currentAllocator = tempAlloc.iAllocator_escaping()

    isInitialized := false
    ws := new Workspace{}

    while true {
        prev := tempAlloc.pushState()

        line := Stdin.tryReadLine().unwrap()
        if !newLine.hasValue {
            newLine = Maybe.from(line[line.length - 1] == '\r' ? "\r\n" : "\n") // Static string, no allocations
        }
        line = line.trimRight()
        
        prefix := "Content-Length: "
        assert(line.startsWith(prefix))
        contentLength := int.tryParse(line.slice(prefix.length, line.length)).unwrap()
        assert(contentLength >= 0)

        line = Stdin.tryReadLine().unwrap().trimRight()
        assert(line == "")

        msg := Stdin.readBytesAsString(contentLength)
        obj := Json.parse(msg)
        method := obj.get("method").as(*string)^
        
        if method == "initialize" {
            assert(!isInitialized)
            handleInitialize(obj, ws, args)
            isInitialized = true
        } else {
            assert(isInitialized)
            if method == "textDocument/didOpen" {
                handleDocumentOpen(obj, ws)
            } else if method == "textDocument/didChange" {
                handleDocumentChange(obj, ws)
            } else if method == "textDocument/definition" {
                handleGoToDefinition(obj, ws)
            } else if method == "workspace/symbol" {
                handleFindSymbol(obj, ws)
            } else {
                debugMessage(format("Unknown method: {}\n{}\n", method, msg))
            }
        }

        debugMessage(format("DocAlloc: {}, CompAlloc: {}, TempAlloc: {}\n", ::documentAllocator.debugInfo(), ::compilationAllocator.debugInfo(), tempAlloc.debugInfo()))

        tempAlloc.restoreState(prev)
    }

    ::debugSocket.close()
}
