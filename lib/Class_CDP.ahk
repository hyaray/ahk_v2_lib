#include WebSocket.ahk
; https://chromedevtools.github.io/devtools-protocol/1-3/Page
; 更深入应用 https://www.autohotkey.com/boards/viewtopic.php?f=6&t=94276&p=418181&hilit=getBoxModel&sid=89e5d3b0771309de236ba0b64b81f44e#p418181
class _CDP {

    static debug := false
    static objInstance := map()
    static objSingleHost := map() ;指定单页面的host(在_AutoCmd里被修改)
    static objPath := map( ;NOTE 后续值可被覆盖
        "chrome", ["c:\Users\administrator\AppData\Local\Google\Chrome\Chrome.exe", 9222],
        "msedge", ["c:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe", 9223],
        "obsidian", [EnvGet("LOCALAPPDATA") . "\Obsidian\Obsidian.exe", 9221],
    )

    ;NOTE 统一管理各应用的端口，顺便管理路径
    static getInfo(name, fp:="") {
        name := StrReplace(StrLower(name), ".exe")
        if (fp != "") ;NOTE 覆盖值
            this.objPath[name][1] := fp
        return this.objPath[name]
    }

    ;NOTE NOTE NOTE 统一管理各 Chrome 系浏览器的实例
    ;可以只传入 key, 会智能判断
    ;var 可以是name，也可以是fp
    ;key 可以是(chrome|msedge|obsidian) 也可以是 (page|url) 等(自动判断当前浏览器)
    static smartGet(var:="", key:="") {
        if (_CDP.debug)
            OutputDebug(format("i#{1} {2}:{3} var={4}", A_LineFile.fn(),A_LineNumber,A_ThisFunc,var))
        name := ""
        if (var != "") {
            if (var ~= "^(chrome|msedge|obsidian)$") {
                name := var
            } else if (var ~= "^\w:") {
                fp := var
                SplitPath(fp,,,, &fnn)
                name := fnn
                this.objPath[name][1] := fp
            } else { ;只传入key
                key := var
            }
        }
        ;获取 name
        if (name == "")
            name := this.getExeName()
        ;获取 oCDP
        if (!this.objInstance.has(name))
            this.objInstance[name] := this(this.getInfo(name)*)
        oCDP := this.objInstance[name]
        ;处理 key
        switch key {
            case "": return oCDP
            case "page": return oCDP.getPage() ;获取指定的 page则先返回 oCDP再手工获取
            default: return oCDP.getByHttp(key)
        }
    }

    static getExeName() {
        exeName := WinGetProcessName("A")
        switch exeName, false {
            case "chrome.exe": name := "chrome"
            case "msedge.exe": name := "msedge"
                ;case "obsidian.exe": name := "obsidian" ;NOTE obsidian 只支持传入
            default:
                if (ProcessExist("chrome.exe"))
                    name := "chrome" 
                else if (ProcessExist("msedge.exe"))
                    name := "msedge"
                else
                    throw TargetError("no chrome opened")
        }
        return name
    }

    static deleteInstance(name, key:="") {
        if (!_CDP.objInstance.has(name)) {
            ;OutputDebug(format("w#{1} {2}:A_ThisFunc={3} create instanceCDP of {4} key={5}", A_LineFile,A_LineNumber,A_ThisFunc,name,key))
            _CDP.objInstance[name] := ""
        }
    }

    static createShortcut(name:="", bUrl:=false) {
        ;只传入第2参数
        if (name is integer) {
            bUrl := name
            name := ""
        }
        ;获取 name
        if (name == "")
            name := this.getExeName()
        if (name ~= "^\w:") {
            fp := name
            SplitPath(name,,,, &name)
            arr := _CDP.getInfo(name)
            arr[1] := fp
        } else {
            arr := _CDP.getInfo(name)
        }
        url := bUrl ?  _CDP.smartGet("chrome","url") . " " : ""
        FileCreateShortcut(arr[1], name.fnn2fp("lnk"),, format("{1}--remote-debugging-port={2}", url,arr[2]))
    }

    ;pathname前面要带 /
    static httpOpen(http, method, pathname:="", port:="") {
        url := format("http://127.0.0.1:{1}/json{2}", port,pathname)
        if (_CDP.debug)
            OutputDebug(format("i#{1} {2}:{3} url={4}", A_LineFile,A_LineNumber,A_ThisFunc,url))
        http.open(method, url)
        try {
            resSend := http.send()
        } catch {
            OutputDebug(format("w#{1} {2}:{3} rebuild http", A_LineFile,A_LineNumber,A_ThisFunc))
            tooltip("rebuild http",,, 9)
            SetTimer(tooltip.bind(,,, 9), -1000)
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.open(method, url)
            try {
                resSend := http.send()
            } catch {
                tooltip("Chrome Devtools Protocol连接异常",,, 9)
                SetTimer(tooltip.bind(,,, 9), -1000)
                exit
            }
        }
        return pathname=="" ? JSON.parse(http.responseText) : resSend
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
        ;    this.sParam .= " --user-data-dir=" . this.CliEscape(this.userdata)
        ;}
        this.http := ComObject("WinHttp.WinHttpRequest.5.1")
        ;this.sParam .= " " . flags
    }

    ;通用命令行参数获取 pid
    FindInstance(key:=unset) {
        for item in ComObjGet("winmgmts:").ExecQuery(format("SELECT CommandLine,ProcessId FROM Win32_Process WHERE Name = '{1}'", this.exeName)) {
            if (RegExMatch(item.CommandLine, "--remote-debugging-port=(\d+)", &m)) {
                if (_CDP.debug)
                    OutputDebug(format("d#{1} {2}:return CommandLine={3}", A_LineFile,A_LineNumber,item.CommandLine))
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
                if (_CDP.debug)
                    OutputDebug(format("d#{1} {2}:not matched CommandLine={3}", A_LineFile,A_LineNumber,item.CommandLine))
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
    tabOpenLink(arrUrl:="", funAfterDo:=unset, bActive:=true) { ;about:blank chrome://newtab
        if (_CDP.debug)
            OutputDebug(format("i#{1} {2}:A_ThisFunc={3}", A_LineFile,A_LineNumber,A_ThisFunc))
        if (arrUrl is string)
            arrUrl := StrSplit(trim(arrUrl,"`r`n"), "`n", "`r")
        if (arrUrl.length > 1) {
            if !(arrUrl[1] ~= "^http") ;NOTE 多行网址则必需为http开头
                return
            bActive := false
        }
        ;bActive := (A_Index==arrUrl.length) ? bActive : false ;只激活最后一个标签
        if (this.detect(1)) {
            if (arrUrl.length) {
                objPage := this.getPages(, "host")
                if (_CDP.debug)
                    OutputDebug(format("i#{1} {2}:{3} objPage={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(objPage,4)))
                for urlOpen in arrUrl { ;NOTE 判断页面是否已打开
                    urlOpen := rtrim(urlOpen, "/")
                    if (urlOpen == "")
                        continue
                    if (!instr(urlOpen, "://") && !(urlOpen ~= "^\w:\\"))
                        urlOpen := "http://" . urlOpen
                    objOpen := urlOpen.jsonUrl()
                    hostThis := objOpen["host"]
                    ;激活匹配的标签
                    if (_CDP.objSingleHost.has(hostThis) && objPage.has(hostThis)) {
                        activeTab(objPage[hostThis][1]["id"])
                        continue
                    } else if (objPage.has(urlOpen)) { ;已有完全一样的网址
                        activeTab(objPage[urlOpen][1]["id"])
                        continue
                    }
                    if (_CDP.debug)
                        OutputDebug(format("i#{1} {2}:this.arrEmpty={3}", A_LineFile,A_LineNumber,json.stringify(this.arrEmpty,4)))
                    ;打开标签
                    if (this.arrEmpty.length) { ;优先在空白页打开
                        id := this.arrEmpty.pop()["id"]
                        this.getPage((x=>(o=>o["id"]==x))(id)).navigate(urlOpen, bActive)
                    } else { ;新标签打开
                        this.httpPut("/new?" . urlOpen.uriEncode()) ;NOTE put 的网址要转义
                    }
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
            urls := ""
            for url in arrUrl
                urls .= format(" {1}", url) ;this.CliEscape(url)
            this.runChrome(urls)
        }
        if (arrUrl.length == 1 && bActive) {
            oPage := this.getPage()
            this.thisisunsafe(oPage)
            ;自动登录接口，为了解耦，不直接放实现函数
            if (isset(funAfterDo) && funAfterDo is func) { ;TODO 判断条件不好获取
                OutputDebug(format("i#{1} {2}:{3} WaitForLoad", A_LineFile,A_LineNumber,A_ThisFunc))
                oPage.WaitForLoad()
                funAfterDo(oPage)
            }
        }
        return true
        activeTab(id) {
            this.httpGet("/activate/" . id)
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
            if (WinExist(this.hwnd)) {
                if (_CDP.debug)
                    OutputDebug(format("i#{1} {2}:{3} existed hwnd={4} this.pid={5}", A_LineFile,A_LineNumber,A_ThisFunc,this.hwnd,this.pid))
                return this.hwnd
            } else {
                if (_CDP.debug)
                    OutputDebug(format("i#{1} {2}:{3} not existed hwnd={4}", A_LineFile,A_LineNumber,A_ThisFunc,this.hwnd,this.pid))
            }
        }
        if (ProcessExist(this.exeName)) { ;可能脚本重启等原因丢失了数据
            this.pid := this.FindInstance("pid")
            if (this.pid) {
                if (_CDP.debug)
                    OutputDebug(format("i#{1} {2}:{3} existed pid={4}", A_LineFile,A_LineNumber,A_ThisFunc,this.pid))
                saveDetect := A_DetectHiddenWindows
                DetectHiddenWindows(true)
                for winHwnd in WinGetList("ahk_class Chrome_WidgetWin_1 ahk_pid " . this.pid) {
                    try {
                        titleLoop := WinGetTitle(winHwnd)
                    } catch {
                        continue
                    }
                    if (titleLoop ~= "\S") {
                        if (_CDP.debug)
                            OutputDebug(format("i#{1} {2}:this.hwnd={3},title={4}", A_LineFile,A_LineNumber,this.hwnd,titleLoop))
                        this.hwnd := winHwnd
                        break
                    }
                }
                DetectHiddenWindows(saveDetect)
                if (this.hwnd) {
                    if (_CDP.debug)
                        OutputDebug(format("i#{1} {2}:{3} 重新获取hwnd={4}", A_LineFile,A_LineNumber,A_ThisFunc,this.hwnd))
                    return this.hwnd
                } else {
                    if (_CDP.debug)
                        OutputDebug(format("i#{1} {2}:{3} 无法获取hwnd", A_LineFile,A_LineNumber,A_ThisFunc))
                }
            } else {
                if (tp) {
                    ;NOTE 找不到，是否结束所有进程
                    if (_CDP.debug)
                        OutputDebug(format("i#{1} {2}:关闭所有进程chrome.exe", A_LineFile,A_LineNumber))
                    for item in ComObjGet("winmgmts:").ExecQuery(format("select ProcessId from Win32_Process where name='{1}'", this.exeName))
                        ProcessClose(item.ProcessId)
                    if (tp == 2) {
                        return this.runChrome()
                    } else {
                        if (_CDP.debug)
                            OutputDebug(format("i#{1} {2}:通用pid检测hwnd失败", A_LineFile,A_LineNumber))
                        tooltip("待完善：通用pid检测hwnd失败")
                        SetTimer(tooltip, -1000)
                    }
                } else {
                    if (_CDP.debug)
                        OutputDebug(format("i#{1} {2}:{3} 现有进程非 CDP 模式，不处理", A_LineFile,A_LineNumber,A_ThisFunc))
                }
            }
        }
        return false
    }

    runChrome(urls:="") {
        sCmd := format("{1} {2} {3}", this.CliEscape(this.ChromePath),this.sParam,urls)
        if (_CDP.debug)
            OutputDebug(format("i#{1} {2}:{3} sCmd={4}", A_LineFile.fn(),A_LineNumber,A_ThisFunc,sCmd))
        run(sCmd,,, &pid) ;--ignore-certificate-errors
        this.pid := pid
        this.hwnd := WinWait("ahk_class Chrome_WidgetWin_1 ahk_pid " . this.pid)
        if (_CDP.debug)
            OutputDebug(format("i#{1} {2}:自动运行浏览器 hwnd={3} sCmd={}", A_LineFile,A_LineNumber,this.hwnd,sCmd))
        WinActivate
        WinMaximize
        return this.hwnd
    }

    /*
    NOTE 仅当非常明确只是获取网址和标题，用 getByHttp("json")
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
    getByHttp(key:="") {
        ;this.detect(true)
        ;debug 模式获取
        if (_CDP.debug)
            OutputDebug(format("i#{1} {2}:httpAll={3}", A_LineFile,A_LineNumber,json.stringify(this.httpGet("",true),4)))
        for objHttp in this.httpGet() {
            if (objHttp["type"] == "page" && !(objHttp["title"] ~= "^(DevTools|yonyou U9帮助)$")) { ;NOTE by 火冷 <2022-10-01 17:42:12>
                objHttp["url"] := rtrim(objHttp["url"], "/")
                if (_CDP.debug)
                    OutputDebug(format("i#{1} {2}:{3} key={4}", A_LineFile,A_LineNumber,A_ThisFunc,key))
                switch key {
                    case "title": return objHttp["title"]
                    case "url": return objHttp["url"]
                    case "arr": return [objHttp["title"], objHttp["url"]] ;标题+url
                    case "json": return objHttp["url"].jsonUrl()
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
    keys
        ="" 则返回全key的ao
        =数组 则返回指定keys的ao
        否则应设置为 jsonUrl 包含的 key，返回以 keys | "href" 为索引的 map(用来判断xx页面是否存在)
    funTrue
        默认只获取 page，如果要获取所有，则传入(*)=>1
    */
    getPages(funTrue:=unset, keys:=unset) {
        if (!isset(funTrue))
            funTrue := (obj)=>obj["type"] == "page"
        arr := this.httpGet()
        if (_CDP.debug)
            OutputDebug(format("i#{1} {2}:arr={3}", A_LineFile,A_LineNumber,json.stringify(arr,4)))
        if (!isset(keys) || keys is array)
            res := []
        else
            res := map()
        this.arrEmpty := [] ;NOTE 初始化空标签
        for obj in arr {
            if (funTrue(obj)) {
                obj["url"] := rtrim(obj["url"], "/") ;删除 url 右边的 /
                ;额外记录 arrEmpty
                if (obj["url"] == "chrome://newtab" || obj["url"] == "about:blank")
                    this.arrEmpty.push(obj)
                if (!isset(keys)) {
                    res.push(obj)
                } else if (keys is array) {
                    objTmp := map()
                    for key in keys
                        objTmp[key] := obj[key]
                    res.push(objTmp)
                } else {
                    ;格式化 url
                    objUrl := obj["url"].jsonUrl()
                    ;新记录两个 key
                    obj["index"] := A_Index
                    obj["json"] := objUrl
                    ;返回结果额外增加 href 的key
                    res.has(objUrl[keys]) ? res[objUrl[keys]].push(obj) : res[objUrl[keys]] := [obj]
                    res.has(objUrl["href"]) ? res[objUrl["href"]].push(obj) : res[objUrl["href"]] := [obj]
                }
            }
        }
        if (_CDP.debug)
            OutputDebug(format("i#{1} {2}:res={3}", A_LineFile,A_LineNumber,json.stringify(res,4)))
        return res
    }

    ;Escape a string in a manner suitable for command line parameters
    CliEscape(Param) => format('"{1}"', RegExReplace(Param, '(\\*)"', '$1$1\"'))

    ;pathname前面要带 /
    httpGet(pathname:="") => _CDP.httpOpen(this.http, "GET", pathname, this.DebugPort)
    httpPut(pathname:="") => _CDP.httpOpen(this.http, "PUT", pathname, this.DebugPort)

    ;closeNewtab(id:="") {
    ;    if (id == "") {
    ;        arr := this.getPages((obj)=>obj["url"]=="chrome://newtab")
    ;        if (arr.length)
    ;            id := arr[1]["id"]
    ;    }
    ;    if (id != "")
    ;        return this.httpGet("/close/" . id)
    ;}

    ;static FindPages(opts, MatchMode := "exact") {
    ;    Pages := []
    ;    for PageData in this.getPages() {
    ;        fg := true
    ;        for k, v in (Type(opts) = "Map" ? opts : opts.OwnProps())
    ;            if !((MatchMode = "exact" && PageData[k] = v) || (MatchMode = "contains" && InStr(PageData[k], v))
    ;                || (MatchMode = "startswith" && InStr(PageData[k], v) == 1) || (MatchMode = "regex" && PageData[k] ~= v)) {
    ;                    fg := false
    ;                    break
    ;                }
    ;        if (fg)
    ;            Pages.Push(PageData)
    ;    }
    ;    return Pages
    ;}

    ;static ClosePage(opts, MatchMode:="exact") {
    ;    for page in this.FindPages(opts, MatchMode)
    ;        return this.httpGet("/close/" . page["id"])
    ;}

    ;https://player.bilibili.com/player.html?aid=976962208&bvid=BV1244y1Y7VR&cid=457445567&page=1
    ;<iframe src="//player.bilibili.com/player.html?aid=720241593&bvid=BV1KQ4y1a7pd&cid=401115360&page=1" scrolling="no" border="0" frameborder="no" framespacing="0" allowfullscreen="true"> </iframe>
    ;iframeCode() {
    ;    obj := this.getByHttp()
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
    ;        UIA.FindElement(, "Button", "翻译此页").GetCurrentPattern("Invoke").Invoke_Invoke()
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

    ;funHttp 一般方式 (o)=>o["url"].jsonUrl("pathname")
    ;_CDP.smartGet("page")
    ;_CDP.smartGet().getPage((o)=>instr(o["url"].jsonUrl("pathname"),"/app/print-format/")==1)
    getPage(funHttp:=unset, bActive:=false) {
        if (isset(funHttp)) {
            arr := this.httpGet()
            for objHttp in arr {
                if (_CDP.debug)
                    OutputDebug(format("i#{1} {2}:{3} objHttp={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(objHttp,4)))
                if (objHttp["type"] == "page" && objHttp["title"] != "DevTools") {
                    ;if (funHttp(objHttp["url"].jsonUrl()))
                    if (funHttp(objHttp)) {
                        if (_CDP.debug)
                            OutputDebug(format("d#{1} {2}:{3} url={4}", A_LineFile,A_LineNumber,A_ThisFunc,objHttp["url"]))
                        oPage := _CDP.CDPP(objHttp, this.http)
                        if (bActive)
                            oPage.activate()
                        return oPage
                    }
                }
            }
        } else {
            return _CDP.CDPP(this.getByHttp(), this.http)
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
    NOTE 此实例的 title 和 url 不会自动更新，如果网页发生变化需要重新获取
    */
    class CDPP extends WebSocket {

        __new(objHttp, http) {
            if (_CDP.debug)
                OutputDebug(format("i#{1} {2}:{3} CDPP(objHttp)={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(objHttp,4)))
            this.idx := 0
            this.responses := map()
            RegExMatch(objHttp["webSocketDebuggerUrl"], "ws://[\d\.]+:(\d+)", &m)
            this.DebugPort := m[1]
            this.setProp(objHttp)
            this.http := http
            super.__new(objHttp["webSocketDebuggerUrl"]) ;NOTE 会修改url属性值为 webSocketDebuggerUrl 值
            if (_CDP.debug)
                OutputDebug(format("i#{1} {2}:{3} after new WebSocket={4}", A_LineFile,A_LineNumber,A_ThisFunc,objHttp["webSocketDebuggerUrl"]))
            ;this.callback := events
            ;this.KeepAlive := keepalive.bind(ObjPtr(this))
            ;SetTimer(this.KeepAlive, 25000)
            ;keepalive() {
            ;    self := ObjFromPtrAddRef(pthis)
            ;    self("Browser.getVersion",, false)
            ;}
        }

        __delete() {
            ;SetTimer(keepalive, 0)
            super.__delete()
        }

        ;调用其他方法
        ;msgbox(json.stringify(_CDP.smartGet("page").call("Page.getLayoutMetrics"), 4))
		call(DomainAndMethod, Params?, WaitForResponse := true) {
            if (this.readyState != 1)
                throw error("Not connected to tab")
            ; Use a temporary variable for id in case more calls are made
            ; before we receive a response.
			if !(idx := this.idx += 1)
				idx := this.idx += 1
			this.sendText(JSON.stringify(map("id",idx, "params",Params ?? {}, "method",DomainAndMethod), 0))
			if (!WaitForResponse)
				return
			; Wait for the response
			this.responses[idx] := false
			while (this.readyState==1 && !this.responses[idx])
				sleep(20)
			; Get the response, check if it's an error
			if !(response := this.responses.Delete(idx))
				throw Error("Not connected to tab")
			if !(response is map)
				return response
            if (response.has("error")) {
                if (_CDP.debug)
                    OutputDebug(format("i#{1} {2}:{3} DomainAndMethod={4}", A_LineFile.fn(),A_LineNumber,A_ThisFunc,DomainAndMethod))
                if (isset(Params) && _CDP.debug)
                    OutputDebug(format("i#{1} {2}:{3} Params={4}", A_LineFile.fn(),A_LineNumber,A_ThisFunc,json.stringify(Params,4)))
                throw error("Chrome indicated error in response",, JSON.stringify(response["error"]))
            }
            if (response.has("result"))
                return response["result"]
        }

        ; https://chromedevtools.github.io/devtools-protocol/1-3/Runtime/#method-evaluate
        ;ahk传入变量：直接修改 jsCode
        ;返回值
        ;   判断null用 evaluate(js)["value"] is ComValue
        ;TODO 生产订单列表，返回null，console测试正常 evaluate('console.log(document.querySelector(".main_Table"));')
        ;Object reference chain is too long 原因可能是jQuery，用原生js试试
        ;`${}` 的用法示例
        ;    document.querySelector(``#AttachCollabATRN\\:${field}\\:0``).value = xxx;
        evaluate(jsCode, key:="") {
            response := this.call("Runtime.evaluate", {
                expression: jsCode,
                objectGroup: "console",
                includeCommandLineAPI: JSON.true,
                silent: JSON.false,
                returnByValue: JSON.true, ;支持返回数组等格式
                userGesture: JSON.true,
                awaitPromise: JSON.false
            })
            if (response is map) {
                if (_CDP.debug)
                    OutputDebug(format("i#{1} {2}:{3} response={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(response,4)))
                if (response.has("ErrorDetails"))
                    throw error(response["result"]["description"],, JSON.stringify(response["ErrorDetails"]))
                else if (response.has("exceptionDetails"))
                    throw error(response["result"]["description"],, JSON.stringify(response["exceptionDetails"]))
                return (key != "") ? response["result"].get(key, "") : response["result"]
            } else {
                throw error(A_ThisFunc)
            }
        }

        close() {
            this.httpGet(format("/close/{1}",this.id))
			this.__Delete()
        }

        /*
            {
            "layoutViewport": {
                "pageX": 0,
                "pageY": 0,
                "clientWidth": 1394,
                "clientHeight": 1363
            },
            "visualViewport": {
                "offsetX": 0,
                "offsetY": 0,
                "pageX": 0,
                "pageY": 0,
                "clientWidth": 1394,
                "clientHeight": 1363,
                "scale": 1,
                "zoom": 1
            },
            "contentSize": {
                "x": 0,
                "y": 0,
                "width": 1394,
                "height": 1363
            },
            "cssLayoutViewport": {
                "pageX": 0,
                "pageY": 0,
                "clientWidth": 1394,
                "clientHeight": 1363
            },
            "cssVisualViewport": {
                "offsetX": 0,
                "offsetY": 0,
                "pageX": 0,
                "pageY": 0,
                "clientWidth": 1394,
                "clientHeight": 1363,
                "scale": 1,
                "zoom": 1
            },
            "cssContentSize": {
                "x": 0,
                "y": 0,
                "width": 1394,
                "height": 1363
            }
        }
        */
        getContentHeight() {
            data := this("Page.getLayoutMetrics")
            return data["contentSize"]["height"]
        }

        activate() => this.httpGet(format("/activate/{1}",this.id))
        ;不见得靠谱
        WaitForLoad(DesiredState:="complete", Interval:=500) {
            loop {
                state := this.evaluate("document.readyState","value")
                if (_CDP.debug)
                    OutputDebug(format("i#{1} {2}:{3} state={4}", A_LineFile,A_LineNumber,A_ThisFunc,state))
                if (state != DesiredState)
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
			if this.responses.Has(id := data.Get("id", 0))
				this.responses[id] := data
            ;try (this.callback)(msg)
        }

        ;在当前标签打开 NOTE 注意信息更新问题
        ;返回 {
        ;   "frameId": "1E191BE8438BBFA10706F45BE9FA067D",
        ;   "loaderId": "927FEC239315EBC32A3D6576A69E5B81"
        ;}
        navigate(url, bActive:=false) {
            resp := this("Page.navigate", map("url",url))
            if (_CDP.debug)
                OutputDebug(format("#{1} {2}:{3} resp={4}", A_LineFile.fn(),A_LineNumber,A_ThisFunc,json.stringify(resp,4)))
            this.setProp(url)
            if (bActive)
                this.activate()
        }

        setProp(objHttp) {
            if (isobject(objHttp)) {
                for k, v in objHttp
                    this.%k% := v
                this.objUrl := objHttp["url"].jsonUrl() ;url 会在后面被修改
                ;this.objUrl["title"] := objHttp["title"] ;和 getByHttp("json") 同格式
            } else {
                this.objUrl := objHttp.jsonUrl() ;url 会在后面被修改
            }
        }

        ;pathname前面要带 /
        httpGet(pathname:="") => _CDP.httpOpen(this.http, "GET", pathname, this.DebugPort)

        saveIco() {
            if !this.HasProp("faviconUrl")
                return
            fp := format("{1}\{2}.{3}",A_Desktop,this.title,RegExReplace(this.faviconUrl,".*\."))
            OutputDebug(format("i#{1} {2}:{3} this.faviconUrl={4}", A_LineFile.fn(),A_LineNumber,A_ThisFunc,this.faviconUrl))
            download(this.faviconUrl, fp)
            ;_TC.runc(fp, 0, false)
        }

        ;TODO
        ;getFrameTree() => this("Page.getFrameTree")

    }
}
