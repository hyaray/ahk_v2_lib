﻿class _CB extends _CDP {

    ;只是为了方便打开网页
    __new(url:="", fp:=unset, funAfterDo:=unset) {
        if (url != "") {
            if (isset(fp))
                oCB := _CDP.smartGet(fp)
            else
                oCB := _CDP.smartGet("chrome")
            oCB.tabOpenLink(url, funAfterDo?)
        }
    }

    static onekey() {
        if (WinActive("ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe")) {
            WinMinimize ;防止左下角的网址残留
            WinHide
        } else {
            _CDP.smartGet("chrome").tabOpenLink()
        }
    }

    ;网页内容的元素
    static getElementOfMain(key:=unset) {
        elWin := UIA.ElementFromHandle(WinActive("A"), true)
        el := elWin.FindFirst(UIA.CreatePropertyCondition("ControlType", "ToolBar"))
        el := el.GetParent().GetNext()
        if (!isset(key))
            return el
        switch key {
            case "y": return el.GetBoundingRectangle()[2]
            case "mark": return el
            default: return el
        }
        return el
    }

    ;ctrl-f查找
    static search(str)=>sendEx("{escape}{ctrl down}f{ctrl up}", 100, str)

    ;扩展所在目录
    static getExtensionDir(extName) {
        switch extName {
            case "FireShot": extID := "mcbpblocgmgfnpjjppndjkmgjaogfceg"
            case "surfingkeys": extID := "gfbliohnnapiefjpjlpjnehglfpaknnc"
            case "SwitchyOmega": extID := "padekgcemlokbadohgkifijomclgjgif"
            case "tampermonkey": extID := "dhdgffkkebhmkfjojejmpbldmpobfkfo"
            default: return
        }
        extDir := "s:\CentBrowser\User Data\Default\Extensions\" . extID
        ;子文件夹数量
        cnt := 0
        loop files, extDir . "\*", "D" {
            if (A_LoopFileAttrib ~= "[HS]")
                continue
            dirName := A_LoopFileName
            cnt++
        }
        if (cnt == 1)
            extDir .= "\" . dirName
        ; msgbox(extDir)
        return extDir
    }

}
