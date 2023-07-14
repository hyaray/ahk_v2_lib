;枚举 https://docs.microsoft.com/en-us/windows/win32/dataxchg/standard-clipboard-formats
; https://docs.microsoft.com/en-us/windows/win32/dataxchg/clipboard-formats#standard-clipboard-formats
; https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerclipboardformata
;HTML Clipboard Format http://msdn.microsoft.com/en-us/library/aa767917
;msgbox(json.stringify(_Clipboard.arrDate(), 4))

;hClip := dllcall("RegisterClipboardFormat", "str","png", "uint")
;if !dllcall("IsClipboardFormatAvailable", "uint",hClip)
;    throw Error("Clipboard does not have PNG stream data.")
;dllcall("GetClipboardData", "uint",hClip, "ptr"))

;遍历 ClipboardAll() 用法见 _Excel.rngByClipboard()
;_Clipboard.fromFiles(["z:\blank.html","z:\Class_CDP.ahk"])
class _Clipboard {

    ;thqby 提供 2022.12.13
    fromFiles(files, MoveFiles:=false) {
        static PreferredDropEffect := dllcall("RegisterClipboardFormat", "Str", "Preferred DropEffect", "uint")
        total_len := 0
        for fp in files
            total_len += strlen(fp) + 1
        if (total_len && dllcall("OpenClipboard", "ptr",A_ScriptHwnd) && dllcall("EmptyClipboard")) {
            hDrop := dllcall("GlobalAlloc", "uint",0x42, "uint",20 + (total_len + 1) << 1, "uptr")
            p := NumPut("uint",20, "int64",0, "uint",0, "uint",1, dllcall("GlobalLock", "ptr",hDrop))
            files.Push("")
            for fp in files
                p += strput(fp, p)
            dllcall("GlobalUnlock", "ptr",hDrop)
            dllcall("SetClipboardData", "uint",0x0F, "uptr",hDrop)
            hMem := dllcall("GlobalAlloc", "uint",0x42, "uint",4, "uptr")
            pMem := dllcall("GlobalLock", "ptr", hMem)
            numput("uchar", MoveFiles ? 2 : 1, pMem)
            dllcall("GlobalUnlock", "ptr",hMem)
            dllcall("SetClipboardData", "uint",PreferredDropEffect, "ptr",hMem)
            dllcall("CloseClipboard")
            return true
        }
        return false
    }

    ;判断顺序
    ;文件 *15
    ;图片 *2 8 17
    ;Excel range 1-5 7-8 13-14 16-17 *129
    ;文本 1 7 *13 16
    ;html
    ;相关 xl.ClipboardFormats https://docs.microsoft.com/zh-cn/office/vba/api/excel.xlclipboardformat
    static getTypes() {
        ClipboardForamts := map(
            1 , "CF_TEXT", ;
            2 , "CF_BITMAP", ;
            3 , "CF_METAFILEPICT", ;
            4 , "CF_SYLK",
            5 , "CF_DIF",
            6 , "CF_TIFF",
            7 , "CF_OEMTEXT", ;
            8 , "CF_DIB",
            9 , "CF_PALETTE",
            10 , "CF_PENDATA",
            11 , "CF_RIFF",
            12 , "CF_WAVE",
            13 , "CF_UNICODETEXT",
            14 , "CF_ENHMETAFILE",
            15 , "CF_HDROP",
            16 , "CF_LOCALE",
            17 , "CF_DIBV5", ;
            128 , "CF_OWNERDISPLAY", ;
            129 , "CF_DSPTEXT", ;
            130 , "CF_DSPBITMAP", ;
            131 , "CF_DSPMETAFILEPICT", ;
            142 , "CF_DSPENHMETAFILE", ;
            512 , "CF_PRIVATEFIRST",
            767 , "CF_PRIVATELAST",
            768 , "CF_GDIOBJFIRST",
            1023 ,"CF_GDIOBJLAST",
        )
        ;dllcall("OpenClipboard", "Ptr",A_ScriptHwnd)  ;【2018年3月18日】不打开这个，则下面的长度，无法获取，打开的话，可能造成一些脚本性能上的问题，刚放开就崩溃了，所以还是关了为好
        arr := []
        for n, str in ClipboardForamts {
            if (dllcall("User32.dll\IsClipboardFormatAvailable", "UInt",n, "Int"))
                arr.push(n)
        }
        return arr
    }

    ;_Clipboard.isPic()
    static isPic() => dllcall("IsClipboardFormatAvailable", "UInt",8) && !dllcall("IsClipboardFormatAvailable", "UInt",13)
    static isFile() => dllcall("IsClipboardFormatAvailable", "UInt",15)
    ;static isHtml() {
    ;    return dllcall("RegisterClipboardFormat", "str","HTML Format")
    ;}

    ;msgbox(json.stringify(_Clipboard.arrDate(), 4))
    ;static arrDate() {
    ;    ClipboardForamts := map(
    ;        1 , "CF_TEXT", ;
    ;        2 , "CF_BITMAP", ;
    ;        3 , "CF_METAFILEPICT", ;
    ;        4 , "CF_SYLK",
    ;        5 , "CF_DIF",
    ;        6 , "CF_TIFF",
    ;        7 , "CF_OEMTEXT", ;
    ;        8 , "CF_DIB",
    ;        9 , "CF_PALETTE",
    ;        10 , "CF_PENDATA",
    ;        11 , "CF_RIFF",
    ;        12 , "CF_WAVE",
    ;        13 , "CF_UNICODETEXT",
    ;        14 , "CF_ENHMETAFILE",
    ;        15 , "CF_HDROP",
    ;        16 , "CF_LOCALE",
    ;        17 , "CF_DIBV5", ;
    ;        128 , "CF_OWNERDISPLAY", ;
    ;        129 , "CF_DSPTEXT", ;
    ;        130 , "CF_DSPBITMAP", ;
    ;        131 , "CF_DSPMETAFILEPICT", ;
    ;        142 , "CF_DSPENHMETAFILE", ;
    ;        512 , "CF_PRIVATEFIRST",
    ;        767 , "CF_PRIVATELAST",
    ;        768 , "CF_GDIOBJFIRST",
    ;        1023 ,"CF_GDIOBJLAST",
    ;        49161 ,"CF_GDIOBJLAST",
    ;        dllcall("RegisterClipboardFormat", "str","HTML Format"), "CF_HTML",
    ;        dllcall("RegisterClipboardFormat", "Str","Link", "UInt"), "CF_LINK",
    ;        dllcall("RegisterClipboardFormat", "Str","VimClipboard2", "UInt"), "CF_Vim",
    ;    )
    ;    arr := []
    ;    n := 0
    ;    oBuf := ClipboardAll()
    ;    while (idFormat := NumGet(oBuf, n, "uint")) {
    ;        size := NumGet(oBuf, n+4, "uint")
    ;        if (ClipboardForamts.has(idFormat)) {
    ;            if (ClipboardForamts[idFormat] == "CF_UNICODETEXT")
    ;                arr.push([idFormat, ClipboardForamts[idFormat], strget(oBuf.ptr+n+4+A_PtrSize,-size, "utf-16")])
    ;            else
    ;                arr.push([idFormat, ClipboardForamts[idFormat], strget(oBuf.ptr+n+4+A_PtrSize,-size, "CP0")])
    ;        }
    ;        n += 4 + A_PtrSize + size
    ;    }
    ;    return arr
    ;}

    static clear() {
        if (!dllcall("OpenClipboard", "ptr",0))
            return false
        dllcall("EmptyClipboard")
        dllcall("CloseClipboard")
        return true
    }

    static isEmpty() => !dllcall("CountClipboardFormats")

}
