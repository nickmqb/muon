exit(code int) void #Foreign("exit")

CStdlib {
    :stdout pointer #Foreign("stdout")
    fflush(fp pointer #As("FILE *")) int #Foreign("fflush")
}

Stdin {
    readBytesAsString(numBytes int) {
        if numBytes == 0 {
            return ""
        }
        buffer := ::currentAllocator.alloc(numBytes)
        read := CStdlib.fread(buffer, 1, checked_cast(numBytes, uint), CStdlib.stdin)
        assert(read == cast(numBytes, uint))
        return string.from(buffer, numBytes)
    }
}

:logSocket TcpSocket #Mutable
:logFile pointer #Mutable
:logStderr bool #Mutable
:newLine Maybe<string> #Mutable

debugMessage(s string) {
    if logSocket != null {
        logSocket.sendString(s)
    }
    if logFile != null {
        CStdlib.fprintf(logFile, "%.*s", s.length, s.dataPtr)
        CStdlib.fflush(logFile)
    }
    if logStderr {
        Stderr.write(s)
        CStdlib.fflush(CStdlib.stderr)
    }
}

abandonHandler(code int) {
    debugMessage("Abandoned\n")
    DebugBreak()
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
        Memory.memmove(list.dataPtr + index + s.length, list.dataPtr + index, cast(list.count - index, uint))
        Memory.memcpy(list.dataPtr + index, s.dataPtr, cast(s.length, uint))
        list.count += s.length
    }

    removeSlice(list List<char>, from int, to int) {
        assert(0 <= from && from <= to && to <= list.count)
        Memory.memmove(list.dataPtr + from, list.dataPtr + to, cast(list.count - to, uint))
        list.count -= (to - from)
    }

    setString(list List<char>, s string) {
        list.count = 0
        insertString(list, s, 0)
    }
}

tryFindDocumentByAbsPath(docs List<Document>, absPath string) {
    for d in docs {
        if Path.equals(d.absPath, absPath) {
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
        doc := cast(null, Document)
        range := Range{}
        if e.unit != null {
            doc = findDocumentByUnit(ws.documents, e.unit)
            span := e.span
            range = Range { start: indexToPos(doc, span.from), end: indexToPos(doc, span.to) }
        } else {
            doc = ws.documents[0]
            range = Range{}
        }
        diag := format("{{\"range\": {}, \"message\": \"{}\", \"severity\": 1}}", range.toJson(), Json.escapeString(e.text))
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
    CStdlib.fprintf(CStdlib.stdout, "%.*s", msg.length, msg.dataPtr)
    //fprintf(stderr, "%.*s", msg.length, msg.dataPtr)
    assert(CStdlib.fflush(CStdlib.stdout) == 0)
}

ResolvePathContext struct {
    rootPath string
}

resolvePath(path string, ctx *ResolvePathContext) {
    if Path.isAbsolutePath(path) {
        return Path.simplify(path)
    }
    return Path.simplify(Path.combine(ctx.rootPath, path))
}

handleInitialize(obj Map<string, JsonValue>, ws Workspace, args ServerArgs) {
    id := int.tryParse(obj.get("id").as(*JsonOtherValue)^.value).unwrap()

    params := obj.get("params").as(Map<string, JsonValue>)

    prev := Memory.pushAllocator(::documentAllocator.iAllocator_escaping())

    rootPath := ""
    if args.rootPath != "" {
        rootPath = args.rootPath
        debugMessage(format("Root path (from command line): {}\n", rootPath))
    } else {
        rootUriNode := params.getOrDefault("rootUri")
        rootPath = rootUriNode != null ? Path.fromFileUri(rootUriNode.as(*string)^) : params.get("rootPath").as(*string)^
        debugMessage(format("Root path (from language client): {}\n", rootPath))
    }

    rootPath = Path.simplify(rootPath)
    ctx := ResolvePathContext { rootPath: rootPath }
    
    errors := new List<ArgsParserError>{}
    compileArgs := ArgsParser.parseArgsFile(args.argsPath, errors, pointer_cast(resolvePath, fun<string, pointer, string>), pointer_cast(ref ctx, pointer))

    if errors.count > 0 {
        for e in errors {
            debugMessage(format("{}\n", e.text))
        }
        abandon()
    }

    ws.compileArgs = compileArgs

    ws.documents = new List<Document>{}
    for si in compileArgs.sources {
        text := new List<char>{}
        text.insertString(si.source, 0)
        text.add(transmute(0, char))

        doc := new Document {
            path: si.path,
            absPath: resolvePath(si.path, ref ctx),
            text: text,
            lineStart: new List<int>{}
        }

        updateLineMap(doc)
        ws.documents.add(doc)
    }

    Memory.restoreAllocator(prev)    

    compile(ws)

    response := format("{{\"jsonrpc\":\"2.0\",\"id\":{},\"result\":{{\"capabilities\":{{\"textDocumentSync\":2,\"definitionProvider\": true,\"workspaceSymbolProvider\":true}}}}}}", id)
    //response := "{\"jsonrpc\":\"2.0\",\"id\":0,\"error\":{\"code\":-32603,\"message\":\"internal server err\"}}"
    sendMessage(response)

    sendDiagnostics(ws)
}

handleDocumentOpen(obj Map<string, JsonValue>, ws Workspace) {
    params := obj.get("params").as(Map<string, JsonValue>)
    textDocument := params.get("textDocument").as(Map<string, JsonValue>)
    uri := textDocument.get("uri").as(*string)^
    path := Path.simplify(Path.fromFileUri(uri))
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

    debugMessage(format("Loaded document: {}\n", path))

    compile(ws)
    
    sendDiagnostics(ws)
}

handleDocumentChange(obj Map<string, JsonValue>, ws Workspace) {
    params := obj.get("params").as(Map<string, JsonValue>)
    textDocument := params.get("textDocument").as(Map<string, JsonValue>)
    uri := textDocument.get("uri").as(*string)^
    path := Path.simplify(Path.fromFileUri(uri))
    doc := tryFindDocumentByAbsPath(ws.documents, path)
    if doc == null {
        return
    }

    contentChanges := params.get("contentChanges").as(List<JsonValue>)

    prev := Memory.pushAllocator(::documentAllocator.iAllocator_escaping())
    for ccval in contentChanges {
        cc := ccval.as(Map<string, JsonValue>)
        text := cc.get("text").as(*string)^
        rangeNode := cc.getOrDefault("range")
        if rangeNode != null {
            range := Range.fromJson(rangeNode.as(Map<string, JsonValue>))
            fromIndex := doc.lineStart[range.start.line] + range.start.character
            toIndex := doc.lineStart[range.end.line] + range.end.character
            doc.text.removeSlice(fromIndex, toIndex)
            doc.text.insertString(text, fromIndex)
        } else {
            doc.text.setString(text)
            doc.text.add(transmute(0, char))
        }
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
    path := Path.simplify(Path.fromFileUri(uri))
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

handleShutdown(obj Map<string, JsonValue>) {
    id := int.tryParse(obj.get("id").as(*JsonOtherValue)^.value).unwrap()
    response := format("{{\"jsonrpc\":\"2.0\",\"id\":{},\"result\":null}}", id)
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

    // Compatibility hack: if all args are passed as a single string, split into individual args first
    commandLineArgs := Environment.getCommandLineArgs()
    if commandLineArgs.count == 2 && commandLineArgs[1].startsWith("--args ") {
        parsedCommandLineArgs := new commandLineArgs[1].split(' ')
        newCommandLineArgs := new Array<string>(parsedCommandLineArgs.count + 1)
        newCommandLineArgs[0] = commandLineArgs[0]
        parsedCommandLineArgs.copySlice(0, parsedCommandLineArgs.count, newCommandLineArgs, 1)
        commandLineArgs = newCommandLineArgs
    }

    errors := new List<CommandLineArgsParserError>{}
    parser := new CommandLineArgsParser.from(commandLineArgs, errors)
    args := parseArgs(parser)
    
    if errors.count > 0 {
        info := parser.getCommandLineInfo()
        for errors {
            Stderr.writeLine(CommandLineArgsParser.getErrorDesc(it, info))
        }
        return
    }

    if args.logPort != 0 {
        TcpSocket.static_init()
        ::logSocket = new TcpSocket.localClient(checked_cast(args.logPort, ushort))
    }
    if args.logFile {
        ::logFile = CStdlib.fopen("muon_language_server.log", "w")
        assert(::logFile != null)
    }
    ::logStderr = args.logStderr

    debugMessage("============== Starting server ==============\n")
    
    ::currentAllocator = Memory.heapAllocator()
    ::documentAllocator = new TrackingHeapAllocator{}
    ::compilationAllocator = new ArenaAllocator(64 * 1024 * 1024)
    ::currentAllocator = tempAlloc.iAllocator_escaping()

    isInitialized := false
    isShutdown := false
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
        debugMessage(format("Got message: {}\n", method))
        
        if method == "initialize" {
            //debugMessage(format("Info: {}\n{}\n", method, msg))
            assert(!isInitialized)
            assert(!isShutdown)
            handleInitialize(obj, ws, args)
            isInitialized = true
        } else if method == "shutdown" {
            handleShutdown(obj)
            isShutdown = true
        } else if method == "exit" {
            break
        } else {
            assert(isInitialized)
            assert(!isShutdown)
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

    if ::logSocket != null {
        ::logSocket.close()
    }
    if ::logFile != null {
        CStdlib.fclose(logFile)
    }
}
