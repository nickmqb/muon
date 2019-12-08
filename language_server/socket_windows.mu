DebugBreak() void #Foreign("DebugBreak")
Sleep(dwMilliseconds uint) void #Foreign("Sleep")
ExitProcess(uExitCode uint) void #Foreign("ExitProcess")

WSAStartup(wVersionRequired ushort, lpWSAData pointer #As("LPWSADATA")) int #Foreign("WSAStartup")
WSACleanup() int #Foreign("WSACleanup")
WSAGetLastError() int #Foreign("WSAGetLastError")
socket(af int, type int, protocol int) pointer #Foreign("socket")
bind(s pointer #As("SOCKET"), name *sockaddr_in #As("struct sockaddr *"), namelen int) int #Foreign("bind")
connect(s pointer #As("SOCKET"), name *sockaddr_in #As("struct sockaddr *"), namelen int) int #Foreign("connect")
listen(s pointer #As("SOCKET"), backlog int) int #Foreign("listen")
accept(s pointer #As("SOCKET"), addr *sockaddr_in #As("struct sockaddr *"), addrlen *int) pointer #Foreign("accept")
recv(s pointer #As("SOCKET"), buf pointer, len int, flags int) int #Foreign("recv")
send(s pointer #As("SOCKET"), buf pointer, len int, flags int) int #Foreign("send")
closesocket(s pointer #As("SOCKET")) int #Foreign("closesocket")
htons(hostshort ushort) ushort #Foreign("htons")
htonl(hostlong uint) uint #Foreign("htonl")

sockaddr_in struct {
    sin_family short
    sin_port ushort
    sin_addr uint
    sin_zero0 uint
    sin_zero1 uint
}

:AF_INET int #Foreign("AF_INET")
:SOCK_STREAM int #Foreign("SOCK_STREAM")
:IPPROTO_TCP int #Foreign("IPPROTO_TCP")
:INADDR_LOOPBACK uint #Foreign("INADDR_LOOPBACK")

:INVALID_SOCKET pointer #Foreign("INVALID_SOCKET")
:SOCKET_ERROR int #Foreign("SOCKET_ERROR")

TcpSocket struct #RefType {
    handle pointer

    static_init() {
        assert(pointer_cast(::currentAllocator.allocFn, pointer) == pointer_cast(ArenaAllocator.alloc, pointer))
        aa := pointer_cast(::currentAllocator.data, ArenaAllocator)
        assert(WSAStartup(0x202_us, aa.current) == 0)
    }
    
    localClient(port ushort) {
        handle := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)        
        assert(handle != INVALID_SOCKET)
        addr := sockaddr_in { sin_family: cast(AF_INET, short), sin_port: htons(port), sin_addr: htonl(INADDR_LOOPBACK) }
        assert(connect(handle, ref addr, sizeof(sockaddr_in)) == 0)
        return TcpSocket { handle: handle }
    }

    send(ts TcpSocket, dataPtr pointer, numBytes int) {
        assert(::send(ts.handle, dataPtr, numBytes, 0) == numBytes)
    }

    sendString(ts TcpSocket, s string) {
        send(ts, s.dataPtr, s.length)
    }

    close(ts TcpSocket) {
        assert(closesocket(ts.handle) == 0)
    }    
}
