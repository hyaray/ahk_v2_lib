class _CB extends _CDP {
    static winTitle := "ahk_class Chrome_WidgetWin_1 ahk_exe chrome.exe"

    static __new() {
        this.init("s:\CentBrowser\chrome.exe", 9222)
    }

    ;只是为了方便打开网页
    __new(url:="", funAfterDo:=false) {
        if (url != "")
            _CB.tabOpenLink(url, funAfterDo)
    }

    static update() {
        _CB.tabOpenLink("http://www.centbrowser.cn/history.html")
    }

    static tabLeft(tp:=1) {
        send("{ctrl down}{shift down}{tab}{shift up}{ctrl up}")
    }

    static tabRight() {
        send("{ctrl down}{tab}{ctrl up}")
    }

    static onekey() {
        if (WinActive(_CB.winTitle)) {
            WinMinimize ;防止左下角的网址残留
            WinHide
        } else {
            _CB.tabOpenLink()
        }
    }

    ;扩展所在目录
    static getExtensionDir(extName) {
        obj := map(
            'FireShot',"mcbpblocgmgfnpjjppndjkmgjaogfceg",
            'Surfingkeys',"gfbliohnnapiefjpjlpjnehglfpaknnc",
            'SwitchyOmega',"padekgcemlokbadohgkifijomclgjgif",
            'Tampermonkey',"dhdgffkkebhmkfjojejmpbldmpobfkfo",
        )
        if (!obj.has(extName))
            return
        extID := obj[extName]
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

