;GDI+系列教程 https://www.autoahk.com/archives/34920
;主要 class 及其表示方法：(用在 ultisnips)
;   GDIP_PBitmap = m(NOTE)
;   GDIP_FontFamily = v(NOTE)
;   GDIP_Brush = b
;   GDIP_Font = f
;   GDIP_Graphics = g
;   GDIP_HBitmap = h
;   GDIP_Pen = p
;   GDIP_StringFormat = s

;特色：
;   父类是 _GDIP
;   用对象的方式，逻辑清晰
;   简化了释放，函数内部会自动释放变量，释放变量会自动调用 __delete 释放资源
;   把 DC 封装到 GDIP_Graphics，不用考虑生成和释放顺序，使用更简单
;       两个方法 SelectObject 和 UpdateLayeredWindow 转成 GDIP_Graphics 的方法
;       简化了 SelectObject
;           用 GDIP_HBitmap 生成 oGraphics 时会自动 SelectObject
;           不需要记录旧对象，释放时，不要传入参数即可
;   简化了方法调用的参数，无需传入对象本身的属性，比如 oPen的方法不需要传入 pPen 参数
;   x,y,w,h 的参数统一用 aRect 数组方式打包传入，而不是传入4个参数

; NOTE 重要说明：
;一般都需要实例化，比如 oPen 为实例，oPen.ptr 为 gdip 原生的 pPen。暂时每个实例只支持一个 ptr 属性。
;【方法】
;   名称，一般都是和 dllcall 函数同名，没涉及 dllcall 的则不是以 Gdip 开头，drawImage 是个例外(支持 oPBitmap)
;   PS：如果参数填oPen，v2-beta会自动读取其 ptr 属性，比如以下两句等效
;   oGraphics.GdipDrawEllipse(oPen,     [0,0,w,h])
;   oGraphics.GdipDrawEllipse(oPen.ptr, [0,0,w,h])
;
;补充：
;   NOTE 边框如果很粗，则会溢出一半的粗细到 aRect外

;NOTE "空"对 gdip 的教程 https://www.autoahk.com/archives/34920
;gdip v1 最新版在 https://github.com/marius-sucan/Quick-Picto-Viewer

;其他处理图片的库
; ImagePut https://github.com/iseahound/ImagePut
;图片信息
;   二进制
;   base64

; 如果你是刚开始接触 GDI+ ，可能还没有完全弄懂这些东西的意思，所以这里总结一下基本流程。
;步骤
;1. 开始的定式
;   初始化 GDI+ ----> 创建位图 ----> 创建 DC ----> 把位图跟 DC 绑定 ----> 创建画布
;2. 收尾
;   删除图片 ----> 删除画布 ----> 释放位图 ----> 删除 DC ----> 删除位图 ----> 关闭 GDI+

;RButton::_GDIP.gesture(map(
;            "↘", ["关闭窗口",(p*)=>WinClose("A")],
;            "↙", ["最小化窗口",(p*)=>WinMinimize("A")],
;            "↖", ["最大化窗口",(p*)=>WinMaximize("A")],
;            "↑", ["复制",(p*)=>send("{ctrl down}c{ctrl up}")],
;            "↓", ["粘贴",(p*)=>send("{ctrl down}v{ctrl up}")],
;            "↑↓", ["上下",(p*)=>msgbox("↑↓")],
;            "↓↑", ["下上",(p*)=>msgbox("↓↑")],
;            "←→", ["左右",(p*)=>msgbox("←→")],
;            "→←", ["右左",(p*)=>msgbox("→←")],
;))

#dllload gdiplus.dll

class _GDIP {

    static __new() {
        if (this != _GDIP)
            return
        ;if !dllcall("GetModuleHandle", "str","gdiplus", "ptr")
        ;    dllcall("LoadLibrary", "str", "gdiplus")
        bufSi := buffer(8+A_PtrSize*2, 0)
        numput("UInt", 1, bufSi)
        dllcall("gdiplus\GdiplusStartup","ptr*",&pToken:=0, "Ptr",bufSi, "Ptr",0)
        this.pToken := pToken
    }

    __delete() {
        dllcall("gdiplus\GdiplusShutdown", "ptr",this.pToken)
        if (hModule := dllcall("GetModuleHandle", "str","gdiplus", "ptr"))
            dllcall("FreeLibrary", "ptr",hModule)
        return 0
    }

    ; https://docs.microsoft.com/en-us/windows/win32/api/gdiplustypes/ne-gdiplustypes-status
    ;见 gdiplustypes.h
    static error(i) {
        return [
            "Ok", ;0,
            "GenericError", ;1,
            "InvalidParameter", ;2,
            "OutOfMemory", ;3,
            "ObjectBusy", ;4,
            "InsufficientBuffer", ;5,
            "NotImplemented", ;6,
            "Win32Error", ;7,
            "WrongState", ;8,
            "Aborted", ;9,
            "FileNotFound", ;10,
            "ValueOverflow", ;11,
            "AccessDenied", ;12,
            "UnknownImageFormat", ;13,
            "FontFamilyNotFound", ;14,
            "FontStyleNotFound", ;15,
            "NotTrueTypeFont", ;16,
            "UnsupportedGdiplusVersion", ;17,
            "GdiplusNotInitialized", ;18,
            "PropertyNotFound", ;19,
            "PropertyNotSupported", ;20,
        ][i+1]
    }

    ; struct BITMAPINFOHEADER - https://docs.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapinfoheader
    static _bufBitmapInfoHeader(w, h, bpp:=32) {
        bufBI := buffer(40, 0)
        numput("uint",40, "uint",w, "uint",h, "ushort",1, "ushort",bpp, bufBI)
        return bufBI
    }

    ; aRect := [100,200,(arrWH)=>0.3*arrWH[1]+20, (arrWH)=>0.4*arrWH[2]]
    ; arrWH := [300,400]
    ;aRect的每个项目都可以是函数，参数是图片的[宽，高] arrWH
    ;转成 [100, 200, 110, 160]
    static rectDeal(aRect, arrWH) {
        for k, v in aRect {
            if (isobject(v))
                aRect[k] := v.call(arrWH)
            else if (v < 0)
                aRect[k] := arrWH[mod(k-1,2)+1] + v ;1,3转成 w+v, 2,4转成 h+v
            else if (v < 1)
                aRect[k] := integer(arrWH[mod(k-1,2)+1] * v) ;1,3转成 w*v, 2,4转成 h*v
        }
        return aRect
    }

    ;确认鼠标选择区域
    ;aRect := _GDIP.getRect((p*)=>GetKeyState(RegExReplace(A_ThisLabel, ".*\s"), "P"))
    ;同 _Mouse.getRect
    static getRect(funDo:="") {
        if (!isobject(funDo))
            funDo := (p*)=>GetKeyState("LButton", "P")
        ;截图时显示的Gui
        oGui := gui("-caption +AlwaysOnTop +Border +E0x80000 +LastFound +OwnDialogs +ToolWindow")
        oGui.BackColor := "FFFFFF"
        WinSetTransparent(110)
        ;记录初始位置
        CoordMode("Mouse", "screen")
        MouseGetPos(&x0, &y0)
        while(funDo.call()) { ;鼠标按住不放
            sleep(10)
            MouseGetPos(&x1, &y1)
            x := min(x0, x1)
            y := min(y0, y1)
            w := abs(x0 - x1)
            h := abs(y0 - y1)
            oGui.show(format("x{1} y{2} w{3} h{4} NA", x,y,w,h))
            tooltip(format("{1},{2},{3},{4}",x,y,w,h))
        }
        oGui.destroy()
        SetTimer(tooltip, -100)
        if (w<=3 || h<=3)
            exit
        return [x,y,w,h]
    }

    ;屏幕区域转成 base64
    static rect2base64(aRect) {
        oPBitmap := GDIP_PBitmap(aRect)
        return oPBitmap.toBase64()
    }

    ;屏幕区域保存为文件
    static rect2fp(aRect, fp:="") {
        if (fp == "")
            fp := format("{1}\{2}.png", A_Desktop,A_Now)
        oPBitmap := GDIP_PBitmap(aRect)
        oPBitmap.GdipSaveImageToFile(fp)
        return fp
    }

    ;aRect 画框
    ;oGui := _GDIP.rectMark(el.GetBoundingRectangle())
    ;oGui := _GDIP.rectMark(_Win.toRect("ahk_id " . this.winInfo["winID"]))
    ;标窗口
    ;WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
    ;_GDIP.rectMark([x,y,w,h])
    static rectMark(aRects, arrStyle:=unset, keyWaitClose:="") {
        if !isobject(aRects[1])
            aRects := [aRects]
        if (!isset(arrStyle))
            arrStyle := []
        clPen := arrStyle.length >= 1 ? arrStyle[1] : 0xffFF0000
        wPen := arrStyle.length >= 2 ? arrStyle[2] : 2
        bOut := arrStyle.length >= 3 ? arrStyle[3] : false
        w := sysget(78)
        h := sysget(79)
        oHBitmap := GDIP_HBitmap(w,h)
        oGraphics := GDIP_Graphics(oHBitmap)
        oGraphics.GdipSetSmoothingMode(4)
        oPen := GDIP_Pen(clPen, wPen)
        oGui := gui("-Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs")
        oGui.Show("NA")
        for k, aRect in aRects {
            if (bOut && wPen > 1) { ;TODO 什么意思？
                n := wPen//2
                aRect[1] -= n
                aRect[2] -= n
                aRect[3] += 2*n
                aRect[4] += 2*n
            }
            oGraphics.GdipDrawRectangle(oPen.ptr, aRect)
        }
        oGraphics.UpdateLayeredWindow(oGui.hwnd, [0,0,w,h])
        oGraphics.SelectObject()
        if (keyWaitClose != "") {
            KeyWait(keyWaitClose, "D")
            oGui.destroy()
        } else {
            return oGui
        }
    }

    ; 十字聚光灯
    ; oGui := _GDIP.rectMarkShizi(aRect, 0xffFF0000, 2)
    static rectMarkShizi(aRect, clBrush:=0x88FF0000) {
        w := sysget(78)
        h := sysget(79)
        oHBitmap := GDIP_HBitmap(w,h)
        oGraphics := GDIP_Graphics(oHBitmap)
        oGraphics.GdipSetSmoothingMode(4)
        oBrush := GDIP_Brush(clBrush)
        oGraphics.GdipFillRectangle(oBrush.ptr, [0,aRect[2],w,aRect[4]]) ;横
        oGraphics.GdipFillRectangle(oBrush.ptr, [aRect[1],0,aRect[3],h]) ;竖
        oBrush := ""
        oGui := gui("-Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs")
        oGui.Show("NA")
        oGraphics.UpdateLayeredWindow(oGui.hwnd, [0,0,w,h])
        oGraphics.SelectObject()
        oHBitmap := ""
        oGraphics := ""
        ; OnMessage(0x201, (p*)=>PostMessage(0xA1, 2))
        return oGui
    }

    ; https://hp.vector.co.jp/authors/VA018351/en/mglahk.html
    ;鼠标手势，支持8个方向
    ;传入 objDo 可以实时显示当前手势会执行什么命令
    ;核心是 getRes
    ;TODO IrfanView 里不用
    ;TODO 会崩溃
    static gesture(funAction) {
        cmMouse := A_CoordModeMouse
        CoordMode("Mouse", "screen")
        MouseGetPos(&x0, &y0, &hwnd, &ctl)
        if !WinActive("ahk_id " . hwnd) ;TODO 激活窗口
            WinActivate("ahk_id " . hwnd)
        ;确保鼠标移动了才开始画图
        if !waitMove()
            return
        objDo := funAction()
        if (!objDo.count)
            return
        exeName := WinGetProcessName("ahk_id " . hwnd)
        ;分别定义【路径】和【提示】的x,y,w,h
        wPath := hPath := 500
        xPath := x0-wPath//2
        yPath := y0-hPath//2
        wPath := hPath := 500
        wTip := 600
        hTip := 400
        xTip := (x0>A_ScreenWidth) ? (sysget(78)+A_ScreenWidth-wTip)//2 : (A_ScreenWidth-wTip)//2
        yTip := A_ScreenHeight*0.9 - hTip
        ;轨迹Gui
        oHBitmap := GDIP_HBitmap(wPath, hPath)
        oGraphics := GDIP_Graphics(oHBitmap)
        oGraphics.GdipSetSmoothingMode(4)
        oPen := GDIP_Pen(0xbbFF9050, 6) ;0xff5090FF 0xbbFF9050
        oGui := gui("-caption +AlwaysOnTop +Border +E0x80000 +LastFound +Owner +E0x20") ; +ToolWindow
        oGui.show("NA")
        ;提醒文字Gui
        clTip := 0xaaff0000
        lenKey := 3 ;箭头+空格的个数，为了对齐显示
        oHBitmap1 := GDIP_HBitmap(wTip,hTip)
        oGraphics1 := GDIP_Graphics(oHBitmap1)
        oGraphics1.GdipSetSmoothingMode(4)
        oFont1 := GDIP_Font("微软雅黑", 38)
        oStringFormat1 := GDIP_StringFormat(0x4000)
        oStringFormat1.GdipSetStringFormatAlign(0)
        oGui1 := gui("-caption +AlwaysOnTop +Border +E0x80000 +LastFound +Owner +E0x20") ; +ToolWindow
        oGui1.show("NA")
        ;显示背景
        oBrush0 := GDIP_Brush(0xffEEEEEE)
        oBrush1 := GDIP_Brush(clTip)
        ;初始化参数
        arrRecord := [] ;最终坐标的记录(同方向的坐标，会合并为1个)
        arrPoints := [[x0-xPath,y0-yPath]]
        lenMin := 5 ;最小步长
        sTipNow := "" ;当前提醒文字(判断是否需要更新)
        ;xPath0 := x0 ;NOTE 轨迹只要坐标有变化就更新(更实时)，和提示不一样
        ;yPath0 := y0
        while(GetKeyState("RButton", "P")) { ;鼠标按住不放
            sleep(10)
            MouseGetPos(&x1, &y1)
            if (x1==x0 && y1==y0) ;没动
                continue
            ;更新轨迹(不写入)
            arrPoints.push([x1-xPath,y1-yPath])
            showPath(arrPoints)
            ;更新提示
            if (abs(x1-x0)<=lenMin && abs(y1-y0)<=lenMin) ;位移太小不作计算处理
                continue
            arrRecord.push([getDirect(x0,y0,x1,y1), x0,y0,x1,y1]) ;NOTE Y轴往下值变小，鼠标往下值变大
            x0 := x1
            y0 := y1
            showTips()
        }
        ;删除图片 ----> 删除画布 ----> 释放位图 ----> 删除 DC ----> 删除位图 ----> 关闭 GDI+
        ;oGraphics := oGraphics1 := ""
        ;oHBitmap := oHBitmap1 := ""
        ;msgbox(arrPoints.toTable())
        ;收尾
        CoordMode("Mouse", cmMouse)
        oGui.destroy()
        oGui1.destroy()
        if (!arrRecord.length) {
            send("{RButton}")
            return
        }
        resAll := getRes()
        ;loop(20)
        ;    tooltip(,,, A_Index)
        if (objDo.has(resAll)) {
            objDo[resAll][2]()
        } else {
            return
            ;tooltip(format("{1}`n{2}不匹配", toTable(arrRecord),resAll), 10,0)
            ;SetTimer(tooltip, -1000)
        }
        return resAll
        waitMove() {
            bMoved := false
            while(GetKeyState("RButton", "P")) { ;鼠标要移动才生效
                sleep(10)
                MouseGetPos(&x1, &y1)
                if (x1!=x0 || y1!=y0) { ;动了
                    bMoved := true
                    break
                }
            }
            if (!bMoved) {
                send("{RButton down}")
                KeyWait("RButton")
                send("{RButton up}")
            }
            return bMoved
        }
        showPath(arr) {
            oGraphics.GdipGraphicsClear()
            oGraphics.GdipDrawLines(oPen, arr)
            oGraphics.UpdateLayeredWindow(oGui.hwnd, [xPath,yPath,wPath,hPath])
        }
        showTips() {
            resAll := getRes() ;NOTE 获取结果
            if (resAll == sTipNow)
                return
            sTip := ""
            for k,v in objDo {
                if (substr(k, 1, strlen(resAll)) == resAll) {
                    sSpace := ""
                    loop(lenKey-strlen(k))
                        sSpace .= "　"
                    sTip .= format("{1}{2}`t{3}`n", k,sSpace,v[1])
                }
            }
            sTipNow := resAll
            oGraphics1.GdipGraphicsClear() ;清除 TODO 只清除文字，不清除背景色
            oGraphics1.GdipFillRectangle(oBrush0, [0,0,wTip,hTip])
            oGraphics1.GdipDrawString(format("{1}　{2}`n{3}", resAll,exeName,sTip), oFont1, oStringFormat1, oBrush1, [0,0,wTip,hTip])
            oGraphics1.UpdateLayeredWindow(oGui1.hwnd, [xTip,yTip,wTip,hTip])
        }
        getDirect(_x0,_y0,_x1,_y1) {
            return ["→","↗","↑","↖","←","↙","↓","↘","→"][round(getAngle(_x0,_y0,_x1,_y1)/45 + 1)]
            getAngle(_x0,_y0,_x1,_y1) { ;NOTE _x轴正方向为0
                _x := _x1-_x0
                _y := _y0-_y1
                if (_x == 0) {
                    if (_y == 0)
                        throw ValueError("_x=_y=0")
                    return (_y>0) ? 90 : 270
                }
                res := atan(_y/_x)*57.295779513
                return _x>0 ? round(res+((_y<0)*360)) : round(res + 180)
            }
        }
        getRes() {
            ;NOTE 数据清理
            ;1.汇总
            ;1.合并
            bTips := false
            if (1) {
                l := arrRecord.length
                _ := arrRecord[l][1]
                if (bTips)
                    tooltip(toTable(arrRecord),10,0, level:=1)
                loop(l-1) { ;逆序遍历并合并
                    i := l-A_Index
                    if (arrRecord[i][1] == _) { ;合并x1,y1
                        arrRecord[i][4] := arrRecord[i+1][4]
                        arrRecord[i][5] := arrRecord[i+1][5]
                        arrRecord.removeat(i+1)
                    } else {
                        _ := arrRecord[i][1]
                    }
                }
                if (bTips)
                    tooltip("合并`n" . toTable(arrRecord),200,0, ++level)
                if (arrRecord.length == 1)
                    return arrRecord[1][1]
                ;2.【临时】删除距离短的项目
                lenOmit := 20
                arrClone := arrRecord.clone()
                l := arrClone.length
                loop(l) {
                    i := l-A_Index+1
                    if (abs(arrClone[i][4]-arrClone[i][2]) <= lenOmit && abs(arrClone[i][5]-arrClone[i][3]) <= lenOmit)
                        arrClone.removeat(i)
                }
                if (bTips)
                    tooltip("临时删除短距离`n" . toTable(arrRecord),400,0, ++level)
                ;3连接
                resAll := "" ;所有的方向
                for arr in arrClone
                    resAll .= arr[1]
            }
            resAll := replace() ;NOTE 进行过渡替换
            return resAll
            replace() {
                if (strlen(resAll)) >= 3 {
                    arrReplace := [
                        ["↓↘→", "↓→"],
                        ["↓↙←", "↓←"],
                        ["↑↗→", "↑→"],
                        ["↑↖←", "↑←"],
                        ["↓→↗", "↓↗"],
                        ["↓←↖", "↓↖"],
                        ["↑→↘", "↑↘"],
                        ["↑←↙", "↑↙"],
                    ]
                    for arrTmp in arrReplace
                        resAll := StrReplace(resAll, arrTmp*)
                }
                return resAll
            }
        }
        toTable(arr) {
            res := ""
            if (!arr.length)
                return ""
            for arr1 in arr
                res .= format("{1}  {2},{3}  {4},{5}`n", arr1*)
            return res
        }
    }

    static DeleteObject(hObject) {
        return dllcall("DeleteObject", "ptr",hObject)
    }

    static StretchBlt(ddc, aRectTo, sdc, aRectFrom, Raster:=0x00CC0020) {
        return dllcall("gdi32\StretchBlt"
            , "ptr", ddc
            , "int", aRectTo[1],"int",aRectTo[2],"int",aRectTo[3],"int", aRectTo[4]
            , "ptr", sdc
            , "int",aRectFrom[1],"int",aRectFrom[2],"int",aRectFrom[3],"int",aRectFrom[4]
            , "uint", Raster)
    }

    static GetMonitorInfo(MonitorNum) {
        Monitors := this.MDMF_Enum()
        for k,v in Monitors
            if (v.Num = MonitorNum)
                return v
    }

    ;数组 aRect 转成 struct
    static CreateRect(&bufRect, aRect) {
        numput("uint",aRect[1],"uint",aRect[2],"uint",aRect[3],"uint",aRect[4], bufRect:=buffer(16))
    }

    ; ======================================================================================================================
    ; Multiple Display Monitors Functions -> msdn.microsoft.com/en-us/library/dd145072(v=vs.85).aspx
    ; by 'just me'
    ; https://autohotkey.com/boards/viewtopic.php?f=6&t=4606
    ; ======================================================================================================================
    static GetMonitorCount() {
        Monitors := this.MDMF_Enum()
        for k,v in Monitors
            count := A_Index
        return count
    }

    static GetPrimaryMonitor() {
        Monitors := this.MDMF_Enum()
        for k,v in Monitors
            if (v.Primary)
                return v.Num
    }
    ; ======================================================================================================================
    ; Enumerates display monitors and returns an object containing the properties of all monitors or the specified monitor.
    ; ======================================================================================================================
    static MDMF_Enum(HMON:="") {
        static CbFunc := (A_AhkVersion < "2") ? func("RegisterCallback") : func("CallbackCreate")
        static Monitors := {}
        this.EnumProc := CbFunc.call("MDMF_EnumProc")
        if (HMON == "") ; enumeration
            Monitors := {}
        if (Monitors.MaxIndex() = "") ; enumerate
            if !dllcall("User32.dll\EnumDisplayMonitors", "Ptr",0, "Ptr",0, "Ptr",this.EnumProc, "Ptr",&Monitors, "uint")
                return false
        return (HMON == "") ? Monitors : Monitors.has(HMON) ? Monitors[HMON] : false
    }
    ; ======================================================================================================================
    ;  Callback function that is called by the MDMF_Enum function.
    ; ======================================================================================================================
    static MDMF_EnumProc(HMON, hDC, PRECT, ObjectAddr) {
        Monitors := object(ObjectAddr)
        Monitors[HMON] := this.MDMF_GetInfo(HMON)
        return true
    }
    ; ======================================================================================================================
    ;  Retrieves the display monitor that has the largest area of intersection with a specified window.
    ; ======================================================================================================================
    static MDMF_FromHWND(hwnd) {
        return dllcall("User32.dll\MonitorFromWindow", "Ptr",hwnd, "uint",0, "ptr")
    }
    ; ======================================================================================================================
    ; Retrieves the display monitor that contains a specified point.
    ; if either X or Y is empty, the function will use the current cursor position for this value.
    ; ======================================================================================================================
    static MDMF_FromPoint(X := "", Y := "") {
        bufPT := buffer(8, 0)
        if (X = "") || (Y = "") {
            dllcall("User32.dll\GetCursorPos", "Ptr", &bufPT)
            if (X = "")
                X := numget(bufPT, 0, "int")
            if (Y = "")
                Y := numget(bufPT, 4, "int")
        }
        return dllcall("User32.dll\MonitorFromPoint", "int64", (X & 0xFFFFFFFF) | (Y << 32), "uint",0, "ptr")
    }
    ; ======================================================================================================================
    ; Retrieves the display monitor that has the largest area of intersection with a specified rectangle.
    ; Parameters are consistent with the common AHK definition of a rectangle, which is X, Y, W, H instead of
    ; left, top, right, bottom.
    ; ======================================================================================================================
    static MDMF_FromRect(X, Y, W, H) {
        bufRC := buffer(16, 0)
        numput("int", X, bufRC)
        numput("int", Y, bufRC, 4)
        numput("int", X + W, bufRC, 8)
        numput("int", Y + H, bufRC, 12)
        return dllcall("User32.dll\MonitorFromRect", "Ptr",bufRC, "uint",0, "ptr")
    }
    ; ======================================================================================================================
    ; Retrieves information about a display monitor.
    ; ======================================================================================================================
    static MDMF_GetInfo(HMON) {
        bufMIEX := buffer(40 + (32 << 1))
        numput("uint", bufMIEX.size, bufMIEX)
        if (dllcall("User32.dll\GetMonitorInfo", "Ptr",HMON, "Ptr",bufMIEX)) {
            MonName := strget(bufMIEX + 40, 32)	; CCHDEVICENAME = 32
            MonNum := RegExReplace(MonName, ".*(\d+)$", "$1")
            return {	Name:		(Name := strget(bufMIEX + 40, 32))
                ,	Num:		RegExReplace(Name, ".*(\d+)$", "$1")
                ,	left:		numget(bufMIEX, 4, "int")		; display rectangle
                ,	top:		numget(bufMIEX, 8, "int")		; "
                ,	right:		numget(bufMIEX, 12, "int")		; "
                ,	bottom:		numget(bufMIEX, 16, "int")		; "
                ,	WALeft:		numget(bufMIEX, 20, "int")		; work area
                ,	WATop:		numget(bufMIEX, 24, "int")		; "
                ,	WARight:	numget(bufMIEX, 28, "int")		; "
                ,	WABottom:	numget(bufMIEX, 32, "int")		; "
                ,	Primary:	numget(bufMIEX, 36, "uint")}	; contains a non-zero value for the primary monitor.
        }
        return false
    }

}

;mm
;根据 ImagePut
;输入的主要步骤
;   1. 获取 ImageType
;   2. 生成 pStream(有些格式会跳过此步骤)
;   3. 生成 pBitmap
;       - 通过 pStream: getFromStream()
;       - getFromRect
;输出的主要步骤
;   1. 生成 stream: toStream()
;   2. 保存成文件: GdipSaveImageToFile()
class GDIP_PBitmap extends _GDIP {
    ptr := 0
    w := 0
    h := 0
    EncoderParameter := 0
    ;fp 文件存在
    ;w,h w是数字
    ;oHBitmap
    ;[x,y,w,h] aRect
    __new(w:="", h:=0) {
        if (isobject(w)) {
            if (w is GDIP_HBitmap)
                this.GdipCreateBitmapFromHBITMAP(w, Palette:=0)
            else if (w.length == 2)
                this.GdipCreateBitmapFromScan0(w[1], w[2])
            else if (w.length == 4)
                this.getFromRect(w)
        } else {
            if (w == "")
                this.getFromClipboard()
            else if (w ~= "^\d+$")
                this.GdipCreateBitmapFromScan0(w, h)
            else if (FileExist(w))
                this.GdipCreateBitmapFromFile(w)
            ; else if (w == "") ;否则就创建个空白的对象(后面再添加图片)
            ;     msgbox(A_ThisFunc . "`n" . w . "`n" . h)
        }
    }

    ;出错，可排查释放顺序
    __delete() {
        dllcall("gdiplus\GdipDisposeImage", "ptr",this)
    }

    GdipCreateBitmapFromScan0(w, h, PixelFormat:=0x26200A) {
        dllcall("gdiplus\GdipCreateBitmapFromScan0", "int",w, "int",h, "int",0, "int",PixelFormat, "ptr",0, "ptr*",&pBitmap:=0)
        if (!pBitmap) {
            msgbox(A_ThisFunc . "`n" . w . "`n" . h)
        }
        this.w := w
        this.h := h
        this.ptr := pBitmap
    }

    ; GdipCreateBitmapFromFile(fp, IconNumber:=1, IconSize:="")
    GdipCreateBitmapFromFile(fp) {
        dllcall("gdiplus\GdipCreateBitmapFromFile", "str",fp, "ptr*",&pBitmap:=0)
        this.w := 0
        this.h := 0
        this.ptr := pBitmap
        ; SplitPath(fp,,, ext)
        ; if (RegExMatch(ext, "^(i:exe|dll)$")) {
        ;     Sizes := IconSize ? IconSize : 256 "|" 128 "|" 64 "|" 48 "|" 32 "|" 16
        ;     BufSize := 16 + (2*A_PtrSize)
        ;     buf := buffer(BufSize, 0)
        ;     for eachSize, Size in StrSplit(Sizes, "|") {
        ;         dllcall("PrivateExtractIcons", "str",fp, "int",IconNumber-1, "int",Size, "int",Size, "ptr*",&hIcon, "ptr*",0, "uint",1, "uint",0)
        ;         if !hIcon
        ;             continue
        ;         if !dllcall("GetIconInfo", "ptr",hIcon, "ptr",&buf) {
        ;             DestroyIcon(hIcon)
        ;             continue
        ;         }
        ;         hbmMask  := numget(buf, 12 + (A_PtrSize - 4))
        ;         hbmColor := numget(buf, 12 + (A_PtrSize - 4) + A_PtrSize)
        ;         if !(hbmColor && dllcall("GetObject", "ptr",hbmColor, "int",BufSize, "ptr",&buf)) {
        ;             DestroyIcon(hIcon)
        ;             continue
        ;         }
        ;         break
        ;     }
        ;     if !hIcon
        ;         return -1
        ;     width := numget(buf, 4, "int"), height := numget(buf, 8, "int")
        ;     hbm := CreateDIBSection(width, -height)
        ;     hDC := GDIP_DC.create()
        ;     obm := SelectObject(hDC, hbm)
        ;     if !dllcall("DrawIconEx", "ptr",hDC, "int",0, "int",0, "ptr",hIcon, "uint",width, "uint",height, "uint",0, "ptr",0, "uint",3) {
        ;         DestroyIcon(hIcon)
        ;         return -2
        ;     }
        ;     bufDIB := buffer(104)
        ;     ; sizeof(DIBSECTION) = 76+2*(A_PtrSize=8?4:0)+2*A_PtrSize
        ;     dllcall("GetObject", "ptr",hbm, "int",A_PtrSize == 8 ? 104 : 84, "ptr",bufDIB)
        ;     Stride := numget(bufDIB, 12, "int"), Bits := numget(bufDIB, 20 + (A_PtrSize - 4)) ; padding
        ;     dllcall("gdiplus\GdipCreateBitmapFromScan0", "int",width, "int",height, "int",Stride, "int",0x26200A, "ptr",Bits, "ptr*",&pBitmapOld)
        ;     pBitmap := Gdip_CreateBitmap(width, height)
        ;     _G := Gdip_GraphicsFromImage(pBitmap)
        ;         , Gdip_DrawImage(_G, pBitmapOld, 0, 0, width, height, 0, 0, width, height)
        ;     SelectObject(hDC, obm), dllcall("gdi32\DeleteObject", "ptr",hbm), DeleteDC(hDC)
        ;     Gdip_DeleteGraphics(_G), Gdip_DisposeImage(pBitmapOld)
        ;     DestroyIcon(hIcon)
        ;     return this.ptr := pBitmap
        ; }
    }

    ;pStream 转 pBitmap
    ;pStream 获取见 getStreamFrom***
    getFromStream(pStream) {
        dllcall("gdiplus\GdipCreateBitmapFromStream", "ptr",pStream, "ptr*",&pBitmap:=0)
        return this.ptr := pBitmap
    }

    getFromClipboard() {
        idData := 8
        if (!dllcall("IsClipboardFormatAvailable", "uint",8))
            return -2 ;throw Error('Clipboard does not have "CF_BITMAP" stream data.')
        if (!dllcall("OpenClipboard", "ptr",A_ScriptHwnd)) ;可用0代替？
            return -1
        if !(hBitmap := dllcall("GetClipboardData", "uint",2, "ptr"))
            return -3 ;throw Error("Shared clipboard data has been deleted.")
        ; Allow the stream to be freed while leaving the hBitmap intact.
        ; Please read: https://devblogs.microsoft.com/oldnewthing/20210930-00/?p=105745
        dllcall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr",hBitmap, "ptr",0, "ptr*",&pBitmap:=0)
        dllcall("CloseClipboard")
        dllcall("DeleteObject", "ptr", hBitmap)
        return this.ptr := pBitmap
    }

    ; Thanks tic - https://www.autohotkey.com/boards/viewtopic.php?t=6517
    getFromWindow(winTitle) {
        hwnd := WinExist(winTitle)
        ; Restore the window if minimized! Must be visible for capture.
        if (dllcall("IsIconic", "ptr",hwnd))
            dllcall("ShowWindow", "ptr",hwnd, "int",4)
        ; Get the width and height of the client window.
        dllcall("GetClientRect", "ptr",hwnd, "ptr",Rect:=buffer(16)) ; sizeof(RECT) = 16
        width  := NumGet(Rect, 8, "int")
        height := NumGet(Rect, 12, "int")
        hdc := dllcall("CreateCompatibleDC", "ptr",0, "ptr")
        bi := _GDIP._bufBitmapInfoHeader()(width, -height)
        hbm := dllcall("CreateDIBSection", "ptr",hdc,"ptr",bi, "uint",0, "ptr*",&pBits:=0, "ptr",0, "uint",0, "ptr")
        obm := dllcall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
        ; Print the window onto the hBitmap using an undocumented flag. https://stackoverflow.com/a/40042587
        dllcall("user32\PrintWindow", "ptr", hwnd, "ptr", hdc, "uint", 0x3) ; PW_RENDERFULLCONTENT | PW_CLIENTONLY
        ; Additional info on how this is implemented: https://www.reddit.com/r/windows/comments/8ffr56/altprintscreen/
        ; Convert the hBitmap to a Bitmap using a built in function as there is no transparency.
        dllcall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr",hbm, "ptr",0, "ptr*",&pBitmap:=0)
        ; Cleanup the hBitmap and device contexts.
        dllcall("SelectObject", "ptr",hdc, "ptr",obm)
        dllcall("DeleteObject", "ptr",hbm)
        dllcall("DeleteDC", "ptr",hdc)
        return pBitmap
    }

    ;Thanks tic - https://www.autohotkey.com/boards/viewtopic.php?t=6517
    ;这个不返回 pStream
    getFromRect(aRect) {
        if (0)
            this.GdipCreateBitmapFromHBITMAP(GDIP_HBitmap(aRect))
        else {
            hdc := dllcall("CreateCompatibleDC", "ptr",0, "ptr")
            bi := _GDIP._bufBitmapInfoHeader(aRect[3], -aRect[4])
            hbm := dllcall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0, "ptr*", &pBits:=0, "ptr", 0, "uint", 0, "ptr")
            obm := dllcall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
            sdc := dllcall("GetDC", "ptr",0, "ptr")
            dllcall("gdi32\BitBlt", "ptr",hdc, "int",0, "int",0, "int",aRect[3], "int",aRect[4], "ptr",sdc, "int",aRect[1], "int",aRect[2], "uint",0x00CC0020 | 0x40000000) ; SRCCOPY | CAPTUREBLT
            dllcall("ReleaseDC", "ptr",0, "ptr",sdc)
            dllcall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr",hbm, "ptr",0, "ptr*",&pBitmap:=0)
            dllcall("SelectObject", "ptr",hdc, "ptr",obm)
            dllcall("DeleteObject", "ptr",hbm)
            dllcall("DeleteDC",     "ptr",hdc)
            return this.ptr := pBitmap
        }
    }

    GdipCreateBitmapFromHBITMAP(oHBitmap, Palette:=0) {
        dllcall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr",oHBitmap.ptr, "ptr",Palette, "ptr*",&pBitmap:=0)
        return this.ptr := pBitmap
    }

    ; getFromHICON(hIcon) {
    ;     dllcall("gdiplus\GdipCreateBitmapFromHICON",A_PtrSize ? "ptr" : "uint",hIcon, A_PtrSize ? "ptr*" : "uint*",&pBitmap:=0)
    ;     return this.ptr := pBitmap
    ; }

    getSize(&w:=0, &h:=0) {
        if (!this.w) {
            dllcall("gdiplus\GdipGetImageWidth", "ptr",this, "uint*",&w:=0)
            this.w := w
        } else
            w := this.w
        if (!this.h) {
            dllcall("gdiplus\GdipGetImageHeight", "ptr",this, "uint*",&h:=0)
            this.h := h
        } else
            h := this.h
        return [this.w, this.h]
    }
    getWidth() {
        if (!this.w) {
            dllcall("gdiplus\GdipGetImageWidth", "ptr",this, "uint*",&w:=0)
            this.w := w
        }
        return this.w
    }
    getHeight() {
        if (!this.h) {
            dllcall("gdiplus\GdipGetImageHeight", "ptr",this, "uint*",&h:=0)
            this.h := h
        }
        return this.h
    }

    getPixel(x, y) {
        dllcall("gdiplus\GdipBitmapGetPixel", "Ptr",this, "int",x, "int",y, "Uint*",&ARGB:=0)
        return ARGB
    }
    setPixel(x, y, ARGB) {
        return dllcall("gdiplus\GdipBitmapSetPixel", "Ptr",this, "int",x, "int",y, "int",&ARGB)
    }

    ; http://www.autohotkey.com/community/viewtopic.php?p=477333
    ; returns resized bitmap. By Learning one.
    resize(PercentOrWH, Dispose:=1) {
        ;NOTE 保存原图
        this.ptr1 := this.ptr
        this.getSize(&w, &h)
        ;新图宽高
        if (isobject(PercentOrWH)) {
            wNew := integer(PercentOrWH[1])
            hNew := integer(PercentOrWH[2])
        } else {
            wNew := integer(w*PercentOrWH)
            hNew := integer(h*PercentOrWH)
        }
        ;创建新 pBitmap
        this.GdipCreateBitmapFromScan0(wNew, hNew)
        oGraphics := GDIP_Graphics(this.ptr)
        oGraphics.GdipSetInterpolationMode(7)
        oGraphics.GdipSetSmoothingMode(4)
        oGraphics.GdipDrawImageRectRect(this.ptr1, [0,0,wNew,hNew], [0,0,w,h])
        oGraphics := ""
        if (Dispose)
            dllcall("gdiplus\GdipDisposeImage", "ptr",this)
    }

    ;旋转后新的宽高
    ;原左上角坐标相对新左上角坐标的偏移：xOffset, yOffset
    ;后续
    ;   oGraphics.GdipTranslateWorldTransform(xOffset, yOffset)
    getRotatedRect(w, h, angle) {
        angle := (angle >= 0) ? mod(angle, 360) : 360-mod(-angle, -360)
        ;90的倍数精确处理
        if (!mod(angle, 90)) {
            if (angle == 0)
                return [0,0,w,h]
            else if (angle == 180)
                return [w,h,w,h]
            else if (angle == 90)
                return [h,0,h,w]
            else if (angle == 270)
                return [0,w,h,w]
        }
        pi := 3.14159 ;TODO 会造成误差
        TAngle := angle*(pi/180)
        if (angle <= 90) {
            xOffset := h*sin(TAngle)
            yOffset := 0
        } else if (angle <= 180) {
            xOffset := (h*sin(TAngle))-(w*cos(TAngle))
            yOffset := -h*cos(TAngle)
        } else if (angle <= 270) {
            xOffset := -w*cos(TAngle)
            yOffset := -(h*cos(TAngle))-(w*sin(TAngle))
        } else {
            xOffset := 0
            yOffset := -w*sin(TAngle)
        }
        newW := ceil(abs(w*cos(TAngle))+abs(h*sin(TAngle)))
        newH := ceil(abs(w*sin(TAngle))+abs(h*cos(Tangle)))
        return [xOffset, yOffset, newW, newH]
    }

    ; https://autohotkey.com/board/topic/29449-gdi-standard-library-145-by-tic/page-58#entry455137
    rotate(angle, Dispose:=1) {
        ;NOTE 保存原图
        this.ptr1 := this.ptr
        this.getSize(&w, &h)
        ;记录角度
        aRect := this.getRotatedRect(w, h, angle)
        wNew := aRect[3]
        hNew := aRect[4]
        this.GdipCreateBitmapFromScan0(wNew, hNew)
        oGraphics := GDIP_Graphics(this.ptr)
        oGraphics.GdipSetInterpolationMode(7)
        oGraphics.GdipSetSmoothingMode(4)
        oGraphics.GdipDrawImageRectRect(this.ptr1, [0,0,wNew,hNew], [0,0,w,h])
        oGraphics := ""
        if (Dispose)
            dllcall("gdiplus\GdipDisposeImage", "ptr",this)
    }

    ;剪切(名字同 python PIL)
    crop(left:=0, right:=0, up:=0, down:=0, Dispose:=1) {
        this.ptr1 := this.ptr
        this.getSize(&w, &h)
        wNew := w-left-right
        hNew := h-up-down
        this.GdipCreateBitmapFromScan0(wNew, hNew)
        oGraphics := GDIP_Graphics(this.ptr)
        oGraphics.GdipSetInterpolationMode(7)
        oGraphics.GdipSetSmoothingMode(4)
        oGraphics.GdipDrawImageRectRect(this.ptr1, [0,0,wNew,hNew], [left,up,wNew,hNew])
        oGraphics := ""
        if (Dispose)
            dllcall("gdiplus\GdipDisposeImage", "ptr",this)
    }

    ;FIXME 马赛克
    ; GdipPixelateBitmap(pBitmap, oBitmapOut, BlockSize) {
    ;     if (!PixelateBitmap) {
    ;         if (A_PtrSize != 8) {
    ;             MCode_PixelateBitmap := "
    ;             (ltrim join
    ;             558BEC83EC3C8B4514538B5D1C99F7FB56578BC88955EC894DD885C90F8E830200008B451099F7FB8365DC008365E000894DC88955F08945E833FF897DD4
    ;             397DE80F8E160100008BCB0FAFCB894DCC33C08945F88945FC89451C8945143BD87E608B45088D50028BC82BCA8BF02BF2418945F48B45E02955F4894DC4
    ;             8D0CB80FAFCB03CA895DD08BD1895DE40FB64416030145140FB60201451C8B45C40FB604100145FC8B45F40FB604020145F883C204FF4DE475D6034D18FF
    ;             4DD075C98B4DCC8B451499F7F98945148B451C99F7F989451C8B45FC99F7F98945FC8B45F899F7F98945F885DB7E648B450C8D50028BC82BCA83C103894D
    ;             C48BC82BCA41894DF48B4DD48945E48B45E02955E48D0C880FAFCB03CA895DD08BD18BF38A45148B7DC48804178A451C8B7DF488028A45FC8804178A45F8
    ;             8B7DE488043A83C2044E75DA034D18FF4DD075CE8B4DCC8B7DD447897DD43B7DE80F8CF2FEFFFF837DF0000F842C01000033C08945F88945FC89451C8945
    ;             148945E43BD87E65837DF0007E578B4DDC034DE48B75E80FAF4D180FAFF38B45088D500203CA8D0CB18BF08BF88945F48B45F02BF22BFA2955F48945CC0F
    ;             B6440E030145140FB60101451C0FB6440F010145FC8B45F40FB604010145F883C104FF4DCC75D8FF45E4395DE47C9B8B4DF00FAFCB85C9740B8B451499F7
    ;             F9894514EB048365140033F63BCE740B8B451C99F7F989451CEB0389751C3BCE740B8B45FC99F7F98945FCEB038975FC3BCE740B8B45F899F7F98945F8EB
    ;             038975F88975E43BDE7E5A837DF0007E4C8B4DDC034DE48B75E80FAF4D180FAFF38B450C8D500203CA8D0CB18BF08BF82BF22BFA2BC28B55F08955CC8A55
    ;             1488540E038A551C88118A55FC88540F018A55F888140183C104FF4DCC75DFFF45E4395DE47CA68B45180145E0015DDCFF4DC80F8594FDFFFF8B451099F7
    ;             FB8955F08945E885C00F8E450100008B45EC0FAFC38365DC008945D48B45E88945CC33C08945F88945FC89451C8945148945103945EC7E6085DB7E518B4D
    ;             D88B45080FAFCB034D108D50020FAF4D18034DDC8BF08BF88945F403CA2BF22BFA2955F4895DC80FB6440E030145140FB60101451C0FB6440F010145FC8B
    ;             45F40FB604080145F883C104FF4DC875D8FF45108B45103B45EC7CA08B4DD485C9740B8B451499F7F9894514EB048365140033F63BCE740B8B451C99F7F9
    ;             89451CEB0389751C3BCE740B8B45FC99F7F98945FCEB038975FC3BCE740B8B45F899F7F98945F8EB038975F88975103975EC7E5585DB7E468B4DD88B450C
    ;             0FAFCB034D108D50020FAF4D18034DDC8BF08BF803CA2BF22BFA2BC2895DC88A551488540E038A551C88118A55FC88540F018A55F888140183C104FF4DC8
    ;             75DFFF45108B45103B45EC7CAB8BC3C1E0020145DCFF4DCC0F85CEFEFFFF8B4DEC33C08945F88945FC89451C8945148945103BC87E6C3945F07E5C8B4DD8
    ;             8B75E80FAFCB034D100FAFF30FAF4D188B45088D500203CA8D0CB18BF08BF88945F48B45F02BF22BFA2955F48945C80FB6440E030145140FB60101451C0F
    ;             B6440F010145FC8B45F40FB604010145F883C104FF4DC875D833C0FF45108B4DEC394D107C940FAF4DF03BC874068B451499F7F933F68945143BCE740B8B
    ;             451C99F7F989451CEB0389751C3BCE740B8B45FC99F7F98945FCEB038975FC3BCE740B8B45F899F7F98945F8EB038975F88975083975EC7E63EB0233F639
    ;             75F07E4F8B4DD88B75E80FAFCB034D080FAFF30FAF4D188B450C8D500203CA8D0CB18BF08BF82BF22BFA2BC28B55F08955108A551488540E038A551C8811
    ;             8A55FC88540F018A55F888140883C104FF4D1075DFFF45088B45083B45EC7C9F5F5E33C05BC9C21800
    ;             )"
    ;         } else {
    ;             MCode_PixelateBitmap := "
    ;             (ltrim join
    ;             4489442418488954241048894C24085355565741544155415641574883EC28418BC1448B8C24980000004C8BDA99488BD941F7F9448BD0448BFA8954240C
    ;             448994248800000085C00F8E9D020000418BC04533E4458BF299448924244C8954241041F7F933C9898C24980000008BEA89542404448BE889442408EB05
    ;             4C8B5C24784585ED0F8E1A010000458BF1418BFD48897C2418450FAFF14533D233F633ED4533E44533ED4585C97E5B4C63BC2490000000418D040A410FAF
    ;             C148984C8D441802498BD9498BD04D8BD90FB642010FB64AFF4403E80FB60203E90FB64AFE4883C2044403E003F149FFCB75DE4D03C748FFCB75D0488B7C
    ;             24188B8C24980000004C8B5C2478418BC59941F7FE448BE8418BC49941F7FE448BE08BC59941F7FE8BE88BC69941F7FE8BF04585C97E4048639C24900000
    ;             004103CA4D8BC1410FAFC94863C94A8D541902488BCA498BC144886901448821408869FF408871FE4883C10448FFC875E84803D349FFC875DA8B8C249800
    ;             0000488B5C24704C8B5C24784183C20448FFCF48897C24180F850AFFFFFF8B6C2404448B2424448B6C24084C8B74241085ED0F840A01000033FF33DB4533
    ;             DB4533D24533C04585C97E53488B74247085ED7E42438D0C04418BC50FAF8C2490000000410FAFC18D04814863C8488D5431028BCD0FB642014403D00FB6
    ;             024883C2044403D80FB642FB03D80FB642FA03F848FFC975DE41FFC0453BC17CB28BCD410FAFC985C9740A418BC299F7F98BF0EB0233F685C9740B418BC3
    ;             99F7F9448BD8EB034533DB85C9740A8BC399F7F9448BD0EB034533D285C9740A8BC799F7F9448BC0EB034533C033D24585C97E4D4C8B74247885ED7E3841
    ;             8D0C14418BC50FAF8C2490000000410FAFC18D04814863C84A8D4431028BCD40887001448818448850FF448840FE4883C00448FFC975E8FFC2413BD17CBD
    ;             4C8B7424108B8C2498000000038C2490000000488B5C24704503E149FFCE44892424898C24980000004C897424100F859EFDFFFF448B7C240C448B842480
    ;             000000418BC09941F7F98BE8448BEA89942498000000896C240C85C00F8E3B010000448BAC2488000000418BCF448BF5410FAFC9898C248000000033FF33
    ;             ED33F64533DB4533D24533C04585FF7E524585C97E40418BC5410FAFC14103C00FAF84249000000003C74898488D541802498BD90FB642014403D00FB602
    ;             4883C2044403D80FB642FB03F00FB642FA03E848FFCB75DE488B5C247041FFC0453BC77CAE85C9740B418BC299F7F9448BE0EB034533E485C9740A418BC3
    ;             99F7F98BD8EB0233DB85C9740A8BC699F7F9448BD8EB034533DB85C9740A8BC599F7F9448BD0EB034533D24533C04585FF7E4E488B4C24784585C97E3541
    ;             8BC5410FAFC14103C00FAF84249000000003C74898488D540802498BC144886201881A44885AFF448852FE4883C20448FFC875E941FFC0453BC77CBE8B8C
    ;             2480000000488B5C2470418BC1C1E00203F849FFCE0F85ECFEFFFF448BAC24980000008B6C240C448BA4248800000033FF33DB4533DB4533D24533C04585
    ;             FF7E5A488B7424704585ED7E48418BCC8BC5410FAFC94103C80FAF8C2490000000410FAFC18D04814863C8488D543102418BCD0FB642014403D00FB60248
    ;             83C2044403D80FB642FB03D80FB642FA03F848FFC975DE41FFC0453BC77CAB418BCF410FAFCD85C9740A418BC299F7F98BF0EB0233F685C9740B418BC399
    ;             F7F9448BD8EB034533DB85C9740A8BC399F7F9448BD0EB034533D285C9740A8BC799F7F9448BC0EB034533C033D24585FF7E4E4585ED7E42418BCC8BC541
    ;             0FAFC903CA0FAF8C2490000000410FAFC18D04814863C8488B442478488D440102418BCD40887001448818448850FF448840FE4883C00448FFC975E8FFC2
    ;             413BD77CB233C04883C428415F415E415D415C5F5E5D5BC3
    ;             )"
    ;         }
    ;         PixelateBitmap := buffer(strlen(MCode_PixelateBitmap)//2)
    ;         loop(strlen(MCode_PixelateBitmap)//2)
    ;             NumPut("uchar", "0x" substr(MCode_PixelateBitmap, (2*A_Index)-1, 2), PixelateBitmap, A_Index-1)
    ;         dllcall("VirtualProtect", "ptr",&PixelateBitmap, "ptr",VarSetCapacity(PixelateBitmap), "uint",0x40, "ptr*",0)
    ;     }
    ;     this.getSize(Width, Height)
    ;     E1 := this.GdipBitmapLockBits([0, 0, Width, Height], Stride1, Scan01, BitmapData1)
    ;     E2 := oBitmapOut.GdipBitmapLockBits([0, 0, Width, Height], Stride2, Scan02, BitmapData2)
    ;     if (E1 || E2)
    ;         return -3
    ;     ; E := - unused exit code
    ;     dllcall(&PixelateBitmap, "ptr",Scan01, "ptr",Scan02, "int",Width, "int",Height, "int",Stride1, "int",BlockSize)
    ;     this.GdipBitmapUnlockBits(BitmapData1)
    ;     oBitmapOut.GdipBitmapUnlockBits(BitmapData2)
    ;     return 0
    ; }

    ;Quality 0-100
    GdipSaveImageToFile(fp, quality:=100) {
        SplitPath(fp,,, &ext)
        if !(ext ~= "^(?i:bmp|dib|rle|jpg|jpeg|jpe|jfif|gif|tif|tiff|png)$")
            return -1
        this.select_codec(ext, quality)
        return dllcall("gdiplus\GdipSaveImageToFile","ptr",this, "ptr",strptr(fp), "ptr",this.pCodec, "ptr",this.EncoderParameter) ? -5 : 0
    }

    ;CryptBinaryToString(bufBin, nFlags:=0x4) {
    ;    dllcall("Crypt32.dll\CryptBinaryToString", "ptr",bufBin, "uint",bufBin.size, "uint",nFlags, "ptr",0, "uint*",&base64Length:=0)
    ;    bufBase64 := buffer(base64Length*2, 0)
    ;    dllcall("Crypt32.dll\CryptBinaryToString", "ptr",bufBin, "uint",bufBin.size, "uint",nFlags, "ptr",bufBase64, "uint*",&base64Length)
    ;    return strget(bufBase64)
    ;}

    ;https://docs.microsoft.com/en-us/windows/win32/api/gdiplusheaders/nf-gdiplusheaders-bitmap-lockbits
    ;LockMode https://docs.microsoft.com/en-us/dotnet/api/system.drawing.imaging.imagelockmode
    ;      ReadOnly	1
    ;      WriteOnly	2
    ;      ReadWrite	3
    ;      UserInputBuffer	4
    ;PixelFormat https://docs.microsoft.com/en-us/dotnet/api/system.drawing.imaging.pixelformat
    ;      Argb	0x26200A
    ;      rgb		？不是0x21808
    GdipBitmapLockBits(aRect, &Stride, &Scan0, &bufBitmapData, LockMode:=3, PixelFormat:=0x21808) {
        bufRect := buffer(A_PtrSize*4)
        numput("uint", aRect[1], bufRect, A_PtrSize*0)
        numput("uint", aRect[2], bufRect, A_PtrSize*1)
        numput("uint", aRect[3], bufRect, A_PtrSize*2)
        numput("uint", aRect[4], bufRect, A_PtrSize*3)
        bufBitmapData := buffer(16 + 2 * A_PtrSize, 0)
        _E := dllcall("Gdiplus\GdipBitmapLockBits", "ptr",this, "ptr",bufRect, "uint",LockMode, "int",PixelFormat, "ptr",bufBitmapData)
        Stride := numget(bufBitmapData, 8, "Int")
        Scan0 := numget(bufBitmapData, 16, "ptr")
        return _E
    }

    ;获取的可能是 agrb
    getLockBitPixel(Scan0, x, y, Stride) {
        return numget(Scan0, (x*4)+(y*Stride), "UInt")
    }

    GdipBitmapUnlockBits(bufBitmapData) {
        return dllcall("Gdiplus\GdipBitmapUnlockBits", "ptr",this, "ptr",bufBitmapData)
    }

    ;-----------------------------------ImagePut-----------------------------------
    ;判断输入的图片类型
    ImageType(oInput) {
        ; Throw if the oInput is an empty string.
        if (oInput == "")
            throw Error("oInput data is an empty string.")
        if (isobject(oInput)) {
            if (oInput.base.HasOwnProp("__class") && oInput.base is ClipboardAll) {
                if (dllcall("IsClipboardFormatAvailable", "uint",dllcall("RegisterClipboardFormat", "str","png", "uint")))
                    return "clipboard_png"
                if (dllcall("IsClipboardFormatAvailable", "uint",2)) ;CF_BITMAP
                    return "clipboard"
                throw Error("Clipboard format not supported.")
            }
            if (oInput is GDIP_PBitmap) ;NOTE hy
                return "GDIP_PBitmap"
            if (oInput.HasOwnProp("pBitmap")) ; A "object" has a pBitmap property that points to an internal GDI+ bitmap.
                return "object"
            if (oInput.HasOwnProp("ptr") && oInput.HasOwnProp("size"))
                return "buffer"
            if (oInput[1] ~= "^-?\d+$" && oInput[2] ~= "^-?\d+$" && oInput[3] ~= "^-?\d+$" && oInput[4] ~= "^-?\d+$") ;aRect
                return "screenshot"
        }
        ; A "window" is anything considered a Window Title including ahk_class and "A".
        if (WinExist(oInput))
            return "window"
        if (oInput = "desktop") ;a hidden window behind the desktop icons created by ImagePutDesktop.
            return "desktop"
        if (oInput = "wallpaper")
            return "wallpaper"
        if (oInput ~= "(?i)^A_Cursor|Unknown|(IDC_)?(AppStarting|Arrow|Cross|Hand(writing)?|Help|IBeam|No|Pin|Person|SizeAll|SizeNESW|SizeNS|SizeNWSE|SizeWE|UpArrow|Wait)$")
            return "cursor"
        ; A "pdf" is either a file or url with a .pdf extension.
        if (oInput ~= "\.pdf$") && (FileExist(oInput) || this.is_url(oInput))
            return "pdf"
        if (this.is_url(oInput))
            return "url"
        if (FileExist(oInput))
            return "file"
        if (strlen(oInput) >= 116) && (oInput ~= "(?i)^\s*(0x)?[0-9a-f]+\s*$") ;binary image data encoded into text using hexadecimal.
            return "hex"
        ; A "base64" string is binary oInput data encoded into text using standard 64 characters.
        if (strlen(oInput) >= 80) && (oInput ~= "^\s*(?:data:oInput\/[a-z]+;base64,)?(?:[A-Za-z0-9+\/]{4})*+(?:[A-Za-z0-9+\/]{3}=|[A-Za-z0-9+\/]{2}==)?\s*$")
            return "base64"
        ;数字
        if (oInput ~= "^-?\d+$") {
            ; A non-zero "monitor" number identifies each display uniquely; and 0 refers to the entire virtual screen.
            if (oInput >= 0 && oInput <= MonitorGetCount())
                return "monitor"
            ; A "dc" is a handle to a GDI device context.
            if (dllcall("GetObjectType", "ptr",oInput, "uint") == 3 || dllcall("GetObjectType", "ptr",oInput, "uint") == 10)
                return "dc"
            ; An "hBitmap" is a handle to a GDI Bitmap.
            if (dllcall("GetObjectType", "ptr",oInput, "uint") == 7)
                return "hBitmap"
            ; An "hIcon" is a handle to a GDI icon.
            if (dllcall("DestroyIcon", "ptr",dllcall("CopyIcon", "ptr",oInput, "ptr")))
                return "hIcon"
            ; A "bitmap" is a pointer to a GDI+ Bitmap.
            try if !dllcall("gdiplus\GdipGetImageType", "ptr",oInput, "ptr*",&type:=0) && (type == 1)
                return "bitmap"
            ; Note 1: All GDI+ functions add 1 to the reference count of COM objects.
            ; Note 2: GDI+ pBitmaps that are queried cease to stay pBitmaps.
            ; Note 3: Critical error for ranges 0-4095 on v1 and 0-65535 on v2.
            ObjRelease(oInput) ; Therefore do not move this, it has been tested.
            ; A "stream" is a pointer to the IStream interface.
            try if (ComObjQuery(oInput, "{0000000C-0000-0000-C000-000000000046}"))
                return "stream"
            ; A "RandomAccessStream" is a pointer to the IRandomAccessStream interface.
            try if (ComObjQuery(oInput, "{905A0FE1-BC53-11DF-8C49-001E4FC686DA}"))
                return "RandomAccessStream"
        }
        ; For more helpful error messages: Catch file names without extensions!
        for extension in ["bmp","dib","rle","jpg","jpeg","jpe","jfif","gif","tif","tiff","png","ico","exe","dll"]
            if (FileExist(format("{1}.{2}", oInput,extension)))
                throw Error(format("A .{1} file extension is required!", extension))
        throw Error("oInput type could not be identified.")
    }

    ;GdipCreateBitmapFromFileICM(bitmap) {
    ;    dllcall("gdiplus\GdipCreateBitmapFromFileICM", "wstr",bitmap, "ptr*",&pBitmap:=0)
    ;    if (!pBitmap)
    ;        msgbox(A_ThisFunc)
    ;    return this.ptr := pBitmap
    ;}

    toStream(ext:="tif", quality:="") {
        this.select_codec(ext, quality)
        dllcall("ole32\CreateStreamOnHGlobal", "ptr",0, "int",true, "ptr*",&pStream:=0, "HRESULT")
        dllcall("gdiplus\GdipSaveImageToStream", "ptr",this, "ptr",pStream, "ptr",this.pCodec, "ptr",this.HasOwnProp("EncoderParameter") ? this.EncoderParameter : 0)
        return pStream
    }

    getStreamFromClipboardPng() {
        if !dllcall("OpenClipboard", "ptr", A_ScriptHwnd)
            return
        idExt := dllcall("RegisterClipboardFormat", "str","png", "uint")
        if !dllcall("IsClipboardFormatAvailable", "uint",idExt)
            throw Error(format('Clipboard does not have "PNG" stream data.', idExt))
        if !(hData := dllcall("GetClipboardData", "uint",idExt, "ptr"))
            throw Error("Shared clipboard data has been deleted.")
        ; Allow the stream to be freed while leaving the hData intact.
        ; Please read: https://devblogs.microsoft.com/oldnewthing/20210930-00/?p=105745
        pStream := this.CreateStreamOnHGlobal(hData)
        dllcall("CloseClipboard")
        return pStream
    }

    getStreamFromFile(fp) {
        f := FileOpen(fp, "r")
        hData := dllcall("GlobalAlloc", "uint",0x2, "ptr",f.length, "ptr")
        pData := dllcall("GlobalLock", "ptr",hData, "ptr")
        f.RawRead(pData, f.length)
        dllcall("GlobalUnlock", "ptr",hData)
        f.close()
        return this.CreateStreamOnHGlobal(hData)
    }

    getStreamFromUrl(image) {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", image, true)
        req.Send()
        req.WaitForResponse()
        IStream := ComObjQuery(req.ResponseStream, "{0000000C-0000-0000-C000-000000000046}"), ObjAddRef(IStream.ptr)
        return IStream.ptr
    }

    ;streamToxxx(pStream) {
    ;    dllcall("ole32\GetHGlobalFromStream", "ptr", pStream, "ptr*", hMemory)
    ;    pMemory := dllcall("GlobalLock", "ptr", hMemory, "ptr")
    ;    pSize   := dllcall("GlobalSize", "ptr", hMemory, "uptr")
    ;    return [pMemory, pSize]
    ;}

    ;Thanks malcev - https://www.autohotkey.com/boards/viewtopic.php?t=80735
    getFromPdf(fp, index := 0) {
        ; Create a stream from either a url or a file.
        pStream := this.isUrl(fp) ? this.getStreamFromUrl(fp) : this.getStreamFromFile(fp)
        ; Compare the signature of the file with the PDF magic string "%PDF".
        dllcall("shlwapi\IStream_Read", "ptr",pStream, "ptr",signature:=buffer(4), "uint",4, "HRESULT")
        StrPut("%PDF", magic:=buffer(4), "CP0")
        if (dllcall("ntdll\RtlCompareMemory", "ptr",signature, "ptr",magic, "uptr",4, "uptr") < 4)
            throw Error("Could not be loaded from a valid file path or URL.")
        ; Create a RandomAccessStream with BSOS_PREFERDESTINATIONSTREAM.
        dllcall("ole32\CLSIDFromString", "wstr","{905A0FE1-BC53-11DF-8C49-001E4FC686DA}", "ptr",CLSID:=buffer(16), "HRESULT")
        dllcall("ShCore\CreateRandomAccessStreamOverStream", "ptr",pStream, "uint",1, "ptr",CLSID, "ptr*",&pRandomAccessStream:=0, "HRESULT")
        ; Create the "Windows.Data.Pdf.PdfDocument" class using IPdfDocumentStatics.
        dllcall("combase\WindowsCreateString", "wstr","Windows.Data.Pdf.PdfDocument", "uint",28, "ptr*",&hString:=0, "HRESULT")
        dllcall("ole32\CLSIDFromString", "wstr","{433A0B5F-C007-4788-90F2-08143D922599}", "ptr",CLSID:=buffer(16), "HRESULT")
        dllcall("combase\RoGetActivationFactory", "ptr",hString, "ptr",CLSID, "ptr*",&PdfDocumentStatics:=0, "HRESULT")
        dllcall("combase\WindowsDeleteString", "ptr",hString, "HRESULT")
        ; Create the PDF document.
        ComCall(IPdfDocumentStatics_LoadFromStreamAsync:=8, PdfDocumentStatics, "ptr",pRandomAccessStream, "ptr*",&PdfDocument:=0)
        PdfDocument := this.WaitForAsync()
        ; Get Page
        ComCall(IPdfDocument_GetPage:=7, PdfDocument, "uint*",&count:=0)
        index := (index > 0) ? index - 1 : (index < 0) ? count + index : 0 ; Zero indexed.
        if (index > count || index < 0) {
            ObjRelease(PdfDocument)
            ObjRelease(PdfDocumentStatics)
            this.ObjReleaseClose(&pRandomAccessStream)
            ObjRelease(pStream)
            throw Error("The maximum number of pages in this pdf is " count ".")
        }
        ComCall(IPdfDocument_GetPage:=6, PdfDocument, "uint",index, "ptr*",&PdfPage:=0)
        ; Render the page to an output stream.
        dllcall("ole32\CreateStreamOnHGlobal", "ptr",0, "uint",true, "ptr*",&pStreamOut:=0)
        dllcall("ole32\CLSIDFromString", "wstr","{905A0FE1-BC53-11DF-8C49-001E4FC686DA}", "ptr",CLSID:=buffer(16), "HRESULT")
        dllcall("ShCore\CreateRandomAccessStreamOverStream", "ptr",pStreamOut, "uint",BSOS_DEFAULT:=0, "ptr",CLSID, "ptr*", &pRandomAccessStreamOut:=0)
        ComCall(IPdfPage_RenderToStreamAsync:=6, PdfPage, "ptr",pRandomAccessStreamOut, "ptr*",&AsyncInfo:=0)
        AsyncInfo := this.WaitForAsync()
        ; Cleanup
        this.ObjReleaseClose(&pRandomAccessStreamOut)
        this.ObjReleaseClose(&PdfPage)
        ObjRelease(PdfDocument)
        ObjRelease(PdfDocumentStatics)
        this.ObjReleaseClose(&pRandomAccessStream)
        ObjRelease(pStream)
        return pStreamOut
    }

    WaitForAsync() {
        AsyncInfo := ComObjQuery(Object, IAsyncInfo := "{00000036-0000-0000-C000-000000000046}")
        while !ComCall(IAsyncInfo_Status := 7, AsyncInfo, "uint*", &status:=0)
            and (status = 0)
        Sleep 10
        if (status != 1) {
            ComCall(IAsyncInfo_ErrorCode := 8, AsyncInfo, "uint*", &ErrorCode:=0)
            throw Error("AsyncInfo status error: " ErrorCode)
        }
        ComCall(8, Object, "ptr*", &ObjectResult:=0) ; GetResults
        ObjRelease(Object)
        Object := ObjectResult
        ComCall(IAsyncInfo_Close := 10, AsyncInfo)
        AsyncInfo := ""
        return Object
    }

    ObjReleaseClose(&obj) {
        if (obj) {
            if (Close := ComObjQuery(obj, IClosable := "{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}")) {
                ComCall(IClosable_Close := 6, Close)
                Close := ""
            }
            refcount := ObjRelease(obj)
            obj := ""
            return refcount
        }
    }

    getStreamFromBase64(sBase64) {
        sBase64 := RegExReplace(trim(sBase64), "^data:image\/[a-z]+;base64,")
        return this._getStreamByString(sBase64, 0x1)
    }

    ; https://docs.microsoft.com/en-us/windows/win32/api/combaseapi/nf-combaseapi-createstreamonhglobal
    ; https://devblogs.microsoft.com/oldnewthing/20210928-00/?p=105737
    CreateStreamOnHGlobal(hGlobal, fDeleteOnRelease:=false) {
        dllcall("ole32\CreateStreamOnHGlobal", "ptr",hGlobal, "int",fDeleteOnRelease, "ptr*",&pStream:=0, "HRESULT")
        return pStream
    }

    isUrl(url) {
        ; Thanks dperini - https://gist.github.com/dperini/729294
        ; Also see for comparisons: https://mathiasbynens.be/demo/url-regex
        ; Modified to be compatible with AutoHotkey. \u0000 -> \x{0000}.
        ; Force the declaration of the protocol because WinHttp requires it.
        return url ~= "^(?i)"
            . "(?:(?:https?|ftp):\/\/)" ; protocol identifier (FORCE)
            . "(?:\S+(?::\S*)?@)?" ; user:pass BasicAuth (optional)
            . "(?:"
        ; IP address exclusion
        ; private & local networks
            . "(?!(?:10|127)(?:\.\d{1,3}){3})"
            . "(?!(?:169\.254|192\.168)(?:\.\d{1,3}){2})"
            . "(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})"
        ; IP address dotted notation octets
        ; excludes loopback network 0.0.0.0
        ; excludes reserved space >= 224.0.0.0
        ; excludes network & broadcast addresses
        ; (first & last IP address of each class)
            . "(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])"
            . "(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}"
            . "(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))"
            . "|"
        ; host & domain names, may end with dot
        ; can be replaced by a shortest alternative
        ; (?![-_])(?:[-\\w\\u00a1-\\uffff]{0,63}[^-_]\\.)+
            . "(?:(?:[a-z0-9\x{00a1}-\x{ffff}][a-z0-9\x{00a1}-\x{ffff}_-]{0,62})?[a-z0-9\x{00a1}-\x{ffff}]\.)+"
        ; TLD identifier name, may end with dot
            . "(?:[a-z\x{00a1}-\x{ffff}]{2,}\.?)"
            . ")"
            . "(?::\d{2,5})?" ; port number (optional)
            . "(?:[/?#]\S*)?$" ; resource path (optional)
    }

    ;CRYPT_STRING_BASE64:=0x1
    ;CRYPT_STRING_HEXRAW:=0xC
    _getStreamByString(image, flags) {
        ;Ask for the size. Then allocate movable memory, copy to the buffer, unlock, and create stream.
        dllcall("crypt32\CryptStringToBinary", "ptr",strptr(image), "uint",0, "uint",flags, "ptr",0, "uint*",&size:=0, "ptr",0, "ptr",0)
        hData := dllcall("GlobalAlloc", "uint",0x2, "ptr",size, "ptr")
        pData := dllcall("GlobalLock", "ptr",hData, "ptr")
        dllcall("crypt32\CryptStringToBinary", "ptr",strptr(image), "uint",0, "uint",flags, "ptr",pData, "uint*",size, "ptr",0, "ptr",0)
        dllcall("GlobalUnlock", "ptr",hData)
        return this.CreateStreamOnHGlobal(hData)
    }

    select_extension(pStream) {
        dllcall("shlwapi\IStream_Reset", "ptr",pStream, "HRESULT")
        dllcall("shlwapi\IStream_Read", "ptr",pStream, "ptr",signature:=buffer(12), "uint",12, "HRESULT")
        ; This function sniffs the first 12 bytes and matches a known file signature.
        ; 256 bytes is recommended, but images only need 12 bytes.
        ; See: https://en.wikipedia.org/wiki/List_of_file_signatures
        dllcall("urlmon\FindMimeFromData"
            , "ptr", 0             ; pBC
            , "ptr", 0             ; pwzUrl
            , "ptr", signature     ; pBuffer
            , "uint", 12            ; cbSize
            , "ptr", 0             ; pwzMimeProposed
            , "uint", 0x20          ; dwMimeFlags
            , "ptr*", &MimeType:=0  ; ppwzMimeOut
            , "uint", 0             ; dwReserved
        ,"HRESULT")
        ; The output is a pointer to a Mime string. It must be dereferenced.
        MimeType := strget(MimeType, "UTF-16")
        if (MimeType ~= "gif")
            return "gif"
        if (MimeType ~= "jpeg")
            return "jpg"
        if (MimeType ~= "png")
            return "png"
        if (MimeType ~= "tiff")
            return "tif"
        if (MimeType ~= "bmp")
            return "bmp"
    }

    ; Thanks noname - https://www.autohotkey.com/boards/viewtopic.php?style=7&p=144247#p144247
    setStringByStream(pStream, flags) {
        ; For compatibility with SHCreateMemStream do not use GetHGlobalFromStream.
        dllcall("shlwapi\IStream_Size", "ptr",pStream, "ptr*",&size:=0, "HRESULT")
        dllcall("shlwapi\IStream_Reset", "ptr",pStream, "HRESULT")
        dllcall("shlwapi\IStream_Read", "ptr",pStream, "ptr",bin:=buffer(size), "uint",size, "HRESULT")
        ; Using CryptBinaryToStringA saves about 2MB in memory.
        dllcall("crypt32\CryptBinaryToStringA", "ptr",bin, "uint",size, "uint",flags, "ptr",0, "uint*",&nLen:=0)
        str := buffer(nLen)
        dllcall("crypt32\CryptBinaryToStringA", "ptr",bin, "uint",size, "uint",flags, "ptr",str, "uint*",nLen)
        return strget(str, nLen, "CP0")
    }

    ;this.toStream()
    getBase64FromStream(pStream) {
        return this.setStringByStream(pStream, 0x40000001) ; CRYPT_STRING_NOCRLF | CRYPT_STRING_BASE64
    }

    ;this.toStream()
    ;ext: 用jpg还是tif
    toBase64(ext:="jpg", quality:=100) {
        pStream := this.toStream(ext, quality)
        return this.getBase64FromStream(pStream)
    }

    ;主要生成
    ;this.pCodec
    ;this.EncoderParameter
    ;this.CodecInfo
    ;this.bufCodecInfo
    ;TODO 目的是什么
    select_codec(ext, quality:=100) {
        dllcall("gdiplus\GdipGetImageEncodersSize", "uint*",&nCount:=0, "uint*",&nSize:=0)
        this.bufCodecInfo := buffer(nSize)
        dllcall("gdiplus\GdipGetImageEncoders", "uint",nCount, "uint",this.bufCodecInfo.size, "ptr",this.bufCodecInfo)
        ; struct ImageCodecInfo - http://www.jose.it-berater.org/gdiplus/reference/structures/imagecodecinfo.htm
        ;获取 idx
        loop {
            if (A_Index > nCount)
                throw Error("Could not find a matching encoder for the specified file format.")
            idx := (48+7*A_PtrSize) * (A_Index-1)
        } until instr(strget(numget(this.bufCodecInfo, idx+32+3*A_PtrSize, "ptr"), "UTF-16"), ext)
        ;idx →pCodec
        this.pCodec := this.bufCodecInfo.ptr + idx ; ClassID
        if (quality ~= "^\d+$") && ("image/jpeg" == strget(numget(this.bufCodecInfo, idx+32+4*A_PtrSize, "ptr"), "UTF-16")) { ; MimeType
            numput("uint", quality, this.bufQuality:=buffer(4))
            ; struct EncoderParameter - http://www.jose.it-berater.org/gdiplus/reference/structures/encoderparameter.htm
            ; enum ValueType - https://docs.microsoft.com/en-us/dotnet/api/system.drawing.imaging.encoderparametervaluetype
            ; clsid Image Encoder Constants - http://www.jose.it-berater.org/gdiplus/reference/constants/gdipimageencoderconstants.htm
            this.EncoderParameter := buffer(24+2*A_PtrSize)
            numput("ptr", 1, this.EncoderParameter) ; Count
            dllcall("ole32\CLSIDFromString", "wstr","{1D5BE4B5-FA4A-452D-9CDD-5DB35105E7EB}", "ptr",this.EncoderParameter.ptr+A_PtrSize, "HRESULT")
            numput("uint",1, "uint",4, "ptr",this.bufQuality.ptr, this.EncoderParameter.ptr, 16+A_PtrSize) ;Number of Values & Type & Value
        }
    }

}

;hh
;需要用 Gui 显示的，需要 oHBitmap 并生成 oGraphics
class GDIP_HBitmap extends _GDIP {
    ptr := 0

    __new(widthOrPBitmap, heightOrColor:=0xffFFFFFF, hDC:=0) {
        if (isobject(widthOrPBitmap)) {
            if (widthOrPBitmap is GDIP_PBitmap) {
                dllcall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr",widthOrPBitmap, "ptr*",&hBitmap:=0, "int",heightOrColor)
                arr := widthOrPBitmap.getSize()
                this.w := arr[1]
                this.h := arr[2]
                this.ptr := hBitmap
            } else if (widthOrPBitmap is Array) { ;aRect
                this.getFromRect(widthOrPBitmap)
            }
        } else {
            this.CreateDIBSection(widthOrPBitmap, heightOrColor, hDC)
        }
    }

    __delete() {
        _GDIP.DeleteObject(this.ptr)
    }

    CreateCompatibleBitmap(hdc, w, h) {
        return DllCall("gdi32\CreateCompatibleBitmap", "Ptr", hdc, "int", w, "int", h)
    }

    getFromRect(aRect) {
        x := aRect[1]
        y := aRect[2]
        w := aRect[3]
        h := aRect[4]
        ;方式1，原始
        tDC := dllcall("CreateCompatibleDC", "ptr",0, "ptr")
        ;创建 hBitmap
        this.CreateDIBSection(w, h, tDC)
        ;修改 hBitmap
        oBM := dllcall("SelectObject", "Uint",tDC, "ptr",this)
        hDC := dllcall("GetDC", "ptr",0, "ptr")
        dllcall("BitBlt", "Uint", tDC, "int",0,"int",0,"int",w,"int",h, "Uint",hDC, "int",x, "int",y, "Uint",0x40000000 | 0x00CC0020)
        dllcall("ReleaseDC", "Uint",0, "Uint",hDC)
        dllcall("SelectObject", "Uint",tDC, "ptr",oBM)
        dllcall("DeleteDC", "Uint", tDC)
    }

    ; 创建一个与设备无关的位图。什么叫与设备无关呢？
    ; 比如你创建一个和屏幕有关的位图，同时你的屏幕是256彩色显示的，这个位图就只能是256彩色。
    ; 又比如你创建一个和黑白打印机有关的位图，这个位图就只能是黑白灰色的。
    ; 设备相关位图 DDB(Device-Dependent-Bitmap)
    ; DDB 不具有自己的调色板信息，它的颜色模式必须与输出设备相一致。
    ; 如：在256色以下的位图中存储的像素值是系统调色板的索引，其颜色依赖于系统调色板。
    ; 由于 DDB 高度依赖输出设备，所以 DDB 只能存在于内存中，它要么在视频内存中，要么在系统内存中。
    ; 设备无关位图 DIB(Device-Independent-Bitmap)
    ; DIB 具有自己的调色板信息，它可以不依赖系统的调色板。
    ; 由于它不依赖于设备，所以通常用它来保存文件，如 .bmp 格式的文件就是 DIB 。
    ; 使用指定的宽高创建这个位图，之后不管你是画画也好，贴图也罢，就这么大地方给你用了。
    ; https://docs.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-createdibsection
    CreateDIBSection(w, h, hDC:=0, bpp:=32, &ppvBits:=0) {
        hDC2 := hDC ? hDC : dllcall("GetDC", "ptr",0, "ptr")
        bufBI := _GDIP._bufBitmapInfoHeader(w, h, bpp)
        hBitmap := dllcall("CreateDIBSection", "ptr",hDC2, "ptr",bufBI, "uint",0, "ptr*",&ppvBits, "ptr",0, "uint",0, "ptr")
        if (!hDC)
            dllcall("ReleaseDC", "ptr",0, "ptr",hDC2)
        return this.ptr := hBitmap
    }

    ; Gdip_CreateHICONFromBitmap(pBitmap) {
    ;     pBitmap := ""
    ;     dllcall("gdiplus\GdipCreateHICONFromBitmap", "ptr",pBitmap, "ptr*",&hIcon:=0)
    ;     return hIcon
    ; }

    ; SetImage(ctlID) {
    ;     res := SendMessage(0x172,, this.ptr,, "ahk_id " . ctlID)
    ;     dllcall("DeleteObject", "Uint",res)
    ;     return res
    ; }

    ;复制 hBitmap 图像到剪切板
    SetClipboardData(bDelete:=false) {
        bufOI := buffer(84,0)
        dllcall("GetObject", "Uint",this.ptr, "int",bufOI.size, "Uint",&bufOI)
        hDIB := dllcall("GlobalAlloc", "Uint",2, "Uint",40+numget(bufOI,44))
        pDIB := dllcall("GlobalLock", "Uint",hDIB)
        dllcall("RtlMoveMemory", "Uint",pDIB, "Uint",&bufOI+24, "Uint",40)
        dllcall("RtlMoveMemory", "Uint",pDIB+40, "Uint",numget(bufOI,20), "Uint",numget(bufOI,44))
        dllcall("GlobalUnlock", "Uint",hDIB)
        if (bDelete)
            dllcall("DeleteObject", "Uint",this.ptr)
        dllcall("OpenClipboard", "Uint",0)
        dllcall("EmptyClipboard")
        dllcall("SetClipboardData", "Uint",8, "Uint",hDIB)
        dllcall("CloseClipboard")
    }

    ;贴图
    showByGui(aRect:=unset) {
        ;放入gui
        ; oGui := gui("-Caption +ToolWindow +AlwaysOnTop +LastFound +Border -DPIScale")
        oGui := gui("-Caption +ToolWindow +AlwaysOnTop +LastFound -DPIScale") ;no border
        ;oGui.title := "hyd-" . A_Now
        oGui.OnEvent("ContextMenu", (p*)=>oGui.destroy())
        oGui.MarginX := 0
        oGui.MarginY := 0
        if (!isset(aRect)) {
            MouseGetPos(&xMouse, &yMouse)
            aRect := [xMouse,yMouse,this.w,this.h]
        }
        oPic := oGui.AddPicture(format("w{1} h{2} +0xE", aRect[3],aRect[4]))
        oPic.OnEvent("click", (p*)=>PostMessage(WM_NCLBUTTONDOWN:=0xA1, 2)) ; 随着鼠标移动
        ;oPic.OnEvent("DoubleClick", ObjBindMethod(this,"zoom"))
        SendMessage(STM_SETIMAGE:=0x172,, this.ptr,, "ahk_id " . oPic.hwnd)
        oGui.show(format("x{1} y{2}", aRect[1]-1,aRect[2]-1))
    }
    zoom(oCtl) {
        n := 2
        objPos := oCtl.pos
        objGuiPos := oCtl.Gui.pos
        w := objPos.w
        h := objPos.h
        oPBitmap := GDIP_PBitmap([objGuiPos.x+1,objGuiPos.y+1,w,h])
        this.resize(n*100)
        oHBitmap := GDIP_HBitmap(oPBitmap)
        oPBitmap := ""
        SendMessage(STM_SETIMAGE:=0x172,, this.ptr,, "ahk_id " . oCtl.hwnd)
        ControlMove(,, w*n, h*n, oCtl)
        WinMove(,, w*n, h*n, "ahk_id " . oCtl.Gui.hwnd)
        ;if (!isobject(oCtl))
        ;{
        ;MouseGetPos(,, idWin, oCtl)
        ;ControlGetPos(x,y,w,h, oCtl, "ahk_id " . idWin)
        ;}
        ;else
        ;{
        ;objPos := oCtl.pos
        ;w := objPos.w
        ;h := objPos.h
        ;objGuiPos := oCtl.Gui.pos
        ;x := objGuiPos.x+1
        ;y := objGuiPos.y+1
        ;}
        ;pToken  := Gdip_Startup()
        ;pBitmap := Gdip_BitmapFromScreen(format("{1}|{2}|{3}|{4}", x,y,w,h))
        ;pBitmap := Gdip_ResizeBitmap(pBitmap, 200)
        ;hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
        ;Gdip_DisposeImage(pBitmap)
        ;Gdip_Shutdown(pToken)
        ;E := SendMessage(0x172, 0, hBitmap,, "ahk_id " . oCtl)
        ;;E := SendMessage(0x172, 0, hBitmap,, "ahk_id " . oCtl.hwnd)
        ;dllcall("DeleteObject", "ptr",E)
        ;ControlMove(,,w*2,h*2, oCtl)
        ;WinMove(,,w*2, h*2,"ahk_id " . oCtl.Gui.hwnd)
    }
}

;gg
;NOTE 写内容都通过 GDIP_Graphics，写好后，相应的 GDIP_PBitmap就已修改，可直接 GdipSaveImageToFile
; G 表示的是一张画布，之后不管我们贴图也好，画画也好，都是画到这上面。

;DC 打包在这里
;创建一个设备环境，也就是 DC 。那什么叫 DC 呢？
; 首先，当我们想要屏幕显示出一个红色圆形图案的话，正常逻辑是直接告诉显卡，给我在 XX 坐标，显示一个 XX 大小， XX 颜色的圆出来。
; 但 Windows 不允许程序员直接访问硬件。所以当我们想要对屏幕进行操作，就得通过 Windows 提供的渠道才行。这个渠道，就是 DC 。
; 屏幕上的每一个窗口都对应一个 DC ，可以把 DC 想象成一个视频缓冲区，对这个缓冲区进行操作，会表现在这个缓冲区对应的屏幕窗口上。
; 在窗口的 DC 之外，可以建立自己的 DC ，就是说它不对应窗口，这个方法就是 CreateCompatibleDC() 。
; 这个 DC 就是一个内存缓冲区，通过这个 DC 你可以把和它兼容的窗口 DC 保存到这个 DC 中，就是说你可以通过它在不同的 DC 之间拷贝数据。
; 例如，你先在这个 DC 中建立好数据，然后再拷贝到目标窗口的 DC 中，就完成了对目标窗口的刷新。
; 最后，之所以叫设备环境，不叫屏幕环境，是因为对其它设备，比如打印机的操作，也是通过它来完成的。
; 额外的扩展，CreateCompatibleDC() 函数，创建的 DC ，又叫内存 DC ，也叫兼容 DC 。
; 我们在绘制界面的时候，常常会听到说什么“双缓冲技术”避免闪烁，实际上就是先把内容在内存 DC 中画好，再一次性拷贝到目标 DC 里。
; 而普通的画法，就是直接在目标 DC 中边显示边画，所以就会闪烁。
class GDIP_Graphics extends _GDIP {
    ptr := 0
    hDC := 0

    __new(oInstance) {
        this.pSelectObject := 0 ;没属性会报错
        if (isobject(oInstance)) {
            if (oInstance is GDIP_PBitmap)
                this.GdipGetImageGraphicsContext(oInstance.ptr)
            else if (oInstance is GDIP_HBitmap) { ;NOTE 先生成 this.hDC
                ;msgbox(oInstance.w . "`n" . oInstance.h)
                this.hDC := dllcall("CreateCompatibleDC", "ptr",0, "ptr")
                resSelect := this.SelectObject(oInstance) ;NOTE 必须先运行
                res := dllcall("gdiplus\GdipCreateFromHDC", "ptr",this.hDC, "ptr*",&pGraphics:=0)
                if (!pGraphics)
                    throw ValueError(A_ThisFunc . "`n" . res . "`n" . oInstance.ptr)
                this.ptr := pGraphics
            }
        } else if (oInstance ~= "^\d+$")
            this.GdipGetImageGraphicsContext(oInstance)
    }

    __delete() {
        dllcall("gdiplus\GdipDeleteGraphics", "Ptr",this)
        this.SelectObject()
        if (this.hDC)
            dllcall("DeleteDC", "ptr",this.hDC)
    }

    GdipGetImageGraphicsContext(pBitmap) {
        dllcall("gdiplus\GdipGetImageGraphicsContext", "ptr",pBitmap, "ptr*",&pGraphics:=0)
        if (!pGraphics)
            msgbox(A_ThisFunc)
        this.ptr := pGraphics
    }

    ;用 color 清除当前内容
    GdipGraphicsClear(color:=0) {
        return dllcall("gdiplus\GdipGraphicsClear", "Ptr",this, "uint",color)
    }

    GdipResetClip() {
        dllcall("gdiplus\GdipResetClip", "Ptr",this)
    }

    ; default = 0
    ; HighSpeed = 1
    ; HighQuality = 2
    ; None = 3
    ; AntiAlias = 4 边缘平滑
    GdipSetSmoothingMode(smoothingMode:=4) {
        return dllcall("gdiplus\GdipSetSmoothingMode", "Ptr",this, "int",smoothingMode)
    }

    ; default = 0
    ; LowQuality = 1
    ; HighQuality = 2
    ; Bilinear = 3
    ; Bicubic = 4
    ; NearestNeighbor = 5
    ; HighQualityBilinear = 6
    ; HighQualityBicubic = 7
    GdipSetInterpolationMode(interpolationMode:=7) {
        return dllcall("gdiplus\GdipSetInterpolationMode", "Ptr",this, "int",interpolationMode)
    }

    ;TextRenderingHintSystemDefault              = 0,
    ;TextRenderingHintSingleBitPerPixelGridFit   = 1,
    ;TextRenderingHintSingleBitPerPixel          = 2,
    ;TextRenderingHintAntiAliasGridFit           = 3,
    ;TextRenderingHintAntiAlias                  = 4,
    ;TextRenderingHintClearTypeGridFit           = 5
    GdipSetTextRenderingHint(TextRenderingHint:=0) {
        return dllcall("gdiplus\GdipSetTextRenderingHint", "Ptr",this, "uint",textRenderingHint)
    }

    ;------------------------------------------------rotate------------------------------------------------
    ;旋转相关
    ;根据【左上角】旋转，新的画布宽高会调整为最小矩形
    ;是给 GdipDrawImageRectRect 等【绘制】工作指定参数
    ;   1.getRotatedRect 旋转后的左上角坐标-原坐标【差值】和【新的宽高】

    ;翻转
    ;水平翻转(以右线翻转)
    ;   GdipScaleWorldTransform(-1, 1)
    ;   GdipTranslateWorldTransform(-w, 0)
    ;垂直翻转(以下线翻转)
    ;   GdipScaleWorldTransform(1, -1)
    ;   GdipTranslateWorldTransform(0, -h)
    GdipScaleWorldTransform(xScale, yScale, MatrixOrder:=0) {
        return dllcall("gdiplus\GdipScaleWorldTransform", "Ptr",this, "float",xScale, "float",yScale, "int",MatrixOrder)
    }

    ;偏移坐标(新-旧)
    ;NOTE 要在 GdipRotateWorldTransform 之后运行
    GdipTranslateWorldTransform(xOffset, yOffset, MatrixOrder:=0) {
        return dllcall("gdiplus\GdipTranslateWorldTransform", "Ptr",this, "float",xOffset, "float",yOffset, "int",MatrixOrder)
    }

    ;回收
    GdipResetWorldTransform() {
        return dllcall("gdiplus\GdipResetWorldTransform", "Ptr",this)
    }

    ;旋转 angle 度
    ;TODO MatrixOrder = 0; The operation is applied before the old operation.
    ; MatrixOrder = 1; The operation is applied after the old operation.
    ;NOTE 要在 GdipTranslateWorldTransform 等调整好之后再运行
    GdipRotateWorldTransform(angle:=90, MatrixOrder:=0) {
        return dllcall("gdiplus\GdipRotateWorldTransform", "Ptr",this, "float",angle, "int",MatrixOrder)
    }

    ;------------------------------------------------draw------------------------------------------------

    ; 把 pBitmap 画到 画布上。
    ; 整个函数的参数分别是 Gdip_DrawImage(画布, pBitmap, 新图x, 新图y, 新图宽, 新图高, 原图x, 原图y, 原图宽, 原图高, 矩阵)
    ; 最后的矩阵参数是给图像改变颜色之类用的，很高级，先不管它。
    ; 原图x, 原图y, 原图宽, 原图高
    ; 代表从原图的 (x,y) 这个坐标点开始，向右获得原图宽、向下获得原图高的图片数据
    ; 举例：当 原图x=50，原图y=100，原图宽=原图的宽，原图高=原图的高，那么实际取得的就是原图右下角部分。
    ; 举例：当 原图x=0，原图y=0，原图宽=原图的宽*0.9，原图高=原图的高*0.9，那么实际取得的就是原图左上角部分。
    ; 当原图选择了部分大小，而新图尺寸是原图大小，则会被放大填满。
    ; 新图x, 新图y, 新图宽, 新图高
    ; 代表新图在画布上的位置和大小。
    ;用 oPBitmap 当参数，画全图时可省略 aRectFrom
    drawImage(oPBitmap, aRectTo, aRectFrom:="", Matrix:=1) {
        if (!isobject(aRectFrom))
            aRectFrom := [0,0,oPBitmap.getWidth(),oPBitmap.getHeight()]
        if !(Matrix is integer)
            ImageAttr := this.GdipSetImageAttributesColorMatrix(Matrix)
        else if (Matrix != 1)
            ImageAttr := this.GdipSetImageAttributesColorMatrix(format("1|0|0|0|0|0|1|0|0|0|0|0|1|0|0|0|0|0|{1}|0|0|0|0|0|1", Matrix))
        else
            ImageAttr := 0
        return dllcall("gdiplus\GdipDrawImageRectRect", "Ptr",this, "Ptr",oPBitmap.ptr
            , "float",aRectTo[1],"float",aRectTo[2],"float",aRectTo[3],"float",aRectTo[4]
            , "float",aRectFrom[1],"float",aRectFrom[2],"float",aRectFrom[3],"float",aRectFrom[4]
            , "uint",2, "Ptr",ImageAttr, "Ptr",0, "Ptr",0)
    }

    ;NOTE 一般推荐用 drawImage，如果需要对原图进行处理才用
    GdipDrawImageRectRect(pBitmap, aRectTo, aRectFrom:="", Matrix:="1") {
        if !(Matrix is integer)
            ImageAttr := this.GdipSetImageAttributesColorMatrix(Matrix)
        else if (Matrix != 1)
            ImageAttr := this.GdipSetImageAttributesColorMatrix(format("1|0|0|0|0|0|1|0|0|0|0|0|1|0|0|0|0|0|{1}|0|0|0|0|0|1", Matrix))
        else
            ImageAttr := 0
        return dllcall("gdiplus\GdipDrawImageRectRect", "Ptr",this, "Ptr",pBitmap
            , "float",aRectTo[1],"float",aRectTo[2],"float",aRectTo[3],"float",aRectTo[4]
            , "float",aRectFrom[1],"float",aRectFrom[2],"float",aRectFrom[3],"float",aRectFrom[4]
            , "uint",2 , "Ptr",ImageAttr, "Ptr",0, "Ptr",0)
    }

    GdipSetImageAttributesColorMatrix(Matrix) {
        bufColourMatrix := buffer(100, 0)
        Matrix := RegExReplace(RegExReplace(Matrix, "^[^\d-\.]+([\d\.])", "$1",, 1), "[^\d-\.]+", "|")
        Matrix := StrSplit(Matrix, "|")
        loop(25) {
            M := (Matrix[A_Index] != "") ? Matrix[A_Index] : !mod(A_Index-1, 6)
            numput("float", M, bufColourMatrix, (A_Index-1)*4)
        }
        dllcall("gdiplus\GdipCreateImageAttributes", "ptr*",&ImageAttr:=0)
        dllcall("gdiplus\GdipSetImageAttributesColorMatrix", "ptr",ImageAttr, "int",1, "int",1, "ptr",bufColourMatrix, "ptr",0, "int",0)
        return ImageAttr
    }

    GdipDrawRectangle(pPen, aRect) {
        return dllcall("gdiplus\GdipDrawRectangle", "Ptr",this, "Ptr",pPen, "float",aRect[1],"float",aRect[2],"float",aRect[3],"float",aRect[4])
    }

    GdipDrawEllipse(pPen, aRect) {
        return dllcall("gdiplus\GdipDrawEllipse", "Ptr",this, "Ptr",pPen, "float",aRect[1],"float",aRect[2],"float",aRect[3],"float",aRect[4])
    }

    ; Pen:		the pen used to draw the line
    ; points		[x1,y1,x2,y2]
    GdipDrawLine(pPen, points) {
        return dllcall("gdiplus\GdipDrawLine", "Ptr",this, "Ptr",pPen, "float",points[1], "float",points[2], "float",points[3], "float",points[4])
    }

    ;[[x1,y1],[x2,y2]]
    GdipDrawLines(pPen, points) {
        oBuf := buffer(8 * points.length)
        for Coord in points
            NumPut("float", Coord[1], "float", Coord[2], oBuf, 8 * (A_Index-1))
        return dllcall("gdiplus\GdipDrawLines", "Ptr",this, "Ptr",pPen, "Ptr",oBuf, "int",points.length)
        ;p1 := points.clone()
        ;loop(p1.length - 1) {
        ;    this.GdipDrawLine(pPen, p1)
        ;    p1.RemoveAt(1)
        ;}
    }

    ; GdipDrawString:	Writes some text with a specified font, rectangle, _stringFormat and Brush on the Graphics
    ; sText:		The text you want to write.
    ; font:		The font you want to use. Has to be a GDIp.font object
    ; rect:		A 4 value array defining [ x, y, w, h ] of the area you want to write to.
    ; stringFormat:	Some options of the text like the text direction. Has to be a GDIp.StringFormat object
    ; brush:		Defines the color of the text. Has to be a GDI+ Brush object. (currently GDIp.SolidBrush & GDIp.LinearGradientBrush)
    GdipDrawString(sText, pFont, pStringFormat, pBrush, aRect) {
        numput("float",aRect[1],"float",aRect[2],"float",aRect[3],"float",aRect[4], bufRectF:=buffer(16))
        return dllcall("gdiplus\GdipDrawString", "Ptr",this, "WStr",sText, "int",-1, "Ptr",pFont, "Ptr",bufRectF, "Ptr",pStringFormat, "Ptr",pBrush)
    }

    /*
    opts := "x10p y60p w80p Centre cff000000 r4 s18p Bold"
    x10p表示百分比
    width和height 为总宽/高，x10p计算百分比要用
    */
    ; DrawText("abc", "x10p y60p w80p Centre cFFff0000 r4 s18p Bold", sFont:="Arial")
    ; DrawText(sText, opts, sFont:="Arial", width:="", height:="", Measure:=0) {
    DrawText(sText, opts, sFont:="Arial", Measure:=0) {
        arrOpt := StrSplit(opts, " ")
        objStyle := map(
            "Regular",0,
            "Bold",1,
            "Italic",2,
            "BoldItalic",3,
            "Underline",4,
            "Strikeout",8,
        )
        objAlign := map(
            "Near",0,
            "Left",0,
            "Centre",1,
            "Center",1,
            "Far",2,
            "Right",2,
        )
        objPos := map(
            "Top",1,
            "Up",1,
            "Bottom",1,
            "Down",1,
            "vCentre",1,
            "vCenter",1,
        )
        objRes := {}
        style := align := 0
        objType := map(
            "x",0,
            "y",0,
            "w",0,
            "h",0,
            "c",0xff000000,
            "r",4,
            "s",12,
            "NoWrap",0x4000,
        )
        for v in arrOpt {
            if (objStyle.has(v))
                style |= objStyle[v]
            else if (objAlign.has(v))
                align |= objAlign[v]
            else if (objPos.has(v))
                arrPos := [1]
            else { ;处理其他选项
                ;完整匹配
                width := 100
                height := 100
                if (v == "NoWrap") {
                    objType["NoWrap"] := 0x4000 | 0x1000
                    continue
                } else if (v ~= "i)Bottom|Down|vCentre|vCenter") {
                    if (v = "vCentre") || (v = "vCenter")
                        objType["y"] += (height-objType["h"]) // 2
                    else if (v = "Bottom") || (v = "Down")
                        objType["y"] := height - objType["h"]
                }
                ;匹配首字母
                RegExMatch(v, "i)([a-z])([a-f0-9]+)([a-z])?", &m)
                try
                    tp := StrLower(m[1])
                catch
                    msgbox(v)
                if (tp == "x")
                    objType[tp] := m[3] ? width*(m[2]/100) : m[2]
                else if (tp == "y")
                    objType[tp] := m[3] ? height*(m[2]/100) : m[2]
                else if (tp == "w")
                    objType[tp] := m[3] ? width*(m[2]/100) : m[2]
                else if (tp == "h")
                    objType[tp] := m[3] ? height*(m[2]/100) : m[2]
                else if (tp == "c")
                    objType[tp] := "0x" . m[2]
                else if (tp == "r")
                    objType[tp] := m[2] ;要求0-5
                else if (tp == "s")
                    objType[tp] := m[2]
            }
        }
        ; hyf_objView(objType)
        ; pattern_opts := (A_AhkVersion < "2") ? "iO)" : "i)"
        ; RegExMatch(opts, pattern_opts . "X([\-\d\.]+)(p*)", &xpos)
        ; RegExMatch(opts, pattern_opts . "Y([\-\d\.]+)(p*)", &ypos)
        ; RegExMatch(opts, pattern_opts . "W([\-\d\.]+)(p*)", &width)
        ; RegExMatch(opts, pattern_opts . "H([\-\d\.]+)(p*)", &height)
        ; RegExMatch(opts, pattern_opts . "C(?!(entre|enter))([a-f\d]+)", &Colour)
        ; RegExMatch(opts, pattern_opts . "Top|Up|Bottom|Down|vCentre|vCenter", &vPos)
        ; RegExMatch(opts, pattern_opts . "R(\d)", &Rendering)
        ; RegExMatch(opts, pattern_opts . "S(\d+)(p*)", &Size)
        ; ; if (Colour && !GdipDeleteBrush(this.GdipCloneBrush(Colour[2]))) {
        ; ;     PassBrush := 1
        ; ;     pBrush := Colour[2]
        ; ; }
        ; if !(width && IHeight) && ((xpos && xpos[2]) || (ypos && ypos[2]) || (width && width[2]) || (height && height[2]) || (Size && Size[2]))
        ;     return -1
        ; style := 0
        ; Styles := "Regular|Bold|Italic|BoldItalic|Underline|Strikeout"
        ; for k, valStyle in StrSplit(Styles, "|") {
        ;     if (RegExMatch(opts, "\b" . valStyle))
        ;         style |= (valStyle != "StrikeOut") ? (A_Index-1) : 8
        ; }
        ; Align := 0
        ; Alignments := [
        ;     "Near",
        ;     "Left",
        ;     "Centre",
        ;     "Center",
        ;     "Far",
        ;     "Right",
        ; ]
        ; For k, valAlignment in Alignments {
        ;     if (opts ~= "\b" . valAlignment)
        ;         Align |= A_Index//2.1	; 0|0|1|1|2|2
        ; }
        ; xpos := (xpos && (xpos[1] != "")) ? (xpos[2] ? width*(xpos[1]/100) : xpos[1]) : 0
        ; ypos := (ypos && (ypos[1] != "")) ? (ypos[2] ? height*(ypos[1]/100) : ypos[1]) : 0
        ; width := (width && width[1]) ? (width[2] ? width*(width[1]/100) : width[1]) : width
        ; height := (height && height[1]) ? (height[2] ? IHeight*(height[1]/100) : height[1]) : IHeight
        ; Colour := "0x" . (Colour && Colour[2] ? Colour[2] : "ff000000")
        ; ; if !PassBrush
        ; ;     Colour := format("0x{1}", Colour && Colour[2] ? Colour[2] : "ff000000")
        ; Rendering := (Rendering && (Rendering[1] >= 0) && (Rendering[1] <= 5)) ? Rendering[1] : 4
        ; Size := (Size && (Size[1] > 0)) ? (Size[2] ? IHeight*(Size[1]/100) : Size[1]) : 12
        oFont := GDIP_Font(sFont, objType["s"])
        oStringFormat := GDIP_StringFormat(objType["NoWrap"])
        oBrush := GDIP_Brush(objType["c"])
        ; pBrush := PassBrush ? pBrush : Gdip_BrushCreateSolid(Colour)
        ; if !(hFamily && hFont && hFormat && pBrush && this.ptr)
        ;     return !this.ptr ? -2 : !hFamily ? -3 : !hFont ? -4 : !hFormat ? -5 : !pBrush ? -6 : 0
        aRect := [objType["x"], objType["y"], objType["w"], objType["h"]]
        this.GdipSetTextRenderingHint(objType["r"])
        oStringFormat.GdipSetStringFormatAlign(align)
        arrRes := this.GdipMeasureString(sText, oFont, oStringFormat, aRect)
        if (!Measure)
            _E := this.GdipDrawString(sText, oFont, oStringFormat, oBrush, aRect)
        ; if !PassBrush
        ;     Gdip_DeleteBrush(pBrush)
        oBrush := ""
        oStringFormat := ""
        oFont := ""
        return _E ? _E : arrRes
    }

    GdipMeasureString(sText, pFont, pStringFormat, aRect) {
        numput("uint",aRect[1],"uint",aRect[2],"uint",aRect[3],"uint",aRect[4], pRect:=buffer(16))
        bufOutRect := buffer(16, 0)
        res := dllcall("gdiplus\GdipMeasureString"
            , "ptr",this
            , "ptr",strptr(sText)
            , "int",-1
            , "ptr",pFont
            , "ptr",pRect
            , "ptr",pStringFormat
            , "ptr",bufOutRect
            , "uint*",&codePointsFitted:=0
            , "uint*",&linesFitted:=0)
        return [
            numget(bufOutRect, 0, "float"),
            numget(bufOutRect, 4, "float"),
            numget(bufOutRect, 8, "float"),
            numget(bufOutRect, 12,"float"),
            codePointsFitted,
            linesFitted,
        ]
    }

    ; GdipDrawBeziers: draw a Bezier Curve onto the graphics with the specified pen and points
    ; pen: 	the pen you want to use to draw on the graphics
    ; points: 	An array of starting and control points of a Bezier line
    ; A single Bezier line consists of 4 points a starting point 2 control points and an end point
    ; The line never actually goes through the control points
    ; The control points control the tangent in the starting and end point and their distance controls how strongly the curve follows there
    GdipDrawBeziers(pPen, points) {
        bufPointsBuffer := buffer(8 * points.length, 0)
        for each, point in points {
            numput("float", point[1], bufPointsBuffer, each * 8 - 8, "float")
            numput("float", point[2], bufPointsBuffer, each * 8 - 4)
        }
        return dllcall("gdiplus\GdipDrawBeziers", "ptr",this, "ptr",pPen, "ptr",bufPointsBuffer, "uint",points.length)
    }

    ;画箭头：妖提供
    ;=======================================================
    ;
    ;                                            M5
    ;                                            M4
    ; A------------------------------------------M1-d-B
    ;                                            M2
    ;                                            M3
    ;
    ;M1-M2，宽为w1
    ;M1-M3，宽为w2
    ;=======================================================
    drawArrow(pGraphics, pBrush, Ax, Ay, Bx, By) {
        if (Ax=Bx)  ;水平线、垂直线的斜率为0、无斜率，对于作图都有问题，所以人为补了1个像素
            Bx := Ax+1
        if (Ay=By)
            By := Ay+1
        l := sqrt((Ax- Bx)**2 +(Ay - By)**2) ; 起点终点之间的距离
        w1 := 3
        w2 := 5
        ; d:=l/10   ;箭头取1/10长度
        if (l < 50)
            d := 10
        else if (l<100)
            d := 20
        else
            d := 30
        My1 := By-(d*(By-Ay))/l
        Mx1 := Bx-(d*(Bx-Ax))/l
        k := (By-Ay)/(Bx-Ax)   ;斜率
        kk := -1/k             ;垂直线的斜率
        zz := sqrt(kk*kk+1)
        Mx2 := Mx1+d/(w1*zz)
        My2 := My1+kk*d/(w1*zz)
        Mx4 := Mx1-d/(w1*zz)
        My4 := My1-kk*d/(w1*zz)
        Mx3 := Mx1+d/(w2*zz)
        My3 := My1+kk*d/(w2*zz)
        Mx5 := Mx1-d/(w2*zz)
        My5 := My1-kk*d/(w2*zz)
        point :=  format("{1},{2}|{3},{4}|{5},{6}|{7},{8}|{9},{10}|{11},{12}", Ax,Ay,Mx3,My3,Mx2,My2,Bx,By,Mx4,My4,Mx5,My5)
        this.GdipFillPolygon(pBrush, point, FillMode:=1)
    }

    ;------------------------------------------------fill------------------------------------------------

    fillRoundedRectangle(pBrush, aRect, r) {
        x := aRect[1]
        y := aRect[2]
        w := aRect[3]
        h := aRect[4]
        this.GdipGetClip()
        this.GdipSetClipRect([x-r, y-r, 2*r, 2*r], 4)
        this.GdipSetClipRect([x+w-r, y-r, 2*r, 2*r], 4)
        this.GdipSetClipRect([x-r, y+h-r, 2*r, 2*r], 4)
        this.GdipSetClipRect([x+w-r, y+h-r, 2*r, 2*r], 4)
        _E := this.GdipFillRectangle(pBrush, aRect)
        this.GdipSetClipRegion(0)
        this.GdipSetClipRect([x-(2*r), y+r, w+(4*r), h-(2*r)], 4)
        this.GdipSetClipRect([x+r, y-(2*r), w-(2*r), h+(4*r)], 4)
        this.GdipFillEllipse(pBrush, [x, y, 2*r, 2*r])
        this.GdipFillEllipse(pBrush, [x+w-(2*r), y, 2*r, 2*r])
        this.GdipFillEllipse(pBrush, [x, y+h-(2*r), 2*r, 2*r])
        this.GdipFillEllipse(pBrush, [x+w-(2*r), y+h-(2*r), 2*r, 2*r])
        this.GdipSetClipRegion(0)
        this.GdipDeleteRegion()
        return _E
    }

    ; extracted from: https://github.com/tariqporter/Gdip2/blob/master/lib/Object.ahk
    ; and adapted by Marius Șucan
    ; fillRoundedRectangle2(pBrush, aRect, r) {
    ;     x := aRect[1]
    ;     y := aRect[2]
    ;     w := aRect[3]
    ;     h := aRect[4]
    ;     r := (w <= h) ? (r < w // 2) ? r : w // 2 : (r < h // 2) ? r : h // 2
    ;     path1 := this.GdipCreatePath(0)
    ;     this.GdipAddPathRectangle(path1, [x+r, y, w-(2*r), r])
    ;     this.GdipAddPathRectangle(path1, [x+r, y+h-r, w-(2*r), r])
    ;     this.GdipAddPathRectangle(path1, [x, y+r, r, h-(2*r)])
    ;     this.GdipAddPathRectangle(path1, [x+w-r, y+r, r, h-(2*r)])
    ;     this.GdipAddPathRectangle(path1, [x+r, y+r, w-(2*r), h-(2*r)])
    ;     this.GdipAddPathPie(path1, [x, y, 2*r, 2*r], 180, 90)
    ;     this.GdipAddPathPie(path1, [x+w-(2*r), y, 2*r, 2*r], 270, 90)
    ;     this.GdipAddPathPie(path1, [x, y+h-(2*r), 2*r, 2*r], 90, 90)
    ;     this.GdipAddPathPie(path1, [x+w-(2*r), y+h-(2*r), 2*r, 2*r], 0, 90)
    ;     E := this.GdipFillPath(this.ptr, pBrush, path1)
    ;     this.GdipDeletePath(path1)
    ;     return E
    ; }

    GdipFillRectangle(pBrush, aRect) {
        return dllcall("gdiplus\GdipFillRectangle", "Ptr",this, "Ptr",pBrush, "float",aRect[1], "float",aRect[2], "float",aRect[3], "float",aRect[4])
    }

    GdipFillEllipse(pBrush, aRect) {
        if (!pBrush)
            msgbox(A_ThisHotkey)
        return dllcall("gdiplus\GdipFillEllipse", "Ptr",this, "Ptr",pBrush, "float",aRect[1], "float",aRect[2], "float",aRect[3], "float",aRect[4])
    }

    GdipFillPolygon(pBrush, points, fillMode:=0) {
        bufPointBuffer := buffer(8 * points.length, 0)
        for pointNr, point in points {
            numput("float", point[1], bufPointBuffer, pointNr * 8 - 8)
            numput("float", point[2], bufPointBuffer, pointNr * 8 - 4)
        }
        return dllcall("gdiplus\GdipFillPolygon", "Ptr",this, "Ptr",pBrush, "Ptr",bufPointBuffer, "int",points.length, "int",fillMode)
    }

    ; 起始角度(右边为0), 阴影角度
    GdipFillPie(pBrush, aRect, angles) {
        return dllcall("gdiplus\GdipFillPie", "Ptr",this, "Ptr",pBrush, "float",aRect[1],"float",aRect[2],"float",aRect[3],"float",aRect[4], "float",angles[1], "float",angles[2])
    }

    GdipFillPath(pGraphics, pBrush, pPath) {
        return dllcall("gdiplus\GdipFillPath", "ptr",pGraphics, "ptr",pBrush, "ptr",pPath)
    }

    GdipCreateRegion() {
        dllcall("gdiplus\GdipCreateRegion", "UInt*",&region:=0)
        if (!region)
            msgbox(A_ThisFunc)
        return this.region := region
    }
    GdipGetClip() {
        this.GdipCreateRegion()
        dllcall("gdiplus\GdipGetClip", "ptr",this, "UInt",this.region)
        return this.region
    }

    GdipSetClipRect(aRect, CombineMode:=0) {
        return dllcall("gdiplus\GdipSetClipRect",  "ptr",this, "float",aRect[1],"float",aRect[2],"float",aRect[3],"float",aRect[4], "int",CombineMode)
    }

    GdipSetClipRegion(CombineMode:=0) {
        return dllcall("gdiplus\GdipSetClipRegion", "ptr",this, "ptr",this.region, "int",CombineMode)
    }

    GdipDeleteRegion() {
        return dllcall("gdiplus\GdipDeleteRegion", "ptr",this.region)
    }

    GdipCreatePath(BrushMode:=0) {
        dllcall("gdiplus\GdipCreatePath", "int",BrushMode, "ptr*",&pPath:=0)
        return pPath
    }

    GdipAddPathRectangle(pPath, aRect) {
        return dllcall("gdiplus\GdipAddPathRectangle",A_PtrSize ? "ptr" : "UInt",pPath, "float",aRect[1],"float",aRect[2],"float",aRect[3],"float",aRect[4])
    }

    GdipAddPathPie(pPath, aRect, StartAngle, SweepAngle) {
        return dllcall("gdiplus\GdipAddPathPie", "ptr",pPath, "float",aRect[1],"float",aRect[2],"float",aRect[3],"float",aRect[4], "float",StartAngle, "float",SweepAngle)
    }

    Gdip_AddPathBeziers(pPath, Points) {
        Points := StrSplit(Points, "|")
        bufPointF := buffer(8*Points.length)
        for Point in Points {
            Coord := StrSplit(Point, ",")
            numput("float", Coord[1], bufPointF, 8*(A_Index-1))
            numput("float", Coord[2], bufPointF, (8*(A_Index-1))+4)
        }
        return dllcall("gdiplus\GdipAddPathBeziers", "ptr",pPath, "ptr",bufPointF, "int", Points.length)
    }

    ; Adds a Bézier spline to the current figure of this path
    GdipAddPathBezier(pPath, x1, y1, x2, y2, x3, y3, x4, y4) {
        return dllcall("gdiplus\GdipAddPathBezier", "ptr", pPath
            , "float", x1, "float", y1, "float", x2, "float", y2
            , "float", x3, "float", y3, "float", x4, "float", y4)
    }

    ;#####################################################################################
    ; Function Gdip_AddPathLines
    ; Description Adds a sequence of connected lines to the current figure of this path.
    ;
    ; pPath Pointer to the GraphicsPath
    ; Points the coordinates of all the points passed as x1,y1|x2,y2|x3,y3.....
    ;
    ; return status enumeration. 0 = success
    GdipAddPathLine2(pPath, Points) {
        Points := StrSplit(Points, "|")
        bufPointF := buffer(8*Points.length)
        for Point in Points {
            Coord := StrSplit(Point, ",")
            numput("float", Coord[1], bufPointF, 8*(A_Index-1))
            numput("float", Coord[2], bufPointF, (8*(A_Index-1))+4)
        }
        return dllcall("gdiplus\GdipAddPathLine2", "ptr",pPath, "ptr",bufPointF, "int",Points.length)
    }

    Gdip_AddPathLine(pPath, aRect) {
        return dllcall("gdiplus\GdipAddPathLine", "ptr", pPath, "float",aRect[1],"float",aRect[2],"float",aRect[3],"float",aRect[4])
    }

    GdipAddPathArc(pPath, aRect, StartAngle, SweepAngle) {
        return dllcall("gdiplus\GdipAddPathArc", "ptr", pPath, "float",aRect[1],"float",aRect[2],"float",aRect[3],"float",aRect[4], "float", StartAngle, "float", SweepAngle)
    }

    ; Starts a figure without closing the current figure. Subsequent points added to this path are added to the figure.
    GdipStartPathFigure(pPath) {
        return dllcall("gdiplus\GdipStartPathFigure", "ptr", pPath)
    }

    ; Closes the current figure of this path.
    GdipClosePathFigure(pPath) {
        return dllcall("gdiplus\GdipClosePathFigure", "ptr", pPath)
    }


    ; Replaces this path with curves that enclose the area that is filled when this path is drawn by a specified pen. This method also flattens the path.
    GdipWidenPath(pPath, pPen, Matrix:=0, Flatness:=1) {
        return dllcall("gdiplus\GdipWidenPath", "ptr", pPath, "uint", pPen, "ptr", Matrix, "float", Flatness)
    }

    GdipClonePath(pPath) {
        dllcall("gdiplus\GdipClonePath", "ptr",pPath, "ptr*",&pPathClone:=0)
        return pPathClone
    }

    ;#####################################################################################
    ; Function Gdip_DrawPath
    ; Description draws a sequence of lines and curves defined by a GraphicsPath object
    ; pGraphics Pointer to the Graphics of a bitmap
    ; pPen Pointer to a pen
    ; pPath Pointer to a Path
    ; return status enumeration. 0 = success
    GdipDrawPath(pPen, pPath) {
        return dllcall("gdiplus\GdipDrawPath", "ptr",this, "ptr",pPen, "ptr",pPath)
    }

    GdipDeletePath(pPath) {
        return dllcall("gdiplus\GdipDeletePath", "ptr",pPath)
    }

    ;oDC 相关方法

    ; DCX_CACHE = 0x2
    ; DCX_CLIPCHILDREN = 0x8
    ; DCX_CLIPSIBLINGS = 0x10
    ; DCX_EXCLUDERGN = 0x40
    ; DCX_EXCLUDEUPDATE = 0x100
    ; DCX_INTERSECTRGN = 0x80
    ; DCX_INTERSECTUPDATE = 0x200
    ; DCX_LOCKWINDOWUPDATE = 0x400
    ; DCX_NORECOMPUTE = 0x100000
    ; DCX_NORESETATTRS = 0x4
    ; DCX_PARENTCLIP = 0x20
    ; DCX_VALIDATE = 0x200000
    ; DCX_WINDOW = 0x1
    ; getEx(hwnd, flags:=0, hrgnClip:=0) {
    ;     Ptr := A_PtrSize ? "ptr" : "uint"
    ;     return this.hDC := dllcall("GetDCEx",ptr,hwnd, ptr,hrgnClip, "int",flags)
    ; }

    release(hwnd:=0) {
        return dllcall("ReleaseDC", "ptr",hwnd, "ptr",this.hDC)
    }

    ;TODO
    ; Raster
    ;   SRCCOPY			= 0x00CC0020
    ;   BLACKNESS		= 0x00000042
    ;   NOTSRCERASE		= 0x001100A6
    ;   NOTSRCCOPY		= 0x00330008
    ;   SRCERASE		= 0x00440328
    ;   DSTINVERT		= 0x00550009
    ;   PATINVERT		= 0x005A0049
    ;   SRCINVERT		= 0x00660046
    ;   SRCAND			= 0x008800C6
    ;   MERGEPAINT		= 0x00BB0226
    ;   MERGECOPY		= 0x00C000CA
    ;   SRCPAINT		= 0x00EE0086
    ;   PATCOPY			= 0x00F00021
    ;   PATPAINT		= 0x00FB0A09
    ;   WHITENESS		= 0x00FF0062
    ;   CAPTUREBLT		= 0x40000000
    ;   NOMIRRORBITMAP		= 0x80000000
    BitBlt(aRectTo, sDC, sx, sy, Raster:=0x00CC0020) {
        if (!this.hDC || !sDC)
            msgbox(A_ThisFunc)
        return dllcall("gdi32\BitBlt", "ptr",this.hDC
            , "int",aRectTo[1],"int",aRectTo[2],"int",aRectTo[3],"int",aRectTo[4]
            , "ptr",sDC, "int",sx, "int",sy, "uint",Raster)
    }

    ; 学名上，这里叫做 “把 GDI 对象选入 DC 里” 。
    ; 为了方便理解呢，可以认为是 “把位图跟 DC 绑定”。
    ; 因为 DC 需要具体的东西才能显示嘛，所以得用东西跟它绑定。
    ; 注意这个函数的特点，它把 hdc 更新了，同时它返回的值是旧的 hbm ！
    ; 因为跟 DC 绑定的当前 hbm 无法删除，所以这里旧的 hbm 得存着，未来释放资源会用到。
    ; https://docs.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-selectobject
    SelectObject(oGdiObj:="") {
        if (oGdiObj) {
            if (!this.pSelectObject) { ;只记录一次(原始对象)
                return this.pSelectObject := dllcall("SelectObject", "ptr",this.hDC, "ptr",oGdiObj)
            } else
                return dllcall("SelectObject", "ptr",this.hDC, "ptr",oGdiObj)
        } else { ;还原
            pOld := this.pSelectObject
            this.pSelectObject := 0
            return dllcall("SelectObject", "ptr",this.hDC, "ptr",pOld)
        }
    }

    ; 将 DC 上的内容显示在窗口上。此时，界面真正显示出来了。
    ; 注意，这里的宽高不能大于 CreateDIBSection() 时的宽高。
    ; 现在的层级关系是这样的，我们眼睛看到的是屏幕，屏幕是一个全透明的玻璃。
    ; 屏幕后面的是 DC 。而 DC 的后面，则是画布。
    ; 我们把 DC 想象成一张纯黑色的纸，中间掏空了部分。显然，透过黑纸掏空的部分，我们才能看到画布上的东西。
    ; 此处做视频的话，最好直接用两张纸做个演示模型，方便大家理解。
    ; 画布的坐标0点是相对 DC 的。而 DC 的坐标0点是相对屏幕的。
    ; 此时可以用 spy 工具观察，图片范围外是没有句柄的，也就是说，这是一个异型的界面。
    ;aRect =屏幕上显示的位置大小
    UpdateLayeredWindow(hwnd, aRect, alpha:=255) {
        if (!hwnd || !this.hDC)
            msgbox(A_ThisFunc)
        w := aRect[3]
        h := aRect[4]
        numput("uint",aRect[1], "uint",aRect[2], bufPT:=buffer(8))
        return dllcall("UpdateLayeredWindow"
            , "ptr", hwnd
            , "ptr", 0
            , "ptr", bufPT
            , "int64*", aRect[3] | (aRect[4]<<32)
            , "ptr", this.hDC
            , "int64*", 0
            , "uint", 0
            , "uint*", alpha<<16|1<<24
            , "uint", 2)
    }

    ;TODO
    ; show() {
    ;     oGui := gui("-Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs")
    ;     oGui.Show("NA")
    ;     this.UpdateLayeredWindow(oGui.hwnd, [0, 0, A_ScreenWidth, A_ScreenHeight])
    ; }

}

;pp
class GDIP_Pen extends _GDIP {
    ptr := 0

    __new(argbOrBrush, width) {
        if (isobject(argbOrBrush))
            this.createByBrush(argbOrBrush)
        else
            this.createByArgb(argbOrBrush, width)
        ; super.registerObject(this)
    }

    __delete() {
        ; msgbox(A_ThisFunc . '---')
        dllcall("gdiplus\GdipDeletePen", "ptr",this)
    }

    createByArgb(argb, width) {
        ;TODO 是否需要先删除原画笔？
        if (this.ptr)
            this.__delete()
        res := dllcall("gdiplus\GdipCreatePen1", "uint",argb, "float",width, "int",2, "ptr*",&pPen:=0)
        if (!pPen)
            msgbox(A_ThisFunc . "`n" . argb . "`n" . width)
        this.ptr := pPen
        return res
    }

    createByBrush(oBrush){
        if (this.ptr)
            this.__delete()
        this.pBrush := oBrush ;TODO 是否需要保存 <2020-12-11 14:36:59> hyaray
        res := dllcall("gdiplus\GdipCreatePen2", "ptr",&argbOrBrush, "float",&width, "int",2, "ptr*",&pPen:=0)
        this.ptr := pPen
        return res
    }

    GdipGetPenWidth() {
        dllcall("gdiplus\GdipGetPenWidth", "ptr",this, "float*",&width:=0)
        return width
    }
    GdipSetPenWidth(width) {
        return dllcall("gdiplus\GdipSetPenWidth", "ptr",this, "float",width)
    }

    GdipGetPenColor() {
        dllcall("gdiplus\GdipGetPenColor", "ptr",this, "uint*",&color:=0)
        return color
    }
    GdipSetPenColor(color) {
        return dllcall("gdiplus\GdipSetPenColor", "ptr",this, "uint",color)
    }

    ; getBrush() {
    ;     return this.ptr
    ; }
    ; setBrush(pBrush := "") {
    ;     if (this.has("pBrush") && pBrush)
    ;         this.ptr := pBrush
    ;     return dllcall("gdiplus\GdipSetPenBrushFill", "ptr",this, "ptr",this.getpBrush())
    ; }

}

;bb
class GDIP_Brush extends _GDIP {
    ptr := 0
    __new(argb, argbBack:=0, HatchStyle:=0) {
        if (argbBack)
            this.GdipCreateHatchBrush(argb, argbBack, HatchStyle)
        else
            this.GdipCreateSolidFill(argb)
    }

    __delete() {
        ; msgbox(A_ThisFunc . '---')
        dllcall("gdiplus\GdipDeleteBrush", "ptr",this)
    }

    GdipCreateSolidFill(argb) {
        if (!argb)
            msgbox(A_ThisFunc . "`nargb = 0")
        ;TODO 是否需要先删除原画刷？
        if (this.ptr)
            this.__delete()
        dllcall("gdiplus\GdipCreateSolidFill", "uint",argb, "ptr*",&pBrush:=0)
        if (!pBrush)
            msgbox(A_ThisFunc)
        this.ptr := pBrush
    }

    ; LinearGradientModeHorizontal = 0
    ; LinearGradientModeVertical = 1
    ; LinearGradientModeForwardDiagonal = 2
    ; LinearGradientModeBackwardDiagonal = 3
    GdipCreateLineBrushFromRect(aRect, ARGB1, ARGB2, LinearGradientMode:=1, WrapMode:=1) {
        numput("uint",aRect[1],"uint",aRect[2],"uint",aRect[3],"uint",aRect[4], bufRect:=buffer(16))
        dllcall("gdiplus\GdipCreateLineBrushFromRect", "ptr",bufRect, "int",ARGB1, "int",ARGB2, "int",LinearGradientMode, "int",WrapMode, "ptr*",&LGpBrush:=0)
        return this.ptr := LGpBrush
    }

    ; HatchStyleHorizontal = 0
    ; HatchStyleVertical = 1
    ; HatchStyleForwardDiagonal = 2
    ; HatchStyleBackwardDiagonal = 3
    ; HatchStyleCross = 4
    ; HatchStyleDiagonalCross = 5
    ; HatchStyle05Percent = 6
    ; HatchStyle10Percent = 7
    ; HatchStyle20Percent = 8
    ; HatchStyle25Percent = 9
    ; HatchStyle30Percent = 10
    ; HatchStyle40Percent = 11
    ; HatchStyle50Percent = 12
    ; HatchStyle60Percent = 13
    ; HatchStyle70Percent = 14
    ; HatchStyle75Percent = 15
    ; HatchStyle80Percent = 16
    ; HatchStyle90Percent = 17
    ; HatchStyleLightDownwardDiagonal = 18
    ; HatchStyleLightUpwardDiagonal = 19
    ; HatchStyleDarkDownwardDiagonal = 20
    ; HatchStyleDarkUpwardDiagonal = 21
    ; HatchStyleWideDownwardDiagonal = 22
    ; HatchStyleWideUpwardDiagonal = 23
    ; HatchStyleLightVertical = 24
    ; HatchStyleLightHorizontal = 25
    ; HatchStyleNarrowVertical = 26
    ; HatchStyleNarrowHorizontal = 27
    ; HatchStyleDarkVertical = 28
    ; HatchStyleDarkHorizontal = 29
    ; HatchStyleDashedDownwardDiagonal = 30
    ; HatchStyleDashedUpwardDiagonal = 31
    ; HatchStyleDashedHorizontal = 32
    ; HatchStyleDashedVertical = 33
    ; HatchStyleSmallConfetti = 34
    ; HatchStyleLargeConfetti = 35
    ; HatchStyleZigZag = 36
    ; HatchStyleWave = 37
    ; HatchStyleDiagonalBrick = 38
    ; HatchStyleHorizontalBrick = 39
    ; HatchStyleWeave = 40
    ; HatchStylePlaid = 41
    ; HatchStyleDivot = 42
    ; HatchStyleDottedGrid = 43
    ; HatchStyleDottedDiamond = 44
    ; HatchStyleShingle = 45
    ; HatchStyleTrellis = 46
    ; HatchStyleSphere = 47
    ; HatchStyleSmallGrid = 48
    ; HatchStyleSmallCheckerBoard = 49
    ; HatchStyleLargeCheckerBoard = 50
    ; HatchStyleOutlinedDiamond = 51
    ; HatchStyleSolidDiamond = 52
    ; HatchStyleTotal = 53
    ; https://docs.microsoft.com/en-us/windows/win32/api/gdiplusenums/ne-gdiplusenums-hatchstyle
    GdipCreateHatchBrush(argbFront, argbBack, HatchStyle:=0) {
        dllcall("gdiplus\GdipCreateHatchBrush", "int",HatchStyle, "UInt",argbFront, "UInt",argbBack, "ptr*",&pBrush:=0)
        if (!pBrush)
            msgbox(A_ThisFunc)
        return this.ptr := pBrush
    }

    GdipCloneBrush() {
        dllcall("gdiplus\GdipCloneBrush", "ptr",this, "ptr*",&pBrushClone:=0)
        return pBrushClone
    }

    SetColor(argb) {
        dllcall("gdiplus\GdipSetSolidFillColor", "ptr",this, "uint",argb)
    }


    getColor() {
        dllcall("gdiplus\GdipSetSolidFillColor", "ptr",this, "uint*",&argb:=0)
        return argb
    }

}

;ff
class GDIP_Font extends _GDIP {
    ptr := 0

    ;oInstance
    ;   oDC
    ;   oFontFamily
    ;   sFont
    __new(oInstance:="Arial", size:=12) {
        res := 0
        if (isobject(oInstance)) {
            if (oInstance is GDIP_Graphics)
                res := dllcall("gdiplus\GdipCreateFontFromDC", "ptr",oInstance.hDC, "ptr*",&pFont:=0)
            else if (oInstance is GDIP_FontFamily)
                this.GdipCreateFont(oInstance.ptr, size)
        } else { ;字体名称
            oFontFamily := GDIP_FontFamily(oInstance)
            this.GdipCreateFont(oFontFamily, size)
            oFontFamily := ""
        }
        if (res)
            msgbox(A_ThisFunc)
    }

    __delete() {
        dllcall("gdiplus\GdipDeleteFont", "ptr",this)
    }

    ; Regular = 0
    ; Bold = 1
    ; Italic = 2
    ; BoldItalic = 3
    ; Underline = 4
    ; Strikeout = 8
    GdipCreateFont(pFontFamily, size, style:=0) {
        res := dllcall("gdiplus\GdipCreateFont", "ptr",pFontFamily, "float",size, "uint",style, "uint",0, "ptr*",&pFont:=0)
        if (res)
            msgbox(A_ThisFunc)
        return this.ptr := pFont
    }
}

class GDIP_FontFamily {
    __new(sFont) {
        res := dllcall("gdiplus\GdipCreateFontFamilyFromName", "ptr",strptr(sFont), "ptr",0, "ptr*",&pFontFamily:=0)
        if (!pFontFamily) {
            msgbox(format("字体{1}不存在", sFont),,0x40000)
            exit
        }
        this.ptr := pFontFamily
    }

    __delete() {
        dllcall("gdiplus\GdipDeleteFontFamily", "ptr",this)
    }

}

;ss
;文字在框中的对齐方式
class GDIP_StringFormat extends _GDIP {

    /*
    formatFlags: Defines some settings of the _StringFormat object
    typedef enum  {
        StringFormatFlagsDirectionRightToLeft    = 0x0001,
        StringFormatFlagsDirectionVertical       = 0x0002,
        StringFormatFlagsNoFitBlackBox           = 0x0004,
        StringFormatFlagsDisplayFormatControl    = 0x0020,
        StringFormatFlagsNoFontFallback          = 0x0400,
        StringFormatFlagsMeasureTrailingSpaces   = 0x0800,
        StringFormatFlagsNoWrap                  = 0x1000,
        StringFormatFlagsLineLimit               = 0x2000,
        StringFormatFlagsNoClip                  = 0x4000
    } StringFormatFlags;
    langId: Defines the language this _StringFormat object should use.
    I don't actually know any besides 0 which is LANG_NEUTRAL and represents the users language - further research is necessary.
    */

    __new(formatFlags:=0, langId:=0) {
        this.GdipCreateStringFormat(formatFlags, langId)
    }

    __delete() {
        dllcall("gdiplus\GdipDeleteStringFormat", "ptr",this)
    }

    GdipCreateStringFormat(formatFlags, langId) {
        res := dllcall("gdiplus\GdipCreateStringFormat", "uint",formatFlags, "UShort",langId, "ptr*",&pStringFormat:=0)
        if (res)
            msgbox(A_ThisFunc)
        this.ptr := pStringFormat
    }

    ; Near = 0
    ; Center = 1
    ; Far = 2
    GdipSetStringFormatAlign(align:=1) {
        return dllcall("gdiplus\GdipSetStringFormatAlign", "ptr",this, "int",align)
    }

}
