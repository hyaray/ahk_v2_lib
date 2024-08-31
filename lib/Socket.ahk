; socket.md
class Socket {
    static WM_SOCKET:=0x9987, MSG_PEEK:=2, FD_READ:=1, FD_ACCEPT:=8, FD_CLOSE:=32
    Bound:=false, Blocking:=true, BlockSleep:=50

    static main(arrAddr, sSend) {
        oS := SocketTCP()
        oS.connect(arrAddr)
        oS.sendText(sSend)
        return oS.recvText(1024)
    }
 
    ;OnTCPAccept(os) {
    ;    newSocket := os.accept()
    ;    sRecv := newSocket.recvText()
    ;    ;deal
    ;    res := strlen(sRecv) . "`n" . sRecv
    ;    switch sRecv {
    ;        case "guanji": shutdown(5)
    ;    }
    ;    ;return
    ;    newSocket.sendText(res)
    ;    if (1) ;是否立即关闭连接
    ;        newSocket.disconnect()
    ;}
    static server(arrAddr, fun) {
        os := SocketTCP()
        os.onAccept := fun
        os.bind(arrAddr)
        os.listen()
    }

    __new(Socket:=-1, ProtocolId:=6, SocketType:=1) {
        static Init := 0
        if (!Init) {
            ; dllcall("LoadLibrary", "Str", "ws2_32", "Ptr")
            WSAData := buffer(394 + A_PtrSize)
            if (err := dllcall("ws2_32\WSAStartup", "UShort",0x0202, "Ptr",WSAData))
                throw Error("Error starting Winsock",, err)
            if (numget(WSAData, 2, "UShort") != 0x0202)
                throw Error("Winsock version 2.2 not available")
            Init := true
        }
        this.Ptr := Socket, this.ProtocolId := ProtocolId, this.SocketType := SocketType
    }

    __Delete() {
		if (this.Ptr != -1)
        this.disconnect()
    }

    ;oSocket := Socket().Connect(["192.168.6.241","50505"])
    connect(arrAddr) {
        if (this.Ptr != -1)
            throw Error("Socket already connected")
        Next := pAddrInfo := this.GetAddrInfo(arrAddr)
        while Next {
            ai_addrlen := numget(Next, 16, "UPtr")
            ai_addr := numget(Next, 16 + (2 * A_PtrSize), "Ptr")
            if ((this.Ptr := dllcall("ws2_32\socket", "Int",numget(Next,4,"Int"), "Int",this.SocketType, "Int",this.ProtocolId, "Ptr")) != -1) {
                if (dllcall("ws2_32\WSAConnect", "Ptr",this.Ptr, "Ptr",ai_addr, "UInt",ai_addrlen, "Ptr",0, "Ptr",0, "Ptr",0, "Ptr",0, "Int") == 0) {
                    dllcall("ws2_32\FreeAddrInfoW", "Ptr",pAddrInfo) ; TODO: Error Handling
                    return this.EventProcRegister(Socket.FD_READ | Socket.FD_CLOSE)
                }
                this.disconnect()
            }
            Next := numget(Next, 16 + (3 * A_PtrSize), "Ptr")
        }
        throw Error("Error connecting")
    }

    bind(arrAddr) {
        if (this.Ptr != -1)
            throw Error("Socket already connected")
        Next := pAddrInfo := this.GetAddrInfo(arrAddr)
        while Next {
            ai_addrlen := numget(Next, 16, "UPtr")
            ai_addr := numget(Next, 16 + (2 * A_PtrSize), "Ptr")
            if ((this.Ptr := dllcall("ws2_32\socket", "Int",numget(Next,4,"Int"), "Int",this.SocketType, "Int",this.ProtocolId, "Ptr")) != -1) {
                if (dllcall("ws2_32\bind", "Ptr",this, "Ptr",ai_addr, "UInt",ai_addrlen, "Int") == 0) {
                    dllcall("ws2_32\FreeAddrInfoW", "Ptr",pAddrInfo) ; TODO: Error Handling
                    return this.EventProcRegister(Socket.FD_READ | Socket.FD_ACCEPT | Socket.FD_CLOSE)
                }
                this.disconnect()
            }
            Next := numget(Next, 16 + (3 * A_PtrSize), "Ptr")
        }
        throw Error("Error binding")
    }

    listen(backlog:=32) => dllcall("ws2_32\listen", "Ptr",this, "Int",backlog) == 0

    accept() {
        if ((s := dllcall("ws2_32\accept", "Ptr",this, "Ptr",0, "Ptr",0, "Ptr")) == -1)
            throw Error("Error calling accept",, this.GetLastError())
        Sock := Socket(s, this.ProtocolId, this.SocketType)
        Sock.EventProcRegister(Socket.FD_READ | Socket.FD_CLOSE)
        return Sock
    }

    disconnect() {
        ; Return 0 if not connected
        if (this.Ptr == -1)
            return 0
        ; Unregister the socket event handler and close the socket
        this.EventProcUnregister()
        if (dllcall("ws2_32\closesocket", "Ptr",this, "Int") == -1)
            throw Error("Error closing socket",, this.GetLastError())
        this.Ptr := -1
        return 1
    }

    MsgSize() {
        if (dllcall("ws2_32\ioctlsocket", "Ptr",this, "UInt",0x4004667F, "UInt*",&argp:=0) == -1) ;FIONREAD
            throw Error("Error calling ioctlsocket",, this.GetLastError())
        return argp
    }

    send(pBuffer, BufSize, Flags:=0) {
        if ((r := dllcall("ws2_32\send", "Ptr",this, "Ptr",pBuffer, "Int",BufSize, "Int",Flags)) == -1)
            throw Error("Error calling send",, this.GetLastError())
        return r
    }

    sendText(Text, Flags:=0, Encoding:="UTF-8") {
        oBuf := buffer(strput(Text, Encoding) - ((Encoding = "UTF-16" || Encoding = "cp1200") ? 2 : 1))
        len := strput(Text, oBuf, Encoding)
        return this.send(oBuf, len, Flags)
    }

    ;return len
    ;data is in oBuf
    recv(&oBuf, BufSize:=0, Flags:=0, Timeout:=0) {
        t := 0
        while (!(len := this.MsgSize()) && this.Blocking && (!Timeout || t < Timeout))
            Sleep(this.BlockSleep), t += this.BlockSleep
        if (!len)
            return 0
        if (!BufSize)
            BufSize := len
        else
            BufSize := Min(BufSize, len)
        oBuf := buffer(BufSize)
        if ((r := dllcall("ws2_32\recv", "Ptr",this, "Ptr",oBuf, "Int",BufSize, "Int",Flags)) == -1)
            throw Error("Error calling recv",, this.GetLastError())
        OutputDebug(format("i#{1} {2}:r{3},BufSize={4}", A_LineFile,A_LineNumber,r,BufSize))
        return r
    }

    recvText(BufSize:=0, Flags:=0, Encoding:="UTF-8", ms:=2000) {
        if (len := this.recv(&oBuf:=0, BufSize, flags, ms))
            return StrGet(oBuf, len, Encoding)
        return ""
    }

    RecvLine(BufSize:=0, Flags:=0, Encoding:="UTF-8", KeepEnd:=false) {
        while !(i := InStr(this.recvText(BufSize, Flags | Socket.MSG_PEEK, Encoding), "`n")) {
            if (!this.Blocking)
                return ""
            Sleep(this.BlockSleep)
        }
        if (KeepEnd)
            return this.recvText(i, Flags, Encoding)
        else
            return RTrim(this.recvText(i, Flags, Encoding), "`r`n")
    }

    ; https://docs.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-getpeername
    GetPeerName() => dllcall("ws2_32\GetPeerName", "ptr",this, "ptr",&name:=0, "int",len:=0)

    ; https://docs.microsoft.com/en-us/windows/win32/api/ws2tcpip/nf-ws2tcpip-getaddrinfo
    GetAddrInfo(arrAddr) {
        Host := arrAddr[1]
        Port := arrAddr[2]
        bufHints := buffer(16 + (4 * A_PtrSize), 0)
        numput("Int",this.SocketType, "Int",this.ProtocolId, bufHints, 8)
        if (err := dllcall("ws2_32\GetAddrInfoW", "Str",Host, "Str",string(Port), "Ptr",bufHints, "Ptr*",&Result:=0))
            throw Error("Error calling GetAddrInfo",, err)
        return Result
    }

    OnMessage(wParam, lParam, Msg, hWnd) {
        if (Msg != Socket.WM_SOCKET || wParam != this.Ptr)
            return
        if (lParam & Socket.FD_READ)
            this.HasOwnProp('onRecv') ? this.onRecv() : 0
        else if (lParam & Socket.FD_ACCEPT) ; https://docs.microsoft.com/en-us/cpp/mfc/reference/casyncsocket-class?view=msvc-170#onaccept
            this.HasOwnProp('onAccept') ? this.onAccept() : 0
        else if (lParam & Socket.FD_CLOSE)
            this.EventProcUnregister(), this.HasOwnProp('OnDisconnect') ? this.OnDisconnect() : 0
    }

    EventProcRegister(lEvent) {
        this.AsyncSelect(lEvent)
        if (!this.Bound) {
            this.Bound := ObjBindMethod(this, "OnMessage")
            OnMessage(Socket.WM_SOCKET, this.Bound)
        }
    }

    EventProcUnregister() {
        this.AsyncSelect(0)
        if (this.Bound) {
            OnMessage(Socket.WM_SOCKET, this.Bound, 0)
            this.Bound := false
        }
    }

    AsyncSelect(lEvent) {
        if (dllcall("ws2_32\WSAAsyncSelect"
            , "Ptr",this	; s
            , "Ptr", A_ScriptHwnd	; hWnd
            , "UInt", Socket.WM_SOCKET	; wMsg
            , "UInt", lEvent) == -1)	; lEvent
        throw Error("Error calling WSAAsyncSelect",, this.GetLastError())
    }

    GetLastError() => dllcall("ws2_32\WSAGetLastError")
}

class SocketTCP extends Socket {

    __new(socket:=-1) => super.__new(socket, 6, 1) ; IPPROTO_TCP SOCK_STREAM

}

class SocketUDP extends Socket {
    __new(socket:=-1) => super.__new(socket, 17, 2) ; IPPROTO_UDP SOCK_DGRAM

    recvfrom(BufSize:=0, Flags:=0, &AddrFrom:=0) {
        while (!(len := this.MsgSize()) && this.Blocking)
            Sleep(this.BlockSleep)
        if (!len)
            return 0
        if (!BufSize)
            BufSize := len
        oBuf := buffer(BufSize)
        AddrFrom := buffer(16, 0)
        if ((r := dllcall("Ws2_32\recvfrom", "ptr",this, "Ptr",buffer, "Int",BufSize, "Int",Flags, "Ptr",AddrFrom, "Ptr*",AddrFrom.size)) == -1)
        throw Error("Error calling RecvFrom",, this.GetLastError())
        return r
    }

    ; https://learn.microsoft.com/en-us/windows/win32/winsock/sockaddr-2
    sockaddr(ip, port) {
        buf := buffer(16, 0)
        numput("Short", 2, buf) ; sin_family
        numput("UShort", dllcall("Ws2_32.dll\htons", "UShort",Port), buf, 2) ; sin_port
        numput("UInt", dllcall("Ws2_32.dll\inet_addr", "Str",ip, "UInt"), buf, 4) ; sin_addr.s_addr
        return buf
    }

    sendto(pBuffer, BufSize, Flags:=0, &ToAddr:=0) {
        if ((r := dllcall("Ws2_32\sendto", "Ptr",this
            , "Ptr", pBuffer, "Int",BufSize
            , "Int", Flags
            , "Ptr", &ToAddr
            , "Int", 16)) == -1)
        throw Error("Error calling SendTo",, this.GetLastError())
        return r
    }

    sendtoByText(Text, Flags:=0, Encoding:="UTF-8") {
        buf := buffer(len:=strput(Text, Encoding) - ((Encoding = "UTF-16" || Encoding = "cp1200") ? 2 : 1))
        len := strput(Text, buf, Encoding)
        return this.sendto(buf, len, Flags)
    }

    SetBroadcast(Enable) {
        static SOL_SOCKET := 0xFFFF, SO_BROADCAST := 0x20
        if (dllcall("ws2_32\setsockopt"
            , "Ptr",this	; SOCKET s
            , "Int", SOL_SOCKET	; int    level
            , "Int", SO_BROADCAST	; int    optname
            , "UInt*", &Enable := !!Enable	; *char  optval
            , "Int", 4) == -1)	; int    optlen
        throw Error("Error calling setsockopt",, this.GetLastError())
    }

}
