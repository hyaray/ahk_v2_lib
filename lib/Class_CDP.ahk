#include WebSocket.ahk
class _CDP {

    static objInstance := map()

    static getInfo(name) {
        return map(
            "chrome", ["s:\CentBrowser\chrome.exe", 9222],
            "msedge", ["c:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe", 9223],
            "obsidian", [A_LocalAppdata . "\Obsidian\Obsidian.exe", 9221],
        )[name]
    }

    ;统一管理各 Chrome 系浏览器的实例
    static getInstance(name, key:="") {
        if (!_CDP.objInstance.has(name)) {
            ;OutputDebug(format("w#{1} {2}:A_ThisFunc={3} create instanceCDP of {4} key={5}", A_LineFile,A_LineNumber,A_ThisFunc,name,key))
            _CDP.objInstance[name] := _CDP(_CDP.getInfo(name)*)
        } else {
            ;OutputDebug(format("w#{1} {2}:A_ThisFunc={3} exist {4} instanceCDP, key={5}", A_LineFile,A_LineNumber,A_ThisFunc,name,key))
        }
        oCDP := _CDP.objInstance[name]
        switch key {
            case "": return oCDP
            case "page": return oCDP.getPage()
            default: return oCDP.getCurrentPage(key)
        }
    }

    static deleteInstance(name, key:="") {
        if (!_CDP.objInstance.has(name)) {
            ;OutputDebug(format("w#{1} {2}:A_ThisFunc={3} create instanceCDP of {4} key={5}", A_LineFile,A_LineNumber,A_ThisFunc,name,key))
            _CDP.objInstance[name] := ""
        }
    }

    __new(fp, DebugPort) {
        this.ChromePath := fp
        SplitPath(this.ChromePath, &fn)
        this.exeName := fn
        this.DebugPort := DebugPort
        this.hwnd := 0
        this.pid := 0
        ;获取 sParam
        this.sParam := format("--remote-debugging-port={1}", this.DebugPort)
        this.userdata := ""
        ;if (this.userdata != "") {
        ;    if (!FileExist(this.userdata))
        ;        DirCreate(this.userdata)
        ;    this.sParam .= ' --user-data-dir=' . this.CliEscape(this.userdata)
        ;}
        this.http := ComObject('WinHttp.WinHttpRequest.5.1')
        this.objSingleHost := map( ;指定单页面的host
            "oa.hf-zj.com:9898", 1,
            "192.168.16.6", 1,
            "192.168.16.217", 1,
            "192.168.16.228", 1,
        )
        ;this.sParam .= ' ' . flags
    }

    ;通用命令行参数获取 pid
    FindInstance(key:=unset) {
        for item in ComObjGet('winmgmts:').ExecQuery(format("SELECT CommandLine,ProcessId FROM Win32_Process WHERE Name = '{1}'", this.exeName)) {
            if (RegExMatch(item.CommandLine, '--remote-debugging-port=(\d+)', &m)) {
                ;OutputDebug(format("d#{1} {2}:return CommandLine={3}", A_LineFile,A_LineNumber,item.CommandLine))
                if (isset(key)) {
                    switch key {
                        case "port": return m[1]
                        case "pid": return item.ProcessId
                        case "cmd": return item.CommandLine
                        default: return
                    }
                } else {
                    return map(
                        "DebugPort", m[1],
                        "CommandLine", item.CommandLine,
                        "pid", item.ProcessId,
                    )
                }
            } else {
                ;OutputDebug(format("d#{1} {2}:not matched CommandLine={3}", A_LineFile,A_LineNumber,item.CommandLine))
            }
        }
        ;not found
        if (isset(key)) {
            switch key {
                case "port": return 0
                case "pid": return 0
                case "cmd": return ""
                default: return
            }
        } else {
            return map()
        }
    }

    ;NOTE 有些页面只限制打开1个，规则在哪里指定
    ;往往在 __new 里被调用 或见 CDPdo.openUrl()
    tabOpenLink(arrUrl:="", funAfterDo:="", bActive:=true) { ;about:blank chrome://newtab
        ;OutputDebug(format("i#{1} {2}:A_ThisFunc={3}", A_LineFile,A_LineNumber,A_ThisFunc))
        if (arrUrl is string)
            arrUrl := (arrUrl == "") ? [] : [arrUrl]
        if (arrUrl.length > 1)
            bActive := false
        ;bActive := (A_Index==arrUrl.length) ? bActive : false ;只激活最后一个标签
        if (this.detect()) {
            if (arrUrl.length) {
                objPage := this.getPageList(, "host")
                ;OutputDebug(format("i#{1} {2}:{3} objPage={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(objPage,4)))
                arrRes := []
                for urlOpen in arrUrl { ;NOTE 判断页面是否已打开
                    urlOpen := rtrim(urlOpen, "/")
                    if (!instr(urlOpen, "://") && !(urlOpen ~= "^\w:\\"))
                        urlOpen := "http://" . urlOpen
                    arrRes.push(A_Index . urlOpen)
                    objOpen := urlOpen.jsonUrl()
                    hostThis := objOpen["host"]
                    ;激活匹配的标签
                    if (this.objSingleHost.has(hostThis) && objPage.has(hostThis)) {
                        activeTab(objPage[hostThis][1]["id"])
                        continue
                    } else if (objPage.has(urlOpen)) { ;已有完全一样的网址
                        activeTab(objPage[urlOpen][1]["id"])
                        continue
                    }
                    OutputDebug(format("i#{1} {2}:this.arrEmpty={3}", A_LineFile,A_LineNumber,json.stringify(this.arrEmpty,4)))
                    ;打开标签
                    if (this.arrEmpty.length) ;优先在空白页打开
                        this.getPage().navigate(urlOpen, bActive) ;CDPP(this, this.arrEmpty.pop()["webSocketDebuggerUrl"])
                    else ;新标签打开
                        this.httpOpen("/new?" . urlOpen) ;TODO 哪里有问题
                }
            }
            WinShow(this.hwnd)
            WinActivate(this.hwnd)
            WinMaximize(this.hwnd)
            ;try {
            ;    WinShow(this.hwnd)
            ;} catch {
            ;    OutputDebug(format("i#{1} {2}:not found hwnd={3} ", A_LineFile,A_LineNumber,this.hwnd))
            ;} else {
            ;    WinActivate(this.hwnd)
            ;    WinMaximize(this.hwnd)
            ;}
        } else { ;新打开
            urls := ''
            for url in arrUrl
                urls .= ' ' . url ;this.CliEscape(url)
            this.runChrome(urls)
        }
        if (arrUrl.length == 1 && bActive) {
            oPage := this.getPage()
            this.thisisunsafe(oPage)
            ;自动登录接口，为了解耦，不直接放实现函数
            if (funAfterDo) { ;TODO 判断条件不好获取
                oPage.WaitForLoad()
                funAfterDo(oPage)
            }
        }
        return true
        activeTab(id) {
            this.httpOpen("/activate/" . id)
            ;arrUrl.RemoveAt(A_Index)
            tooltip("已激活已存在标签")
            SetTimer(tooltip, -1000)
        }
    }

    ;核实并赋值Chrome的 this.pid 和 this.hwnd
    ;返回 this.hwnd
    ;tp 检测不到浏览器的处理方式
    ;	0 什么也不做
    ;	1 关闭当前浏览器
    ;	2 关闭并正确打开浏览器
    detect(tp:=0) {
        if (this.hwnd && ProcessExist(this.pid)) {
            OutputDebug(format("i#{1} {2}:{3} existed hwnd={4} this.pid={5}", A_LineFile,A_LineNumber,A_ThisFunc,this.hwnd,this.pid))
            return this.hwnd
        }
        if (ProcessExist(this.exeName)) { ;可能脚本重启等原因丢失了数据
            this.pid := this.FindInstance("pid")
            OutputDebug(format("i#{1} {2}:{3} existed pid={4}", A_LineFile,A_LineNumber,A_ThisFunc,this.pid))
            if (this.pid) {
                saveDetect := A_DetectHiddenWindows
                DetectHiddenWindows(true)
                for winHwnd in WinGetList("ahk_class Chrome_WidgetWin_1 ahk_pid " . this.pid) {
                    try {
                        titleLoop := WinGetTitle(winHwnd)
                    } catch {
                        continue
                    }
                    if (titleLoop ~= "\S") {
                        ;OutputDebug(format("i#{1} {2}:this.hwnd={3},title={4}", A_LineFile,A_LineNumber,this.hwnd,titleLoop))
                        this.hwnd := winHwnd
                        break
                    }
                }
                DetectHiddenWindows(saveDetect)
                if (this.hwnd) {
                    OutputDebug(format("i#{1} {2}:{3} 重新获取hwnd={4}", A_LineFile,A_LineNumber,A_ThisFunc,this.hwnd))
                    return this.hwnd
                } else {
                    OutputDebug(format("i#{1} {2}:{3} 无法获取hwnd", A_LineFile,A_LineNumber,A_ThisFunc))
                }
            } else if (tp) {
                ;NOTE 找不到，是否结束所有进程
                OutputDebug(format("i#{1} {2}:关闭所有进程chrome.exe", A_LineFile,A_LineNumber))
                for item in ComObjGet("winmgmts:").ExecQuery(format("select ProcessId from Win32_Process where name='{1}'", this.exeName))
                    ProcessClose(item.ProcessId)
                if (tp == 2) {
                    return this.runChrome()
                } else {
                    OutputDebug(format("i#{1} {2}:通用pid检测hwnd失败", A_LineFile,A_LineNumber))
                    tooltip("待完善：通用pid检测hwnd失败")
                    SetTimer(tooltip, -1000)
                }
            }
        }
        return false
    }

    runChrome(urls:="") {
        sCmd := format("{1} {2} {3}", this.CliEscape(this.ChromePath),this.sParam,urls)
        run(sCmd,,, &pid) ;--ignore-certificate-errors
        this.pid := pid
        this.hwnd := WinWait("ahk_class Chrome_WidgetWin_1 ahk_pid " . this.pid)
        OutputDebug(format("i#{1} {2}:自动运行浏览器 hwnd={3} sCmd={}", A_LineFile,A_LineNumber,this.hwnd,sCmd))
        WinActivate
        WinMaximize
        return this.hwnd
    }

    /*
    NOTE 仅当非常明确只是获取网址和标题，用 getCurrentPage("json")
    其他考虑功能性，都用 getPage
    {
        "description": "",
        "devtoolsFrontendUrl": "/devtools/inspector.html?ws=127.0.0.1:9222/devtools/page/8A5B6CDB1ABE9E40BAD3C9902841BBE2",
        "faviconUrl": "https://mat1.gtimg.com/www/icon/favicon2.ico",
        "id": "8A5B6CDB1ABE9E40BAD3C9902841BBE2",
        "title": "腾讯首页",
        "type": "page", //background_page other iframe
        "url": "https://www.qq.com",
        "webSocketDebuggerUrl": "ws://127.0.0.1:9222/devtools/page/8A5B6CDB1ABE9E40BAD3C9902841BBE2"
    }
    */
    getCurrentPage(key:="") {
        ;this.detect(true)
        ;debug 模式获取
        ;OutputDebug(format("i#{1} {2}:httpAll={3}", A_LineFile,A_LineNumber,json.stringify(this.httpOpen("",true),4)))
        for objHttp in this.httpOpen() {
            if (objHttp["type"] == "page" && objHttp["title"] != "DevTools") { ;NOTE by 火冷 <2022-10-01 17:42:12>
                objHttp["url"] := rtrim(objHttp["url"], "/")
                OutputDebug(format("i#{1} {2}:{3} key={4}", A_LineFile,A_LineNumber,A_ThisFunc,key))
                switch key {
                    case "json": ;增加个 title
                        jsonPage := objHttp["url"].jsonUrl()
                        ;jsonPage["title"] := objHttp["title"]
                        return jsonPage
                    case "arr": return [objHttp["title"], objHttp["url"]] ;标题+url
                    case "": return objHttp
                    default:
                        jsonPage := objHttp["url"].jsonUrl()
                        return jsonPage.get(key, objHttp.get(key, ""))
                }
            }
        }
    }

    /*
    所有标签+插件的信息
    顺序为最近激活的顺序，当前页为第一个
    keyJson
        ="" 则返回数组
        否则应设置为 jsonUrl 包含的 key，返回以 keyJson | "href" 为索引的 map(用来判断xx页面是否存在)
    */
    getPageList(funTrue:="", keyJson:="") {
        if (funTrue == "")
            funTrue := (obj)=>obj["type"] == "page"
        arr := this.httpOpen()
        ;OutputDebug(format("i#{1} {2}:arr={3}", A_LineFile,A_LineNumber,json.stringify(arr,4)))
        if (keyJson == "")
            arrRes := []
        else
            objRes := map()
        this.arrEmpty := [] ;NOTE 初始化空标签
        for obj in arr {
            if (funTrue(obj)) {
                obj["url"] := rtrim(obj["url"], "/") ;删除 url 右边的 /
                ;额外记录 arrEmpty
                if (obj["url"] == "chrome://newtab" || obj["url"] == "about:blank")
                    this.arrEmpty.push(obj)
                if (keyJson == "") {
                    arrRes.push(obj)
                } else {
                    ;格式化 url
                    objUrl := obj["url"].jsonUrl()
                    ;新记录两个 key
                    obj["index"] := A_Index
                    obj["json"] := objUrl
                    ;返回结果额外增加 href 的key
                    objRes.has(objUrl[keyJson]) ? objRes[objUrl[keyJson]].push(obj) : objRes[objUrl[keyJson]] := [obj]
                    objRes.has(objUrl["href"]) ? objRes[objUrl["href"]].push(obj) : objRes[objUrl["href"]] := [obj]
                }
            }
        }
        if (keyJson == "") {
            ;OutputDebug(format("i#{1} {2}:arrRes={3}", A_LineFile,A_LineNumber,json.stringify(arrRes,4)))
            return arrRes
        } else {
            ;OutputDebug(format("i#{1} {2}:objRes={3}", A_LineFile,A_LineNumber,json.stringify(objRes,4)))
            return objRes
        }
    }

    ;Escape a string in a manner suitable for command line parameters
    CliEscape(Param) => format('"{1}"', RegExReplace(Param, '(\\*)"', '$1$1\"'))

    ;pathname前面要带 /
    httpOpen(pathname:="") {
        this.http.open('GET', format("http://127.0.0.1:{1}/json{2}", this.DebugPort,pathname))
        try
            resSend := this.http.send()
        catch as e
            msgbox(format("{1}`nhttp://127.0.0.1:{2}/json{3}`n{4}", A_ThisFunc,this.DebugPort,pathname,json.stringify(e, 4)))
        return pathname=="" ? JSON.parse(this.http.responseText) : resSend
    }

    ;closeNewtab(id:="") {
    ;    if (id == "") {
    ;        arr := this.getPageList((obj)=>obj["url"]=="chrome://newtab")
    ;        if (arr.length)
    ;            id := arr[1]['id']
    ;    }
    ;    if (id != "")
    ;        return this.httpOpen("/close/" . id)
    ;}

    ;static FindPages(opts, MatchMode := 'exact') {
    ;    Pages := []
    ;    for PageData in this.GetPageList() {
    ;        fg := true
    ;        for k, v in (Type(opts) = 'Map' ? opts : opts.OwnProps())
    ;            if !((MatchMode = 'exact' && PageData[k] = v) || (MatchMode = 'contains' && InStr(PageData[k], v))
    ;                || (MatchMode = 'startswith' && InStr(PageData[k], v) == 1) || (MatchMode = 'regex' && PageData[k] ~= v)) {
    ;                    fg := false
    ;                    break
    ;                }
    ;        if (fg)
    ;            Pages.Push(PageData)
    ;    }
    ;    return Pages
    ;}

    ;static ClosePage(opts, MatchMode:='exact') {
    ;    for page in this.FindPages(opts, MatchMode)
    ;        return this.httpOpen("/close/" . page["id"])
    ;}

    ;https://player.bilibili.com/player.html?aid=976962208&bvid=BV1244y1Y7VR&cid=457445567&page=1
    ;<iframe src="//player.bilibili.com/player.html?aid=720241593&bvid=BV1KQ4y1a7pd&cid=401115360&page=1" scrolling="no" border="0" frameborder="no" framespacing="0" allowfullscreen="true"> </iframe>
    ;iframeCode() {
    ;    obj := this.getCurrentPage()
    ;    return format('<iframe src="{1}" scrolling="no" border="0" frameborder="no" framespacing="0" allowfullscreen="true" width="100%" height="450px"> </iframe>', obj["href"])
    ;}

    thisisunsafe(oPage) {
        objHost := map(
            "192.168.16.218:4430", 1,
            "192.168.16.217", 1,
        )
        if (objHost.has(oPage.url))
            oPage.WaitForLoad()
        if (WinActive("隐私设置错误")) {
            MouseMove(200, 300, 0)
            click
            send("thisisunsafe")
            return true
        } else {
            return false
        }
    }

    ;翻译切换
    ;static translate() {
    ;    try {
    ;        UIA.FindElement(WinActive("A"), "Button", "翻译此页").GetCurrentPattern("Invoke").Invoke_Invoke()
    ;    } catch {
    ;        send("{RButton}")
    ;        sleep(100)
    ;        send("t")
    ;        return
    ;    }
    ;    WinWaitNotActive
    ;    send("{right}")
    ;    sleep(100)
    ;    WinClose("A")
    ;    ; send("{escape}") ;退出窗口
    ;}

    ;deleteCache() => send("{ctrl down}{shift down}{delete}{shift up}{ctrl up}")

    ;errScroll() { ;无法滚动的问题
    ;    WinWaitActive("ahk_exe Chrome.exe")
    ;    A_Clipboard := "chrome://flags/#enable-gpu-rasterization"
    ;    doSend()
    ;    msgbox("设置【GPU rasterization】成disabled，完成后请关闭本窗口并按pause键继续")
    ;    KeyWait("pause", "D")
    ;    sleep(200)
    ;    WinWaitActive("ahk_exe Chrome.exe")
    ;    A_Clipboard := "chrome://settings/"
    ;    doSend()
    ;    msgbox("点击最下方的【高级】，拉到最后，关闭【使用硬件加速模式（如果可用）】，完成后请关闭本窗口并按pause键结束")
    ;    KeyWait("pause", "D")
    ;    tooltip()
    ;    doSend() {
    ;        sleep(20)
    ;        send("o")
    ;        sleep(100)
    ;        send("c")
    ;        sleep(1000)
    ;    }
    ;}

    ;errOpenUrl() { ;打开网址变成c:\*
    ;    run("s:\CentBrowser\chrome.exe --make-default-browser")
    ;    msgbox("完成")
    ;}

    ;SoundClose() { ;设置静音
    ;    ;hyf_winActiveOrOpen("ahk_class Chrome_WidgetWin_1 ahk_exe Chrome.exe", gBrowser, 1, "Max")
    ;    WinWaitActive("ahk_exe Chrome.exe")
    ;    this.tabOpenLink("chrome://flags/#enable-tab-audio-muting")
    ;    if !WinWaitActive("chrome://flags/#enable-tab-audio-muting",, 1) {
    ;        A_Clipboard := "chrome://flags/#enable-tab-audio-muting"
    ;        msgbox("网址已复制，请手动粘贴并打开")
    ;    }
    ;    msgbox("【启用】tab audio muting UI control`n重启浏览器后，对标签右键就可以设置【将此标签页静音】")
    ;}

    ;mhtml() { ;保存为mhtml
    ;    this.tabOpenLink("chrome://flags/#save-page-as-mhtml")
    ;}

    ;downloadSave() { ;下载内容要点击【保留】才行
    ;    this.tabOpenLink("chrome://settings/privacyV")
    ;    msgbox("【保护您和您的设备不受危险网站的侵害】选项取消打勾")
    ;}

    getPage(funObj:=unset) {
        if (isset(funObj)) {
            arr := this.httpOpen()
            for objHttp in arr {
                if (objHttp["type"] == "page" && objHttp["title"] != "DevTools") {
                    if (funObj(objHttp["url"].jsonUrl()))
                        return _CDP.CDPP(objHttp, this.http)
                }
            }
        } else {
            return _CDP.CDPP(this.getCurrentPage(), this.http)
        }
    }

    activatePage(funObj) {
        oPage := this.getPage(funObj)
        if (isobject(oPage)) {
            oPage.activate()
            return oPage
        }
    }

    /*
    CDP https://chromedevtools.github.io/devtools-protocol/1-3/Page
    Connects to the debug interface of a page given its WebSocket URL.
    {
        "description": "",
        "devtoolsFrontendUrl": "/devtools/inspector.html?ws=127.0.0.1:9222/devtools/page/8A5B6CDB1ABE9E40BAD3C9902841BBE2",
        "faviconUrl": "https://mat1.gtimg.com/www/icon/favicon2.ico",
        "id": "8A5B6CDB1ABE9E40BAD3C9902841BBE2",
        "title": "腾讯首页",
        "type": "page",
        "url": "https://www.qq.com",
        "webSocketDebuggerUrl": "ws://127.0.0.1:9222/devtools/page/8A5B6CDB1ABE9E40BAD3C9902841BBE2"
    }
    */
    class CDPP extends WebSocket {

        __new(objHttp, http) {
            this.idx := 0
            this.responses := map()
            RegExMatch(objHttp["webSocketDebuggerUrl"], 'ws://[\d\.]+:(\d+)', &m)
            this.DebugPort := m[1]
            this.setProp(objHttp)
            this.http := http
            super.__new(objHttp["webSocketDebuggerUrl"]) ;NOTE 会修改url属性值为 webSocketDebuggerUrl 值
            ;this.callback := events
            ;this.KeepAlive := keepalive.bind(ObjPtr(this))
            ;SetTimer(this.KeepAlive, 25000)
            ;keepalive() {
            ;    self := ObjFromPtrAddRef(pthis)
            ;    self('Browser.getVersion',, false)
            ;}
        }

        __delete() {
            ;SetTimer(keepalive, 0)
            super.__delete()
        }

		call(DomainAndMethod, Params?, WaitForResponse := true) {
            if (this.readyState != 1)
                throw error("Not connected to tab")
            ; Use a temporary variable for id in case more calls are made
            ; before we receive a response.
			if !(idx := this.idx += 1)
				idx := this.idx += 1
			this.sendText(JSON.stringify(map('id', idx, 'params', Params ?? {}, 'method', DomainAndMethod), 0))
			if (!WaitForResponse)
				return
			; Wait for the response
			this.responses[idx] := false
			while (this.readyState = 1 && !this.responses[idx])
				Sleep(20)

			; Get the response, check if it's an error
			if !response := this.responses.Delete(idx)
				throw Error('Not connected to tab')
			if !(response is Map)
				return response
            if (response.has("error"))
                throw error("Chrome indicated error in response",, JSON.stringify(response['error']))
            if (response.has("result"))
                return response["result"]
        }

        ; https://chromedevtools.github.io/devtools-protocol/1-3/Runtime/#method-evaluate
        ;判断null用 evaluate(js)["value"] is ComValue
        ;ahk传入变量：直接修改 jsCode
        ;TODO 生产订单列表，返回null，console测试正常 evaluate('console.log(document.querySelector(".main_Table"));')
        evaluate(jsCode, key:="") {
            response := this.call('Runtime.evaluate', {
                expression: jsCode,
                objectGroup: "console",
                includeCommandLineAPI: JSON.true,
                silent: JSON.false,
                returnByValue: JSON.true, ;支持返回数组等格式
                userGesture: JSON.true,
                awaitPromise: JSON.false
            })
            if (response is map) {
                ;OutputDebug(format("i#{1} {2}:{3} response={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(response,4)))
                if (response.has("ErrorDetails"))
                    throw error(response["result"]["description"],, JSON.stringify(response["ErrorDetails"]))
                return (key != "") ? response["result"].get(key, "") : response["result"]
            } else {
                throw error(A_ThisFunc)
            }
        }

        close() {
            this.httpOpen(format("/close/{1}",this.id))
			this.__Delete()
        }

        activate() => this.httpOpen(format("/activate/{1}",this.id))
        WaitForLoad(DesiredState:="complete", Interval:=100) {
            loop {
                state := this.evaluate('document.readyState',"value")
                OutputDebug(format("i#{1} {2}:{3} state={4}", A_LineFile,A_LineNumber,A_ThisFunc,state))
                if (this.evaluate('document.readyState',"value") != DesiredState)
                    sleep(Interval)
                else
                    return 1
            }
        }
		onClose(*) {
			try this.reconnect()
			catch WebSocket.Error
				this.__Delete()
		}
        onMessage(msg) {
            data := JSON.parse(msg)
			if this.responses.Has(id := data.Get('id', 0))
				this.responses[id] := data
            ;try (this.callback)(msg)
        }

        ;在当前标签打开 NOTE 注意信息更新问题
        navigate(url, bActive:=true) {
            this("Page.navigate", map("url",url))
            this.setProp(url)
            if (bActive)
                this.activate()
        }

        setProp(objHttp) {
            if (isobject(objHttp)) {
                for k, v in objHttp
                    this.%k% := v
                this.objUrl := objHttp["url"].jsonUrl() ;url 会在后面被修改
                ;this.objUrl["title"] := objHttp["title"] ;和 getCurrentPage("json") 同格式
            } else {
                this.objUrl := objHttp.jsonUrl() ;url 会在后面被修改
            }
        }

        ;pathname前面要带 /
        httpOpen(pathname:="") {
            this.http.open('GET', format("http://127.0.0.1:{1}/json{2}", this.DebugPort,pathname))
            try
                resSend := this.http.send()
            catch as e
                msgbox(format("{1}`nhttp://127.0.0.1:{2}/json{3}`n{4}", A_ThisFunc,this.DebugPort,pathname,json.stringify(e, 4)))
            return pathname=="" ? JSON.parse(this.http.responseText) : resSend
        }

        saveIco() {
            if !this.HasProp("faviconUrl")
                return
            fp := format("{1}\{2}.{3}",A_Desktop,this.title,RegExReplace(this.faviconUrl,".*\."))
            download(this.faviconUrl, fp)
            ;_TC.runc(fp, 0, false)
        }

        ;TODO
        ;getFrameTree() => this("Page.getFrameTree")

    }
}
