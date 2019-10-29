DebugBreak() void {
    // STUB
}

TcpSocket struct #RefType {
    handle pointer

    static_init() {
        // STUB
    }
    
    localClient(port ushort) {
        // STUB
        return TcpSocket{}
    }

    send(ts TcpSocket, dataPtr pointer, numBytes int) {
        // STUB
    }

    sendString(ts TcpSocket, s string) {
        // STUB
    }

    close(ts TcpSocket) {
        // STUB
    }    
}
