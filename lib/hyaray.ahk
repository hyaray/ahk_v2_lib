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
;-----------------------------------交互-----------------------------------
*/

;-----------------------------------general__-----------------------------------

;插件A的子文件由A.ahk #include(NOTE 不包含可能有的定义文件A_define.ahk)
;这里只include A.ahk
;有需要定义的变量则单独放A_define.ahk

hyf_checkNewPlugin(includeFile, arrDirs, strBefore:="", arrDefault:=unset) {
    OutputDebug(format("i#{1} {2}:{3} start check {4}", A_LineFile,A_LineNumber,A_ThisFunc,includeFile))
    if (!isset(arrDefault))
        arrDefault := []
    ext := (A_AhkVersion ~= "^2") ? "ahk" : "ah1" ;NOTE
    strOld := FileRead(includeFile, "utf-8")
    cntAll := arrDefault.length
    objNum := map()
    objNum.default := 0 ;记录各项目的总数
    ;确保循环的内容都在includeFile里
    for arrDir in arrDirs {
        ;文件
        loop files, format("{1}\{2}\*.{3}", arrDir[1],arrDir[2],ext) {
            objNum[arrDir[2]]++
            sLoop := format("{1}\{2}", arrDir[2],A_LoopFileName)
            if (!instr(strOld, sLoop)) {
                msgbox(sLoop,,0x40000)
                return true
            }
        }
        ;文件夹
        loop files, format("{1}\{2}\*", arrDir[1],arrDir[2]), "D" {
            if (A_LoopFileAttrib ~= "[HS]")
                continue
            objNum[arrDir[2]]++
            sLoop := format("{1}\{2}\{3}{2}.{4}", arrDir[2], A_LoopFileName,strBefore,ext)
            if (!instr(strOld, sLoop)) {
                msgbox(sLoop,,0x40000)
                return true
            }
        }
    }
    OutputDebug(format("i#{1} {2}:{3} objNum={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(objNum,4)))
    ;检查数字是否一致来判断是否有删除的插件
    for k, v in objNum
        cntAll += v
    StrReplace(strOld, "`n", "",, &cnt)
    if (cnt != cntAll) {
        msgbox(json.stringify(objNum,4), format("总数不一致，获取 {1} 文件{2}", cntAll,cnt))
        return true
    }
}

hyf_speak(text, volume:=0) {
    if (volume) {
        vv := round(SoundGetVolume())
        SoundSetVolume(volume)
    }
    ComObject("SAPI.SpVoice").speak(text)
    if (volume)
        SoundSetVolume(vv)
}

;如果可直接键盘输出，一般用 SendText
;用剪切板发送字符串
hyf_paste(str, k:="", ms:=500) {
    if (ProcessExist("Ditto.exe")) {
        saveDetect := A_DetectHiddenWindows
        DetectHiddenWindows(true)
        PostMessage(0x111, 32775,,, "Ditto") ;断开剪切板
    }
    c := A_Clipboard
    A_Clipboard := str
    while(A_Clipboard != str)
        sleep(10)
    exeName := WinGetProcessName("A").fnn64(1)
    switch exeName {
        case "MobaXterm":
            send("{shift down}{ins}{shift up}")
        default:
            OutputDebug(format("i#{1} {2}:{3} ctrl-v", A_LineFile,A_LineNumber,A_ThisFunc))
            send("{ctrl down}v{ctrl up}")
    }
    sendEx(20, k, ms) ;ms是因为有些应用反应比较慢
    A_Clipboard := c
    if (ProcessExist("Ditto.exe")) {
        PostMessage(0x111, 32775,,, "Ditto") ;连接剪切板
        DetectHiddenWindows(saveDetect)
    }
}

;数字则sleep，{xxx}开头则 send，否则 SendText
;NOTE send("{1000}") 相当于 sleep(1000)，但有未知BUG，不要用
;sendEx("string1`n", 1000, "{tab}", "string2", 1000)
;NOTE 第1个参数为数组，则是有规律地批量录入，第2个参数最好也是数组，表示中间的按键
;sendEx(["a","b","c"], [500, "{down}"]) ;录入Excel多行分别为a b c
sendEx(arr*) {
    if (arr[1] is array) {
        if (!arr[1].length)
            return
        SendText(arr[1][1])
        loop(arr[1].length-1) {
            (arr[2] is array) ? sendEx(arr[2]*) : sendEx(arr[2])
            SendText(arr[1][A_Index+1])
        }
        return true
    }
    for v in arr {
        if (v is integer) {
            sleep(v)
        } else {
            if (v ~= "i)^\{\w+(?: (?:down|up|\d+))?\}") ;{ctrl down}|{a 2}|{ctrl up} NOTE 如果要发送 {\w+} 格式字符串，则不要用此函数
                send(v)
            else
                SendText(v)
        }
    }
    return 1
}

;指定utf-8类型
hyf_readyaml(fp, arr:=unset, default:=unset) {
    obj := yaml.parse(fileread(fp, "utf-8"))
    if (isset(arr))
        obj := obj.getEx(arr, default?)
    return obj
}

deepclone(obj) {
	objs := map()
	objs.default := ""
	return clone(obj)
	clone(obj) {
		switch type(obj) {
			case "Array", "Map":
				o := obj.Clone()
				for k, v in o
					if isobject(v)
						o[k] := objs[p := ObjPtr(v)] || (objs[p] := clone(v))
				return o
			case "Object":
				o := obj.Clone()
				for k, v in o.OwnProps()
					if isobject(v)
						o.%k% := objs[p := ObjPtr(v)] || (objs[p] := clone(v))
				return o
			default:
				return obj
		}
	}
}

;NOTE 可直接获取的不依赖复制
;bVimNormal 获取 Vim normal模式下的内容
hyf_getSelect(bVimNormal:=false, bInput:=false) {
    do_copy := true
    if (WinActive("ahk_class XLMAIN")) {
        if (ControlGetClassNN(ControlGetFocus()) == "EXCEL71")
            return rng2str(ox().selection)
    } else if (WinActive("ahk_exe tabby.exe")) {
        do_copy := false
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
    if (do_copy) {
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
            if (WinActive("ahk_class OpusApp"))
                res := RegExReplace(trim(A_Clipboard,"`r`n"), "^\d+(\.\d+)*\.?\s") ;word列表复制的内容
            else
                res := A_Clipboard ;TODO 可trim(A_Clipboard)能会耗时较长
            ;OutputDebug(format("i#{1} {2}:res={3}", A_LineFile,A_LineNumber,res))
            A_Clipboard := clipSave
            return res
        }
        OutputDebug(format("d#{1} {2}:copy failed clip={3}", A_LineFile,A_LineNumber,A_Clipboard))
        A_Clipboard := clipSave
    }
    if (bInput) {
        res := inputbox("获取和复制失败，请手工输入内容")
        if (res.result!="Cancel" && (res.value != ""))
            return res.value
    } else {
        return ""
    }
    ;暂时应用是选中多个标题名
    ;NOTE qz 里获取值依赖
    rng2str(rng, charCol:="`t") {
        if (rng.cells.count == 1)
            return rng.text
        res := ""
        arrV := rng.value
        rs := arrV.MaxIndex(1)
        cs := arrV.MaxIndex(2)
        loop(rs) {
            r := A_Index
            ;if (mod(r,1000)==0)
            ;    tooltip(r)
            res .= delete0(arrV[r,1])
            loop(cs-1)
                res .= charCol . delete0(arrV[r,A_Index+1])
            res .= "`r`n"
        }
        ;tooltip
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
    if (str == "")
        return
    if (GetKeyState("LCtrl", "P"))
        A_Clipboard := format("{1}`n{2}", A_Clipboard,str)
    else
        A_Clipboard := str
    ;if (WinExist("ahk_class tooltips_class32"))
    ;    tooltip
    tooltip(format("{1}`n`n{2}", stip,str))
    SetTimer(tooltip, -n)
}

hyf_addClip(str) {
    hyf_setClip(format("{1}`n{2}", A_Clipboard,str))
}

RegExist(dir) {
    loop reg, dir, "KV"
        return true
    return false
}

;输入字符串，增加了置顶和非空检测，NOTE 不匹配直接exit
hyf_inputstr(str:="请输入", varDefault:="", title:="") {
    SetTimer((p*)=>WinSetAlwaysOnTop(true, "A"), -500)
    oInput := inputbox(str, title,,varDefault)
    if (oInput.result=="Cancel" || (oInput.value=="")) {
        msgbox("错误：输入为空",,0x40000)
        exit
    }
    return oInput.value
}

hyf_inputnum(str:="请输入数字", varDefault:="", title:="") {
    SetTimer((p*)=>WinSetAlwaysOnTop(true, "A"), -500)
    oInput := inputbox(str, title,,varDefault)
    if (oInput.result == "Cancel" || !(oInput.value ~= "^-?\d+(\.\d+)?$")) {
        msgbox("错误：非数字",,0x40000)
        exit
    }
    return number(oInput.value)
}

;#8::msgbox(hyf_input())
hyf_input(toLow:=false, ms:=0) {
    ih := InputHook()
    ih.VisibleNonText := false
    ih.VisibleText := false
    ih.KeyOpt("{All}", "E")
    ih.start()
    ih.Timeout := ms
    timeSave := A_TickCount
    suspend(true) ;#HotIf HotIfWinActive 优先级更高
    ih.wait() ;. "`n2" . ih.EndKey . "`n1" . ih.EndReason
    if (A_TickCount - timeSave < 200 && ih.EndKey == "LControl") { ;A_MenuMaskKey 会自动发送按键
        ;msgbox("hyaray:hyf_input A_MenuMaskKey")
        ih.start()
        ih.wait()
    }
    suspend(false)
    if (ih.EndReason == "Timeout")
        res := "Timeout"
    else
        res := ih.EndKey
    if (toLow)
        res := StrLower(res)
    return res
}

;支持多行的 inputbox
;替换换行符用 StrReplace(sList, "`r`n", ",")
inputboxEX(tips, sDefaluet:="", sTitle:="", bEmpty:=false) {
    nameEdit := "vvv"
    oGui := gui("+resize +AlwaysOnTop +Border +LastFound +ToolWindow")
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
        ctl.gui.destroy()
    }
    doEscape(oGui, param*) {
        res := ""
        oGui.destroy()
    }
}

/*
TODO 默认激活控件
arr2 := [
    ["姓名", "name", "hy"],
    ["性别", "gender", ["男","女"], 2],
    ["年龄", "age", "20", "n"],
    ["是否党员", "dangyuan", 0, "b"],
    ["备注", "beizhu", "", "2"],
]
objOpt := hyf_inputOption(arr2, "提示")
msgbox(json.stringify(objOpt, 4))
;arr2的子数组各项说明:
;   1.提示文字
;   2.变量名
;   3.默认值|数据范围(可选)
;      数组，则为 ComboBox
;   4.opt(可选)
;      "n" Edit只能输入数字，返回为数字类型
;      "f" Edit为浮点数
;      "b" 是否的 Checkbox
;      数字 多行Edit|ComboBox的默认项
;   5.focus和disable
;      focus 默认控件
;      0 禁用(用得少)
;bOne 表示限制单结果，则会在 Edit内容改变时，清空其他控件
;关闭则返回map()
;NOTE 自动过滤空值
*/
hyf_inputOption(arr2, title:="", funOut:="", bOne:=false) {
    if (arr2 is map) {
        for k, v in arr2.clone()
            arr2.push([k,k,v])
    }
    oGui := gui("+resize +AlwaysOnTop +Border +LastFound +ToolWindow")
    if (title != "")
        oGui.title := title
    oGui.OnEvent("escape", doEscape)
    oGui.OnEvent("close", doEscape)
    oGui.SetFont("cRed s22")
    oGui.SetFont("cDefault s11")
    funOpt := (x,w:=600)=>format("ys v{1} w{2}", x,w) ;默认宽
    focusCtl := ""
    for arr in arr2 {
        oGui.AddText("x10 section", arr[1])
        if (arr.length >= 5 && arr[5]==0)
            continue
        varName := arr[2]
        ;设置 opt
        ctl := ""
        if (arr.length >= 3) {
            if (arr[3] is array) {
                ;if (arr.length>=4 && arr[4] == "m") #TODO 单控件无法实现多选返回数组
                ;    ctl := "Checkbox"
                ctl := "ComboBox"
                lMax := max(arr[3].map(x=>strlen(x))*)
                opt := funOpt(varName, max(lMax*30, 50))
                if (arr.length >= 4)
                    opt .= format(" choose{1}", arr[4])
            } else if (arr.length>=4 && arr[4] == "b") { ;boolean
                ctl := "Checkbox"
                opt := funOpt(varName, 100)
            }
        }
        ;其他为Edit
        if (ctl == "") {
            ctl := "Edit"
            opt := funOpt(varName)
            if (arr.length >= 4) {
                switch arr[4] {
                    case "n","f": ;限制为数字
                        opt .= " number"
                    default:
                        if (arr[4] is integer)
                            opt .= format(" r{1}", arr[4])
                }
            }
        }
        switch ctl {
            case "ComboBox":
                oGui.AddComboBox(opt, arr[3])
            case "Checkbox":
                oGui.SetFont("cRed")
                if (arr[3])
                    opt .= " checked"
                oGui.AddCheckbox(opt)
                oGui.SetFont("cDefault")
            case "Edit":
                if (arr.length >= 3 && arr[3] != "")
                    oGui.AddEdit(opt, arr[3]).OnEvent("change", editChange)
                else
                    oGui.AddEdit(opt).OnEvent("change", editChange)
        }
        ;默认激活字段
        if (arr.length >= 5 && arr[5]=="focus")
            focusCtl := varName
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
        o := ctl.gui.submit()
        ;msgbox(type(o) . "`n" . json.stringify(hyf_props(o), 4))
        for arr in arr2 {
            v := o[arr[2]]
            ;记录
            if (v != "") { ;过滤空值
                ;输出结果二次加工
                if (funOut)
                    v := funOut(v) ;TODO 是否trim(比如每行前加"- "转成无序列表)
                if (arr.length >=4 && arr[4]~="n|f")
                    objRes[arr[2]] := number(v)
                else
                    objRes[arr[2]] := v
            }
        }
        ctl.gui.destroy()
    }
    doEscape(oGui, p*) => oGui.destroy()
}

;line
;   _TC.getLineInFile(fp, funLine)
;   reg
;NOTE 为了兼容性，转到 _c.e by 火冷 <2023-06-30 01:36:49>
hyf_runByVim(fp, line:=0, params:="--remote-tab-silent") { ;用文本编辑器打开
    if (line is integer) {
        if (line)
            params .= " +" . line
    } else if (line != "") {
        if (instr(line, " "))
            line := format('"{1}"', StrReplace(line,'"','\"'))
        params .= format(" +/{1}", line)
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

;arrFnn 从后向前找第一个匹配的文件路径
;dirIn
;   文件夹：找不到就返回""
;   文件：找不到就返回 dirIn
;   数组：按顺序返回第一个找的结果
;ext
;   ""精准
;   "*"搜索
hyf_findFile(dirIn, arrFnn, ext:="*", funFilter:=unset) {
    ;数组
    if (dirIn is array) {
        for _ in dirIn {
            fp := hyf_findFile(_, arrFnn, ext)
            if (fp != "")
                return fp
        }
        return ""
    }
    if (DirExist(dirIn)) {
        dir := dirIn
        ;OutputDebug(format("i#{1} {2}:dir={3}", A_LineFile,A_LineNumber,dir))
        res := ""
    } else if FileExist(dirIn) { ;文件
        SplitPath(dirIn,, &dir)
        res := dirIn
    } else {
        return
    }
    if (arrFnn is string)
        arrFnn := [arrFnn]
    fps := []
    loop(arrFnn.length) {
        if (ext == "") { ;精准文件名
            dir := format("{1}\{2}", dir,arrFnn[-A_Index]) ;d:\a\b.txt 可以遍历搜索b.txt
            loop files, dir, "RF" {
                if (!isset(funFilter) || funFilter(A_LoopFileFullPath))
                    fps.push(A_LoopFileFullPath)
            }
        } else {
            fp := format("{1}\{2}.{3}", dir,arrFnn[-A_Index],ext)
            loop files, fp, "RF" {
                if (A_LoopFileAttrib ~= "[HS]")
                    continue
                if (!isset(funFilter) || funFilter(A_LoopFileFullPath))
                    fps.push(A_LoopFileFullPath)
            }
        }
        if (fps.length)
            break
    }
    ;OutputDebug(format("i#{1} {2}:{3} fps={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(fps,4)))
    if (fps.length == 1)
        return fps[1]
    ;找层级最深的文件
    level := 0
    for fp in fps {
        StrReplace(fp, "\", "", 0, &cnt)
        if (cnt > level)
            res := fp
    }
    return res
}

FileExistEx(fp, ms:=5000) {
    endTime := A_TickCount + ms
    loop {
        if (FileExist(fp))
            return true
        else
            sleep(100)
    } until (A_TickCount >= endTime)
    return false
}

hyf_searchFile(dir, sFile:="*", opt:="RF") {
    ;arr2 := []
    ;l := strlen(dir)
    ;loop files, format("{1}\{2}", dir,sFile), opt {
    ;    if (A_LoopFileAttrib ~= "[HS]")
    ;        continue
    ;    arr2.push([substr(A_LoopFileFullPath, l+1)])
    ;}
    arr2 := dir.dir2files(sFile,, true)
    arrRes := hyf_selectByArr(arr2, 1, "20")
    if (!arrRes.length)
        exit
    return format("{1}\{2}", dir,arrRes[1])
}

hyf_searchText(dir, reg, ext:="*") {
    ext := ltrim(ext, ".")
    loop files, format("{1}\*.{2}", dir,ext), "F" {
        if (A_LoopFileAttrib ~= "[HS]")
            continue
        if (fileread(A_LoopFileFullPath, "utf-8") ~= reg)
            return A_LoopFileFullPath
    }
}

;hyf_findCtrl(funCtlTrue, winTitle:="") {
;    try
;        arr := WinGetControls(winTitle)
;    catch
;        return
;    for ctlName in arr {
;        if funCtlTrue(ctlName)
;            return ctlName
;    }
;}

;-----------------------------------calc-----------------------------------
eval(str) {
    oSC := ComObject("ScriptControl")
    oSC.Language := "VBScript" ;"JavaScript"
    return oSC.eval(str)
}

;返回 screen 的坐标
;以 xOffset为例, yOffset 同理
;tp
;   1=往【外部】偏移，xOffset 情况如下
;       -0.1=左侧往左0.1宽
;        0.1=右侧往右0.1宽
;   0=往【内部】偏移，xOffset 情况如下
;       -0.1=右侧往左0.1宽
;        0.1=左侧往右0.1宽
;   2=NOTE 相对坐标，主要用来转换浮点数和高宽的关系
hyf_offsetXY(xOffset:=unset, yOffset:=unset, tp:=0, aRect:=unset) {
    if (!isset(aRect)) {
        WinGetPos(&winX, &winY, &winW, &winH, "A")
        aRect := [winX,winY,winW,winH]
    } else if (aRect is integer) {
        WinGetPos(&winX, &winY, &winW, &winH, aRect)
        aRect := [winX,winY,winW,winH]
    }
    if (tp == 2) { ;则两个参数必填
        if (isset(xOffset)) {
            if (xOffset is float)
                xOffset *= aRect[3]
        } else {
            xOffset := 0
        }
        if (isset(yOffset)) {
            if (yOffset is float)
                yOffset *= aRect[4]
        } else {
            yOffset := 0
        }
        return [xOffset, yOffset]
    }
    ;只传入单个值
    if (!isset(xOffset) || !isset(yOffset)) {
        if (isset(xOffset)) {
            return isobject(xOffset) ? xOffset(aRect) : deal(xOffset, aRect[1], aRect[3], tp)
        } else if (isset(yOffset)) {
            return (isobject(yOffset)) ? yOffset(aRect) : deal(yOffset, aRect[2], aRect[4], tp)
        } else {
            throw ValueError("x,y至少传一个")
        }
    }
    arrXY := []
    arrXY.push(isobject(xOffset) ? xOffset(aRect) : deal(xOffset, aRect[1], aRect[3], tp))
    arrXY.push(isobject(yOffset) ? yOffset(aRect) : deal(yOffset, aRect[2], aRect[4], tp))
    ;OutputDebug(format("i#{1} {2}:{3} xOffset={4},yOffset={5} aRect={6} arrXY={7}", A_LineFile,A_LineNumber,A_ThisFunc,xOffset,yOffset,json.stringify(aRect),json.stringify(arrXY)))
    return arrXY
    deal(v, x, w, tp) {
        if (v is float)
            v := round(w*v)
        if (v == 0) {
            res := x + w*tp + v
        } else if (v < 0) {
            res := tp ? x + v : x + w + v
        } else {
            res := x + w*tp + v
        }
        ;OutputDebug(format("i#{1} {2}:{3} v={4},x={5},w={6} tp={7}, res={8}", A_LineFile,A_LineNumber,A_ThisFunc,v,x,w,tp,res))
        return res
    }
}

hyf_offsetRect(xyxy, tp:=0, aRect:=unset) {
    if (!isset(aRect)) {
        WinGetPos(&winX, &winY, &winW, &winH, "A")
        aRect := [winX,winY,winW,winH]
    } else if (aRect is integer || aRect is string) {
        WinGetPos(&winX, &winY, &winW, &winH, aRect)
        aRect := [winX,winY,winW,winH]
    }
    res := []
    xy := hyf_offsetXY(xyxy[1], xyxy[2], tp, aRect)
    xy1 := hyf_offsetXY(xyxy[3], xyxy[4], tp, aRect)
    return [xy[1], xy[2], xy1[1]-xy[1], xy1[2]-xy[2]]
}

hyf_offsetBoundingBox(xyxy, tp:=0, aRect:=unset) {
    if (!isset(aRect)) {
        WinGetPos(&winX, &winY, &winW, &winH, "A")
        aRect := [winX,winY,winW,winH]
    } else if (aRect is integer || aRect is string) {
        WinGetPos(&winX, &winY, &winW, &winH, aRect)
        aRect := [winX,winY,winW,winH]
    }
    res := []
    xy := hyf_offsetXY(xyxy[1], xyxy[2], tp, aRect)
    xy1 := hyf_offsetXY(xyxy[3], xyxy[4], tp, aRect)
    return [xy[1], xy[2], xy1[1], xy1[2]]
}

hyf_rect2BoundingBox(rect) {
    return [rect[1], rect[2], rect[1]+rect[3], rect[2]+rect[4]]
}

hyf_BoundingBox2rect(xyxy) {
    return [xyxy[1], xyxy[2], xyxy[3]-xyxy[1], xyxy[4]-xyxy[2]]
}

hyf_xy2percent(xy, jingdu:=2, aRect:=unset) {
    if (!isset(aRect)) {
        WinGetPos(&winX, &winY, &winW, &winH, "A")
        aRect := [winX,winY,winW,winH]
    } else if (aRect is integer) {
        WinGetPos(&winX, &winY, &winW, &winH, aRect)
        aRect := [winX,winY,winW,winH]
    }
    arr := []
    for v in xy
        arr.push(round((xy[A_Index]-aRect[A_Index])/aRect[A_Index+2], jingdu))
    return arr
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

hyf_direction(_x0,_y0, _x1,_y1) {
    return ["→","↗","↑","↖","←","↙","↓","↘","→"][round(getAngle(_x0,_y0,_x1,_y1)/45 + 1)]
    getAngle(_x0,_y0, _x1,_y1) { ;NOTE _x轴正方向为0
        _x := _x1-_x0
        _y := _y0-_y1
        if (_x == 0) {
            if (_y == 0)
                throw ValueError("_x=_y=0")
            ret := (_y>0) ? 90 : 270
        } else {
            res := atan(_y/_x)*57.295779513
            ret := _x>0 ? round(res+((_y<0)*360)) : round(res + 180)
        }
        OutputDebug(format("i#{1} {2}:{3} {4},{5}, {6},{7} ret={8}", A_LineFile,A_LineNumber,A_ThisFunc,_x0,_y0,_x1,_y1,ret))
        return ret
    }
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
        for v in num {
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
        for v in num {
            if (mod(v, n) != 0)
                continue 2
        }
        return n
    }
}

;-----------------------------------Windows__-----------------------------------

;右键并点击菜单(菜单必须有单独窗口)
;flag !=0 则为包含name
hyf_contentMenu(winMenu, name:="", flag:=0) {
    if (!WinExist(winMenu)) {
        send("{RButton}")
        if (!WinWait(winMenu,, 0.5))
            return false
    }
    if (name != "") {
        elItem := UIA.FindControl("MenuItem", name,,, flag)
        if (elItem) {
            elItem.clickTo()
            return true
        } else {
            return false
        }
    } else {
        return true
    }
}

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

;https://www.autohotkey.com/boards/viewtopic.php?f=82&t=112505&p=501016
; SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX
; https://www.geoffchappell.com/studies/windows/km/ntoskrnl/api/ex/sysinfo/handle_ex.htm
; https://www.geoffchappell.com/studies/windows/km/ntoskrnl/api/ex/sysinfo/handle_table_entry_ex.htm
hyf_GetOpenedFiles(pid, fun:=unset) {
    hProcess := dllcall("OpenProcess", "UInt",0x40, "UInt",0, "UInt",pid, "Ptr") ;PROCESS_DUP_HANDLE
    obj := map()
    res := size := 1, failed := false
    while res != 0 && !(A_Index = 100 && failed := true) {
        buf := buffer(size, 0)
        res := dllcall("ntdll\NtQuerySystemInformation", "Int",0x40, "Ptr",buf, "UInt",size, "UIntP",&size, "UInt") ;info
    }
    if failed {
        dllcall("CloseHandle", "Ptr", hProcess)
        throw "NtQuerySystemInformation failed, NTSTATUS: " . res
    }
    numberOfHandles := numget(buf, "Ptr")
    VarSetStrCapacity(&filePath, 1026)
    structSize := A_PtrSize*3 + 16 ; size of SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX
    loop numberOfHandles {
        ProcessId := numget(buf, A_PtrSize*2 + structSize*(A_Index-1) + A_PtrSize, "UInt")
        if (pid == ProcessId) {
            handleValue := numget(buf, A_PtrSize*2 + structSize*(A_Index-1) + A_PtrSize*2, "Pre")
            dllcall("DuplicateHandle", "Ptr",hProcess, "Ptr",handleValue, "Ptr",dllcall("GetCurrentProcess"), "PtrP",&lpTargetHandle:=0, "UInt",0, "UInt",0, "UInt",2) ;DUPLICATE_SAME_ACCESS=2
            if (dllcall("GetFileType", "Ptr", lpTargetHandle) == 1) && dllcall("GetFinalPathNameByHandle", "Ptr",lpTargetHandle, "Str",filePath, "UInt",512, "UInt", 0) ;;FILE_TYPE_DISK=1
                obj[RegExReplace(filePath, "^\\\\\?\\")] := ""
            dllcall("CloseHandle", "Ptr", lpTargetHandle)
        }
    }
    dllcall("CloseHandle", "Ptr", hProcess)
    arr := []
    if isset(fun) {
        for k, v in obj {
            if (fun(k))
                arr.push(k)
        }
    } else {
        for k, v in obj
            arr.push(k)
    }
    return arr
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
        numput("int64",0x11CF3C3D618736E0, "int64",0x719B3800AA000C81, IID:=buffer(16))
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
            numput("int64",0x11CE74366D5140C1, "int64",0xFA096000AA003480, pid:=buffer(16))
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

hyf_winMove(xOffset:=0, yOffset:=0, w:=1, h:=1, hwnd:=unset) {
    if (!isset(hwnd))
        hwnd := WinExist("A")
    WinGetPos(&xWin, &yWin, &wWin, &hWin, hwnd)
    wWin := (w is float) ?  wWin * w : w
    hWin := (h is float) ?  hWin * h : h
    WinRestore(hwnd) ;先还原，否则会失败
    WinMove(xWin+xOffset, yWin+yOffset, wWin, hWin, hwnd)
}

;同 exe 的其他窗口
;返回格式如下(hwnd放末尾，用arr[-1]获取)
;[
;   [1, 标题, hwnd]
;   [2, 标题, hwnd]
;]
hyf_exeOtherWindows(bSkipBlankTitle:=false) {
    idA := WinActive("A")
    if (!idA)
        return
    title := WinGetTitle()
    cls := WinGetClass()
    exeName := WinGetProcessName()
    arrRes := []
    for hwnd in WinGetList(format("ahk_class {1} ahk_exe {2}", cls,exeName)) {
        if (hwnd == idA)
            continue
        tt := trim(WinGetTitle(hwnd))
        if (bSkipBlankTitle && tt == "")
            continue
        arrRes.push([arrRes.length+1, tt, hwnd])
    }
    return arrRes
}

;funHwnd 处理 hwnd 为 true 则添加
;hyf_hwnds("ahk_exe a.exe", hwnd=>hwnd.isDialog())
;hyf_hwnds("ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe")
hyf_hwnds(winTitle, funHwnd:=unset) {
    saveDetect := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    arr := []
    for hwnd in WinGetList(winTitle) {
        try
            titleLoop := WinGetTitle(hwnd)
        catch
            continue
        if (isset(funHwnd)) {
            if (funHwnd(hwnd))
                arr.push(hwnd)
        } else if (instr(winTitle, "ahk_class ")) {
            if (titleLoop ~= "\S") ;指定了 ahk_class 则非空标题就添加
                arr.push(hwnd)
        } else {
            arr.push(hwnd)
        }
    }
    DetectHiddenWindows(saveDetect)
    return arr
}

hyf_showExe(exeName, funHwnd:=unset) {
    if (exeName is integer) { ;pid
        winTitle := "ahk_pid " . string(exeName)
        exeName := WinGetProcessName(winTitle)
    } else {
        winTitle := "ahk_exe " . exeName
    }
    arr2 := []
    arrId := hyf_hwnds(winTitle, funHwnd?)
    for v in arrId
        arr2.push([v,WinGetTitle(v),WinGetClass(v),format("0x{:08X}", format("0x{:08X}", WinGetStyle(v)))])
    ;return arr2
    hyf_GuiListView(arr2, ["hwnd","title","class","style"], exeName)
}

;遍历控件
hyf_ctls(hwnd) {
    arr2 := []
    WinExist(hwnd)
    exeName := WinGetProcessName()
    for ctlName in WinGetControls() ;名称
        arr2.push([ctlName, ControlGetHwnd(ctlName), ControlGetText(ctlName)])
    ;return arr2
    hyf_GuiListView(arr2, ["name","id","text"], exeName)
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

;run帮助增加了数组的支持(TODO 哪里不完善？)
;批量执行cmd并一次性返回结果
;hyf_run(sCmd) {
;    if (sCmd is array)
;        sCmd := "`n".join(sCmd)
;    shell := ComObject("WScript.Shell")
;    ; 打开 cmd.exe 禁用命令回显
;    exec := shell.Exec(A_ComSpec " /Q /K echo off")
;    ; 发送并执行命令, 使用新行分隔
;    exec.StdIn.WriteLine(sCmd "`nexit")  ; 总是在最后退出!
;    ; 读取并返回所有命令的输出
;    return exec.StdOut.ReadAll()
;}

;不是路径，不用 ProcessExist 判断
;已打开则激活
runEx(var, winTitle) {
    if (hwnd := WinExist(winTitle)) {
        WinActivate
    } else {
        (var is string) ? run(var) : var()
        hwnd := WinWaitActive(winTitle)
    }
    return hwnd
}

;hyf_smartWin 简易版
;适合直接用 winTitle 就能激活主窗口的
hyf_win(fp, winTitle, objHook:=unset) {
    SplitPath(fp, &fn)
    if (!ProcessExist(fn)) {
        if (isset(objHook) && objHook.has("br"))
            objHook["br"]()
        try
            run(fp)
        catch
            return
        else
            hwnd := WinWait(winTitle)
        WinActivate
        if (isset(objHook) && objHook.has("ar"))
            objHook["ar"]()
    } else if (hwnd := WinActive(winTitle)) {
        if (isset(objHook) && objHook.has("bh"))
            objHook["bh"]()
        WinHide
        if (isset(objHook) && objHook.has("ah"))
            objHook["ah"]()
    } else {
        if (isset(objHook) && objHook.has("ba"))
            objHook["ba"]()
        WinShow(winTitle)
        WinActivate(winTitle)
        if (isset(objHook) && objHook.has("aa"))
            objHook["aa"]()
        hwnd := WinActive("A")
    }
    return hwnd
}

;fp要支持fn，见_ET.smartWin
;funcHwndOrwinClass很多程序，还需要进一步筛选
;   如果是 ahk_class class，则默认会过滤空标题
;   如果还要考虑标题，必须要传入函数来判断
;objHook的键是br(beforeRun), ar(afterRun), ba(beforeActive), aa(afterActive), bh(beforeHide), ah(afterHide)
;有些窗口不需要记录窗口id
hyf_smartWin(fp, funcHwndOrwinClass:=unset, objHook:=unset, allWin:=0) {
    ;获取 exeName
    if !(instr(fp, ":")) {
        msgbox(format("{1}`n不是完整路径", fp))
        exit
    }
    SplitPath(fp, &exeName)
    if (exeName ~= "i)\.[vbe|cmd|bat]") ;NOTE cmd的需要转换
        exeName := substr(exeName,1,strlen(exeName)-4) . ".exe"
    ;获取 winTitle(用来遍历)
    winTitle := "ahk_exe " . exeName
    if (isset(funcHwndOrwinClass)) {
        if (funcHwndOrwinClass is string) {
            winTitle := format("{1} {2}", funcHwndOrwinClass,winTitle)
            funcHwndOrwinClass := (*)=>1
        }
    }
    ;if (isobject(funcHwndOrwinClass) || (funcHwndOrwinClass == ""))
    ;    winTitle := "ahk_exe " . exeName
    ;else
    ;    winTitle := funcHwndOrwinClass . " ahk_exe " . exeName
    ;获取 fnn
    fnn := exeName.fnn64()
    if (fnn ~= "^\d") ;数字开头不能当函数名
        fnn := "_" . fnn
    ;处理逻辑
    ;OutputDebug(format("i#{1} {2}:ProcessExist(exeName)={3}", A_LineFile,A_LineNumber,ProcessExist(exeName)))
    if (!ProcessExist(exeName)) {
        smartRun(fp)
    } else if (WinActive(winTitle)) {
        if (isset(objHook) && objHook.has("bh")) ;返回 运行函数
            objHook["bh"]()
        WinHide(winTitle)
        if (allWin) {
            for hwnd in WinGetList(winTitle)
                WinHide(hwnd)
        }
        ;激活鼠标所在窗口 TODO
        MouseGetPos(,, &idMouse)
        WinActivate(idMouse)
    } else { ;NOTE
        arrHwnd := hyf_hwnds(winTitle, funcHwndOrwinClass)
        if (allWin) { ;激活所有匹配窗口(比如开了多个谷歌浏览器)
            for v in arrHwnd {
                WinShow(v)
                WinActivate(v)
                idWin := v
            }
            WinActivate(idWin)
        } else {
            if (arrHwnd.length) {
                idWin := arrHwnd[1]
                WinShow(idWin)
                WinActivate(idWin)
            } else {
                tooltip("找不到窗口，从激活改成【打开】")
                smartRun(fp)
                SetTimer(tooltip, -1000)
            }
        }
        if (isset(objHook) && objHook.has("aa"))
            objHook["aa"]()
    }
    smartRun(fp) {
        ;_ToolTip.tips("启动中，请稍等...")
        params := ""
        if (isset(objHook) && objHook.has("br")) ;返回 运行函数
            params := objHook["br"]()
        SplitPath(fp, &fn, &dir)
        if (params != "")
            fp := format("{1} {2}", fp,params)
        OutputDebug(format("i#{1} {2}:fp={3}", A_LineFile,A_LineNumber,fp))
        ;打开程序
        try
            run(format("{1} /c {2}", A_ComSpec,fp), dir, "hide") ;run(fp, dir) ;TODO 尝试 <2023-04-22 23:31:11> hyaray
        catch
            throw ValueError(fp)
        ;打开后自动运行
        if (isset(objHook) && objHook.has("ar")) { ;返回 运行函数
            objHook["ar"]()
        } else {
            ;sleep(1000)
            ;if !ProcessExist(exeName) {
            ;    msgbox(exeName . "`n未出现，打开软件失败",,0x40000)
            ;    exit
            ;}
            if (WinWait(winTitle,, 2)) { ;自动激活
                if !WinWaitActive(winTitle,, 0.2)
                    WinActivate(winTitle)
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
;run帮助也有此类方法(TODO 哪里不完善？)
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
;NOTE 中文编码encode=CP936
; https://www.autohotkey.com/boards/viewtopic.php?t=93944
hyf_cmd(strCode, encode:="utf-8", callback:="") { ;  GAHK32 ; Modified version : SKAN 05-Jul-2013  http://goo.gl/j8XJXY
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
            if (funRegname(A_LoopRegName))
                return true
        }
    }
}

;-----------------------------------Excel__-----------------------------------

;http://www.autohotkey.com/forum/viewtopic.php?p=492448
;idObject := -16
;if dllcall("oleacc\AccessibleObjectFromWindow", "ptr", ctlID, "uint",idObject&=0xFFFFFFFF, "ptr",-VarSetCapacity(IID,16)+numput(idObject==0xFFFFFFF0?0x46000000000000C0:0x719B3800AA000C81,numput(idObject==0xFFFFFFF0?0x20400:0x11CF3C3D618736E0,IID,"int64"),"int64"), "ptr*",&pacc:=0) == 0
;xl := ComObject("{00024500-0000-0000-C000-000000000046}")
;xl := ComObject("Excel.Application.14")
ox(winTitle:="ahk_class XLMAIN") {
    if (WinExist(winTitle))
        ctlID := ControlGetHwnd("EXCEL71")
    else
        return ComObject("Excel.application")
    numput("Int64",0x20400, "Int64",0x46000000000000C0, IID_IDispatch:=buffer(16))
    dllcall("oleacc\AccessibleObjectFromWindow", "ptr",ctlID, "uint",0xFFFFFFF0, "ptr",IID_IDispatch, "ptr*",win:=ComValue(9,0), "HRESULT")
    loop {
        try
            return win.application
        catch
            ControlSend("{escape}", "EXCEL71")
    }
}

;测试数据
;    0.01,
;    1.0100,
;    2.10010,
;    3.19999999996,
;arrV要用这个方法 整数可用 integer() 代替
;NOTE 日期表示为 3.20，会影响实际数据
hyf_delete0(var) {
    if (var is ComObject) ;单元格
        var := var.value
    else if !(var is string)
        var := string(var)
    if (var ~= "^-?\d+\.\d+$") {
        if (var ~= "\.\d{8,}$") ;小数位太多的异常
            var := round(var+0.00000001, 6)
        return rtrim(RegExReplace(var, "\.\d*?\K0+$"), ".")
    } else {
        return var
    }
}

;单元格所在行的【记录】转成 obj[标题] := v
;表格要求：超级表或标准表
hyf_cell2objRecord(cell:="", skip:=false) {
    if (!isobject(cell))
        cell := ox().ActiveCell
    try
        rngTable := cell.ListObject.range
    catch
        rngTable := cell.CurrentRegion
    r := cell.row-rngTable.row+1
    arrV := hyf_rng2arrayV(rngTable)
    obj := map()
    loop(rngTable.columns.count) {
        v := arrV[r,A_Index]
        if (!skip || v != "")
            obj[arrV[1,A_Index]] := v
    }
    return obj
}

;值转成一维数组
hyf_rng2array(rng:=unset) {
    if (!isset(rng))
        rng := ox().selection
    arrVal := []
    ;TODO 多区域则遍历单元格
    if (rng.areas.count > 1) {
        xl := rng.application
        xl.ScreenUpdating := false
        for cell in rng
            arrVal.push(hyf_delete0(cell))
        xl.ScreenUpdating := true
    }
    ;单单元格
    if (rng.count == 1)
        return [hyf_delete0(rng)]
    ;多单元格
    arrV := rng.value
    loop(arrV.MaxIndex(1)) {
        r := A_Index
        loop(arrV.MaxIndex(2))
            arrVal.push(hyf_delete0(arrV[r,A_Index]))
    }
    return arrVal
}

;判断了单个单元格的情况
;funVal可直接修改原单元格值
;   unset=hyf_delete0
;   0=不处理
;   自定义函数
;fillUp 如果为空则填充上单元格的值(主要用于有合并单元格的情况)
hyf_rng2arrayV(rng:=unset, funVal:=unset, bWrite:=false) {
    if (!isset(rng))
        rng := ox().selection
    if (rng.areas.count > 1 || rng.MergeCells) { ;TODO 多区域则直接修改值或转成arr
        if (!isset(funVal)) { ;NOTE 未定义修改函数，则返回arrVal
            arrVal := []
            for cell in rng
                arrVal.push(hyf_delete0(cell))
            return arrVal
        }
        xl := rng.application
        xl.ScreenUpdating := false
        for cell in rng {
            if (cell.MergeCells && cell.address != cell.MergeArea.cells(1).address)
                continue
            if (funVal is map)
                cell.value := funVal.get(cell.value, cell.value)
            else
                cell.value := funVal(cell)
        }
        xl.ScreenUpdating := true
        return
    }
    if (!isset(funVal)) {
        funVal := hyf_delete0
    } else if (funVal is integer && funVal == 0) {
        funVal := x=>x
    }
    ;单单元格
    if (rng.cells.count == 1) {
        if (bWrite) {
            if (funVal is map)
                rng.value := funVal.get(rng.value, rng.value)
            else
                rng.value := funVal(rng.text)
        } else {
            arrA := ComObjArray(12, 1, 1)
            if (funVal is map)
                arrA[0,0] := funVal.get(arrA[0,0], arrA[0,0])
            else
                arrA[0,0] := funVal(rng)
            return arrA
        }
        return
    }
    ;多单元格
    arrV := rng.value
    loop(arrV.MaxIndex(1)) {
        r := A_Index
        loop(arrV.MaxIndex(2)) {
            if (funVal is map)
                arrV[r,A_Index] := funVal.get(arrV[r,A_Index], arrV[r,A_Index])
            ;else if (fillUp && arrV[r,A_Index]=="") ;需要填充空白单元格
            ;    arrV[r,A_Index] := arrV[r-1,A_Index]
            else
                arrV[r,A_Index] := funVal(arrV[r,A_Index])
        }
    }
    if (bWrite)
        rng.value := arrV
    return arrV
}

;普通数组转VBA标准数组
;一维时，如果 tp 则转成多行
;二维时，如果 tp 0=arr2[1]当列数 1=遍历获取最大列数 >1=直接当列数 
hyf_arr2arrayA(arr2, tp:=false, cellWrite:=unset) {
    if (!arr2.length)
        return
    rs := arr2.length
    if (isobject(arr2[1])) {
        ;获取列数 cs
        cs := 0
        if (tp) {
            if (tp > 1) { ;直接当列数
                cs := tp
            } else {
                for v in arr2 {
                    if (v.length > cs)
                        cs := v.length
                }
            }
        } else {
            cs := arr2[1].length
        }
        arrA := ComObjArray(12, rs, cs)
        loop(rs) {
            i := A_Index
            loop(cs) {
                try
                    arrA[i-1,A_Index-1] := arr2[i][A_Index]
                catch
                    msgbox(i . "`n" . A_Index . "`n" . arr2[i][A_Index])
            }
        }
    } else { ;单维
        if (tp) {
            arrA := ComObjArray(12, rs, 1)
            loop(rs)
                arrA[A_Index-1,0] := arr2[A_Index]
        } else {
            arrA := ComObjArray(12, rs)
            loop(rs)
                arrA[A_Index-1] := arr2[A_Index]
        }
    }
    if (isset(cellWrite)) {
        if !ProcessExist("excel.exe")
            return arrA
        if (type(cellWrite) != "ComObject")
            cellWrite := ox().ActiveCell
        hyf_arrayA2cell(hyf_arr2arrayA(arr2, tp), cellWrite)
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
                SplitPath(wb.name,,,, &fnn)
                if (wb.name = fn || fnn = fn) { ;为什么要 fnn？
                    if (bActive) {
                        WinActivate(hwnd)
                        WinMaximize
                    }
                    return wb
                }
            }
        }
    }
    ;打开文件
    wb := ComObject("Excel.application").workbooks.open(fp)
    if (bActive) {
        wb.parent.visible := -1
        WinWait(wb.application)
        WinActivate(wb.application)
    }
    return wb
}

;获取类|实例的所有方法和属性
;名称参考python
;hyf_dir(_Excel, (p)=>p~="^__")
hyf_dir(cls, funFilter:="", bShowValue:=false) {
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
;简单的直接用 msgbox(json.stringify(cls, 4))
;funFilter
;   隐藏 __开头的内置方法 (x)=>!(x~="^__")
hyf_props(cls, funFilter:=unset) {
    obj := map()
    for prop in cls.OwnProps() {
        if (isset(funFilter)) {
            if (!funFilter(prop))
                continue
        }
        OutputDebug(format("i#{1} {2}:{3} prop={4} {5}", A_LineFile,A_LineNumber,A_ThisFunc,prop,json.stringify(cls.%prop%, 4)))
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
*     mode     [in, opt] - Defaults to one(1) which uses "Rpcrt4\UuidCreate",
*                          otherwise specify two(2) for "UuidCreateSequential"
*                          or zero(0) for "UuidCreateNil".
*     format   [in, opt] - if "format" contains an opening brace("{"), output
*                          will be wrapped in braces. Include the letter "U" to
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
;hyf_pipeRun("msgbox(1)")
;WM_COPYDATA_send("aaa")
;TODO  "`n`n" 这种字符串不兼容
;也可见 DynaRun.ahk https://www.autohotkey.com/board/topic/56141-ahkv2-dynarun-run-autohotkey-process-dynamically
;来源 run 的帮助文件
;是单独的文件运行，所以不支持本脚本的代码，可用 _Do.doAny()
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
        strCode := format("#SingleInstance Force`n#NoTrayIcon`n{1}", code)
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

;-----------------------------------交互-----------------------------------
;提供多种显示方式见 _Do.showBySelect

;直接选择其中一项，NOTE 支持输入(优先)
;适合选择项较少的场景
hyf_selectSingle(arr, title:="") {
    oGui := gui("+resize +AlwaysOnTop +Border +LastFound +ToolWindow")
    if (title != "")
        oGui.title := title
    oGui.OnEvent("escape", doEscape)
    oGui.OnEvent("close", doEscape)
    oGui.SetFont("s16")
    ;if (sTitle != "")
    ;    oGui.AddText("x10", sTitle . "`n")
    for v in arr {
        if (A_Index == 1)
            oGui.AddRadio("checked", v)
        else
            oGui.AddRadio(, v)
    }
    ctlEdit := oGui.AddEdit("", "")
    oGui.AddButton("default", "确认").OnEvent("click", funDo)
    oGui.show()
    res := ""
    WinWaitClose(oGui)
    return res
    funDo(btn, p*) {
        if (ctlEdit.value != "") {
            res := ctlEdit.value
        } else {
            for ctl in oGui {
                if (ctl.type == "Radio" && ctl.value) {
                    res := ctl.text
                    break
                }
            }
        }
        oGui.destroy()
        return res
    }
    doEscape(oGui) => oGui.destroy()
}

;defButton是默认按钮前面的text内容
;仅支持选择，不支持搜索，不支持输入
;返回二维数组(因为支持多选)
;arr2 支持 ao
;arrField
;   1 从arr2第1项获取(如果是数组则删除第1项)
;   0 以1-n作为标题
;   arr 直接用
hyf_GuiListView(arr2, arrField:=0, title:="", arrWidth:=unset) {
    if (!isobject(arr2))
        return
    if (!arr2.length)
        return
    if (arr2.length == 1) { ;NOTE 仅一项则直接弹框
        hyf_msgbox(arr2[1], title)
        return
    }
    ;处理arr2
    if !(arr2[1] is array) {
        if (!isobject(arr2[1])) {
            for v in arr2
                arr2[A_Index] := [v]
        } else if (arr2[1] is map) { ;NOTE map
            ;获取标题
            if (arrField == 1) {
                arrField := arr2[1].keys()
            }
            ;map转数组
            for obj in arr2 {
                i := A_Index
                arr2[i] := obj.values()
            }
        }
    }
    oGui := gui("+resize +AlwaysOnTop +Border +LastFound +ToolWindow")
    oGui.BackColor := "222222"
    oGui.title := format("{1}", title)
    oGui.SetFont("s13")
    oGui.OnEvent("escape",doEscape)
    if (arrField is integer) {
        switch arrField {
            case 1: arrField := arr2.RemoveAt(1)
            case 0: ;自动生成
                arrField := []
                for v in arr2[1]
                    arrField.push(A_Index)
        }
    }
    rs := min(arr2.length, 40)
    w := 1200.fromDPI()
    oLv := oGui.AddListView(format("VScroll count grid checked w{1} r{2}", w-50,rs+2), arrField)
    oLv.name := "lv"
    ;oLv.OnEvent("DoubleClick", do)
    oLv.opt("-Redraw")
    for k, arr in arr2
        oLv.add(, arr*)
    ;设置宽度
    cntCol := oLv.GetCount("column")
    if (isset(arrWidth)) {
        loop(cntCol)
            oLv.ModifyCol(A_Index, arrWidth is integer ? arrWidth : arrWidth[A_Index])
    } else {
        ;oLv.ModifyCol(A_Index, 1000//cntCol)
        oLv.ModifyCol()
    }
    oLv.opt("+Redraw")
    arrRes := []
    oGui.AddButton("default center section", "确定").OnEvent("click", btnClick)
    oGui.AddButton("center ys", "全选").OnEvent("click", btnSelectAll)
    oGui.AddButton("center ys", "全不选").OnEvent("click", btnSelectNone)
    oGui.AddStatusBar(, format("共有{1}项结果", arr2.length))
    oGui.show(format("w{1} center", w))
    LVICE := LVICE_XXS(oLV)
    WinWaitClose(oGui)
    return arrRes
    doEscape(oGui) => oGui.destroy()
    do(oLV, r, status:=unset) { ;NOTE 要做的事
        ;if (isset(status)) {
        ;    ;获取当前行整行内容
        ;    ;GuiControlGet
        ;    if (status) {
        ;        arrRes.push([])
        ;        loop(oLv.GetCount("column"))
        ;            arrRes[-1].push(oLv.GetText(r, A_Index))
        ;    } else {
        ;        v := oLv.GetText(r,1)
        ;        for arr in arrRes {
        ;            if (v = arr[1]) ;可能数字和字符串比较
        ;                arrRes.RemoveAt(A_Index)
        ;        }
        ;    }
        ;} else { ;比如双击
        arrRes := [[]] ;返回格式相同
        loop(oLv.GetCount("column"))
            arrRes[-1].push(oLv.GetText(r, A_Index))
        oLV.gui.destroy()
        ;}
        ;做任何事
        ;设置返回值
        ;oGui.destroy()
    }
    btnSelectAll(ctl, p*) {
        oLV := ctl.gui["lv"]
        loop(oLV.GetCount())
            oLV.modify(A_Index, "+check")
    }
    btnSelectNone(ctl, p*) {
        oLV := ctl.gui["lv"]
        loop(oLV.GetCount())
            oLV.modify(A_Index, "-check")
    }
    btnClick(ctl, param*) {
        oLV := ctl.gui["lv"]
        loop(oLV.GetCount()) {
            if (SendMessage(0x102C, A_Index-1, 0x2000, oLV.hwnd)) {
                r := A_Index
                arrRes.push([])
                loop(oLv.GetCount("column"))
                    arrRes[-1].push(oLv.GetText(r, A_Index))
            }
        }
        ;msgbox(json.stringify(arrRes, 4))
        ctl.gui.destroy()
    }
}

;去重或生成拼音都是根据 subArr[indexKey]
;indexKey 主值在 subArr 的序号(用来搜索和生成拼音)
;sPyAndIndex
;   第1位：0=不添加拼音 1=已有拼音(无需添加，但要匹配搜索) 2=添加拼音
;   第2位：0=不push序号 1=要
;bDistinct 是否去重
;unicodeKey，去重和objRaw用
;返回 subArr
hyf_selectByArr(arr2, indexKey:=1, sPyAndIndex:="21", bDistinct:=false, uniqueKey:=1) {
    if (!arr2.length)
        return []
    bAddIndex := (substr(sPyAndIndex, 1, 2) == "1")
    ;1. arrNew 转成二维，NOTE 并可能在每项末尾添加 A_Index
    if (!isobject(arr2[1])) {
        arrNew := bAddIndex ? arr2.map((v)=>[v, A_Index]) : arr2.map((v)=>[v])
    } else {
        if (bAddIndex)
            arr2.map((v)=>v.push(A_Index))
        arrNew := arr2
    }
    ;   去重(根据 subArr[1])
    if (bDistinct) {
        arrTmp := deepclone(arrNew)
        arrNew := []
        obj := map()
        for arr in arrTmp {
            if obj.has(arr[uniqueKey])
                continue
            obj[arr[uniqueKey]] := 1
            arrNew.push(arr)
        }
    }
    ;记录 objRaw 最终返回用(因为有些对象不会在 ListView 显示)
    objRaw := map()
    for subArr in arrNew
        objRaw[subArr[uniqueKey]] := subArr
    ;添加标题
    arrField := ["序号"]
    loop(arrNew[1].length)
        arrField.push("v" . string(A_Index))
    ;添加拼音
    if (substr(sPyAndIndex,1,1) == "2") {
        arrField.push("拼音")
        sFile := fileread("d:\BB\lib\汉字拼音对照表.txt", "utf-8")
        for arr in arrNew
            arr.push(pinyin(arr[indexKey]))
    }
    ;OutputDebug(format("i#{1} {2}:arrNew={3}", A_LineFile,A_LineNumber,arrNew.toTable(",")))
    ;添加到 Gui
    oGui := gui("+resize +AlwaysOnTop +Border +LastFound +ToolWindow")
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
    oLv := oGui.AddListView("VScroll vlv1 xs r20 cRed w1400", arrField) ;NOTE selectN 要用 lv1 获取控件，不要用 oLv(影响释放)
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
    resGui := []
    WinWaitActive(oGui)
    try { ;可能gui还没加载完成，按键已经触发了 oGui.destroy()
        ctl := ControlGetFocus(oGui) || WinGetID()
    } catch {
        return resGui
    } else {
        PostMessage(0x50,, dllcall("LoadKeyboardLayout", "str","04090409", "uint",1), ctl)
        OnMessage(0x100, selectN)
        WinWaitClose(oGui)
        return resGui
    }
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
        idxMatch := (substr(sPyAndIndex,1,1)!="0" && sInput ~= "^[[:ascii:]]+$") ? -1 : 1 ;-1是末位字段
        i := 1
        OutputDebug(format("i#{1} {2}:sInput={3} idxMatch={4}", A_LineFile,A_LineNumber,sInput,idxMatch))
        for subArr in arrNew {
            if (sInput=="" || instr(subArr[idxMatch], sInput)) {
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
        ;loop(arrNew[1].length)
        ;    resGui.push(oLv.GetText(r, A_Index+1))
        ;OutputDebug(format("d#{1} {2}:{3} resGui={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(resGui,4)))
        ;做任何事
        ;设置返回值
        key := oLv.GetText(r, uniqueKey+1)
        OutputDebug(format("w#{1} {2}:r={3} indexKey={4} key={5}", A_LineFile,A_LineNumber,r,indexKey,key))
        resGui := objRaw[key] ;NOTE 有些是对象不是文本，要求key不能有重复值
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

;showAll 没输入时是否显示
hyf_selectByTooltip(arr2, showAll:=false) {
    arrKey := []
    loop {
        if (!arrKey.length) {
            if (showAll)
                tipForSelect()
            else
                tipForSelect("等待按键中")
            arrRes := arr2
        } else {
            arrRes := tipForSelect()
        }
        if (arrRes.length == 1) { ;单结果返回
            tooltip
            return arrRes[1]
        }
        ;更新 arrKey
        key := hyf_input()
        switch key, false {
            case "escape":
                tooltip
                exit
            case "BackSpace":
                arrKey.pop()
            default:
                if (strlen(key) == 1) {
                    arrKey.push(key)
                } else if (key ~= "^F\d+$") {
                    tooltip
                    return arrRes[integer(substr(key,2,1))]
                }
        }
    }
    ;自动根据 arrKey 转成 arr
    tipForSelect(res:="") {
        if (res != "") {
            tooltip(res, 20, 20)
            return
        }
        sKeys := "".join(arrKey)
        ;msgbox(sKeys . "`n" . json.stringify(arrKey, 4))
        ;获取 arr
        arr := []
        for a in arr2 {
            if (instr(a[2],sKeys)) {
                if (a[2] = sKeys) ;相同的优先前第1个
                    arr.insertat(1, a[1])
                else
                    arr.push(a[1])
            }
        }
        if (arrRes.length == 0) { ;NOTE 没结果，则回滚
            arrKey.pop()
            sKeys := "".join(arrKey)
            arr := []
            for a in arr2 {
                if (instr(a[2],sKeys)) {
                    if (a[2] = sKeys) ;相同的优先前第1个
                        arr.insertat(1, a[1])
                    else
                        arr.push(a[1])
                }
            }
        }
        for s in arr {
            i := (A_Index <= 12) ? "F" . string(A_Index) : A_Index.toABCD(13)
            res .= format("{1}`t{2}`n", i,s)
        }
        ;msgbox(json.stringify(arr, 4))
        tooltip(res, 20, 20)
        return arr
    }
}

;defButton是默认按钮前面的text内容
;hyf_GuiMsgbox(map("a",132,"b",22), "aaa")
hyf_GuiMsgbox(obj, title:="By hyaray", defButton:="", fun:=unset, oGui:="", times:=0) {
    if (!isobject(obj))
        return
    if (obj is array && !obj.length)
        return
    if (obj is map && !obj.count)
        return
    if (times == 0) {
        oGui := gui("+resize +OwnDialogs +AlwaysOnTop +Border +LastFound +ToolWindow")
        oGui.title := title
        oGui.SetFont("cBlue s12")
        oGui.OnEvent("escape",doEscape)
    }
    funDo := isset(fun) ? fun : hyf_GuiMsgbox_1
    optButton := "ys yp-5"
    wLabel := 600.fromDPI()
    rs := 20
    for k, v in obj {
        x := times*30 + 10 ;缩进30，离左边缘10
        if (mod(A_Index, rs) == 1)
            oGui.AddText(format("section x{1} y10", x+wLabel*((A_Index-1)//rs)), k).OnEvent("click", funDo)
        else
            oGui.AddText("section xs", k).OnEvent("click", funDo)
        if (isobject(v)) {
            if (v is ComValue) {
                oGui.AddButton(optButton, "ComValue").OnEvent("click", funDo)
            } else if (v is array) {
                switch v.length {
                    case 1,2:
                        oGui.AddText("ys yp", v[1]).OnEvent("click", funDo)
                        oGui.AddButton(optButton, v[-1]).OnEvent("click", funDo)
                    default:
                        %A_ThisFunc%(v, title, defButton, funDo, oGui, times+1)
                }
            } else {
                %A_ThisFunc%(v, title, defButton, funDo, oGui, times+1)
            }
        } else if (defButton != "") && (v = defButton) {
            oGui.AddButton(optButton . " cRed default", v).OnEvent("click", funDo)
        } else {
            try
                oGui.AddButton(optButton, v).OnEvent("click", funDo)
            catch
                oGui.AddButton(optButton, v)
        }
    }
    if (times = 0)
        oGui.show("center")
    return oGui
    hyf_GuiMsgbox_1(ctl, p*) {
        if (GetKeyState("LCtrl", "P"))
            hyf_addClip(ctl.text)
        else
            hyf_setClip(ctl.text)
        ;ctl.gui.destroy() ;NOTE
    }
    doEscape(oGui) => oGui.destroy()
}

hyf_obj2str(obj, char:="`n", level:=0) {
    static t := "", s := ""
    if (level)
        t .= A_Tab ;前置tab显示级数
    else
        t := "", s := "" ;防止多次运行时结果叠加
    if (!isobject(obj))
        return obj ;"非对象，值为`n" . obj
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

hyf_msgbox(obj, str:="", char:="`n", n:=0) {
    if (str != "")
        return msgbox(format("{1}`n{2}", str,hyf_obj2str(obj,char)),,0x40000+n)
    else
        return msgbox(hyf_obj2str(obj,char),,0x40000+n)
}

hyf_objToolTip(obj, str:="", t:=0) {
    res := str ? str . "`n" . hyf_obj2str(obj, "`n") : hyf_obj2str(obj, "`n")
    if (!t) {
        tooltip(res)
        hyf_input()
        tooltip
    } else {
        tooltip(res)
        SetTimer(tooltip, -t*1000)
    }
}

;tooltip 后等待任意按键结束
hyf_tooltipWait(str, x:=unset, y:=unset) {
    if (isset(x))
        tooltip(str, x, y)
    else
        tooltip(str)
    hyf_input()
    tooltip
}

;arrIn 如果是一维，会自动转成二维(以F1-F12当key)
;arrIn := [
;   ["J","jpg"],
;   ["P","png"],
;]
;arrRes := hyf_tooltipAsMenu(arrIn)
;if (!arrRes.length)
;    return
;msgbox(json.stringify(arrRes, 4))
hyf_tooltipAsMenu(arrIn, strTip:="", x:=8, y:=8) {
    static level := 19
    if (!arrIn.length)
        return []
    if !isobject(arrIn[1]) { ;一维转成[hot, item]
        for k, v in arrIn
            arrIn[k] := [k.toABCD(), v]
    }
    if (arrIn.length == 1)
        return arrIn[1]
    strTip := (strTip!="") ? strTip . "`n`n" : ""
    tooltip(strTip . arr2str(arrIn), x, y, level)
    arrKeys := [] ;按键列表
    loop {
        key := hyf_input(true)
        switch key, false {
            case "escape":
                tooltip(,,, level)
                return []
            case "space": ;TODO 接受空格
                arrKeys.push(A_Space)
            default:
                switch strlen(key) {
                    case 1:
                        arrKeys.push(StrUpper(key))
                    default:
                        arrKeys.push(format("{{1}}", key))
                }
        }
        ;通过 arrKeys 获取筛选后的内容 arrThis
        arrThis := arrIn
        for keyLoop in arrKeys
            arrThis := getArrByKey(arrThis, keyLoop)
        ;单结果则直接返回，否则继续 tooltip
        if (arrThis.length == 0) {
            return []
        } else if (arrThis.length == 1) {
            tooltip(,,, level)
            return arrThis[1]
        } else {
            tooltip(strTip . arr2str(arrThis), x, y, level)
        }
    }
    getArrByKey(arr, key:="") { ;根据 key 获取子arr
        if (key == "")
            return arr
        ;hyf_msgbox(arr, key)
        for v in arr {
            if (v[1] = key) ;TODO 多项
                return [v]
        }
        ;没结果退出
        tooltip(,x,y, level)
        return []
    }
    arr2str(arr) { ;arr 根据 sKey 转为字符串
        str := ""
        for arrSub in arr
            str .= format("({1})`t{2}`n", arrSub[1],arrSub[2])
        return str
    }
}

;网址，编码, 请求方式，post数据(NOTE 可能不好用)
;https://docs.microsoft.com/en-us/windows/win32/winhttp/iwinhttprequest-send
;form-data https://www.autohotkey.com/boards/viewtopic.php?p=480935
hyf_post(url, objData:="", headers:="application/x-www-form-urlencoded", Encoding:="") {
    rst := ComObject("WinHttp.WinHttpRequest.5.1")
    rst.open("POST", url)
    if (isobject(headers)) {
        for k, v in headers {
            if (v)
                rst.SetRequestHeader(k, v)
        }
        headers := headers.get("Content-Type", "") ;修改 headers 用于判断 isLikeJson
    } else if (headers != "") {
        rst.SetRequestHeader("Content-Type", headers)
    }
    isLikeJson := (headers ~= "^application\/(json|octet-stream)$")
    if (isobject(objData)) {
        if (isLikeJson) {
            rst.send(json.stringify(objData))
        } else { ; if (headers == "application/x-www-form-urlencoded")
            param := ""
            for k, v in objData {
                if (v is integer)
                    param .= format("&{1}={2}", k,v)
                else
                    param .= format("&{1}={2}", k,v.uriEncode()) ;NOTE 要转编码
            }
            ;OutputDebug(format("d#{1} {2}:param={3}", A_LineFile,A_LineNumber,param))
            param := substr(param, 2)
            rst.send(param)
        }
    } else {
        rst.send()
    }
    ;rst.WaitForResponse(objData.has("timeout") ? objData.timeout : -1)
    ; rsy.option(2) := nPage ;Codepage:nPage
    if (Encoding && rst.ResponseBody) {
        oADO := ComObject("adodb.stream")
        oADO.Type := 1
        oADO.Mode := 3
        oADO.Open()
        oADO.Write(rst.ResponseBody)
        oADO.Position := 0
        oADO.Type := 2
        oADO.Charset := Encoding
        res := oADO.ReadText()
        oADO.Close()
        return res
    }
    return rst.ResponseText
}

;NOTE 最通用的闭包
;目的是让所有 fun 【延迟执行】，并把结果当作 funmain 的参数
;hyf_closure_funs((p*)=>msgbox(json.stringify(p,4)), strlen.bind("aa"), strlen.bind("aaa"))()
;hyf_closure_funs(ObjBindMethod(cls,"method"), strlen.bind("aa"), strlen.bind("aaa"))()
;hyf_closure_funs(SendText, strlen.bind("aa"), strlen.bind("aaa"))()
hyf_closure_funs(funmain, fun*) => (p*)=>funmain(fun.map(f=>(f is func)?f():f)*)

;目的是【绑定参数】
;_(y) => ((x)=>(x + y))
;fun := _(2) ;NOTE 绑定 y=2
;合并 fun := (y)=>((x)=>(x + y))(2)

;hyf_closure_strs((p*)=>msgbox(json.stringify(p,4)), "aa", "aaa")()
hyf_closure_strs(funmain, str*) => (p*)=>funmain(str*)

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
;         arrRes.push(funcObj(v))
;     return arrRes
; }

; mapObj(funcObj, obj) {
;     objRes := []
;     for k, v in obj
;         objRes[k] := funcObj(v)
;     return objRes
; }

reduce(fun, arr, v0:="") {
    if (arr.length == 1) {
        if (v0 != "")
            return fun(v0, arr[1])
    }
    res := (v0 != "") ? fun(v0, arr[1]) : arr[1]
    loop(arr.length-1)
        res := fun(res, arr[A_Index+1])
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

;不考虑DPI，_Mouse.clickR 会考虑DPI
clickR(x, y, cnt:=1, checkCursor:=unset, waitDisappear:=false, ms:=5000) {
    MouseMove(x, y, 0, "R")
    sleep(20)
    click(cnt)
    if (isset(checkCursor)) {
        if (checkCursor is string) {
            MouseWait(checkCursor, true)
        } else if (isobject(checkCursor)) {
            endtime := A_TickCount + ms
            loop {
                CaretGetPos(&x, &y)
                if (checkCursor(x,y))
                    return true
                sleep(200)
                if (A_TickCount > endtime)
                    return false
            }
        }
    }
    return true
}

MouseWait(tp, waitDisappear:=false, ms:=5000) {
    endTime := A_TickCount + ms
    ;等待出现
    ;tooltip("等待鼠标形状【出现】`n" . tp)
    loop {
        if (A_Cursor == tp) {
            OutputDebug(format("d#{1} {2}:{3} waitA done {4} tp={5} A_Cursor={6}", A_LineFile,A_LineNumber,A_ThisFunc,A_Index,tp,A_Cursor))
            break
        }
        if (A_TickCount > endtime) {
            OutputDebug(format("i#{1} {2}:{3} waitA TimeOut {4} tp={5} A_Cursor={6}", A_LineFile,A_LineNumber,A_ThisFunc,A_Index,tp,A_Cursor))
            return false
        }
        if (A_Cursor != tp) {
            OutputDebug(format("i#{1} {2}:{3} waitA {4} tp={5} A_Cursor={6}", A_LineFile,A_LineNumber,A_ThisFunc,A_Index,tp,A_Cursor))
            sleep(100)
        }
    }
    ;等待结束
    if (waitDisappear) {
        endTime := A_TickCount + ms
        loop {
            if (A_Cursor != tp) {
                OutputDebug(format("d#{1} {2}:{3} waitB done {4} tp={5} A_Cursor={6}", A_LineFile,A_LineNumber,A_ThisFunc,A_Index,tp,A_Cursor))
                break
            }
            if (A_TickCount > endtime) {
                OutputDebug(format("i#{1} {2}:{3} waitB TimeOut {4} tp={5} A_Cursor={6}", A_LineFile,A_LineNumber,A_ThisFunc,A_Index,tp,A_Cursor))
                return false
            }
            if (A_Cursor = tp) {
                OutputDebug(format("i#{1} {2}:{3} waitB {4} tp={5} A_Cursor={6}", A_LineFile,A_LineNumber,A_ThisFunc,A_Index,tp,A_Cursor))
                sleep(100)
            }
        }
    }
    ;tooltip
    return true
}
