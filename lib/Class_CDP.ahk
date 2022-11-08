/*
类似实现 https://github.com/Xeo786/Rufaydium-Webdriver
CDP https://chromedevtools.github.io/devtools-protocol/1-3/Page
原理：
1.this.detect(true)
2.httpOpen
3.getPageList|getCurrentPage
当前页面的处理，推荐用
oPage := CDP_Page(_CB)

https://github.com/G33kDude/Chrome.ahk
https://github.com/mark-wiemer/Chrome.ahk/tree/v2
ImagePut原理 https://github.com/iseahound/ImagePut/wiki/Internal-Documentation
https://www.autohotkey.com/boards/viewtopic.php?f=6&t=42890
快捷键 https://support.google.com/chrome/answer/157179?hl=zh-Hans
驱动	https://sites.google.com/a/chromium.org/chromedriver/downloads
	https://chromedriver.storage.googleapis.com/index.html

chrome://flags/#enable-tab-audio-muting
chrome://flags/#enable-quic
chrome://flags/#smooth-scrolling
chrome://flags/#overlay-scrollbars

清除全部缓存
    send("{ctrl down}{shift down}{delete}{shift up}{ctrl up}")
清除当前页缓存
    右键刷新按钮→清空缓存并硬性重新加载

打开网址变成【本地文件】：设置其他浏览器为默认，再设置回默认浏览器。
扩展被隐藏：往左拖动地址栏右侧把他们都显示出来就行了
弹框询问是否转中文：
翻墙科普 https://www.youtube.com/playlist?list=PLqybz7NWybwUgR-S6m78tfd-lV4sBvGFG
ctrl-f查找内容时崩溃：

允许编辑网页
    开发者工具→console→最下方输入 document.body.contentEditable='true';

命令行
    --user-data-dir=d:\hy\User Data ;如果用命令行指定，普通的邮箱弹框则会加载默认文件夹影响使用

NOTE 问题：
打不开，热点没问题：判断dns，ping ip测试
页面变成英文，删除 User Data\Default\Local Storage\ 文件夹
;您的连接不是私密连接
    添加命令行参数 --ignore-certificate-errors
    chrome://flags ??
    send("thisisunsafe")

路径：
HKEY_CURRENT_USER\SOFTWARE\Classes\http\DefaultIcon
*/

;NOTE url 支持多个，用空格分开即可
;StrSplit(RegRead("HKEY_CLASSES_ROOT\http\shell\open\command"), '"')[1]

class _CDP {
    static oHttp := ComObject('WinHttp.WinHttpRequest.5.1')
    ;static funLogin := {}
    static objSingleHost := map( ;指定单页面的host
        "oa.hf-zj.com:9898", 1,
        "192.168.16.6", 1,
        "192.168.16.217", 1,
        "192.168.16.228", 1,
    )

    ;NOTE 必须要运行
    static init(fp, port) {
        this.ChromePath := fp
        SplitPath(this.ChromePath, &fn)
        this.exeName := fn
        this.DebugPort := port
        this.hwnd := 0
        this.pid := 0
        ;msgbox(type(this) . "`n" . this.hwnd . "`n" . this.pid)
        this.userdata := ""
        if (this.userdata != "") {
            if (!FileExist(this.userdata))
                DirCreate(this.userdata)
            this.sParam .= ' --user-data-dir=' . this.CliEscape(this.userdata)
        }
        ;获取 sParam
        this.sParam := format("--remote-debugging-port={1}", this.DebugPort)
        ;this.sParam .= ' ' . flags
    }

    ;NOTE 有些页面只限制打开1个，规则在哪里指定
    ;往往在 __new 里被调用 或见 Chrome_Do.openUrl()
    static tabOpenLink(arrUrl:='', funAfterDo:="", bActive:=true) { ;about:blank chrome://newtab
        OutputDebug(format("i#{1} {2}:A_ThisFunc={3}", A_LineFile,A_LineNumber,A_ThisFunc))
        if (!isobject(arrUrl))
            arrUrl := (arrUrl == "") ? [] : [arrUrl]
        ;msgbox(json.stringify(arrUrl, 4))
        if (arrUrl.length > 1)
            bActive := false
        ;bActive := (A_Index==arrUrl.length) ? bActive : false ;只激活最后一个标签
        if (this.hwnd := this.detect()) {
            if (arrUrl.length) {
                objPage := this.getPageList(, "host")
                arrRes := []
                for urlOpen in arrUrl { ;NOTE 判断页面是否已打开
                    urlOpen := rtrim(urlOpen, "/")
                    if (!instr(urlOpen, "://"))
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
                    ;打开标签
                    if (this.arrEmpty.length) ;优先在空白页打开
                        CDP_Page(this, this.arrEmpty.pop()["webSocketDebuggerUrl"]).navigate(urlOpen, bActive)
                    else ;新标签打开
                        this.httpOpen("/new?" . urlOpen) ;TODO 哪里有问题
                }
            }
            try {
                WinShow(this.hwnd)
            } catch {
                OutputDebug(format("i#{1} {2}:not found hwnd={3} ", A_LineFile,A_LineNumber,this.hwnd))
            } else {
                WinActivate(this.hwnd)
                WinMaximize(this.hwnd)
            }
        } else { ;新打开
            urls := ''
            for url in arrUrl
                urls .= ' ' . url ;this.CliEscape(url)
            this.runChrome(urls)
        }
        if (arrUrl.length == 1 && bActive) {
            oPage := CDP_Page(this)
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

    static getTipsText() {
        cmMouse := A_CoordModeMouse
        CoordMode("Mouse", "screen")
        MouseGetPos(&xMouse, &yMouse)
        CoordMode("Mouse", cmMouse)
        cond := UIA.CreatePropertyCondition("ControlType", "Tooltip")
        for hwnd in WinGetList("ahk_class Chrome_WidgetWin_1") {
            WinGetPos(&x, &y,,, hwnd)
            if ((x-xMouse)**2 + (y-yMouse)**2 <= 100**2) { ;离鼠标近
                el := UIA.ElementFromHandle(hwnd).GetFirst()
                if (el.CurrentControlType == UIA.ControlType.Tooltip)
                    return el.CurrentName
            }
        }
    }

    static runChrome(urls:="") {
        sCmd := format("{1} {2} {3}", _CDP.CliEscape(this.ChromePath),this.sParam,urls)
        run(sCmd,,, &pid) ;--ignore-certificate-errors
        this.pid := pid
        this.hwnd := WinWait("ahk_class Chrome_WidgetWin_1 ahk_pid " . this.pid)
        OutputDebug(format("i#{1} {2}:自动运行浏览器 hwnd={3} sCmd={}", A_LineFile,A_LineNumber,this.hwnd,sCmd))
        WinActivate
        WinMaximize
    }

    ;核实并获取Chrome的 pid 和 hwnd
    ;0 不检测
    ;1 检测不到则关闭当前浏览器
    ;2 检测不到则关闭并正确打开浏览器
    ;返回 hwnd
    static detect(tp:=0) {
        if (this.hwnd && ProcessExist(this.pid))
            return this.hwnd
        if (ProcessExist(this.exeName)) { ;可能脚本重启等原因丢失了数据
            this.pid := this.FindInstances().get("pid", 0)
            OutputDebug(format("i#{1} {2}:this.pid={3}", A_LineFile,A_LineNumber,this.pid))
            if (this.pid) {
                for winHwnd in WinGetList("ahk_class Chrome_WidgetWin_1 ahk_pid " . this.pid) {
                    try
                        titleLoop := WinGetTitle(winHwnd)
                    catch
                        continue
                    if (titleLoop ~= "\S") {
                        this.hwnd := winHwnd
                        break
                    }
                }
                if (this.hwnd) {
                    tooltip(format("detect重新获取chrome.hwnd={1}", this.hwnd))
                    SetTimer(tooltip, -1000)
                    return this.hwnd
                } else if (tp) {
                    ;NOTE 找不到，是否结束所有进程
                    for item in ComObjGet("winmgmts:").ExecQuery(format("select ProcessId from Win32_Process where name='{1}'", this.exeName))
                        ProcessClose(item.ProcessId)
                    if (tp == 2) {
                        this.runChrome()
                        return true
                    }
                }
            } else {
                tooltip("待完善：通用pid检测hwnd失败")
                SetTimer(tooltip, -1000)
            }
        }
        return false
    }

    ;pathname前面要带 /
    static httpOpen(pathname, bResponse:=false) {
        _CDP.oHttp.open('GET', format("http://127.0.0.1:{1}/json{2}", this.DebugPort,pathname))
        resSend := _CDP.oHttp.send()
        return bResponse ? JSON.parse(_CDP.oHttp.responseText) : resSend
    }

    /*
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
    static getCurrentPage(key:="") {
        this.detect(true)
        ;debug 模式获取
        try {
            ;OutputDebug(format("i#{1} {2}:httpAll={3}", A_LineFile,A_LineNumber,json.stringify(this.httpOpen("",true),4)))
            for obj in this.httpOpen("", true) {
                if (obj["type"] == "page" && obj["title"] != "DevTools") { ;NOTE by 火冷 <2022-10-01 17:42:12>
                    obj["url"] := rtrim(obj["url"], "/")
                    return key=="" ? obj : obj[key]
                }
            }
        } catch {
            return map()
        }
    }

    /*
    Queries Chrome for a list of pages that expose a debug interface.
    In addition to standard tabs, these include pages such as extension
    configuration pages.
    所有标签+插件的信息
    keyJson
        ="" 则返回数组
        否则应设置为 jsonUrl 包含的 key，返回以 keyJson | "href" 为索引的 map
    */
    static getPageList(funTrue:="", keyJson:="") {
        if (funTrue == "")
            funTrue := (obj)=>obj["type"] == "page"
        arr := this.httpOpen("", true)
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
        return keyJson == "" ? arrRes : objRes
    }

    static closeNewtab(id:="") {
        if (id == "") {
            arr := this.getPageList((obj)=>obj["url"]=="chrome://newtab")
            if (arr.length)
                id := arr[1]['id']
        }
        if (id != "")
            return this.httpOpen("/close/" . id)
    }

    ;static ClosePage(opts, MatchMode:='exact') {
    ;    for page in this.FindPages(opts, MatchMode)
    ;        return this.httpOpen("/close/" . page["id"])
    ;}

    ;static ActivatePage(opts, MatchMode:='exact') {
    ;    for page in this.FindPages(opts, MatchMode)
    ;        return this.httpOpen("/activate/" . page["id"])
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

    ;Firefox UIA.ElementFromHandle(WinActive("A")).FindFirst(UIA.CreatePropertyCondition("AutomationId", "urlbar-input")).GetCurrentPropertyValue("ValueValue")
    static getUrl() => this.getCurrentPage()["url"]

    ;https://player.bilibili.com/player.html?aid=976962208&bvid=BV1244y1Y7VR&cid=457445567&page=1
    ;<iframe src="//player.bilibili.com/player.html?aid=720241593&bvid=BV1KQ4y1a7pd&cid=401115360&page=1" scrolling="no" border="0" frameborder="no" framespacing="0" allowfullscreen="true"> </iframe>
    static iframeCode() {
        obj := this.getCurrentPage()
        return format('<iframe src="{1}" scrolling="no" border="0" frameborder="no" framespacing="0" allowfullscreen="true" width="100%" height="450px"> </iframe>', obj["href"])
    }

    static thisisunsafe(oPage) {
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

    static isF12() {
        WinGetPos(&x0, &y0, &w0, &h0, "A")
        ControlGetPos(&x, &y, &w, &h, "Chrome_RenderWidgetHostHWND1", "A")
        return (x+w < w0 - 100) || (y+h < h0 - 100)
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

    ;删除末尾的 - Cent Browser
    static title(bClean:=true) => this.getCurrentPage()["title"]

    ;移到次显示器并全屏播放
    static moveToSubScreen(winTitle:="", full:=true) {
        WinMove(A_ScreenWidth-8, -8,,, winTitle)
        if (full && WinGetExStyle(winTitle)) ;非全屏则返回 256，否则为 0
            send("{F11}")
    }

    static deleteCache() => send("{ctrl down}{shift down}{delete}{shift up}{ctrl up}")

    static errScroll() { ;无法滚动的问题
        WinWaitActive("ahk_exe Chrome.exe")
        A_Clipboard := "chrome://flags/#enable-gpu-rasterization"
        doSend()
        msgbox("设置【GPU rasterization】成disabled，完成后请关闭本窗口并按pause键继续")
        KeyWait("pause", "D")
        sleep(200)
        WinWaitActive("ahk_exe Chrome.exe")
        A_Clipboard := "chrome://settings/"
        doSend()
        msgbox("点击最下方的【高级】，拉到最后，关闭【使用硬件加速模式（如果可用）】，完成后请关闭本窗口并按pause键结束")
        KeyWait("pause", "D")
        tooltip()
        doSend() {
            sleep(20)
            send("o")
            sleep(100)
            send("c")
            sleep(1000)
        }
    }

    static errOpenUrl() { ;打开网址变成c:\*
        run("s:\CentBrowser\chrome.exe --make-default-browser")
        msgbox("完成")
    }

    static SoundClose() { ;设置静音
        ;hyf_winActiveOrOpen("ahk_class Chrome_WidgetWin_1 ahk_exe Chrome.exe", gBrowser, 1, "Max")
        WinWaitActive("ahk_exe Chrome.exe")
        this.tabOpenLink("chrome://flags/#enable-tab-audio-muting")
        if !WinWaitActive("chrome://flags/#enable-tab-audio-muting",, 1) {
            A_Clipboard := "chrome://flags/#enable-tab-audio-muting"
            msgbox("网址已复制，请手动粘贴并打开")
        }
        msgbox("【启用】tab audio muting UI control`n重启浏览器后，对标签右键就可以设置【将此标签页静音】")
    }

    static mhtml() { ;保存为mhtml
        this.tabOpenLink("chrome://flags/#save-page-as-mhtml")
    }

    static downloadSave() { ;下载内容要点击【保留】才行
        this.tabOpenLink("chrome://settings/privacyV")
        msgbox("【保护您和您的设备不受危险网站的侵害】选项取消打勾")
    }

    ;Escape a string in a manner suitable for command line parameters
    static CliEscape(Param) => format('"{1}"', RegExReplace(Param, '(\\*)"', '$1$1\"'))

    ;通用命令行参数获取 pid
    static FindInstances() {
        for item in ComObjGet('winmgmts:').ExecQuery(format("SELECT CommandLine,ProcessId FROM Win32_Process WHERE Name = '{1}'", this.exeName)) {
            if (RegExMatch(item.CommandLine, '--remote-debugging-port=(\d+)', &m)) {
                OutputDebug(format("d#{1} {2}:return CommandLine={3}", A_LineFile,A_LineNumber,item.CommandLine))
                return map(
                    "DebugPort", m[1],
                    "CommandLine", item.CommandLine,
                    "pid", item.ProcessId,
                )
            } else {
                OutputDebug(format("d#{1} {2}:not matched CommandLine={3}", A_LineFile,A_LineNumber,item.CommandLine))
            }
        }
        return map()
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
class CDP_Page extends WebSocket {
    static count := 0
    idx := 0
    responses := map()

    __new(cls, events:=0) {
        CDP_Page.count++
        OutputDebug(format("w#{1} {2}:CDP_Page.count={3}", A_LineFile,A_LineNumber,CDP_Page.count))
        this.cls := cls
        ;OutputDebug(format("i#{1} {2}:page={3}", A_LineFile,A_LineNumber,this.cls.getCurrentPage()))
        for k, v in this.cls.getCurrentPage()
            this.%k% := v
        ;OutputDebug(format("i#{1} {2}:this.url={3}", A_LineFile,A_LineNumber,this.url))
        this.setUrlJson(this.url)
        super.__new(StrReplace(this.webSocketDebuggerUrl, "localhost", "127.0.0.1")) ;NOTE 会修改url属性值为 webSocketDebuggerUrl 值
        ;pthis := ObjPtr(this)
        ;this.KeepAlive := keepalive
        this.callback := events
        ;SetTimer(keepalive, -1000)
        ;keepalive() {
        ;    self := ObjFromPtrAddRef(pthis)
        ;    self('Browser.getVersion',, false)
        ;}
    }

    __delete() {
        CDP_Page.count--
        OutputDebug(format("w#{1} {2}:CDP_Page.count={3}", A_LineFile,A_LineNumber,CDP_Page.count))
        ;SetTimer(keepalive, 0)
        super.close()
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
            if (response.has("ErrorDetails"))
                throw error(response["result"]["description"],, JSON.stringify(response["ErrorDetails"]))
            return (key != "") ? response["result"].get(key, "") : response["result"]
        } else {
            throw error(A_ThisFunc)
        }
    }

    setUrlJson(url) {
        this.objUrl := url.jsonUrl() ;url 会在后面被修改
        for k, v in this.objUrl
            this.%k% := v
    }

    ;删除网址多余部分
    urlClean() {
        if (this.hostname == "www.bilibili.com") {
            if (instr(this.pathname, "/video/"))
                return this.origin . RegExReplace(this.pathname, "^\/video\/\w+\K.*") ;. this["search"]
            else
                return this.href
        } else if (this.hostname == "item.jd.com") {
            return this.origin . this.pathname
        } else
            return this.href
    }

    saveIco() {
        if !this.HasProp("faviconUrl")
            return
        fp := format("{1}\{2}.{3}",A_Desktop,this.title,RegExReplace(this.faviconUrl,".*\."))
        download(this.faviconUrl, fp)
        ;_TC.runc(fp, 0, false)
    }

    arrTitleUrl(bClean:=true, param:="") {
        fun := bClean ? titleClean : (x)=>x
        return [titleClean(this.title),this.href.urlClean()]
        titleClean(tt) {
            tt := StrReplace(tt, "_哔哩哔哩_bilibili", "_哔哩哔哩") ;TODO 待完善
            return tt
        }
    }

    markdownUrl(bClean:=true) {
        arr := this.arrTitleUrl(bClean)
        return format("[{1}]({2})", arr*)
    }

    ;call("browser.close")
    call(DomainAndMethod, Params:='', WaitForResponse:=true) {
        if (this.readyState != 1)
            throw error("Not connected to tab")
        ; Use a temporary variable for ID in case more calls are made
        ; before we receive a response.
        this.sendText(JSON.stringify(map('id',idx:=this.idx+=1, 'params',Params?Params:{}, 'method',DomainAndMethod), 0))
        if (!WaitForResponse)
            return
        ; Wait for the response
        this.responses[idx] := false
        while (this.readyState == 1 && !this.responses[idx]) {
            sleep(20)
        }
        ; Get the response, check if it's an error
        response := this.responses.delete(idx)
        if !(response is map)
            return
        if (response.has("error"))
            throw error("Chrome indicated error in response",, JSON.stringify(response['error']))
        if (response.has("result"))
            return response["result"]
    }

    ;event(EventName, Event) {
    ;    ; If it was called from the WebSocket adjust the class context
    ;    if (this.Parent)
    ;        this := this.Parent
    ;    ; TODO: Handle error events
    ;    if (EventName == "Open") {
    ;        ;this.connected := True
    ;        ;BoundKeepAlive := this.BoundKeepAlive
    ;        ;SetTimer(BoundKeepAlive, 15000)
    ;    } else if (EventName == "Message") {
    ;        data := Chrome.Jxon_Load(Event.data)
    ;        ;Run the callback routine
    ;        fnCallback := this.fnCallback
    ;        if (newData := %fnCallback%(data))
    ;            data := newData
    ;        if (this.responses.HasKey(data.ID))
    ;            this.responses[data.ID] := data
    ;    } else if (EventName == "Close") {
    ;        this.Disconnect()
    ;        fnClose := this.fnClose
    ;        %fnClose%(this)
    ;    }
    ;}

    ;TODO
    translateType() => msgbox(this("Page.TransitionType"))
    activate() => this.cls.httpOpen(format("/activate/{1}",this.id))
    close() {
        super.close()
        this.cls.httpOpen(format("/close/{1}",this.id))
    }

    ;TODO
    getFrameTree() => this("Page.getFrameTree")

    ;在当前标签打开
    navigate(url, bActive:=true) {
        this("Page.navigate", map("url",url))
        this.setUrlJson(url)
        if (bActive)
            this.activate()
    }

    WaitForLoad(DesiredState:="complete", Interval:=100) {
        while (this.evaluate('document.readyState',"value") != DesiredState)
            sleep(Interval)
    }
    onClose() => this.reconnect()
    onMessage(msg) {
        data := JSON.parse(msg)
        if (data.has('id') && this.responses.has(data['id']))
            this.responses[data['id']] := data
        try (this.callback)(msg)
    }
}
