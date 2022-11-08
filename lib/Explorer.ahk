;有些 windows 错误是通过 explorer.exe 通知的，所以写在这里
class Explorer {

    static get(winTitle:="ahk_class CabinetWClass") {
        idA := WinGetID(winTitle)
        for wind in ComObject("shell.Application").Windows {
            if (wind.hwnd == idA)
                return wind
        }
    }

    ;NOTE 只支持 Explorer 的保存对话框，其他软件不支持
    static dir(winTitle:="") {
        idSave := WinGetID(winTitle)
        for wind in ComObject("Shell.Application").Windows {
            if (wind.hWnd == idSave)
                return wind.Document.folder.self.path
        }
    }

    ;打印机→管理纸张
    static print_papers() => UIA.FindElement(WinGetID("A"), "Button", "打印服务器属性").ClickByMouse()
    ;static print_noSleep()
    
    static print_addPaper() {
        if WinActive("打印服务器 属性") { ;添加纸张
            ;24.1*9.3
            ControlSetChecked(true, "Button3")
            sleep(100)
            ControlFocus("Edit2")
            SendMessage(EM_SETSEL:=0xB1, 0, -1, "Edit2")
            msgbox("找不到纸如何处理？",,0x40000)
        }
    }

    ;修改目录
    static setDir(dn) {
        if (wind := this.get())
            wind.navigate("file:///" . dn)
        else
            this.open(dn)
    }

    ;定位并选中某文件
    static open(fp) => run(format('explorer /select, "{1}"', fp)) ;select后面的逗号不能省

    ;所有选中的文件路径
    static getArrSelection(winTitle:="ahk_class CabinetWClass") {
        idA := WinGetID(winTitle)
        cls := WinGetClass(winTitle)
        arr := []
        if (cls ~= "(Cabinet|Explore)WClass") { ;主界面
            for item in this.get(winTitle).document.SelectedItems
                arr.push(item.path)
        } else if (cls ~= "Progman|WorkerW") {
            loop parse, ListViewGetContent(,"SysListView321", "ahk_class " . cls), "`n", "`r"
                arr.push(A_Desktop . "\" . A_LoopField)
        }
        return arr
    }

    ;选择特定文件
    static select() {
        sfv := this.get().document
        for item in sfv.folder.items {
            if (1)
                sfv.SelectItem(item, true)
        }
    }

    ;遍历当前目录
    static getItem(winTitle:="A") {
        for item in this.get(winTitle).document.folder.items {
            msgbox(item.name . "`n" . item.type)
            ;if (item.name = vItem)
            ;{
            ;objWin.document.SelectItem(item, dwFlags)
            ;return
            ;}
        }
    }

    ;traverse() ;遍历 ?
    ;{
        ;a := []
        ;for o in ComObject("Shell.application").Windows
        ;{
            ;p := RegExReplace(o.LocationURL, "^file:\/+") ;去除前面的file:///
            ;a.push(StrReplace(p, "/", "\")) ;替换/为\
        ;}
        ;return a
    ;}

    ;要扫描并修复**
    ;原因：电源供电不足+没有安全插拔造成的
    ;TODO 不一定有效
    static errorUSBScan() {
        "sc stop stisvc".runCmdHide() ;关闭 ShellHWDetection 要先关这个
        "sc stop ShellHWDetection".runCmdHide()
        "sc config ShellHWDetection start= disabled".runCmdHide() ;disabled前必须带空格
    }

    class dialog {

        ;获取当前完整路径
        ;NOTE 若获取不到扩展名，则返回空字符串
        static fp(winTitle:="") {
            fn := this.fn(winTitle)
            if (fn != "") {
                dn := this.dir(winTitle)
                return format("{1}\{2}", dn,fn)
            }
            return ""
        }

        ;保存对话框 #32770
        static dir(winTitle:="") { ;获取保存对话框的目录路径
            if (!WinExist(winTitle) || WinGetClass() != "#32770")
                return
            for ctl in WinGetControls() {
                if (substr(ctl, 1, 15) != "ToolbarWindow32")
                    continue
                str := ControlGetText(ctl)
                if (substr(str,1,3) == "地址:") {
                    res := substr(str,5)
                    obj := map(
                        "桌面", A_Desktop,
                        "文档", A_MyDocuments,
                    )
                    return obj.has(res) ? obj[res] : res
                }
            }
            ;不支持其他程序的【保存】窗口
            ;return substr(this.get(WinGetID()).LocationURL, 9)
        }

        ;获取文件名
        ;NOTE 若获取不到扩展名，则返回空字符串
        static fn(winTitle:="") {
            fn := ControlGetText("Edit1", winTitle)
            if (fn ~= "\.\w+$") { ;TODO 有类似扩展名则判定为文件名
                return fn
            } else {
                ext := this.ext(winTitle)
                if (ext != "")
                    return format("{1}.{2}", fn,ext)
                else ;NOTE 没有扩展名，则返回空
                    return ""
            }
        }

        ;获取扩展名
        static ext(winTitle:="") {
            str := ControlGetText("ComboBox2", winTitle)
            if (str ~= "\*\.\w+\)$")
                return rtrim(RegExReplace(str, ".*\."), ")")
            else ;TODO 待完善
                return ""
        }

        ;static dialogErrorText() {
        ;    elWin := UIA.ElementFromHandle(WinGetID())
        ;    cond := UIA.CreatePropertyCondition("ControlType", "Text")
        ;    el := elWin.FindFirst(cond)
        ;    return el.CurrentName
        ;}

    }
}
