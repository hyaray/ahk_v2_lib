;NOTE 光标用 CaretGetPos 获取
;修改光标见 _IME.curModify()
;鼠标点击和移动类

class _Mouse {
    static bMoving := false
    static speed := 1

    static save() {
        cmMouse := A_CoordModeMouse
        CoordMode("mouse", "screen")
        MouseGetPos(&xSave, &ySave)
        this.arrSave := [xSave, ySave]
        CoordMode("mouse", cmMouse)
    }

    static back(cnt:=0) {
        cmMouse := A_CoordModeMouse
        CoordMode("mouse", "screen")
        MouseMove(this.arrSave[1], this.arrSave[2], 0)
        if (cnt) {
            sleep(10)
            click(cnt)
        }
        CoordMode("mouse", cmMouse)
    }

    ;获取鼠标当前的速度
    static saveSpeed() {
        dllcall("SystemParametersInfo", "UInt",SPI_GETMOUSESPEED:=0x70, "UInt",0, "Ptr*",&OrigMouseSpeed:=0, "UInt",0)
        return OrigMouseSpeed
        ; 现在在倒数第二个参数中设置较低的速度 (范围为 1-20, 10 是默认值):
        ;dllcall("SystemParametersInfo", "UInt",SPI_SETMOUSESPEED, "UInt",0, "Ptr",3, "UInt",0)
        ;dllcall("SystemParametersInfo", "UInt",SPI_SETMOUSESPEED:=0x71, "UInt",0, "Ptr",OrigMouseSpeed, "UInt",0)  ; 恢复原始速度
    }

    ;主要用来生成代码
    ;如果偏右/下，则返回负数
    ;xPercent=100则不会获取相对坐标
    static getXYByWindowR(arrXY:="", xPercent:=80, yPercent:=80, winTitle:="") {
        cmMouse := A_CoordModeMouse
        CoordMode("mouse", "window")
        WinGetPos(&x, &y, &w, &h, winTitle)
        if (isobject(arrXY)) {
            x := arrXY[1]
            y := arrXY[2]
        }
        if (x > w * xPercent/100)
            x := x - w
        if (y > h * yPercent/100)
            y := y - h
        CoordMode("mouse", cmMouse)
        return [x, y]
    }

    ;获取当前鼠标的Window坐标
    static getXYByWindow(&x, &y) {
        cmMouse := A_CoordModeMouse
        CoordMode("mouse", "window")
        MouseGetPos(&x, &y)
        CoordMode("mouse", cmMouse)
        return [x, y]
    }

    ;获取当前鼠标的screen坐标
    static getXYByScreen(&x:=0, &y:=0) {
        cmMouse := A_CoordModeMouse
        CoordMode("mouse", "screen")
        MouseGetPos(&x, &y)
        CoordMode("mouse", cmMouse)
        return [x, y]
    }

    ;target 0=鼠标所在屏幕 1=另一屏幕
    ;获取w,h形状居中显示的起始x,y坐标
    static getPosOfRect(w, h, target:=0) {
        CoordMode("mouse", "screen")
        MouseGetPos(&xMouse, &yMouse)
        if ((xMouse > A_ScreenWidth) == target)
            x := A_ScreenWidth//2 - w//2
        else
            x := (sysget(78)+A_ScreenWidth)//2 - w//2
        if ((yMouse < A_ScreenHeight) == target)
            y := A_ScreenHeight//2 - h//2
        else
            y := (sysget(79)+A_ScreenHeight)//2 - h//2
        return [x, y]
    }

    ;鼠标所在的文本
    static mouseText() {
        ;return IUIAutomationElement(IUIAutomation().ElementFromPoint()).CurrentName()
        ; oAcc := Acc_ObjectFromPoint(child, x, y)
        ; try
        ;     return oAcc.accValue(child)
        ; try
        ;     return oAcc.accName(child)
    }

    ;笔直移动 to 为4个方向 up/down/left/right
    ;this.shiftMove("right", (p*)=>GetKeyState("CapsLock", "P"), (p*)=>send("{LButton down}"), (p*)=>send("{LButton up}"))
    static shiftMove(to:="right", funState:="", funBefore:="", funAfter:="") {
        if (this.bMoving) {
            this.speed++
            tooltip(this.speed)
            SetTimer(tooltip, -1000)
            return
        } else
            this.speed := 1
        if (!this.bMoving && isobject(funBefore))
            funBefore.call()
        this.bMoving := true
        SetTimer(%to . "Move"%, -1) ;用 SetTimer 解放当前线程，再次运行可增加速度
        rightMove() {
            while (funState.call()) {
                MouseMove(this.speed, 0, 0, "R")
                sleep(1)
            }
            after()
        }
        leftMove() {
            while (funState.call()) {
                MouseMove(-this.speed, 0, 0, "R")
                sleep(1)
            }
            after()
        }
        upMove() {
            while (funState.call()) {
                MouseMove(0, -this.speed, 0, "R")
                sleep(1)
            }
            after()
        }
        downMove() {
            while (funState.call()) {
                MouseMove(0, this.speed, 0, "R")
                sleep(1)
            }
            after()
        }
        after() { ;放函数里，延迟调用
            this.bMoving := false
            this.speed := 1
            if (isobject(funAfter))
                funAfter.call()
        }
    }

    ;控件中心位置 window 坐标
    static getCtrlXY(ctl, winTitle:="") {
        WinExist(winTitle)
        WinGetClientPos(&xClient, &yClient)
        WinGetPos(&xWin, &yWin)
        ControlGetPos(&x, &y, &w, &h, ctl)
        return [x+xClient-xWin+w//2, y+yClient-yWin+h//2]
    }

    static clickCtrl(ctl, winTitle:="") {
        arrXY := this.getCtrlXY(ctl, winTitle)
        this.clickByClient()
    }

    static getColorByWindow(x, y) { ;获取鼠标位置的颜色(6位16进制)
        cmPixel := A_CoordModePixel
        CoordMode("pixel", "window")
        cl := substr(PixelGetColor(x,y), 3)
        CoordMode("pixel", cmPixel)
        return cl
    }

    static getColorByScreen(x, y) { ;获取鼠标位置的颜色(6位16进制)
        cmPixel := A_CoordModePixel
        CoordMode("pixel", "screen")
        cl := substr(PixelGetColor(x,y), 3)
        CoordMode("pixel", cmPixel)
        return cl
    }

    static getXYColor(screenX, screenY) { ;获取鼠标位置的颜色
        CoordMode("pixel", "screen")
        strRGB := substr(PixelGetColor(screenX,screenY), 3)
        r := substr(strRGB, 1, 2)
        g := substr(strRGB, 3, 2)
        b := substr(strRGB, 5, 2)
        obj := map()
        obj["RGB"] := map()
        obj["RGB"]["16进制"] := map()
        obj["RGB"]["16进制"][1] := map()
        obj["RGB"]["十进制"] := map()
        obj["RGB"]["十进制"][1] := map()
        obj["RGB"]["16进制"][1][1] := r
        obj["RGB"]["16进制"][1][2] := g
        obj["RGB"]["16进制"][1][3] := b
        obj["RGB"]["16进制"][2] := strRGB
        obj["RGB"]["16进制"][3] := "#" . strRGB
        obj["RGB"]["16进制"][4] := "0x" . strRGB
        obj["RGB"]["十进制"][1][1] := format("{:d}", "0x" . r)
        obj["RGB"]["十进制"][1][2] := format("{:d}", "0x" . g)
        obj["RGB"]["十进制"][1][3] := format("{:d}", "0x" . b)
        obj["RGB"]["十进制"][2] := format("{:d}", "0x" . strRGB)
        ;strBGR := b . g . r
        return obj
    }

    static fblSwitch(obj, arr1, arr2) { ;arr1分辨率下的n坐标转成arr2分辨率下的坐标
        res := map()
        for k, v in obj {
            if (isobject(v))
                res[k] := this.fblBase(v, arr1, arr2)
            else if (k = 1 || instr(k, "w")) { ;按A_ScreenWidth转换
                ;msgbox(k . "`n" . v . "`n" . arr1[1] . "`n" . arr2[1] . "`n" . hyf_fblNumSwitch(v, arr1[1], arr2[1]))
                res[k] := this.fblBase(v, arr1[1], arr2[1])
            } else
                res[k] := this.fblBase(v, arr1[2], arr2[2])
        }
        return res
        fblBase(n, w1, w2) { ;w1分辨率下的n坐标转成w2分辨率下的坐标
            return floor(n*w2 / w1)
        }
    }

    ;n0为第一个线段中点坐标，l为线段长度，查看n在第几格
    ;0123456789
    ;----------
    ;n0=3,l=4
    ;得出n1=7,n2=11,n3=15,n4=19,n5=23
    static index(n, n0, l) {
        if (n < (n0-l/2))
            return
        loop {
            if (abs(n - (n0 + l*(A_Index-1))) <= l/2) {
                return A_Index
            }
        }
    }

    static waitCursor(tp:="wait") {
        while(A_Cursor = tp) {
            sleep(100)
            tooltip("等待鼠标形状`n" . tp)
        }
        tooltip()
    }

    ;window坐标转screen坐标
    static toScreen(xWindow, yWindow:="") {
        if (isobject(xWindow)) {
            yWindow := xWindow[2] ;这句必须放前面
            xWindow := xWindow[1]
        }
        WinGetPos(&xWin, &yWin,,, "A")
        return [xWindow+xWin, yWindow+yWin]
    }
    static toWindow(xScreen, yScreen:="") {
        if (isobject(xScreen)) {
            yScreen := xScreen[2] ;这句必须放前面
            xScreen := xScreen[1]
        }
        WinGetPos(&xWin, &yWin,,, "A")
        return [xScreen-xWin, yScreen-yWin]
    }
    static toClient(xScreen, yScreen:="") {
        if (isobject(xScreen)) {
            yScreen := xScreen[2] ;这句必须放前面
            xScreen := xScreen[1]
        }
        WinGetClientPos(&xWin, &yWin,,, "A")
        return [xScreen-xWin, yScreen-yWin]
    }

    ;获取指定坐标点的鼠标光标特征码
    static shapeByWindow(x, y, toStr:=0) {
        this.moveByWindow(x, y)
        MouseMove(X, Y, 0, "R")
        return this.shapeResult(this.shapeBase(), toStr:=0)
    }

    ;获取指定坐标点的鼠标光标特征码
    static shapeR(x, y, toStr:=0) {
        MouseMove(X, Y, 0, "R")
        return this.shapeResult(this.shapeBase(), toStr)
    }

    ;shapeBase结果简化
    static shapeResult(n, toStr:=false) {
        switch n {
            case 126898458:
                return toStr ? "button" : 1
            case 161920:
                return toStr ? "input" : 2
            case 130504298:
                return toStr ? "normal" : 3
            default:
                return toStr ? "other" : 4
        }
    }

    ;获取鼠标所在位置的光标特征码，by nnrxin
    shapeBase() {
        size := 16 + A_PtrSize
        pCursorInfo := buffer(size, 0)
        numput("uint", size, pCursorInfo, 0)  ;*声明出 结构 的大小cbSize = 20字节
        ; https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getcursorinfo
        dllcall("GetCursorInfo", "ptr",pCursorInfo, "int") ;获取 结构-光标信息
        ; msgbox(numget(pCursorInfo, 8, "uint")) ;含义是什么？
        if (!numget(pCursorInfo, 4, "uint")) ;当光标隐藏时，直接输出特征码为0
            return 0
        obj := map(
            65541, "normal",
            65543, "input",
            65569, "click",
            1705339, "excel_normal",
            2951675, "excel_fill",
            94309089, "excel_move",
        )
        code := numget(pCursorInfo, 8, "Ptr")
        if obj.has(code)
            return obj[code]
        msgbox(code . "`n未定义",,0x40000)
        return code
        ;hIcon := buffer(size, 0) ;创建 结构-图标信息
        ; https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-geticoninfo
        ;dllcall("GetIconInfo", "ptr",hIcon, "ptr",pCursorInfo, "int") ;获取 结构-图标信息
        ;lpvMaskBits := buffer(128, 0) ;创造 数组-掩图信息（128字节）
        ;dllcall("GetBitmapBits", "ptr", numget(hIcon, 12), "uint", 128, "uint", &lpvMaskBits)  ;读取数组-掩图信息
        ;MaskCode := 0
        ;loop(128) ;掩图码
        ;    MaskCode += numget(lpvMaskBits, A_Index, "UChar")  ;累加拼合
        ;if (numget(hIcon, 16, "uint") != "0") { ;颜色图不为空时（彩色图标时）
        ;    lpvColorBits := buffer(4096, 0)  ;创造 数组-色图信息（4096字节）
        ;    dllcall("GetBitmapBits", "ptr", numget(hIcon, 16), "uint", 4096, "uint", &lpvColorBits)  ;读取 数组-色图信息
        ;    loop(256) ;色图码
        ;        ColorCode += numget(lpvColorBits, A_Index*16-3, "UChar")  ;累加拼合
        ;} else {
        ;    ColorCode := "0"
        ;}
        ;dllcall("DeleteObject", "ptr",numget(hIcon,12))  ; *清理掩图
        ;dllcall("DeleteObject", "ptr",numget(hIcon,16))  ; *清理色图
        ;pCursorInfo := buffer(0) ;清空 结构-光标信息
        ;hIcon := buffer(0) ;清空 结构-图标信息
        ;lpvMaskBits := buffer(0)  ;清空 数组-掩图
        ;lpvColorBits := buffer(0)  ;清空 数组-色图
        ;130504298 普通状态
        ;161920 说明是输入状态
        ;126898458 说明是按钮或超链接
        ;135470 Excel空心十字架
        ;144310 Excel实心十字架
        ;return MaskCode//2 . ColorCode  ;输出特征码
    }

    static moveByWindow(x, y:=1) {
        this._move("window", x, y)
    }
    static moveByScreen(x, y:=1) {
        this._move("screen", x, y)
    }

    ;如果x是数组，则y直接当n用(调用时不需要中间空一个参数) NOTE
    ;如果是负数，则点击高/宽相减的坐标
    static clickByWindow(x, y:=1, n:=1) {
        this._click("window", x, y, n)
    }
    static clickByScreen(x, y:=1, n:=1) {
        this._click("screen", x, y, n)
    }
    static clickByClient(x, y:=1, n:=1) { ;获取控件的坐标是client
        this._click("client", x, y, n)
    }

    static clickStayByWindow(x, y:=1, n:=1) { ;点击后鼠标不回到原位置
        this._clickStay("window", n, x, y)
    }
    static clickStayByScreen(x, y:=1, n:=1) {
        this._clickStay("screen", n, x, y)
    }
    static clickStayByClient(x, y:=1, n:=1) { ;获取控件的坐标是client
        this._clickStay("client", n, x, y)
    }

    ;如果x是数组，则y直接当n用(调用时不需要中间空一个参数) NOTE
    static downByWindow(x, y:=1) {
        this.downBase("window", x, y)
    }
    static downByScreen(x, y:=1, n:=1) {
        this.downBase("screen", x, y)
    }
    static downByClient(x, y:=1, n:=1) { ;获取控件的坐标是client
        this.downBase("client", x, y)
    }

    ;如果x是数组，则y直接当n用(调用时不需要中间空一个参数) NOTE
    ;NOTE 鼠标会停留
    static clickR(x:=0, y:=0, n:=1) {
        if (isobject(x)) {
            MouseMove(x[1], x[2], 0, "R")
            sleep(20)
            click(y ? y : 1)
        } else {
            MouseMove(x, y, 0, "R")
            sleep(20)
            click(n)
        }
    }

    ;鼠标会回到原坐标
    static clickBackR(x, y:=1, n:=1) {
        cmMouse := A_CoordModeMouse
        CoordMode("mouse", "Screen")
        MouseGetPos(&x0, &y0)
        if (isobject(x)) {
            MouseMove(x[1], x[2], 0, "R")
            sleep(20)
            click(y)
        } else {
            MouseMove(x, y, 0, "R")
            sleep(20)
            click(n)
        }
        MouseMove(x0, y0, 0)
        CoordMode("mouse", cmMouse)
    }

    ;dllcall("SetCursorPos", int,xScreen, int,yScreen)
    static _move(mode, x, y) {
        cmMouse := A_CoordModeMouse
        CoordMode("mouse", mode)
        if (isobject(x)) {
            if (x[1] < 0 || x[2] < 0) { ;处理负数(则用宽/高加上负数)
                WinGetPos(,, &w, &h, "A")
                if (x[1] < 0)
                    x[1] := w+x[1]
                if (x[2] < 0)
                    x[2] := h+x[2]
            }
            MouseMove(x[1], x[2])
        } else {
            if (x < 0 || y < 0) {
                WinGetPos(,, &w, &h, "A")
                if (x < 0)
                    x := w+x
                if (y < 0)
                    y := h+y
            }
            MouseMove(x, y, 0)
        }
        CoordMode("mouse", cmMouse)
    }

    static _click(mode, x, y:=1, n:=1) {
        ;保存坐标
        CoordMode("mouse", "Screen")
        MouseGetPos(&x0, &y0)
        this._move(mode, x, y)
        sleep(20)
        if (isobject(x))
            click(y)
        else
            click(n)
        sleep(10)
        MouseMove(x0, y0, 0)
        CoordMode("mouse", "Screen")
    }

    static _clickStay(mode, n:=1, arr*) {
        this._move(mode, arr[1], arr[2])
        sleep(20)
        click(n)
        ; isobject(x) ? click(y) : click(n)
    }

    static downBase(mode, x, y:=1) { ;按下左键不放
        cmMouse := A_CoordModeMouse
        CoordMode("mouse", mode)
        if (isobject(x))
            MouseMove(x[1], x[2])
        else
            MouseMove(x, y, 0)
        sleep(20)
        send("{LButton down}")
        CoordMode("mouse", cmMouse)
    }

    ;m := MenuCreate()
    ;h := 45 ;每个框的间距
    ;m.add("(&1)每个到末尾", ObjBindMethod(_Mouse,"clickThrough",A_ScreenHeight-50, h, 1))
    ;m.add("(&A)每个到指定", ObjBindMethod(_Mouse,"clickThrough",0,h,1))
    ;m.add("(&2)每2个到末尾",ObjBindMethod(_Mouse,"clickThrough",A_ScreenHeight-50, h, 2))
    ;m.add("(&B)每2个到指定",ObjBindMethod(_Mouse,"clickThrough",0,h,2))
    ;m.show()
    ;从当前位置点击到目标位置
    static clickThrough(yMax:=0, part:=0, nFenge:=1, ms:=20) {
        cmMouse := A_CoordModeMouse
        CoordMode("mouse", "screen") ;用全屏模式不需要后面的 sleep
        ;sleep(100) ;等待窗口激活
        MouseGetPos(&x, &y0)
        if (!yMax) {
            tooltip("移到最终位置并按任意键")
            ih := InputHook()
            ih.VisibleNonText := false
            ih.KeyOpt("{All}", "E")
            ih.start()
            suspend true
            ih.wait()
            suspend false
            tooltip
            MouseGetPos(, &yMax)
        }
        if (!part) {
            oInput := inputbox("请输入区域内点击数量")
            if (oInput.result=="Cancel" || oInput.value == "")
                throw ValueError("empty string")
            part := round((yMax-y0)/(oInput.value-1))
        }
        if (!nFenge) {
            oInput := inputbox("每几个点击一次",,, 1)
            if (oInput.result=="Cancel" || oInput.value == "")
                throw ValueError("empty string")
            nFenge := oInput.value
        }
        yLoop := y0
        while(yLoop <= round(part/2+yMax)) {
            this.clickStayByScreen(x, yLoop)
            sleep(ms)
            yLoop += part*nFenge
        }
        CoordMode("mouse", cmMouse)
    }

}

;和当前鼠标有关的坐标在 _Mouse
;无关的才放这里
;比如要点击窗口的 x,y,可以自动根据窗口或 aRect 转化为
class xy {

    ;从左/上，向外部偏移
    ;返回 [xScreen, yScreen]
    static offsetOut(xOffset, yOffset, aRect) {
        if (aRect is integer || aRect is string) {
            WinGetPos(&x, &y, &w, &h, aRect)
            aRect := [x,y,w,h]
        }
        return [deal(xOffset,aRect[1],aRect[3]), deal(yOffset,aRect[2],aRect[4])]
        ;v
        ;   0 = 中点
        ;   负数 = 左边界再往左偏移(支持小数点按百分比计算)
        ;   正数 = 右边界再往右偏移(支持小数点按百分比计算)
        deal(v, x, w) {
            if (v == 0) {
                v := x + w // 2
            } else if (v < 0) {
                if (v > -1)
                    v := x - round(w*abs(v))
                else
                    v := x - abs(v)
            } else {
                if (v < 1)
                    v := x + w + round(w * v)
                else if (v >= 1)
                    v := x + w + v
            }
            return v
        }
    }

}
