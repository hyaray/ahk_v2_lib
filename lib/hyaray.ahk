/*
;只放不依赖第3方的基础函数
;常规用到的也放这里方便移植，不适合放到软件专属库里

;hotkey("F10",(p*)=>hyf_ttt())
;hyf_ttt() {
;    arr := [
;        "_TC",
;    ]
;    for v1 in arr {
;        v2 := StrReplace("VimD_" . v1, "__", "_")
;        arr1 := hyf_dir(%v1%)
;        arr2 := hyf_dir(%v2%)
;        json.stringify(arr1, 4).compareByBC(json.stringify(arr2, 4))
;    }
;}

;-----------------------------------general__-----------------------------------
;-----------------------------------calc-----------------------------------
;-----------------------------------Windows__-----------------------------------
;-----------------------------------Excel__-----------------------------------
;-----------------------------------obj__-----------------------------------
*/

;-----------------------------------general__-----------------------------------
;数字则sleep，{xxx}开头则 SendText
;NOTE send("{1000}") 相当于 sleep(1000)，但有未知BUG，不要用
; sendEx("string1`n", 1000, "{tab}", "string2", 1000)
sendEx(arr*) {
    for v in arr {
        if (v is integer) {
            sleep(v)
        } else {
            if (v ~= "i)^\{\w+(?: (?:down|up|\d+))?\}") ;NOTE 如果要发送 {\w+} 格式字符串，则不要用此函数
                send(v)
            else
                SendText(v)
        }
    }
}

;NOTE 可直接获取的不依赖复制
;bVimNormal 获取 Vim normal模式下的内容
hyf_getSelect(bVimNormal:=false, bInput:=false) {
    if (WinActive("ahk_class XLMAIN")) {
        if (ControlGetClassNN(ControlGetFocus()) == "EXCEL71")
            return rng2str(ox().selection)
    } else if (WinActive("ahk_class Vim")) { ;Vim 用接口直接获取内容，无需复制
        oVim := ComObjActive("Vim.application")
        if (oVim.eval("mode()") == "n") {
            if (bVimNormal) {
                cword := oVim.eval('iconv(expand("<cword>"),"utf-8","cp936")')
                if (cword != "")
                    return cword
            }
        } else if (instr(oVim.eval("mode()"), "v")) { ;见 _Vim.getSelect()
            oVim.SendKeys("y")
            res := oVim.eval('iconv(@0,"utf-8","cp936")')
            oVim.SendKeys("gv")
            return res
        }
    } else if (WinActive("ahk_class #32770")) {
        OutputDebug(format("i#{1} {2}:#32770", A_LineFile,A_LineNumber))
        res := getTextIn32770()
        if (res != "")
            return res
    }
    try {
        WinExist("A")
        ctl := ControlGetClassNN(ControlGetFocus())
        if (ctl ~= "i)^Edit\d+$") { ;Edit 控件也无需复制内容
            OutputDebug(format("i#{1} {2}:Edit", A_LineFile,A_LineNumber))
            sPos := buffer(4, 0)
            ePos := buffer(4, 0)
            SendMessage(EM_GETSEL:=0xB0, sPos, ePos, ctl)
            s := numget(sPos, 0, "UInt")
            e := numget(ePos, 0, "UInt")
            if (e > s) {
                str := ControlGetText(ctl)
                return substr(str, s+1, e-s)
            }
        }
    }
    ;其他情况复制
    clipSave := A_Clipboard
    A_Clipboard := ""
    sleep(10)
    if (WinActive("ahk_class VirtualConsoleClass")) {
        send("{enter}")
    } else {
        OutputDebug(format("i#{1} {2}:^c", A_LineFile,A_LineNumber))
        send("{ctrl down}c{ctrl up}")
    }
    if (ClipWait(0.2)) {
        if (0)
            res := trim(A_Clipboard) ;TODO 可能会耗时较长
        else
            res := A_Clipboard
        ;OutputDebug(format("i#{1} {2}:res={3}", A_LineFile,A_LineNumber,res))
        A_Clipboard := clipSave
        return res
    } else {
        OutputDebug(format("d#{1} {2}:copy failed clip={3}", A_LineFile,A_LineNumber,A_Clipboard))
        A_Clipboard := clipSave
        if (bInput) {
            res := inputbox("获取和复制失败，请手工输入内容")
            if (res.result=="Cancel" || (res.value == ""))
                return
            return res.value
        } else {
            return ""
        }
    }
    ;暂时应用是选中多个标题名
    rng2str(rng, charCol:="`t", funcObj:="") {
        if (rng.cells.count == 1)
            return rng.text
        res := ""
        if (!isobject(funcObj))
            funcObj := x=>x
        arrV := rng.value
        loop(rng.rows.count) {
            r := A_Index
            loop(rng.columns.count) {
                try
                    res .= funcObj(delete0(arrV[r,A_Index])) . charCol
                catch
                    msgbox(r . "`n" . A_Index)
            }
            res := rtrim(res,charCol) . "`r`n"
        }
        return rtrim(res, "`r`n")
        delete0(num) {
            if (num ~= "^-?\d+\.\d+$") {
                if (num ~= "\.\d{8,}$")
                    num := round(num+0.00000001, 6)
                return rtrim(RegExReplace(num, "\.\d*?\K0+$"), ".")
            } else
                return num
        }
    }
    getTextIn32770() {
        if (StrLower(ControlGetClassNN(ControlGetFocus())) ~= "(static|button)") {
            /*
            ---------------------------
            KwMusic.exe - 系统错误
            ---------------------------
            由于找不到 MSVCP120.dll，无法继续执行代码。重新安装程序可能会解决此问题。 
            ---------------------------
            确定   
            ---------------------------

            更新(&U)
            不更新(&N)
            帮助(&H)
            此工作簿包含到一个或多个可能不安全的外部源的链接。
            如果信任这些链接，请更新它们以获得最新数据。否则，继续使用现有的数据。
            100198
            */
            str := StrLower(ControlGetClassNN(ControlGetFocus())) ~= "static" ? ControlGetText(ControlGetFocus()) : WinGetText()
            str := trim(str)
            if (str ~= "^-{27}") {
                RegExMatch(str, "^-{27}.*?-{27}(.*?)-{27}", &m)
                str := m[1]
            }
            arr := StrSplit(str, "`n", "`r")
            ;msgbox(json.stringify(arr, 4))
            res := ""
            for sLine in arr {
                if (sLine ~= "^(|\d+|-+|确定|取消|.*(\(\&\S\)))$") ;NOTE
                    continue
                res .= sLine . "`r`n"
            }
            res := rtrim(res, "`r`n")
            return res
        }
        _32770_textDeal(s) {
            ;s := WinGetTitle(winTitle)
            arr := StrSplit(s, "`n", "`r")
            msgbox(json.stringify(arr, 4))
            l := arr.length
            if (arr[1] == "---------------------------") {
                loop(3)
                    arr.pop()
                loop(3)
                    arr.RemoveAt(1)
            }
            res := ""
            for sLine in arr
                res .= sLine . "`r`n"
            return rtrim(res, "`r`n")
        }
    }
}

;设置剪切板并提示
hyf_setClip(str, stip:="已复制", n:=3000) {
    A_Clipboard := str
    tooltip(stip . "`n`n" . str)
    SetTimer(tooltip, -n)
}

;如果可直接键盘输出，一般用 SendText
;用剪切板发送字符串
hyf_paste(str, k:="") {
    c := A_Clipboard
    A_Clipboard := str
    while(A_Clipboard != str)
        sleep(10)
    if (0) ;待完善
        send("{shift down}{ins}{shift up}")
    else
        send("{ctrl down}v{ctrl up}")
    sleep(20)
    if (k != "")
        send(k)
    sleep(100)
    A_Clipboard := c
}

RegExist(dir) {
    loop reg, dir, "KV"
        return true
    return false
}

;输入字符串，增加了置顶和非空检测，NOTE 不匹配直接exit
hyf_inputstr(str:="请输入", varDefault:="") {
    SetTimer((p*)=>WinSetAlwaysOnTop(true, "A"), -500)
    oInput := inputbox(str,,,varDefault)
    if (oInput.result=="Cancel" || (oInput.value=="")) {
        msgbox("错误：输入为空",,0x40000)
        exit
    }
    return oInput.value
}

hyf_inputnum(str:="请输入数字", varDefault:="") {
    SetTimer((p*)=>WinSetAlwaysOnTop(true, "A"), -500)
    oInput := inputbox(str,,,varDefault)
    if (oInput.result == "Cancel" || !(oInput.value ~= "^\d+(\.\d+)?$")) {
        msgbox("错误：非数字",,0x40000)
        exit
    }
    return oInput.value
}

;#8::msgbox(hyf_input())
hyf_input(toLow:=false) {
    ih := InputHook()
    ih.VisibleNonText := false
    ih.VisibleText := false
    ih.KeyOpt("{All}", "E")
    ih.start()
    timeSave := A_TickCount
    suspend(true) ;#HotIf HotIfWinActive 优先级更高
    ih.wait() ;. "`n2" . ih.EndKey . "`n1" . ih.EndReason
    if (A_TickCount - timeSave < 200 && ih.EndKey == "LControl") { ;A_MenuMaskKey 会自动发送按键
        ih.start()
        ih.wait()
    }
    suspend(false)
    return toLow ? StrLower(ih.EndKey) . ih.EndMods : ih.EndKey
}

;支持多行的 inputbox
;替换换行符用 StrReplace(sList, "`r`n", ",")
inputboxEX(tips, sDefaluet:="", sTitle:="", bEmpty:=false) {
    nameEdit := "vvv"
    oGui := gui()
    oGui.title := sTitle
    oGui.OnEvent("escape", doEscape)
    oGui.OnEvent("close", doEscape)
    oGui.SetFont("s13")
    oEdit := oGui.AddEdit("w700 R18 section", sDefaluet)
    oText := oGui.AddText("w700", tips)
    oEdit.name := nameEdit
    oGui.SetFont("s23 cRED")
    oGui.AddButton("xs", "确定(&A)").OnEvent("click", btnClick)
    ; oGui.AddButton("xp+300", "取消(&C)").OnEvent("click", btnCancle)
    oGui.show("w800 h600")
    res := oEdit.text
    WinWaitClose(oGui)
    if (!bEmpty && (res == "")) {
        msgbox("错误：为空",,0x40000)
        exit
    }
    return res
    btnClick(ctl, param*) {
        res := ctl.gui[nameEdit].text
        sleep(100)
        oGui.destroy()
    }
    doEscape(oGui, param*) {
        res := ""
        oGui.destroy()
    }
}

/*
arr := [
 ["姓名", "name", "default"],
 ["性别", "gender", ["男","女"]],
 ["年龄", "n|age", "20"],
 ["是否党员", "b|dangyuan", 0],
 ["备注", "2|beizhu", ""],
]
objOpt := hyf_inputOption(arr, "提示")
msgbox(json.stringify(objOpt, 4))
;arr的子数组
;1.提示文字
;2.变量名
;   ①n|则强制为数字
;   ②b|则为是否的 Checkbox
;   ②2|则设置为多行Edit(添加选项 r2)
;3.默认值
;   数组，则为 AddComboBox
;bOne 表示限制单结果，则会在 Edit内容改变时，清空其他控件
;关闭则返回map()
;NOTE 自动过滤空值
*/
hyf_inputOption(arr, sTips:="", bOne:=false) {
    if (type(arr) == "Map") {
        arr1 := arr.clone()
        for k, v in arr1
            arr.push([k,k,v])
    }
    oGui := gui()
    oGui.OnEvent("escape", doEscape)
    oGui.OnEvent("close", doEscape)
    oGui.SetFont("cRed s22")
    if (sTips != "")
        oGui.AddText("x10", sTips . "`n")
    oGui.SetFont("cDefault s13")
    funOpt := (x)=>"ys w400 v" . x
    focusCtl := ""
    for a in arr {
        oGui.AddText("x10 section", a[1])
        if (a.length > 3) ;NOTE 有第4参数，则跳过
            continue
        if (a.length > 2) { ;NOTE 核心判断
            if (instr(a[2], "|")) { ;有选项
                opt := StrSplit(a[2], "|")[1]
                a[2] := StrSplit(a[2], "|")[2]
                if (opt == "n") { ;限制为数字
                    oGui.AddEdit(funOpt(a[2]) . " number", a[3]).OnEvent("change", editChange)
                } else if (opt == "b") { ;boolean
                    oGui.SetFont("cRed")
                    if (a[3])
                        oGui.AddCheckbox(funOpt(a[2]) . " checked", "是")
                    else
                        oGui.AddCheckbox(funOpt(a[2]), "是")
                    oGui.SetFont("cDefault")
                } else if (opt ~= "^\d+$") { ;r2
                    if (a[3] is array)
                        oGui.AddComboBox(format("choose{1} {2}", opt,funOpt(a[2])), a[3])
                    else
                        oGui.AddEdit(format("{1} r{2}", funOpt(a[2]),opt), a[3]).OnEvent("change", editChange)
                }
            } else if (a[3] is array) {
                oGui.AddComboBox(funOpt(a[2]), a[3])
            } else {
                oGui.AddEdit(funOpt.call(a[2]), a[3]).OnEvent("change", editChange)
            }
            if (a.length >= 4)
                focusCtl := a[2]
        } else {
            oGui.AddEdit(funOpt(a[2])).OnEvent("change", editChange)
        }
    }
    oBtn := oGui.AddButton("default center", "确定")
    oBtn.OnEvent("click", btnClick)
    if (focusCtl != "") {
        oGui[focusCtl].focus()
    }
    objRes := map() ;空白值不返回
    objRes.default := ""
    oGui.show()
    WinWaitClose(oGui)
    return objRes
    editChange(ctl, p*) {
        if (bOne) {
            for hwnd, ctlLoop in ctl.gui {
                if (ctlLoop.ClassNN ~= "^Edit\d+$" && hwnd != ctl.hwnd)
                    ctlLoop.text := ""
            }
        }
    }
    btnClick(ctl, p*) {
        ctl.gui.submit
        for k, a in arr {
            try ;有些控件并未生成
                oGui[a[2]]
            catch
                continue
            if (a[2] ~= "^b" || a.length <= 2)
                v := oGui[a[2]].value
            else
                v := oGui[a[2]].text
            if (type(v) == "String")
                v := trim(v) ;TODO 是否trim
            if (v != "")
                objRes[a[2]] :=  v
        }
        oGui.destroy()
    }
    doEscape(oGui, p*) => oGui.destroy()
}

;line
;   _TC.getLineInFile(fp, funLine)
;   reg
hyf_runByVim(fp, line:=0, params:="--remote-tab-silent") { ;用文本编辑器打开
    if (line is integer) {
        if (line)
            params .= " +" . line
    } else {
        if (instr(line, " "))
            line := format('"{1}"', StrReplace(line,'"','\"'))
        params .= format(' +/{1}', line)
        if !(line ~= "\/[+-]\d+$") ;查找内容没有偏移行数，则手工添加/(FIXME 临时方案)
            params .= "/"
    }
    if (ProcessExist("gvim.exe"))
        WinShow("ahk_class Vim")
    sCmd := format('d:\TC\soft\Vim\gvim.exe {1} "{2}"', params, fp)
    OutputDebug(format("i#{1} {2}:vimcmd={3}", A_LineFile,A_LineNumber,sCmd))
    run(sCmd)
    WinWait("ahk_class Vim")
    WinActivate("ahk_class Vim")
    WinWaitActive("ahk_class Vim")
    ;检查多进程 TODO 原因？？
    objPid := map()
    for hwnd in WinGetList("ahk_class Vim")
        objPid[WinGetPID(hwnd)] := 1
    if (objPid.count > 1)
        msgbox("注意：gvim 有两个进程",,0x40000)
}

hyf_runByFirefox(url:="") {
    if (url == "")
        return
    run(format('"s:\Firefox\firefox.exe" "{1}"', url))
}

hyf_runByIE(url:="") { ;关闭当前窗口
    if (url == "")
        return
    run(format('"C:\Program Files\Internet Explorer\iexplore.exe" {1}', url))
    WinWaitActive("ahk_class IEFrame")
}

;arrNoExt 从后向前找第一个匹配的文件路径
;如果是文件夹，找不到就返回空，如果是文件，找不到就返回文件路径
hyf_findFile(dirIn, arrNoExt, ext:="") {
    if (DirExist(dirIn)) {
        dir := dirIn
        res := ""
    } else {
        SplitPath(dirIn,, &dir)
        res := dirIn
    }
    ;msgbox(FileExist(dirIn) . "`n" . dir . "`n" . dirIn)
    if (ext == "") ;FIXME
        return res
    if (!isobject(arrNoExt))
        arrNoExt := [arrNoExt]
    loop(arrNoExt.length) {
        fp := findPath(arrNoExt[-A_Index]) ;NOTE 从后向前遍历
        if (fp != "")
            return fp
    }
    return res
    findPath(noExt) {
        ;先在子文件夹中找？
        loop files, format("{1}\*", dir), "D" { ;明确的文件名，则只遍历文件夹，NOTE 不能有多文件
            if (ext == "*") {
                loop files, format("{1}\{2}.{3}", A_LoopFileFullPath,noExt,ext) ;明确的文件名，则只遍历文件夹，NOTE 不能有多文件
                    return A_LoopFileFullPath
            } else {
                fp := format("{1}\{2}.{3}", A_LoopFileFullPath,noExt,ext)
                if (FileExist(fp))
                    return fp
            }
        }
        ;在主目录中找
        if (FileExist(format("{1}\{2}.{3}", dir,noExt,ext)))
            return format("{1}\{2}.{3}", dir,noExt,ext)
    }
}

;hyf_findCtrl(funCtlTrue, winTitle:="") {
;    try
;        arr := WinGetControls(winTitle)
;    catch
;        return
;    for ctlName in arr {
;        if funCtlTrue.call(ctlName)
;            return ctlName
;    }
;}

;-----------------------------------calc-----------------------------------
eval(str) {
    oSC := ComObject("ScriptControl")
    oSC.Language := "VBScript" ;"JavaScript"
    return oSC.eval(str)
}

hyf_md5(fp, cSz:=4) { ;获取文件md5值
    cSz := (cSz<0||cSz>8) ? 2**22 : 2**(18+cSz)
    Buffer := buffer(cSz,0)
    hFil := dllcall("CreateFile", "str",fp, "uint",0x80000000, "int",3, "int",0, "int",3, "int",0, "int",0)
    if (hFil < 1)
        return hFil
    hMod := dllcall("LoadLibrary", "str","advapi32.dll")
    dllcall("GetFileSizeEx", "uint",hFil, "uint",&Buffer)
    fSz := numget(Buffer, 0, "int64")
    MD5_CTX := buffer(104, 0)
    dllcall("advapi32\MD5Init", "uint",&MD5_CTX)
    loop(fSz//cSz + !!mod(fSz,cSz)) {
        dllcall("ReadFile", "uint",hFil, "uint",&Buffer, "uint",cSz, "uint*",&bytesRead:=0, "uint",0)
        dllcall("advapi32\MD5Update", "uint",&MD5_CTX, "uint",&Buffer, "uint",bytesRead)
    }
    dllcall("advapi32\MD5Final", "uint",&MD5_CTX)
    dllcall("CloseHandle", "uint",hFil)
    hex := "123456789ABCDEF0"
    res := ""
    loop(16) {
        num := numget(MD5_CTX, 87+A_Index, "char")
        p1 := mod((num>>4)+15,16) + 1
        p2 := mod((num&15)+15,16) + 1
        res .= substr(hex,p1,1) . substr(hex,p2,1)
    }
    dllcall( "FreeLibrary", "uint",hMod )
    return res
}

;nf为设置 NumberFormat
hyf_sum(arr*) {
    res := 0
    for v in arr
        res += v
    return res
}

hyf_average(arr*) {
    res := 0
    for v in arr
        res += v
    return round(res/arr.length, 2)
}

;1-n默认对4求余，结果为1230循环，而我们往往需要0-3或1-4
hyf_mod(n, m) => mod(n-1, m)+1

;求整除(1-10整数10，结果为1，11才为1)
hyf_div(n, m) => ((n-1) // m)+1

;最小公倍数
hyf_zxgbs(num*) {
    nMax := max(num*)
    loop {
        n := nMax * A_Index
        for k, v in num {
            if (mod(n, v) != 0)
                continue 2
        }
        return n
    }
}

;最大公约数
hyf_zdgys(num*) {
    nMin := min(num*)
    loop((nMin-1)) {
        n := nMin - A_Index + 1
        for k, v in num {
            if (mod(v, n) != 0)
                continue 2
        }
        return n
    }
}

;-----------------------------------Windows__-----------------------------------

;TODO 睡眠后恢复，是否 oInput 还会存在。
hyf_onekeyHide() {
    static oInput
    regSound := "sound"
    send("{LWin down}d{LWin up}")
    DetectHiddenWindows(false)
    if (WinExist("ahk_class Shell_TrayWnd")) {
        tooltip("hide")
        hideGeneral()
        WinHide("ahk_class Shell_TrayWnd")
        BlockInput("MouseMove")
        ;SystemCursor(false)
        oInput := InputHook()
        oInput.VisibleNonText := false
        oInput.VisibleText := false
        ;oInput.KeyOpt("{All}")
        oInput.start()
        ;其他动作
        RegWrite(round(SoundGetVolume()), "REG_SZ", "HKEY_CURRENT_USER\hy", regSound)
        SoundSetVolume(0)
        PostMessage(WM_SYSCOMMAND:=0x112, 0xF170, 2,, "Program Manager")
    } else {
        tooltip("nohide")
        WinShow("ahk_class Shell_TrayWnd")
        BlockInput("MouseMoveOff")
        MouseMove(A_ScreenWidth/2, A_ScreenHeight/2, 0)
        ;SystemCursor(true)
        try
            oInput.stop()
        catch
            reload
        if (soundSave := RegRead("HKEY_CURRENT_USER\hy", regSound)) {
            SoundSetVolume(soundSave)
            RegWrite(0, "REG_SZ", "HKEY_CURRENT_USER\hy", regSound)
        }
    }
    SetTimer(tooltip, -1000)
    SystemCursor(bShow:=0) {
        static c := map()
        if (!c.count) {
            for id in [32512,32513,32514,32515,32516,32642,32643,32644,32645,32646,32648,32649,32650] {
                h_cursor := dllcall("LoadCursor", "ptr",0, "ptr",id)
                c[id] := [
                    dllcall("CreateCursor", "ptr",0, "int",0, "int",0, "int",32, "int",32, "ptr",buffer(32*4,0xFF), "ptr",buffer(32*4,0)),
                    dllcall("CopyImage", "ptr",h_cursor, "uint",2, "int",0, "int",0, "uint",0),
                ]
            }
        }
        for id, arr in c {
            h_cursor := dllcall("CopyImage", "ptr",arr[bShow+1], "uint",2, "int",0, "int",0, "uint",0)
            dllcall("SetSystemCursor", "ptr",h_cursor, "uint",id)
        }
    }
    hideGeneral() {
        arrWinTitle := [
            "Clash for Windows ahk_class Chrome_WidgetWin_1",
            "ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe",
            "ahk_class Vim",
        ]
        for winTitle in arrWinTitle {
            if (WinExist(winTitle))
                WinHide
        }
    }
}

hyf_getDocumentPath(winTitle:="") { ;获取当前窗口编辑文档的路径
    exeName := StrLower(WinGetProcessName(winTitle))
    exeName := RegExReplace(exeName, "\.exe$")
    switch exeName {
    case "gvim": return WinGetTitle(winTitle)
    case "ithought": return WinGetTitle(winTitle)
    case "excel": return ox().ActiveWorkbook.fullname
    case "winword": return ComObjActive("Word.application").ActiveDocument.fullname
    case "powerpnt": return ComObjActive("Powerpoint.application").ActivePresentation.fullname
    case "hh.exe": return getDocPathOfHH(winTitle)
    default:
        if (RegExMatch(substr(getCommandLine(winTitle), 4), "[a-zA-Z]:[^:]+$", &m))
            return m[0]
    }
    getCommandLine(winTitle:="") {
        for item in ComObjGet("winmgmts:").ExecQuery(format("Select * from Win32_Process where ProcessId={1}", WinGetPID(winTitle)))
            return item.CommandLine
    }
    ;comcall 简化了下面3行
    ;if !dllcall(numget(numget(0,pobj,"UPtr"), 0, "UPtr"), "Ptr",pobj, "Ptr",PID, "Ptr*",&psp:=0)
    ;   && !dllcall(numget(numget(0,psp,"UPtr"),A_PtrSize*3,"UPtr"), "Ptr",psp, "Ptr",Query_Guid4String(&SID,SID), "Ptr",IID=="!"?SID:Query_Guid4String(&IID,IID), "Ptr*",&pobj:=0) {
    ;   dllcall(numget(numget(0,psp,"UPtr"),A_PtrSize*2,"UPtr"), "Ptr",psp)
    getDocPathOfHH(winTitle:="") {
        ctl := ControlGetHwnd("Internet Explorer_Server1", winTitle)
        dllcall("LoadLibrary", "Str","oleacc", "Ptr")
        numput('int64',0x11CF3C3D618736E0, 'int64',0x719B3800AA000C81, IID:=buffer(16))
        if (!dllcall("oleacc\AccessibleObjectFromWindow", "ptr",ctl, "uint",0, "ptr",IID, "ptr*",&pacc:=0)) {
            accWin := ComValue(9, pacc, 1)
            chmPath := Query_Service(accWin, "{332C4427-26CB-11D0-B483-00C04FD90119}").document.url
            chmPath := RegExReplace(chmPath, "im)mk\:\@MSITStore\:(.*)\:\:.*$", "$1")
            chmPath := StrReplace(chmPath, "%20", " ")
            return chmPath
        }
        ;没单独放起来，可能有重复
        Query_Service(pobj, SID, IID:="!", bRaw:="") {
            if (isobject(pobj))
                pobj := ComObjValue(pobj)
            numput('int64',0x11CE74366D5140C1, 'int64',0xFA096000AA003480, pid:=buffer(16))
            res0 := comcall(0, pobj, "Ptr",pid, "Ptr*",&psp:=0)
            res3 := comcall(3, psp, "Ptr",Query_Guid4String(&SID, SID), "Ptr",IID=="!"?SID:Query_Guid4String(&IID,IID), "Ptr*",&pobj:=0)
            if (!res0 && !res3 || ObjRelease(psp)) {
                if (bRaw)
                    return pobj
                else
                    return ComValue(9, pobj, 1)
            }
        }
        Query_Guid4String(&GUID, sz:="") {
            dllcall("ole32\CLSIDFromString", "WStr",sz?sz:sz==""?"{00020400-0000-0000-C000-000000000046}":"{00000000-0000-0000-C000-000000000046}", "Ptr",GUID:=buffer(16,0))
            return GUID
        }
    }
}

;funHwnd 处理 hwnd 为 true 则添加
;hyf_hwnds("ahk_exe a.exe", (p)=>substr(WinGetClass(p"),1,4) == "Afx:")[1]
;hyf_hwnds("ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe")
hyf_hwnds(winTitle, funHwnd:="") {
    saveDetect := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    arr := []
    for hwnd in WinGetList(winTitle) {
        try
            titleLoop := WinGetTitle(hwnd)
        catch
            continue
        if (isobject(funHwnd)) {
            if (funHwnd.call(hwnd))
                arr.push(hwnd)
        } else if (instr(winTitle, "ahk_class")) {
            if (titleLoop ~= "\S") ;指定了 ahk_class 则非空标题就添加
                arr.push(hwnd)
        } else {
            arr.push(hwnd)
        }
    }
    DetectHiddenWindows(saveDetect)
    return arr
}

hyf_showWin(winTitle) {
    hwnd := WinExist(winTitle)
    obj := map(
        "title", WinGetTitle(),
        "class", WinGetClass(),
        "hwnd", hwnd,
    )
    return obj
}

;获取单个窗口的pid用 WinGetPID 或 ProcessExist
;hyf_pidList("chrome.exe")
;https://docs.microsoft.com/zh-cn/windows/win32/cimwin32prov/win32-process
hyf_pids(exeName) {
    arr := []
    for item in ComObjGet("winmgmts:").ExecQuery(format("select ProcessId,name from Win32_Process where name='{1}'", exeName))
        arr.push(item["ProcessId"])
    return arr
}

;if (!instr(DriveGetList(), "w"))
;   _Windows.vhdxLoad()
hyf_vhdxLoad(arrVhdx) {
    for arr in arrVhdx {
        if (!instr(DriveGetList(), arr[1])) {
            run(arr[2])
            WinWait("ahk_class CabinetWClass ahk_exe explorer.exe")
            try
                WinClose
            if (WinExist("新通知 ahk_class Windows.UI.Core.CoreWindow"))
                WinClose
        }
    }
}

;如果失败，可能是被应用程序占用，用 this.getPowershell("Get-WinEvent @map(logname='application','system';starttime=[datetime],,today;id=225) | select logname, timecreated, id, message")
hyf_removeUSB(bUPan:=true) { ;移除U盘
    u := DriveGetList("REMOVABLE") ;获取U盘盘符
    if (strlen(u) > 1) { ;删除 NotReady 的盘符
        res := ""
        loop parse, u {
            if (DriveGetStatus(A_LoopField . ":\") == "Ready")
                res .= A_LoopField
        }
        u := res
    }
    l := strlen(u)
    if (!l) {
        arr := hardList()
        if (arr.length) {
            return (eject("u") == 1) ;TODO 如何获取移动硬盘盘符
        } else {
            tooltip("没找到U盘")
            SetTimer(tooltip, -1000)
        }
        return
    }
    if (l == 1) { ;只有一个U盘则直接删除U盘
        return (eject(u) == 1)
    } else {
        tooltip(res)
        SetTimer(tooltip, -3000)
        return false
    }
    hardList() {
        sql := "select * from Win32_DiskDrive where MediaType='External hard disk media'"
        return ComObjGet("winmgmts:").ExecQuery(sql).count ? [1] : []
    }
    ; https://www.autohotkey.com/boards/viewtopic.php?f=83&t=94113
    ; https://www.autohotkey.com/boards/search.php?keywords=&terms=all&author=SKAN&fid%5B%5D=83&sc=0&sf=firstpost&sr=topics&sk=t&sd=d&st=0&ch=0&t=0&submit=Search
    eject(drv, bCheck:=0, bEject:=1) {
        drv := substr(drv, 1, 1)
        ;1. CreateFile
        hVolume := dllcall("CreateFile", "Str",format("\\.\{1}:",drv), "int",0 ,"int",0, "Ptr",0, "int",OPEN_EXISTING:=3, "int",0, "ptr",0, "ptr")
        if (hVolume == -1 )
            return drv . " error"
        ;2. DEVICE_NUMBER
        DEVICE_NUMBER := IOCTL_STORAGE_GET_DEVICE_NUMBER(hVolume)
        dllcall("CloseHandle", "ptr",hVolume)
        ; https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-diskdrive
        sql := format("select * from Win32_DiskDrive where DeviceID='\\\\.\\PHYSICALDRIVE{1}'", DEVICE_NUMBER)
        ComObjGet("winmgmts:").ExecQuery(sql)._NewEnum()(&DiskDrive)
        if (!bEject)
            return "needn't"
        if (bCheck) {
            res := CheckMediaType(DiskDrive.MediaType)
            if res
                return res
        }
        ;3. do
        hSetupApi := dllcall("LoadLibrary", "Str","SetupAPI.dll", "ptr")
        dllcall("SetupAPI\CM_Locate_DevNode", "ptr*",&nDeviceID:=0, "Str",DiskDrive.PNPDeviceID, "int",0)
        dllcall("SetupAPI\CM_Get_Parent", "ptr*",&nDeviceID, "uint",nDeviceID, "int",0)
        if dllcall("SetupAPI\CM_Request_Device_Eject" ,"uint",nDeviceID, "Ptr*",&nVetoType:=0, "str",nVetoType, "int",1, "int",0) {
            dllcall("Kernel32.dll\FreeLibrary", "ptr",hSetupApi)
            return [
                "PNP_VetoTypeUnknown`nThe specified operation was rejected for an unknown reason.",
                "PNP_VetoLegacyDevice`nThe device does not support the specified PnP operation.",
                "PNP_VetoPendingClose`nThe specified operation cannot be completed because of a pending close operation.",
                "PNP_VetoWindowsApp`nA Microsoft Win32 application vetoed the specified operation.",
                "PNP_VetoWindowsService`nA Win32 service vetoed the specified operation.",
                "PNP_VetoOutstandingOpen`nThe requested operation was rejected because of outstanding open handles.",
                "PNP_VetoDevice`nThe device supports the specified operation, but the device rejected the operation.",
                "PNP_VetoDriver`nThe driver supports the specified operation, but the driver rejected the operation.",
                "PNP_VetoIllegalDeviceRequest`nThe device does not support the specified operation.",
                "PNP_VetoInsufficientPower`nThere is insufficient power to perform the requested operation.",
                "PNP_VetoNonDisableable`nThe device cannot be disabled.",
                "PNP_VetoLegacyDriver`nThe driver does not support the specified PnP operation.",
                "PNP_VetoInsufficientRights`nThe caller has insufficient privileges to complete the operation.",
                "PNP_VetoAlreadyRemoved`nThe device has been already removed"][nVetoType]
        }
        dllcall("Kernel32.dll\FreeLibrary", "ptr",hSetupApi)
        return true
        IOCTL_STORAGE_GET_DEVICE_NUMBER(hDevice) {
            STORAGE_DEVICE_NUMBER := buffer(12, 0)
            dllcall("DeviceIoControl", "Ptr",hDevice, "uint",0x2D1080, "int",0, "int",0, "ptr",STORAGE_DEVICE_NUMBER, "int",12, "ptr*",0, "ptr",0)
            return numget(STORAGE_DEVICE_NUMBER, 4, "uint")
        } 
        CheckMediaType(MT) {
            switch MT {
                case "Removable Media", "External hard disk media":  return
                case "Fixed hard disk media":                        return(MT)
                default:                                             return("Media type Unknown")
            }
        }
    }
}

;NOTE 实现从其他脚本比如 python 获取结果
;执行cmd命令并获取返回结果 TODO 少部分内容会编码错误
;原函数名 StdOutStream https://autohotkey.com/board/topic/96903-simplified-versions-of-seans-stdouttovar/
;callback第1个参数是循环序号，第2个参数是循环的值，结束后最后一次调用，第1个参数=0，第2个参数为所有值
;其他相关网址
; https://autohotkey.com/board/topic/7874-cmdret-ahk-functions/
; https://autohotkey.com/board/topic/15455-stdouttovar/
; https://autohotkey.com/board/topic/3489-cmdret-return-output-from-console-progs-dll-version/
;run帮助也有此类方法(不完善)
;示例
;msgbox(hyf_cmd("ping www.taobao.com", StdOutStream_Callback))
;StdOutStream_Callback(idx, data) {
;   static str
;   if idx
;      tooltip(str .= data)
;   else {
;       str := ""
;       tooltip
;       return data
;   }
;}
; https://www.autohotkey.com/boards/viewtopic.php?t=93944
hyf_cmd(strCode, callback:="", encode:="CP936") { ;  GAHK32 ; Modified version : SKAN 05-Jul-2013  http://goo.gl/j8XJXY
    ; https://docs.microsoft.com/en-us/windows/win32/api/namedpipeapi/nf-namedpipeapi-createpipe
    dllcall("CreatePipe", "ptr*",&hStdInRd:=0, "ptr*",&hStdInWr:=0, "UInt",0, "UInt",0)
    ; https://docs.microsoft.com/en-us/windows/win32/api/handleapi/nf-handleapi-sethandleinformation
    dllcall("SetHandleInformation", "ptr",hStdInWr, "UInt",1, "UInt",1)
    ; https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-startupinfow
    STARTUPINFO := buffer(32+A_PtrSize*9, 0)
    numput("UInt", STARTUPINFO.size, STARTUPINFO) ; cbSize
    numput("UInt", STARTF_USESTDHANDLES:=0x100, STARTUPINFO, 28+A_PtrSize*4) ; dwFlags 44 60
    numput("ptr", hStdInWr, STARTUPINFO, 32+A_PtrSize*7) ; hStdOutput
    numput("ptr", hStdInWr, STARTUPINFO, 32+A_PtrSize*8) ; hStdError
    ; https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-process_information
    PROCESS_INFORMATION := buffer(8 + A_PtrSize*2)
    ; https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessa
    if !dllcall("CreateProcess", "ptr",0, "str",strCode, "ptr",0, "ptr",0, "UInt",true, "UInt",0x08000000 | dllcall("GetPriorityClass", "Ptr",-1, "UInt"), "ptr",0, "ptr",0, "ptr",STARTUPINFO, "ptr",PROCESS_INFORMATION) {
        dllcall("CloseHandle", "ptr",hStdInWr)
        dllcall("CloseHandle", "ptr",hStdInRd)
        dllcall("SetLastError", "int",-1)
        return ""
    }
    hProcess := numget(PROCESS_INFORMATION, 0, "ptr")
    hThread := numget(PROCESS_INFORMATION, A_PtrSize, "ptr")
    dllcall("CloseHandle", "UInt",hStdInWr)
    oBuf := buffer(4096, 0)
    nSz := 0
    sRes := ""
    ; https://docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-readfile
    while (dllcall("ReadFile", "ptr",hStdInRd, "ptr",oBuf, "UInt",4094, "ptr*",&nSz:=0, "ptr",0)) {
        sThis := strget(oBuf, nSz, encode)
        sRes .= sThis
        if (isobject(callback))
            callback.call(A_Index, sThis)
    }
    ; https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getexitcodeprocess
    dllcall("GetExitCodeProcess", "ptr",hProcess, "ptr*",&ExitCode:=0)
    dllcall("CloseHandle", "ptr",hProcess )
    dllcall("CloseHandle", "ptr",hThread  )
    dllcall("CloseHandle", "ptr",hStdInRd)
    dllcall("SetLastError", "UInt",ExitCode)
    return isobject(callback) ? callback.call(0,sRes) : sRes
}

hyf_powershell(cmd) => hyf_cmd(format("PowerShell -Command `"& {{1}}`"", cmd))

;msgbox(_Web.isPing("50.1"))
hyf_isPing(ip, ms:=200) {
    ip := ipCreate(ip)
    res := hyf_cmd(format("ping {1} -n 1 -w {2}", ip,ms))
    return !!instr(res, " TTL=")
    ;ip地址生成
    ipCreate(str, _ip:="192.168.1.1") {
        arr := StrSplit(str, ".")
        arrBase := StrSplit(_ip, ".")
        loop(arr.length)
            arrBase[-A_Index] := arr[-A_Index]
        res := ""
        for v in arrBase
            res .= v . "."
        return rtrim(res, ".")
    }
}

;funRegname(reg) 为 true 则返回
hyf_isInstalled(funRegname) {
    arr := [
        "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    ]
    for k, v in arr {
        loop reg, v, "K" {
            if (funRegname.call(A_LoopRegName))
                return true
        }
    }
}

;-----------------------------------Excel__-----------------------------------

ox(winTitle:="ahk_class XLMAIN") {
    if (WinExist(winTitle))
        ctlID := ControlGetHwnd("EXCEL71")
    else
        return ComObject("Excel.application")
    numput('Int64',0x20400, 'Int64',0x46000000000000C0, IID_IDispatch:=buffer(16))
    dllcall("oleacc\AccessibleObjectFromWindow", "ptr",ctlID, "uint",0xFFFFFFF0, "ptr",IID_IDispatch, "ptr*",win:=ComValue(9,0), 'HRESULT')
    loop {
        try
            return win.application
        catch
            ControlSend("{escape}", "EXCEL71")
    }
}

;普通数组转VBA标准数组
;一维时，如果 toRows 则转成多行
;二维时，如果 toRows 则列数要通过arr[1]遍历获得
hyf_arr2arrayA(arr, toRows:=false) {
    if (!arr.length)
        return
    rs := arr.length
    if (isobject(arr[1])) {
        ;获取列数 cs
        cs := 0
        if (toRows) {
            if (toRows > 1) ;直接当列数
                cs := toRows
            else {
                for v in arr {
                    if (v.length > cs)
                        cs := v.length
                }
            }
        } else
            cs := arr[1].length
        arrA := ComObjArray(12, rs, cs)
        loop(rs) {
            i := A_Index
            loop(cs)
                arrA[i-1,A_Index-1] := arr[i][A_Index]
        }
    } else { ;单维
        if (toRows) {
            arrA := ComObjArray(12, rs, 1)
            loop(rs)
                arrA[A_Index-1,0] := arr[A_Index]
        } else {
            arrA := ComObjArray(12, rs)
            loop(rs)
                arrA[A_Index-1] := arr[A_Index]
        }
    }
    return arrA
}

;普通数组转VBA标准数组
;一维时，如果 toRows 则转成多行
hyf_arr2cell(arr, cell:="", toRows:=false) {
    if (!isobject(cell))
        cell := ox().ActiveCell
    hyf_arrayA2cell(hyf_arr2arrayA(arr, toRows), cell)
}

;nf为设置 NumberFormat
hyf_arrayA2cell(arrA, cell, nf:="") {
    rng := cell.resize(arrA.MaxIndex(1)+1,arrA.MaxIndex(2)+1)
    if (nf != "")
        rng.NumberFormat := nf
    rng.value := arrA
}

hyf_getWorkbook(fp, bActive:=false) {
    ;wb
    if (isobject(fp))
        return fp
    ;已打开
    SplitPath(fp, &fn)
    for hwnd in WinGetList("ahk_class XLMAIN") { ;可能有多个Excel进程
        xl := ox(hwnd)
        try { ;可能是进程残留
            for wb in xl.workbooks {
                SplitPath(wb.name,,,, &noExt)
                if (wb.name = fn || noExt = fn) { ;为什么要 noExt？
                    if (bActive)
                        WinActivate(hwnd)
                    return wb
                }
            }
        }
    }
    ;打开文件
    ; tooltip("正在打开文件`n" . fp)
    wb := ComObject("Excel.application").workbooks.open(fp)
    if (bActive) {
        wb.parent.visible := -1
        WinWait(wb.application)
        WinActivate(wb.application)
        tooltip
    }
    return wb
}

;获取类|实例的所有方法和属性
;名称参考python
;hyf_dir(_Excel, (p)=>p~="^__")
hyf_dir(cls, funFilter:="", bShowValue:=false) {
    ;if (type(cls) != "Class")
    ;    return []
    if (type(cls) == "Class" && !isobject(funFilter)) {
        if (cls.prototype.__class == "_TC")
            funFilter := (p)=>p~="^(__|cm_)"
        else
            funFilter := (p)=>p~="^(__)"
    }
    if (!isobject(funFilter))
        funFilter := (p)=>p~="^(__)"
    arr := []
    ;类则包含所有，实例只有属性
    for prop in cls.OwnProps() {
        if (!funFilter(prop))
            pushProp(prop)
    }
    for prop in cls.base.OwnProps() {
        if (!funFilter(prop))
            pushProp(prop)
    }
    ;实例添加方法
    if (type(cls) != "Class") {
        for method in cls.base.OwnProps() {
            if (!funFilter(method))
                pushMethod(method)
        }
    }
    return arr
    pushProp(prop) {
        if (bShowValue)
            arr.push([prop, cls.%prop%])
        else
            arr.push(prop)
    }
    pushMethod(method) {
        if (bShowValue)
            arr.push([method, cls.%method%()])
        else
            arr.push(method)
    }
}

;获取类|实例的所有属性和值
hyf_objProps(cls, funFilter:="") {
    obj := []
    for prop in cls.OwnProps() {
        try
            obj[prop] := cls.%prop%
    }
    return obj
}

/* Function: UUIDCreate
*     Generate UUID using Rpcrt4\UuidCreate[Sequential/Nil]
* License:
*     WTFPL [http://wtfpl.net/]
* Syntax:
*     sUUID := UUIDCreate( [ mode := 1 , format := "" , &UUID := "" ] )
* Parameter(s):
*     sUUID     [retval] - UUID (string)
*     mode     [in, opt] - Defaults to one(1) which uses 'Rpcrt4\UuidCreate',
*                          otherwise specify two(2) for 'UuidCreateSequential'
*                          or zero(0) for 'UuidCreateNil'.
*     format   [in, opt] - if 'format' contains an opening brace('{'), output
*                          will be wrapped in braces. Include the letter 'U' to
*                          convert output to uppercase. default is blank.
*     UUID  [ByRef, opt] - Pass this parameter if you need the raw UUID
*/
UUIDCreate(mode:=1, format:="", &UUID:="") {
    UuidCreate := "Rpcrt4\UuidCreate"
    if (instr("02", mode))
        UuidCreate .= mode ? "Sequential" : "Nil"
    UUID := buffer(16, 0) ;// long(UInt) + 2*UShort + 8*UChar
    if (dllcall(UuidCreate, "ptr",&UUID) == 0)
        && (dllcall("Rpcrt4\UuidToString", "ptr",&UUID, "uint*",&pString:=0) == 0) {
        string := strget(pString)
        dllcall("Rpcrt4\RpcStringFree", "uint*",&pString:=0)
        if (instr(format, "U"))
            dllcall("CharUpper", "ptr",&string)
        return instr(format, "{") ? "{" . string . "}" : string
    }
    ;方法2：慢
    ;shellobj := ComObject("Scriptlet.TypeLib")
    ;ret := shellobj.GUID
    ;uuid := RegExReplace(ret,"(\{|\}|-)","")
    ;;msgbox(ret . "`n" . uuid)
    ;return uuid
}

;转成没层级的数组，只包含key和val
hyjson2arr(obj, mark:=1) {
    arr := []
    for k, v in obj {
        if (v["key"] == "") ;首先过滤key为空的 NOTE
            continue
        if (v.has("sub") && isobject(v["sub"])) { ;为目录
            for v in hyjson2arr(v["sub"], 0)
                arr.push(v)
        } else {
            arr.push([v["key"], v["val"]])
        }
    }
    return arr
}

;运行ahk脚本
;hyf_pipeRun('strlen("abc")')
;hyf_pipeRun('msgbox(1)')
;WM_COPYDATA_send("aaa")
;TODO  "`n`n" 这种字符串不兼容
;也可见 DynaRun.ahk https://www.autohotkey.com/board/topic/56141-ahkv2-dynarun-run-autohotkey-process-dynamically
;来源 run 的帮助文件
hyf_pipeRun(code, fn:="", callback:=0) {
    if (fn == "")
        fn := A_ScriptDir
    if (callback) {
        CopyOfData := ""
        OnMessage(0x4a, (p*)=>Receive_WM_COPYDATA(p*))
        strCode := "
        (
            #SingleInstance force
            WM_COPYDATA_send(StringToSend, TargetScriptTitle) {
                CopyDataStruct := Buffer(3*A_PtrSize)  ; 分配结构的内存区域.
                ; 首先设置结构的 cbData 成员为字符串的大小, 包括它的零终止符:
                SizeInBytes := (StrLen(StringToSend) + 1) * 2
                NumPut( "Ptr", SizeInBytes  ; 操作系统要求这个需要完成.
                      , "Ptr", StrPtr(StringToSend)  ; 设置 lpData 为到字符串自身的指针.
                      , CopyDataStruct, A_PtrSize)
                Prev_DetectHiddenWindows := A_DetectHiddenWindows
                Prev_TitleMatchMode := A_TitleMatchMode
                DetectHiddenWindows True
                SetTitleMatchMode 2
                TimeOutTime := 4000  ; 可选的. 等待 receiver.ahk 响应的毫秒数. 默认是 5000
                ; 必须使用发送 SendMessage 而不是投递 PostMessage.
                RetValue := SendMessage(0x4a, 0, CopyDataStruct,, TargetScriptTitle,,,, TimeOutTime) ; 0x4a 是 WM_COPYDATA.
                DetectHiddenWindows Prev_DetectHiddenWindows  ; 恢复调用者原来的设置.
                SetTitleMatchMode Prev_TitleMatchMode         ; 同样.
                return RetValue  ; 返回 SendMessage 的回复给我们的调用者.
            }
        )"
        strCode .= format('`nWM_COPYDATA_send(string({1}), "{2}")', code,fn)
    } else {
        strCode := format('#SingleInstance Force`n#NoTrayIcon`n{1}', code)
    }
    shell := ComObject("WScript.Shell")
    oExec := shell.exec(A_AhkPath . " *")
    oExec.StdIn.write(strCode)
    oExec.StdIn.close()
    if (callback) {
        while (CopyOfData == "") ;NOTE 等待
            sleep(100)
        return CopyOfData
    }
    Receive_WM_COPYDATA(wParam, lParam, msg, hwnd) {
        StringAddress := numget(lParam, 2*A_PtrSize, "Ptr")  ; 检索 CopyDataStruct 的 lpData 成员.
        CopyOfData := strget(StringAddress)  ; 从结构中复制字符串.
        ;ToolTip A_ScriptName "`nReceived the following string:`n" CopyOfData
        return true  ;  返回 1(true) 是回复此消息的传统方式.
    }
}

;去重或生成拼音都是根据 subArr[indexKey]
;indexKey 主值在 subArr 的序号(不能重复，否则返回结果有问题)
;bAddPy 是否添加拼音
;bDistinct 是否去重
;返回 subArr
hyf_selectByArr(arr2, indexKey:=1, bAddPy:=false, bDistinct:=false) {
    if (!arr2.length)
        return []
    arrNew := [] ;防止修改原数组
    ;1. arrNew 转成二维，NOTE 并在每项末尾添加 A_Index
    if (!isobject(arr2[1])) {
        for v in arr2
            arrNew.push([v, A_Index])
    } else {
        for subArr in arr2 {
            subArr.push(A_Index)
            arrNew.push(subArr)
        }
    }
    ;   去重(根据 subArr[1])
    if (bDistinct)
        arrNew := arrNew.filter2((v,k)=>v[indexKey]!="", (v,k)=>v[indexKey])
    ;记录 objRaw 最终返回用(因为有些对象不会在 ListView 显示)
    objRaw := map()
    for subArr in arrNew
        objRaw[subArr[indexKey]] := subArr
    ;添加标题
    arrField := ["序号"]
    loop(arrNew[1].length)
        arrField.push("v" . string(A_Index))
    ;添加拼音
    if (bAddPy) {
        arrField.push("拼音")
        sFile := fileread("d:\BB\lib\汉字拼音对照表.txt", "utf-8")
        for arr in arrNew
            arr.push(pinyin(arr[indexKey]))
    }
    ;OutputDebug(format("i#{1} {2}:arrNew={3}", A_LineFile,A_LineNumber,arrNew.toTable(",")))
    ;添加到 Gui
    oGui := gui("+resize")
    oGui.OnEvent("escape",doEscape)
    oGui.OnEvent("close",doEscape)
    oGui.SetFont("s13")
    oGui.add("Text",,"按 F1-F12 或【双击】可直接确定对应条目")
    oEdit := oGui.add("Edit", "Lowercase section")
    oEdit.OnEvent("change", loadLV)
    oCB1 := oGui.Add("Checkbox", "yp checked", arrField[2])
    ;添加按键显示结果(点击复制)
    oButton1 := oGui.add("button", "w200 xs cRed")
    oButton1.OnEvent("click", (ctl, p*)=>A_Clipboard := ctl.text)
    if (arrNew[1].length > 2) {
        oButton2 := oGui.add("button", "w500 yp xp+300 cRed")
        oButton2.OnEvent("click", (ctl, p*)=>A_Clipboard := ctl.text)
    }
    ;ListView 标题名
    ;field := 65
    oLv := oGui.AddListView("vlv1 xs r20 cRed w1400", arrField) ;NOTE selectN 要用 lv1 获取控件，不要用 oLv(影响释放)
    oLv.OnEvent("DoubleClick", do)
    oLv.OnEvent("ItemFocus", tips)
    tooltip("加载数据...")
    timeSave := A_TickCount
    obj := ""
    nLoad := A_TickCount - timeSave
    tooltip("添加到Gui...")
    loadLV(oEdit)
    nGui := A_TickCount - timeSave - nLoad
    tooltip
    oGui.title := format("读取耗时 {1} 加载到Gui耗时 {2}", nLoad,nGui)
    oGui.show()
    WinWaitActive(oGui)
    ctl := ControlGetFocus(oGui) || WinGetID()
    PostMessage(0x50,, dllcall("LoadKeyboardLayout", "str","04090409", "uint",1), ctl)
    resGui := []
    OnMessage(0x100, selectN)
    WinWaitClose(oGui)
    return resGui
    doEscape(oGui, p*) {
        OnMessage(0x100, selectN, 0)
        oGui.destroy()
    }
    loadLV(ctl, p*) { ;中文则搜索第1个内容，否则搜索第2个内容
        oLv.delete()
        oLv.opt("-Redraw")
        ;获取匹配项
        ;if (oCB1.value == "")
        ;    return
        sInput := ctl.text
        ;NOTE 获取匹配的 idxMatch
        idxMatch := (bAddPy && sInput ~= "[[:ascii:]]") ? -1 : 1
        i := 1
        ;OutputDebug(format("i#{1} {2}:sInput={3} idxMatch={4}", A_LineFile,A_LineNumber,sInput,idxMatch))
        for subArr in arrNew {
            if (sInput=="" || instr(subArr[idxMatch], sInput)) {
                ;OutputDebug(format("i#{1} {2}:subArr={3}", A_LineFile,A_LineNumber,json.stringify(subArr)))
                oLv.add(, i++, subArr*)
            }
        }
        ;搜网址有用没结果且只搜索标题，则搜索网址
        ;if (oLv.GetCount() == 0) {
        ;    for subArr in arrNew {
        ;        if (instr(subArr[2], sInput))
        ;            oLv.add(, i++, subArr[1], subArr[2], subArr[3])
        ;    }
        ;}
        oLv.ModifyCol()
        oLv.ModifyCol(1, "48")
        oLv.opt("+Redraw")
        if (oLv.GetCount() == 1) { ;单结果
            do(oLv, 1)
        } else if (oLv.GetCount() > 1) {
            oLv.modify(1, "+select")
            tips(oLv, 1)
        }
    }
    selectN(wParam, lParam, msg, hwnd) { ;NOTE 由于这个函数不传入oGui或oControl，要用 hwnd获取oGui，用oGui[ctlNmae]获取控件
        try
            oLv := GuiFromHwnd(hwnd, 1)["lv1"] ;NOTE
        catch
            return
        if (wParam == 13) { ;enter
            do(oLv, oLv.GetNext())
        } else if (wParam == 40) { ;down
            n := oLv.GetNext()
            if (!n)
                oLv.modify(1, "+select")
            else {
                oLv.modify(n, "-select")
                oLv.modify(n+1, "+select")
            }
        } else if (wParam == 38) { ;up
            n := oLv.GetNext()
            if (n>1) {
                oLv.modify(n, "-select")
                oLv.modify(n-1, "+select")
            }
        } else {
            r := wParam-111
            if (r >= 1 && r <= 12) ;F1-F12
                do(oLv, r)
        }
    }
    tips(oLv, r, p*) {
        ;获取当前行整行内容
        arrRes := []
        loop(arrNew.length)
            arrRes.push(oLv.GetText(r, A_Index))
        oButton1.text := arrRes[2]
        try
            oButton2.text := arrRes[3]
    }
    do(oLv, r, p*) { ;NOTE 要做的事
        ;获取当前行整行内容
        ;arrRes := []
        ;loop(arrNew[1].length)
        ;    arrRes.push(oLv.GetText(r, A_Index+1))
        ;做任何事
        ;设置返回值
        key := oLv.GetText(r, indexKey+1)
        ;OutputDebug(format("i#{1} {2}:r={3} indexKey={4} key={5}", A_LineFile,A_LineNumber,r,indexKey,key))
        resGui := objRaw[key] ;TODO 增加了序号
        doEscape(oLv.gui)
    }
    pinyin(str){
        res := ""
        loop parse, str {
            if (A_LoopField ~= "[\x{00}-\x{FF}]")
                res .= A_LoopField
            else if (RegExMatch(sFile, A_LoopField . ".*\s\K.", &m))
               res .= m[0]
            else
                res .= A_LoopField
        }
        return res
    }
}

;defButton是默认按钮前面的text内容
;hyf_GuiMsgbox(map("a",132,"b",22), "aaa")
hyf_GuiMsgbox(obj, title:="", defButton:="", oGui:="", times:=0) {
    if (!isobject(obj))
        return
    if (obj is array && !obj.length)
        return
    if (obj is map && !obj.count)
        return
    if (times == 0) {
        oGui := gui()
        oGui.title := title
        oGui.SetFont("cBlue s13")
        oGui.OnEvent("escape",doEscape)
    }
    for k, v in obj {
        x := times*30 + 10 ;缩进30，离左边缘10
        oGui.AddText("section x" . x, k)
        if (isobject(v))
            %A_ThisFunc%(v, title, defButton, oGui, times+1)
        else if (defButton != "") && (k = defButton)
            oGui.AddButton("ys yp-5 default", v).OnEvent("click", hyf_GuiMsgbox_1)
        else
            oGui.AddButton("ys yp-5", v).OnEvent("click", hyf_GuiMsgbox_1)
    }
    if (times = 0)
        oGui.show("center")
    return oGui
    hyf_GuiMsgbox_1(ctl, p*) {
        hyf_setClip(ctl.text)
        ctl.gui.destroy()
    }
    doEscape(oGui) => oGui.destroy()
}

;defButton是默认按钮前面的text内容
hyf_GuiListView(arr2, arrCol:="") {
    if (!arr2.length)
        return
    if (arr2.length == 1) {
        hyf_GuiMsgbox(arr2[1])
        return
    }
    wCol := 100
    if (!isobject(arr2))
        return
    oGui := gui()
    oGui.OnEvent("escape",doEscape)
    if (!isobject(arrCol)) {
        arrCol := []
        for v in arr2[1]
            arrCol.push(A_Index)
    }
    oLv := oGui.add("ListView", "w1200 r40", arrCol)
    oLv.OnEvent("DoubleClick", do)
    oLv.SetFont("s12")
    oLv.opt("-Redraw")
    for k, arr in arr2
        oLv.add(, arr*)
    cntCol := oLv.GetCount("column")
    loop(cntCol)
        oLv.ModifyCol(A_Index, wCol . " +center")
    oLv.opt("+Redraw")
    oGui.show(format("w{1} center", wCol*cntCol+20))
    return oGui
    doEscape(oGui) => oGui.destroy()
    do(oLV, r, p*) { ;NOTE 要做的事
        ;获取当前行整行内容
        arrRes := []
        loop(oLv.GetCount("column"))
            arrRes.push(oLv.GetText(r, A_Index))
        hyf_GuiMsgbox(arrRes)
        ;做任何事
        ;设置返回值
        oGui.destroy()
    }
}

;-----------------------------------obj__-----------------------------------
;提示函数

;提供多种显示方式
;Excel单元格
;txt
;msgbox
;tooltip
;hyf_showObj 由于依赖其他库，写到 hyaray1.ahk

hyf_obj2Str(obj, char:="`n", level:=0) {
    static t := "", s := ""
    if (level)
        t .= A_Tab ;前置tab显示级数
    else
        t := "", s := "" ;防止多次运行时结果叠加
    if (!isobject(obj))
        return "非对象，值为`n" . obj
    try { ;FIXME 无故出错
        for k, v in obj {
            if (isobject(v)) {
                s .= t . k . char
                %A_ThisFunc%(v, char, level + 1)
                t := substr(t, 2) ;删除一个tab
            } else {
                ;if (strlen(v) > 100) ;TODO 删除太长的内容
                ;    v := substr(v, 1, 100) . "..."
                if (char == "`n") { ;NOTE 添加key信息
                    s .= t . k . A_Tab . v . char
                } else
                    s .= t . v . char
            }
        }
    }
    if (char != "`n") ;强制换行
        s .= "`n"
    if (level = 0) ;返回结果
        return s
}

hyf_objView(obj, str:="", char:="`n", n:=0) {
    if (str != "")
        return msgbox(str . "`n" . hyf_obj2Str(obj,char),,0x40000+n)
    else
        return msgbox(hyf_obj2Str(obj,char),,0x40000+n)
}

hyf_objToolTip(obj, str:="", t:=0) {
    res := str ? str . "`n" . hyf_obj2Str(obj, "`n") : hyf_obj2Str(obj, "`n")
    if (!t) {
        tooltip(res)
        hyf_input()
        tooltip
    } else {
        tooltip(res)
        SetTimer(tooltip, -t*1000)
    }
}

hyf_tooltip(str) {
    tooltip(str)
    hyf_input()
    tooltip
}

;*************以下为函数配套的子程序*****************

;LabelForMenu_FontInWord: ;Word中设置字体
;wd := ComObjActive("Word.application")
;wd.selection.font.name := Arr_SetFontInWord[A_ThisMenuItemPos].name
;wd.selection.font.size := Arr_SetFontInWord[A_ThisMenuItemPos].size
;ObjRelease(wd)
;return

; mapArr(funcObj, arr) {
;     arrRes := []
;     for v in arr
;         arrRes.push(funcObj.call(v))
;     return arrRes
; }

; mapObj(funcObj, obj) {
;     objRes := []
;     for k, v in obj
;         objRes[k] := funcObj.call(v)
;     return objRes
; }

reduce(fun, arr, v0:="") {
    if (arr.length == 1) {
        if (v0 != "")
            return fun.call(v0, arr[1])
    }
    res := (v0 != "") ? fun.call(v0, arr[1]) : arr[1]
    loop(arr.length-1)
        res := fun.call(res, arr[A_Index+1])
    return res
}

;filter(fun, obj) {
;    res := %type(obj)%()
;    for k, v in obj {
;        if (fun(k, v))
;            (obj is array) ? res.push(v) : (res[k] := v)
;    }
;    return res
;}

