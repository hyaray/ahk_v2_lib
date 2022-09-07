;UIA 和 GDIP 结合的应用
#include Class_UIA.ahk
#include Class_GDIP.ahk

class _UIADo {

    ;bSec 为显示秒数，0则一直显示，直到按下任意键
    static seeUIE(el, sTip:="", bSec:=0) {
        obj := el.allProperty()
        oGuiWin := guiShow(obj)
        oGui1 := _UIADo.rectControls([el])
        WinWaitClose("ahk_id " . oGuiWin.hwnd)
        oGui1.destroy()
        ;s := sTip . "`n"
        ;for k, v in obj {
        ;    if strlen(v)
        ;        s .= format("{1}=`t{2}`n", k,v)
        ;}
        ;tooltip(s,,, 9)
        ;oGui := _UIADo.rectControls(el)
        ;if bSec {
        ;    SetTimer(func("tooltip").bind(,,, 9), -(bSec*1000))
        ;    oGui.destroy()
        ;} else { ;
        ;    ih := InputHook()
        ;    ih.VisibleNonText := false
        ;    ih.KeyOpt("{all}", "E")
        ;    ih.start()
        ;    suspend true
        ;    ih.wait()
        ;    suspend false
        ;    tooltip(,,, 9)
        ;    oGui.destroy()
        ;}
        ;defButton是默认按钮前面的text内容
        guiShow(obj, defButton:="", oGui:="", times:=0) {
            if !isobject(obj)
                return
            if (type(obj)) == "Array" && !obj.length
                return
            if (type(obj)) == "Map" && !obj.count
                return
            if (times == 0) {
                oGui := gui()
                oGui.title := "mouse"
                oGui.SetFont("cBlue s11")
                oGui.OnEvent("escape",doEscape)
            }
            for k, v in obj {
                x := times*30 + 10 ;缩进30，离左边缘10
                oGui.add("text","section x" . x, k)
                if isobject(v)
                    %A_ThisFunc%(v, defButton, oGui, times+1)
                else if strlen(defButton) && (k = defButton)
                    oGui.add("button","ys yp-5 default v" . k, v).OnEvent("click", hyf_GuiMsgbox_1)
                else
                    oGui.add("button","ys yp-5 v" . k, v).OnEvent("click", hyf_GuiMsgbox_1)
            }
            if (times = 0)
                oGui.show("center")
            return oGui
            hyf_GuiMsgbox_1(ctl, p*) {
                sType := obj["ControlType"]
                ;val := (ctl.name ~= "^Is[A-Z]") ? integer(ctl.text) : format('"{1}"', ctl.text)
                val := (ctl.name ~= "Is[A-Z]") ? "ComValue(0xB,-1)" : format('"{1}"', ctl.text)
                if (GetKeyState("LCtrl", "P")) {
                    if (ctl.name = "name")
                        A_Clipboard := format('el := UIA.FindElement(WinGetID("A"), "{1}", {2})', sType,val)
                    else
                        A_Clipboard := format('el := UIA.FindElement(WinGetID("A"), "{1}", {2}, "{3}")', sType,val,ctl.name)
                } else if (GetKeyState("LShift", "P")) {
                    if (ctl.name = "name")
                        A_Clipboard := format('elWin.FindControl("{1}", {2})', sType,val)
                    else
                        A_Clipboard := format('elWin.FindControl("{1}", {2}, "{3}")', sType,val,ctl.name)
                } else
                    A_Clipboard := ctl.text
                tooltip("已复制到剪切板`n" . A_Clipboard)
                SetTimer(tooltip, -1000)
                ctl.gui.destroy()
            }
            doEscape(oGui) {
                oGui.destroy()
            }
        }
    }

    ;选中区域保存为图片
    static save(ThisHotkey) {
        arrRect := _GDIP.getRect((p*)=>GetKeyState(substr(ThisHotkey, instr(ThisHotkey,"button")-1), "P"))
        _GDIP.rect2fp(arrRect)
    }

    ;对多个控件进行矩形标注
    /*
    oGui := _UIADo.rectControls()(["LCLListBox1","Window5"])
    KeyWait("LButton", "D")
    oGui.destroy()
    */
    static rectControls(aCtls, clPen:=0xffFF0000, wPen:=2, winTitle:="A") {
        if !(type(aCtls) ~= "^(Array|IUIAutomationElementArray)$")
            aCtls := [aCtls]
        WinExist(winTitle)
        WinGetClientPos(&xClient, &yClient)
        ;控件转 aRects
        aRects := []
        for ctl in aCtls {
            aRect := (type(ctl) == "IUIAutomationElement") ? ctl.GetBoundingRectangle() : getRectByCtrl(ctl)
            if (wPen > 1) { ;NOTE 画外框需要调整
                n := wPen//2
                aRect[1] -= n
                aRect[2] -= n
                aRect[3] += 2*n
                aRect[4] += 2*n
            }
            aRects.push(aRect)
        }
        if (aRects.length == 1)
            _UIADo.aRect := aRects[1]
        return _GDIP.rectMark(aRects, [clPen, wPen])
        getRectByCtrl(ctl) {
            ControlGetPos(&x, &y, &w, &h, ctl)
            return [x+xClient, y+yClient, w, h]
        }
    }

    ;对多个控件进行文字说明
    ;oGui := _GDIP.fontControls(["Button2","Button3"], ["前后同时出声","只前面出声"], "Centre cffFF0000 r4 s16p Bold", (x)=>x-20, "A")
    ;oGui.destroy()
    static fontControls(aCtls, aText, opts, funcRect:="", winTitle:="") {
        WinExist(winTitle)
        WinGetPos(&x, &y, &w, &h)
        WinGetClientPos(&xClient, &yClient)
        oHBitmap := GDIP_HBitmap(w,h)
        oGraphics := GDIP_Graphics(oHBitmap)
        oGraphics.GdipSetSmoothingMode(4)
        for i, ctl in aCtls {
            aRect := getRectByCtrl(ctl)
            if isobject(funcRect) {
                for k, v in aRect
                    aRect[k] := funcRect.call(v)
            }
            oGraphics.DrawText(aText[i], format("{1} x{2} y{3} w{4}", opts,aRect*), sFont:="Arial")
            ; oGraphics.DrawText(aText[i], format("x{1} y{2} w{3} h{4}", opts,aRect*), sFont:="Arial") ;为什么不是这个？？
        }
        oGui := gui("-Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs")
        oGui.Show("NA")
        oGraphics.UpdateLayeredWindow(oGui.hwnd, [x,y,w,h])
        oGraphics.SelectObject()
        return oGui
        getRectByCtrl(ctl) {
            ControlGetPos(&x, &y, &w, &h, ctl)
            return [x+xClient, y+yClient, w, h]
        }
    }

}
