class _Edge extends _CDP {

    ;只是为了方便打开网页
    __new(url:="", funAfterDo:=unset) {
        if (url != "")
            _CDP.smartGet("msedge").tabOpenLink(url, funAfterDo?)
    }

    static onekey() {
        if (WinActive("ahk_class Chrome_WidgetWin_1 ahk_exe msedge.exe")) {
            WinMinimize ;防止左下角的网址残留
            WinHide
        } else {
            _CDP.smartGet("msedge").tabOpenLink()
        }
    }

}
