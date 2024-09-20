;有些 windows 错误是通过 explorer.exe 通知的，所以写在这里
class Explorer {

    ;打印机→管理纸张
    static print_papers() => UIA.FindControl("Button", "打印服务器属性").ClickByMouse()
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

    static get() {
        hwnd := WinGetID("A")
        return Explorer(hwnd).dir()
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

    __new(hwnd:=0) {
        if (!hwnd)
            hwnd := WinActive("ahk_exe explorer.exe")
        else if (hwnd is string)
            hwnd := WinExist(hwnd)
        this.hwnd := hwnd
        for wind in ComObject("Shell.Application").Windows {
            if (wind.hwnd == hwnd) {
                OutputDebug(format("i#{1} {2}:{3} get win={4}", A_LineFile.fn(),A_LineNumber,A_ThisFunc,this.hwnd))
                this.win := wind
                return
            }
        }
    }

    ;NOTE 只支持 Explorer 的保存对话框，其他软件不支持
    dir() => this.win.document.folder.self.path

    ;所有选中的文件路径
    arrSelectFilePath() {
        cls := WinGetClass(this.hwnd)
        arr := []
        if (cls ~= "(Cabinet|Explore)WClass") { ;主界面
            for item in this.win.document.SelectedItems
                arr.push(item.path)
        } else if (cls ~= "Progman|WorkerW") {
            loop parse, ListViewGetContent(,"SysListView321", "ahk_class " . cls), "`n", "`r"
                arr.push(A_Desktop . "\" . A_LoopField)
        }
        return arr
    }

    class dialog {

        __new(hwnd) {
            if (hwnd is string)
                hwnd := WinExist(hwnd)
            this.hwnd := hwnd
            OutputDebug(format("i#{1} {2}:{3} this.hwnd={4}", A_LineFile,A_LineNumber,A_ThisFunc,this.hwnd))
            for wind in ComObject("Shell.Application").Windows {
                if (wind.hwnd == hwnd) {
                    this.win := wind
                    return
                }
            }
        }

        ;获取文件名
        ;NOTE 若获取不到扩展名，则返回空字符串
        fn() {
            fn := ControlGetText("Edit1", this.hwnd)
            OutputDebug(format("i#{1} {2}:{3} fn={4}", A_LineFile,A_LineNumber,A_ThisFunc,fn))
            if (fn ~= "\.\w+$") { ;TODO 有类似扩展名则判定为文件名
                return fn
            } else {
                ext := this.ext(this.hwnd)
                if (ext != "")
                    return format("{1}.{2}", fn,ext)
                else ;NOTE 没有扩展名，则返回空
                    return ""
            }
        }

        ;获取扩展名
        ext() {
            str := ControlGetText("ComboBox2", this.hwnd)
            if (str ~= "\*\.\w+\)$") {
                ext := rtrim(RegExReplace(str, ".*\."), ")")
                OutputDebug(format("i#{1} {2}:{3} ext={4}", A_LineFile,A_LineNumber,A_ThisFunc,ext))
                return ext
            } ;TODO 待完善
        }

        ;获取当前完整路径
        ;NOTE 若获取不到扩展名，则返回空字符串
        fp() {
            fn := this.fn()
            if (fn != "") {
                dn := this.dir()
                fp := format("{1}\{2}", dn,fn)
                OutputDebug(format("i#{1} {2}:{3} fp={4}", A_LineFile,A_LineNumber,A_ThisFunc,fp))
                return fp
            }
            return ""
        }

        ;获取保存对话框的目录路径
        dir() {
            if (!WinExist(this.hwnd) || WinGetClass() != "#32770")
                return
            for ctl in WinGetControls() {
                if (substr(ctl, 1, 15) != "ToolbarWindow32")
                    continue
                str := ControlGetText(ctl)
                if (substr(str,1,3) == "地址:") {
                    res := substr(str,5)
                    switch res {
                        case "桌面": return A_Desktop
                        case "文档": return A_MyDocuments
                        default: return res
                    }
                }
            }
            ;不支持其他程序的【保存】窗口
            ;return substr(this.get(WinGetID()).LocationURL, 9)
        }

        ;static dialogErrorText() {
        ;    elWin := UIA.ElementFromHandle(WinGetID())
        ;    cond := UIA.CreatePropertyCondition("ControlType", "Text")
        ;    el := elWin.FindFirst(cond)
        ;    return el.CurrentName
        ;}

    }
}
