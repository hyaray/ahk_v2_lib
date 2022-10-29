/************************************************************************
* @author thqby
* @date 2021/12/05
* @version 0.0.8
***********************************************************************/

class WebSocket {
    static BUFFER_TYPE := {
        BINARY: 0,
        BINARY_FRAGMENT: 1,
        UTF8: 2,
        UTF8_FRAGMENT: 3,
        CLOSE: 4
    }

    Ptr := async := readyState := _callback := 0
    url := ''
    cache := buffer(0)
    HINTERNETs := []
    waiting := false
    recdata := buffer(0)

    __new(url, Events:=0, Async:=true, Headers:='') {
        this.HINTERNETs := []
        this.async := !!Async
        this.cache.Size := 8192
        this.url := url
        if (!RegExMatch(url, 'i)^((?<SCHEME>wss?)://)?((?<USERNAME>[^:]+):(?<PASSWORD>.+)@)?(?<HOST>[^/:]+)(:(?<PORT>\d+))?(?<PATH>/.*)?$', &m))
            throw Error('无效的ws url')
        if !hSession := dllcall('Winhttp\WinHttpOpen', 'ptr',0, 'uint',0, 'ptr',0, 'ptr',0, 'uint',Async ? 0x10000000 : 0, 'ptr')
            throw Error('创建会话失败')
        this.HINTERNETs.push(hSession)
        port := m.PORT ? Integer(m.PORT) : m.SCHEME = 'ws' ? 80 : 443
        dwFlags := m.SCHEME = 'wss' ? 0x800000 : 0
        if !hConnect := dllcall('Winhttp\WinHttpConnect', 'ptr',hSession, 'wstr',m.HOST, 'ushort',port, 'uint',0, 'ptr')
            throw Error('建立连接失败')
        this.HINTERNETs.push(hConnect)
        switch type(Headers) {
            case 'Object', 'Map':
            s := ''
            for k, v in Headers is map ? Headers : Headers.OwnProps()
                s .= format("`r`n{1}: {2}", k,v)
            Headers := LTrim(s, '`r`n')
            case 'String':
            default:
                Headers := ''
        }
        if (Events) {
            for k, v in Events.OwnProps()
                if (k ~= 'i)^(data|message|close)$')
                    this.on%k% := v
        }
        connect(this)
        this.reconnect := connect

        connect(self) {
            while (self.HINTERNETs.Length > 2)
                dllcall('Winhttp\WinHttpCloseHandle', 'ptr',self.HINTERNETs.pop())
            if !hRequest := dllcall('Winhttp\WinHttpOpenRequest', 'ptr',hConnect, 'wstr','GET', 'wstr',m.PATH, 'ptr',0, 'ptr',0, 'ptr',0, 'uint',dwFlags, 'ptr')
                throw Error('打开请求失败')
            self.HINTERNETs.push(hRequest)
            if (Headers)
                dllcall('Winhttp\WinHttpAddRequestHeaders', 'ptr',hRequest, 'wstr',Headers, 'uint',-1, 'uint',0x20000000, 'int')
            if (!dllcall('Winhttp\WinHttpSetOption', 'ptr',hRequest, 'uint',114, 'ptr',0, 'uint',0, 'int')
                || !dllcall('Winhttp\WinHttpSendRequest', 'ptr',hRequest, 'ptr',0, 'uint',0, 'ptr',0, 'uint',0, 'uint',0, 'uptr',0, 'int')
                || !dllcall('Winhttp\WinHttpReceiveResponse', 'ptr',hRequest, 'ptr',0)
                || !dllcall('Winhttp\WinHttpQueryHeaders', 'ptr',hRequest, 'uint',19, 'ptr',0, 'wstr',status:='00000', 'uint*',10, 'ptr',0, 'int')
                || status != '101')
            throw Error('建立websocket失败')
            if !self.Ptr := dllcall('Winhttp\WinHttpWebSocketCompleteUpgrade', 'ptr',hRequest, 'ptr',0)
                throw Error('websocket握手失败')
            dllcall('Winhttp\WinHttpCloseHandle', 'ptr',self.HINTERNETs.pop())
            self.HINTERNETs.push(self.Ptr)
            self.readyState := 1
            if (Async) {
                dllcall('Winhttp\WinHttpSetOption', 'ptr',self, 'uint',45, 'ptr*',ObjPtr(self), 'uint',A_PtrSize)
                dllcall('Winhttp\WinHttpSetStatusCallback', 'ptr',self, 'ptr',self._callback:=CallbackCreate(StatusCallback, 'fast'), 'uint',0xffffffff, 'uptr',0, 'ptr')
                self.waiting := true
                dllcall('Winhttp\WinHttpWebSocketReceive', 'ptr',self, 'ptr',self.cache.Ptr, 'uint',self.cache.Size, 'uint*',0, 'uint*',0)
            }
        }
        StatusCallback(hInternet, dwContext, dwInternetStatus, lpvStatusInformation, dwStatusInformationLength) {
            if (dwInternetStatus = 0x80000) {
                dwBytesTransferred := NumGet(lpvStatusInformation, 'uint'), eBufferType := NumGet(lpvStatusInformation, 4, 'uint')
                ws := ObjFromPtrAddRef(dwContext), ws.waiting := false, rec := ws.recdata, offset := rec.Size
                if (ws.readyState != 1)
                    return
                switch eBufferType {
                    case 0, 1:
                    if (ws.onData)
                        try ws.onData(eBufferType, ws.cache.Ptr, dwBytesTransferred)
                            case 2:
                    if (ws.onMessage) {
                        if (offset) {
                            rec.Size += dwBytesTransferred, dllcall('RtlMoveMemory', 'ptr',rec+offset, 'ptr',ws.cache.Ptr, 'uint',dwBytesTransferred)
                            msg := strget(rec, 'utf-8')
                            ws.recdata := buffer(offset := 0), wait()
                            try ws.onMessage(msg)
                                return
                        } else {
                            msg := strget(ws.cache.Ptr, dwBytesTransferred, 'utf-8'), wait()
                            try
                                ws.onMessage(msg)
                            catch Error as e
                                MsgBox(e.Message)
                            return
                        }
                    }
                    case 3:
                    rec.Size += dwBytesTransferred, dllcall('RtlMoveMemory', 'ptr', rec.Ptr + offset, 'ptr', ws.cache.Ptr, 'uint', dwBytesTransferred), offset += dwBytesTransferred
                    default:
                    ws.close(), ws.readyState := 3
                    try ws.onClose()
                }
                wait()
            } else if (dwInternetStatus = 0x4000000)
                ws := ObjFromPtrAddRef(dwContext), ws.readyState := 3
            wait() {
                SetTimer(receive, -1)
                receive() {
                    ws.waiting := true
                    ret := dllcall('Winhttp\WinHttpWebSocketReceive', 'ptr', hInternet, 'ptr', ws.cache.Ptr, 'uint', ws.cache.Size, 'uint*', 0, 'uint*', 0)
                    if (ret = 12030) {
                        ws.readyState := 3
                        try ws.onClose(1006, '')
                    }
                }
            }
        }
    }

    __Delete() {
        this.close()
        while (this.HINTERNETs.Length)
            dllcall('Winhttp\WinHttpCloseHandle', 'ptr',this.HINTERNETs.pop())
        if (this._callback)
            CallbackFree(this._callback)
    }

    QueryCloseStatus() {
        if (!dllcall('Winhttp\WinHttpWebSocketQueryCloseStatus', 'ptr',this, 'ushort*',&usStatus:=0, 'ptr',vReason:=buffer(123), 'uint',123, 'uint*',&len:=0))
            return ({status: usStatus, reason: strget(vReason, len, 'utf-8')})
        else if (this.readyState > 1)
            return {status: 1006, reason: ''}
    }

    send(eBufferType, pvBuffer, dwBufferLength) {
        if (this.readyState != 1)
            throw Error('websocket已断开')
        ret := dllcall('Winhttp\WinHttpWebSocketSend', 'ptr',this, 'uint',eBufferType, 'ptr',pvBuffer, 'uint',dwBufferLength, 'uint')
        if (ret) {
            if (ret != 12030)
                throw Error(ret)
            this.readyState := 3
            try this.onClose(1006, '')
        }
    }
    sendText(str) {
        if (size := StrPut(str, 'utf-8') - 1) {
            buf := buffer(size), StrPut(str, buf, 'utf-8')
            this.send(2, buf.Ptr, size)
        } else
            this.send(2, 0, 0)
    }
    receive() {
        if (this.async)
            throw Error('仅在同步模式中使用')
        cache := this.cache
        size := this.cache.Size
        rec := buffer(0)
        offset := 0
        while (!ret := dllcall('Winhttp\WinHttpWebSocketReceive', 'ptr',this, 'ptr',cache, 'uint',size, 'uint*',&dwBytesRead:=0, 'uint*',&eBufferType:=0)) {
            switch eBufferType {
                case 0:
                    if (offset) {
                        rec.Size += dwBytesRead
                        dllcall('RtlMoveMemory', 'ptr',rec.Ptr+offset, 'ptr',cache, 'uint',dwBytesRead)
                    } else {
                        rec := cache
                        rec.Size := dwBytesRead
                    }
                    return rec
                case 1, 3:
                    rec.Size += dwBytesRead
                    dllcall('RtlMoveMemory', 'ptr',rec.Ptr+offset, 'ptr',cache, 'uint',dwBytesRead)
                    offset+=dwBytesRead
                case 2:
                if (offset) {
                    rec.Size += dwBytesRead
                    dllcall('RtlMoveMemory', 'ptr',rec.Ptr+offset, 'ptr',cache, 'uint',dwBytesRead)
                    return strget(rec, 'utf-8')
                }
                return strget(cache, dwBytesRead, 'utf-8')
                default:
                    this.close()
                    rea := this.QueryCloseStatus()
                    try this.onClose(rea.status, rea.reason)
                        return
            }
        }
        if (ret) {
            if (ret != 12030)
                throw Error(ret)
            this.readyState := 3
            try this.onClose(1006, '')
        }
    }
    asyncreceive() {
        static cb := CallbackCreate(waitreceive)
        if (this.async)
            throw Error('仅在同步模式中使用')
        if (this.waiting)
            return
        this.waiting := true, dllcall('CreateThread', "Ptr",0, "UInt",0, "Ptr",cb, "Ptr",ObjPtrAddRef(this), "UInt",0, "UInt*",&threadid:=0)
        waitreceive(lp) {
            ws := ObjFromPtr(lp)
            ws.waiting := false
            try {
                if ((data := ws.receive()) is string) {
                    if (data)
                        try ws.onMessage(data)
                } else {
                    try ws.onData(data)
                }
            }
        }
    }
    close() {
        if (this.readyState = 1) {
            this.readyState := 2
            if (dllcall('Winhttp\WinHttpWebSocketShutdown', 'ptr',this, 'ushort',1000, 'ptr',0, 'uint',0, 'uint'))
                this.readyState := 3
        }
    }
}
