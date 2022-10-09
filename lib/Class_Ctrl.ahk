﻿/*
https://docs.microsoft.com/en-us/windows/win32/controls/about-edit-controls#edit-control-notification-messages
整理 by 火冷<2020-10-27 00:02:54>
获取父元素 parent
hCtl := ControlGetHwnd("SysListView321", "A")
arr := []
while (parent := DllCall("GetParent","int",hCtl)) {
    arr.push(parent)
    hCtl := parent
}
msgbox(arr[-1])
*/

class _Ctrl {

    ;所有子类都调用此方法记录控件
    __new(ctl, winTitle:="") {
        this.ctl := ctl
        this.hwnd := WinExist(winTitle)
        this.hCtl := ControlGetHwnd(ctl, "A")
        ; msgbox(ctl . "`n" . this.hwnd . "`n" . this.hCtl . "`n" . WinExist())
        this.pid := WinGetPID()
    }

    ;通过 ClassNN 和 text 获取 winTitle 的控件
    ;fun(ctlName) 为 true 则返回
    ;fun := ctlName=>instr(ctlName, name) && instr(ControlGetText(ctlName), text)
    static get(fun, winTitle:="") {
        try
            arr := WinGetControls(winTitle)
        catch
            return
        for ctlName in arr {
            if (fun.call(ctlName))
                return ctlName
        }
    }
    ;Iterate through controls with the same class, find the one with ctrlID and return its handle
    ;Used for finding a specific control
    ;FindWindowExID(dlg, className, ctrlId) {
    ;    local ctrl, id
    ;    ctrl := 0
    ;    loop {
    ;        ctrl := dllcall("FindWindowEx", "uint",dlg, "uint",ctrl, "str",className, "uint",0)
    ;        if (ctrlId == "0")
    ;            return ctrl
    ;        if (ctrl != "0") {
    ;            id := dllcall( "GetDlgCtrlID", "uint", ctrl )
    ;            if (id == ctrlId)
    ;                return ctrl
    ;        } else
    ;            return 0
    ;    }
    ;}

    ;控件 Rect 坐标
    ;mode 0=window 1=screen
    static getRect(ctl, mode:=1, winTitle:="") {
        WinExist(winTitle)
        WinGetClientPos(&xClient, &yClient)
        ControlGetPos(&x, &y, &w, &h, ctl)
        if (mode) {
            return [x+xClient, y+yClient, w, h]
        } else {
            WinGetPos(&xWin, &yWin)
            return [x+xClient-xWin, y+yClient-yWin, w, h]
        }
    }

    ;getIndexByFunText("SysListView321", (sLine)=>StrSplit(sLine,A_Tab)[1]==value)
    static getIndexByFunText(ctl, funStrLine) {
        for k, sLine in ControlGetItems(this.hCtl) {
            msgbox(sLine)
             if (funStrLine.call(sLine))
                 return A_Index
        }
    }

    ;示例 getValue(ControlGetHwnd("Chrome_RenderWidgetHostHWND1", "ahk_class Chrome_WidgetWin_1"))
    static getValue(hCtl) {
        uia := ComObject("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
        ;获取 AutomationElement
        dllcall(numget(numget(uia,0,"ptr") + 6*A_PtrSize, 0, "ptr"), "ptr",uia, "ptr",hCtl, "ptr*",&ae:=0)
        if (!ae)
            msgbox(hCtl)
        ;创建 variant 变量
        var := buffer(8 + 2*A_PtrSize)
        numput("UPtr", 0, var, 0, "short")
        numput("UPtr", 0, var, 8, "ptr")
        ;获取 Value
        dllcall(numget(numget(ae,0,"ptr") + 10*A_PtrSize, 0, "ptr"), "ptr",ae, "int",30045, "ptr",&var)
        return strget(numget(var, 8, "ptr"), "utf-16")
    }

    ;TODO ControlClick 很多时候不靠谱，待验证，不行用鼠标点击 _Mouse.clickCtrl()
    static click(hCtl, WinTitle:="", WinText:="", ExcludeTitle:="", ExcludeText:="") {
        if !(hCtl ~= "^\d+$")
            hCtl := ControlGetHwnd(hCtl, winTitle, WinText, ExcludeTitle, ExcludeText)
        uia := ComObject("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
        ; tmplinshi
        ; https://www.autohotkey.com/boards/viewtopic.php?t=23607&tdsourcetag=s_pctim_aiomsg
        ; if (WinExist(WinTitle, WinText, ExcludeTitle, ExcludeText)) {
        ;     hCtl := ControlGetHwnd(ctl)
        ;     SendMessage(WM_COMMAND:=0x111, (0 << 16) | (dllcall("GetDlgCtrlID","ptr",hCtl) & 0xffff), hCtl)
        ; }
    }

    ;等待控件出现并可用(暂时没用)
    ;static waitEnabled(name, text, winTitle:="") {
    ;    WinExist(winTitle)
    ;    ctl := ""
    ;    while (!ctl) {
    ;        sleep(200)
    ;        ctl := _Ctrl.get((ctlName)=>(instr(ctlName, name) && instr(ControlGetText(ctlName), text)), text)
    ;    }
    ;    while(!ControlGetEnabled(ctl))
    ;        sleep(100)
    ;    return ctl
    ;}

    ;清空并赋值(Edit)
    ;setText(str, ctl, winTitle:="", ent:=false)
    ;{
        ;if (winTitle != "") && !WinExist(winTitle) ;NOTE 设置 Last Found Window
            ;return
        ;if (instr(ctl, "edit"))
        ;{
            ;ControlSetText("", ctl) ;ControlEditPaste不会清空
            ;ControlEditPaste(str, ctl)
        ;}
        ;else
            ;_Key.sendP(str)
        ;if (ent)
            ;send("{enter}")
    ;}

    ;有些控件需要输入内容才能激活比如出现【保存】
    ;SendEditPaste(str, ctl:="", winTitle:="")
    ;{
        ;if (ctl == "")
            ;ctl := ControlGetFocus(winTitle)
        ;ControlSend("1", ctl, winTitle) ;发送任意内容激活控件
        ;sleep(500)
        ;ControlSetText("", ctl, winTitle) ;ControlEditPaste不会清空
        ;ControlEditPaste(str, ctl, winTitle)
    ;}

    static list(winTitle:="") { ;遍历控件
        WinExist(winTitle)
        ctlNames := WinGetControls()
        res := ""
        for ctlName in ctlNames
            res.push(format("{1}`t{2}", ctlName,ControlGetText(ctlName)))
        if (ctlNames.length > 30) { ;写入桌面文件
            fp := format("{1}\ControlList{2}.txt", A_Desktop,A_Now)
            FileAppend(res, fp)
            ;hyf_runByVim(fp)
        } else
            msgbox(res)
    }

}

;ee
class _Edit extends _Ctrl {

    __new(ctl:="", winTitle:="") {
        if (ctl == "")
            ctl := ControlGetFocus(winTitle)
        super.__new(ctl, winTitle)
    }

    ;获取选择区域的起始和末尾序号(0开始)
    ; https://docs.microsoft.com/en-us/windows/win32/controls/em-getsel
    ; hyf_objView(_Edit("Edit1", "A").getSelectPos())
    getSelectPos() {
        sPos := buffer(4, 0)
        ePos := buffer(4, 0)
        SendMessage(EM_GETSEL:=0xB0, &sPos, &ePos, "Edit1", "A")
        s := numget(sPos, 0, "UPtr")
        e := numget(ePos, 0, "UPtr")
        return [s, e]
    }

    ;返回选择的文本内容
    ;EditGetSelectedText
    ;getSelectText() {
    ;    arr := this.getSelectPos()
    ;    str := ControlGetText(this.ctl, "ahk_id " . this.hwnd)
    ;    return substr(str, arr[1]+1, arr[2]-arr[1])
    ;}

    ; https://docs.microsoft.com/en-us/previous-versions/aa932540(v=msdn.10)?redirectedfrom=MSDN
    ;选择文本(参数同 substr 选中第3-5，则参数要用3和3))
    ;还可用来定位光标，比如2,2，光标停留在第2个字符后面
    ;Edit 选择文本
    ;_Edit("Edit1", "A").select(1,5)
    select(start:=0, len:=-1) {
        SendMessage(EM_SETSEL:=0xB1, start, start+len, this.ctl, "ahk_id " . this.hwnd)
    }

}

;ListBox1
;oLB := _ListBox("ListBox1", "A")
;TODO selected 获取的是所有内容
class _ListBox extends _Ctrl {
    __new(ctl, winTitle:="") {
        super.__new(ctl, winTitle)
        ; msgbox(this.ctl . "`n" . this.hwnd)
    }

    GetCount() {
        return SendMessage(LB_GETCOUNT:=0x18B,,,, "ahk_id " . this.hCtl) + 1
    }

    ;第1项为 1
    getSelectedIndex() {
        return SendMessage(LB_GETCURSEL:=0x188,,,, "ahk_id " . this.hCtl)+1
    }

    getSelectedText() {
        idx := this.getSelectedIndex()
        for sLine in ControlGetItems(this.ctl, "ahk_id " . this.hwnd) {
            if (idx == A_Index)
                return sLine
        }
    }

    getIndexByText(strOrFun) {
        if (!isobject(strOrFun))
            strOrFun := (sLine)=>(sLine==strOrFun)
        for sLine in ControlGetItems(this.ctl, "ahk_id " . this.hwnd) {
            if (strOrFun(sLine))
                return A_Index
        }
        throw ValueError("value not matched")
    }

    ;第 idx 行所有文本(一般需要 StrSplit)
    getTextByIndex(idx) {
        len := SendMessage(LB_GETTEXTLEN:=0x18A, idx-1,,, "ahk_id " . this.hCtl)+1
        var := buffer(len<<1, 0)
        SendMessage(LB_GETTEXT:=0x189, idx-1,&var,, "ahk_id " . this.hCtl)+1
        return strget(&var)
    }

    setCurrent(idx) {
        return SendMessage(LB_SETCURSEL:=0x186, idx-1,,, "ahk_id " . this.hCtl)
    }
    
    ;第 idx 项设置为列表框的第1个可见项
    setTop(idx) {
        SendMessage(LB_SETTOPINDEX:=0x197, idx-1,,, "ahk_id " . this.hCtl)
    }

    ;选中第 idx 个
    selectByIndex(idx:=unset) {
        if (!isset(idx)) {
            str := hyf_selectByArr(ControlGetItems(this.ctl, "ahk_id " . this.hwnd))
            msgbox(str)
        }
        if (!idx)
            throw ValueError("idx == 0")
        if (0)
            SendMessage(LB_SETCURSEL:=0x186, idx-1,,, "ahk_id " . this.hCtl) ;选中项优先在首行(NOTE 不会触发事件)
        else
            ControlChooseIndex(idx, this.ctl, "ahk_id " . this.hwnd) ;选中项可能显示在末行
    }

    selectByText(strOrFun) {
        OutputDebug(format("i#{1} {2}:strOrFun={3}", A_LineFile,A_LineNumber,strOrFun))
        idx := this.getIndexByText(strOrFun)
        this.selectByIndex(idx)
    }

    selectAll() {
        PostMessage(LB_SETSEL:=0x185, 1, -1,, "ahk_id " . this.hCtl)
    }
}

;ll
;SysListView321
;_ListView("SysListView321", "A").selectByIndex(2)
;_ListView("SysListView321", "A").selectByText()
; getIndexByText("SysListView321", (sLine)=>StrSplit(sLine)[1]==value)
;TODO 在程序和功能获取内容会包含 \u2008 的特殊符号
class _ListView extends _Ctrl {

    __new(ctl, winTitle:="") {
        super.__new(ctl, winTitle)
    }

    focus() {
        ControlFocus(this.hCtl, "ahk_id " . this.hwnd)
    }
    arrSelect() {
        return StrSplit(this.getSelectedText(), "`n", "`r")
    }
    getIndexByText(str, i:=1) {
        loop parse, ListViewGetContent(, this.hCtl), "`n", "`r" {
            ;msgbox(str . "`n" . json.stringify(StrSplit(A_LoopField,A_Tab), 4))
            arr := StrSplit(A_LoopField,A_Tab)
            if (arr.length < i)
                continue
            if (arr[i] == str)
                return A_Index
        }
        return 0
    }
    getSelectedCount() {
        return SendMessage(LVM_GETSELECTEDCOUNT:=0x1032,,,, "ahk_id " . this.hCtl)
    }
    getSelectedText() {
        return ListViewGetContent("Selected", this.hCtl, "ahk_id " . this.hwnd)
    }
    getSelectedIndex() { ;TODO 只返回1个(从0开始)
        return SendMessage(LVM_GETSELECTIONMARK:=0x1042,,,, "ahk_id " . this.hCtl)
        ;return SendMessage(LVM_GETITEMNEXT:=0x100c,-1,3,, "ahk_id " . this.hCtl) ;返回 4294967296 异常 http://msdn.microsoft.com/en-us/library/bb761057.aspx
    }
    ;getHoverIndex() { ;TODO 鼠标停留的序号(从0开始)
    ;    return SendMessage(LVM_GETSELECTIONMARK:=0x1042,,,, "ahk_id " . this.hCtl)
    ;}

    selectByInput(i:=1) {
        arr := []
        loop parse, ListViewGetContent(, this.hCtl), "`n", "`r"
            arr.push(RegExReplace(A_LoopField, "`t.*"))
        arrRes := hyf_selectByArr(arr)
        if (arrRes.length)
            this.selectByText(arrRes[i], i)
    }
    selectByText(str, i:=1) {
        idx := this.getIndexByText(str, i)
        if (!idx)
            throw ValueError(format('not found "{1}" in ListView', str))
        this.selectByIndex(idx)
    }
    selectByIndex(idx:=1) {
        bufLvItem := buffer(52+(2*A_PtrSize))
        numput("UPtr", state:=3, bufLvItem, 12)
        numput("UPtr", stateMask:=2, bufLvItem, 16)
        oRB := RemoteBuffer(this.pid, bufLvItem.size)
        oRB.write(bufLvItem)
        SendMessage(LVM_ENSUREVISIBLE:=0x1013, idx-1,,, "ahk_id" . this.hCtl)
        SendMessage(LVM_SETITEMSTATE:=0x102B, idx-1, oRB.arrBuffer[1],, "ahk_id" . this.hCtl)
        ;PostMessage(0x1043,, 2,, "ahk_id" . ControlGetHwnd(ctl, winTitle))
    }
    setChecked(idx, bCheck:=true) {
        size := 40
        LVITEM := buffer(size, 0)
        numput("UPtr", state:=0x1000*(bCheck+1), LVITEM, 12)
        numput("UPtr", stateMask:=0xF000, LVITEM, 16)
        oRB := RemoteBuffer(this.pid, size)
        oRB.write(LVITEM)
        SendMessage(LVM_SETITEMSTATE:=0x102B, idx-1, oRB.arrBuffer[1],, "ahk_id " . this.hCtl)
    }
    doubleClickByText(str) {
        idx := this.getIndexByText(str)
        this.doubleClickByIndex(idx)
    }
    ;_ListView("SysListView321", "A").doubleClickByIndex(2)
    doubleClickByIndex(idx) {
        this.selectByIndex(idx) ;选中该项
        oRB := RemoteBuffer(this.pid, 8)
        SendMessage(LVM_GETITEMPOSITION:=0x1010, idx-1, oRB.arrBuffer[1],, "ahk_id" . this.hCtl) ;http://msdn.microsoft.com/en-us/library/bb761048.aspx
        pXY := oRB.read()
        x := numget(pXY, 0, "UPtr")
        y := numget(pXY, 4, "UPtr")
        PostMessage(WM_NCACTIVATE:=0x86,,,, "ahk_id " . this.hCtl)
        ;PostMessage(WM_LBUTTONDOWN:=0x201,, x&0xFFFF | y<<16,, "ahk_id " . this.hCtl)
        ;PostMessage(WM_LBUTTONUP:=0x202,, x&0xFFFF | y<<16,, "ahk_id " . this.hCtl)
        PostMessage(WM_LBUTTONDBLCLCK:=0x203,, x&0xFFFF | y<<16,, "ahk_id " . this.hCtl)
        PostMessage(WM_LBUTTONUP:=0x202,, x&0xFFFF | y<<16,, "ahk_id " . this.hCtl)
    }

}

;SysTabControl321
class _Tab extends _Ctrl  {

    __new(ctl, winTitle:="") {
        super.__new(ctl, winTitle)
    }

    ;选中第几个标签(1开始)
    ; _Tab("SysTabControl321", "A").getSelectedIndex()
    getSelectedIndex() {
        return SendMessage(TCM_GETCURSEL:=0x130B,,,, "ahk_id " . this.hCtl) + 1
    }

    getSelectedText() {
        return this.arrText()[this.getSelectedIndex()]
    }

    ;所有标签内容
    ;https://docs.microsoft.com/en-us/windows/win32/api/commctrl/ns-commctrl-tcitema
    arrText() {
        sizeItem := 16 + A_PtrSize*3
        lMax := 260
        sizeMax := lMax * (1+1) ;文本总长度
        oRB := RemoteBuffer(WinGetPID("ahk_id " . this.hCtl), sizeItem+sizeMax, 0x8|0x10|0x20|0x400)
        pTabItem := oRB.arrBuffer[1]
        pText := pTabItem + sizeItem ;文字内容紧跟在 pTabItem 末尾
        ;给单个 bufTabItem 申请空间
        bufTabItem := buffer(sizeItem, 0)
        numput("UPtr", TCIF_TEXT:=1, bufTabItem, 0, "uint")
        numput("UPtr", pText, bufTabItem, 8+A_PtrSize)
        numput("UPtr", lMax, bufTabItem, 8 + A_PtrSize*2, "int")
        oRB.write(bufTabItem, sizeItem)
        arr := []
        loop(this.getCount()) {
            if (SendMessage(TCM_GETITEM:=0x133C, A_Index-1, pTabItem,, "ahk_id " . this.hCtl)) ;写入 bufTabItem 到 pTabItem 位置
                arr.push(oRB.read(1, 1, sizeItem, sizeMax))
            else
                arr.push("")
        }
        return arr
    }

    getIndexByText(str) {
        for i, v in this.arrText() {
            if (v == str)
                return i
        }
        return 0
    }

    ;数量
    getCount() {
        return SendMessage(TCM_GETITEMCOUNT:=0x1304,,,, "ahk_id " . this.hCtl)
    }

    ; 选中第n个标签
    ;ControlChooseIndex(idx, ctl, "A")

    ;根据名称选中
    tabSelect(val) {
        if (type(val) == "String")
            idx := this.getIndexByText(val)
        else
            idx := val
        if (idx) {
            ControlChooseIndex(idx, this.hCtl)
            ;SendMessage(TCM_SETCURFOCUS:=0x1330, idx-1,, this.hCtl)
            ;SendMessage(TCM_SETCURSEL:=0x130C, idx-1,, this.hCtl)
        } else {
            throw ValueError(val . " not valid")
        }
    }

}

;tt
; https://www.autohotkey.com/boards/viewtopic.php?t=4998
; SysTreeView321 根据路径选中项目
class _TreeView extends _Ctrl {
    __new(ctl, winTitle:="") {
        super.__new(ctl, winTitle)
    }

    ; _TreeView("SysTreeView321", "A").getPath()
    getPath(char:="\") {
        if (1) {
            el := UIA.ElementFromHandle(this.hCtl) ;获取控件
            op := el.FindFirst(UIA.CreatePropertyCondition("SelectionItemIsSelected", ComValue(0xB,-1)), 4)
            if (op) { ;找到选中项
                ;op.see(0)
                res := op.CurrentName ;NOTE 记录当前文字
                vw := UIA.ControlViewWalker()
                ;遍历选中项的父节点
                loop {
                    op := vw.GetParentElement(op)
                    ;op.see(0)
                    if (op.CurrentControlType == UIA.ControlType.tree) { ;普通都是 UIA_TreeItemControlTypeId
                        ;msgbox(res)
                        return res
                    }
                    res := format("{1}{2}{3}", op.CurrentName,char,res)
                }
                return res ;一般没用
            }
        } else {
            arr := []
            pLoop := this.GetSelection()
            while (pLoop) {
                arr.push(this.GetText(pLoop))
                pLoop := this.GetParent(pLoop)
            }
            ; hyf_objView(arr, "SysTreeView321内容")
            res := arr.pop()
            loop(arr.length)
                res .= "\" . arr[-A_Index]
            return res
        }
    }

    ;-------------以下为示例
    ;_TreeView("SysTreeView321", "A").selectByPath("安全设置\本地策略\用户权限分配")
    selectByPath(path, bEnter:=false) {
        elParent := UIA.ElementFromHandle(this.hCtl) ;获取控件
        arrPath := StrSplit(path, "\")
        for i, v in arrPath {
            if (instr(v, ":"))
                v := format("{1} ({2})", DriveGetLabel(v),StrUpper(v))
            ; tooltip(v)
            ;查找下一级并展开
            cond := UIA.CreateAndCondition(UIA.CreatePropertyCondition("ControlType","TreeItem"), UIA.CreatePropertyCondition("Name",v))
            ;查找元素(按时间)
            endtime := A_TickCount + 3000
            loop {
                el := elParent.FindFirst(cond, UIA.TreeScope.Children)
                if (el := elParent.FindFirst(cond, UIA.TreeScope.Children))
                    break
            }
            if (i == arrPath.length) { ;最后1项，直接选中结束
                OutputDebug(format("i#{1} {2}:select-{3}", A_LineFile,A_LineNumber,v))
                el.GetCurrentPattern("SelectionItem").Select()
            } else {
                op := el.GetCurrentPattern("ExpandCollapse")
                if (!op.CurrentExpandCollapseState) {
                    OutputDebug(format("i#{1} {2}:expand-{3}", A_LineFile,A_LineNumber,v))
                    op.Expand()
                } else { ;仅选中
                    OutputDebug(format("i#{1} {2}:select-{3}", A_LineFile,A_LineNumber,v))
                    el.GetCurrentPattern("SelectionItem").Select()
                    ;sleep(300)
                }
                elParent := el
            }
        }
        if (bEnter)
            send("{enter}")
        return true
    }

    ; _TreeView("SysTreeView321", "A").expandOnlyThis()
    expandOnlyThis() {
        oTree := UIA.ElementFromHandle(this.hCtl) ;获取控件
        el := oTree.FindFirst(UIA.CreatePropertyCondition("SelectionItemIsSelected", ComValue(0xB,-1)))
        if (el) { ;找到选中项
            vw := UIA.ControlViewWalker()
            ;找到第1根节点并往后循环
            oAE_First := vw.GetFirstChildElement(oTree)
            oAE_First.GetCurrentPattern("ExpandCollapse").Collapse()
            oAELoop := oAE_First
            while(oAELoop := vw.GetNextSiblingElement(oAELoop))
                oAELoop.GetCurrentPattern("ExpandCollapse").Collapse()
            ;最后打开一个
            vw.GetParentElement(el).GetCurrentPattern("ExpandCollapse").Expand()
        }
        ;oUIA := oTree := op := ""
    }

    ;----------------------------------------------------------------------------------------------
    ; Method: SetSelection
    ;         Makes the given item selected and expanded. Optionally scrolls the
    ;         TreeView so the item is visible.
    ;
    ; Parameters:
    ;         pItem			- Handle to the item you wish selected
    ;
    ; returns:
    ;         TRUE if successful, or FALSE otherwise
    ;
    SetSelection(pItem) {
        SendMessage(TVM_SELECTITEM:=0x110B, 0x9, pItem,, "ahk_id " this.hCtl)
        ; SendMessage(TVM_SELECTITEM:=0x110B, 0x8, pItem,, "ahk_id " this.hCtl) ;NOTE 慎用，可能会造成无法选择其他项
        ; SendMessage(TVM_SELECTITEM:=0x110B, 0x5, pItem,, "ahk_id " this.hCtl) ;TODO 好像多余
        return SendMessage(TVM_SELECTITEM:=0x110B, 0x9|0x8000, pItem,, "ahk_id " this.hCtl)
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: GetSelection
    ;         Retrieves the currently selected item
    ;
    ; Parameters:
    ;         None
    ;
    ; returns:
    ;         Handle to the selected item if successful, Null otherwise.
    ;
    GetSelection() {
        return SendMessage(TVM_GETNEXTITEM:=0x110A, 0x9,,, "ahk_id " this.hCtl)
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: GetRoot
    ;         Retrieves the root item of the treeview
    ;
    ; Parameters:
    ;         None
    ;
    ; returns:
    ;         Handle to the topmost or very first item of the tree-view control
    ;         if successful, NULL otherwise.
    ;
    GetRoot() {
        return SendMessage(TVM_GETNEXTITEM:=0x110A, 0x0,,, "ahk_id " this.hCtl)
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: GetParent
    ;         Retrieves an item's parent
    ;
    ; Parameters:
    ;         pItem			- Handle to the item
    ;
    ; returns:
    ;         Handle to the parent of the specified item. returns
    ;         NULL if the item being retrieved is the root node of the tree.
    ;
    GetParent(pItem) {
        return SendMessage(TVM_GETNEXTITEM:=0x110A, 0x3, pItem,, "ahk_id " this.hCtl)
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: GetChild
    ;         Retrieves an item's first child
    ;
    ; Parameters:
    ;         pItem			- Handle to the item
    ;
    ; returns:
    ;         Handle to the first Child of the specified item, NULL otherwise.
    ;
    GetChild(pItem) {
        return SendMessage(TVM_GETNEXTITEM:=0x110A, 0x4, pItem,, "ahk_id " this.hCtl)
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: GetNext
    ;         returns the handle of the sibling below the specified item (or 0 if none).
    ;
    ; Parameters:
    ;         pItem			- (Optional) Handle to the item
    ;
    ;         flag          - (Optional) "FULL" or "F"
    ;
    ; returns:
    ;         This method has the following modes:
    ;              1. When all parameters are omitted, it returns the handle
    ;                 of the first/top item in the TreeView (or 0 if none).
    ;
    ;              2. When the only first parameter (pItem) is present, it returns the
    ;                 handle of the sibling below the specified item (or 0 if none).
    ;                 if the first parameter is 0, it returns the handle of the first/top
    ;                 item in the TreeView (or 0 if none).
    ;
    ;              3. When the second parameter is "Full" or "F", the first time GetNext()
    ;                 is called the hItem passed is considered the "root" of a sub-tree that
    ;                 will be transversed in a depth first manner. No nodes except the
    ;                 decendents of that "root" will be visited. To traverse the entire tree,
    ;                 including the real root, pass zero in the first call.
    ;
    ;                 When all descendants have benn visited, the method returns zero.
    ;
    ; Example:
    ;				hItem = 0  ; Start the search at the top of the tree.
    ;				Loop
    ;				{
    ;					hItem := MyTV.GetNext(hItem, "Full")
    ;					if not hItem  ; No more items in tree.
    ;						break
    ;					ItemText := MyTV.GetText(hItem)
    ;					MsgBox The next Item is %hItem%, whose text is "%ItemText%".
    ;				}
    ;
    GetNext(pItem:=0, flag:="") { ;视图里的下一项，不是兄弟节点的下一个，所以当前项子结点展开后(Expand)，和 GetChild 是同效果
        static Root := -1
        if (RegExMatch(flag, "i)^\s*(F|Full)\s*$")) {
            if (Root == -1) {
                Root := pItem
            }
            res := SendMessage(TVM_GETNEXTITEM:=0x110A, 0x4, pItem,, "ahk_id " this.hCtl)
            if (res == 0) {
                res := SendMessage(TVM_GETNEXTITEM:=0x110A, 0x1, pItem,, "ahk_id " this.hCtl)
                if (res == 0) {
                    loop {
                        pItem := SendMessage(TVM_GETNEXTITEM:=0x110A, 0x3, pItem,, "ahk_id " this.hCtl)
                        if (pItem = Root) {
                            Root := -1
                            return 0
                        }
                        res := SendMessage(TVM_GETNEXTITEM:=0x110A, 0x1, pItem,, "ahk_id " this.hCtl)
                    } until res
                }
            }
            return res
        }
        Root := -1
        if (!pItem)
            return SendMessage(TVM_GETNEXTITEM:=0x110A, 0x0,,, "ahk_id " this.hCtl)
        else
            return SendMessage(TVM_GETNEXTITEM:=0x110A, 0x1, pItem,, "ahk_id " this.hCtl)
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: GetPrev
    ;         returns the handle of the sibling above the specified item (or 0 if none).
    ;
    ; Parameters:
    ;         pItem			- Handle to the item
    ;
    ; returns:
    ;         Handle of the sibling above the specified item (or 0 if none).
    ;
    GetPrev(pItem) {
        return SendMessage(TVM_GETNEXTITEM:=0x110A, 0x2, pItem,, "ahk_id " this.hCtl)
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: Expand
    ;         Expands or collapses the specified tree node
    ;
    ; Parameters:
    ;         pItem			- Handle to the item
    ;
    ;         flag			- Determines whether the node is expanded or collapsed.
    ;                         true : expand the node (default)
    ;                         false : collapse the node
    ;
    ;
    ; returns:
    ;         Nonzero if the operation was successful, or zero otherwise.
    ;
    Expand(pItem, DoExpand:=true) {
        flag := DoExpand ? 0x2 : 0x1
        return SendMessage(0x1102, flag, pItem,, "ahk_id " this.hCtl)
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: Check
    ;         Changes the state of a treeview item's check box
    ;
    ; Parameters:
    ;         pItem			- Handle to the item
    ;
    ;         fCheck        - if true, check the node
    ;                         if false, uncheck the node
    ;
    ;         Force			- if true (default), prevents this method from failing due to
    ;                         the node having an invalid initial state. See IsChecked
    ;                         method for more info.
    ;
    ; returns:
    ;         returns true if if successful, otherwise false
    ;
    ; Remarks:
    ;         This method makes pItem the current selection.
    ;
    Check(pItem, fCheck, Force:=true) {
        SavedDelay := A_KeyDelay
        SetKeyDelay(30)
        CurrentState := this.IsChecked(pItem, false)
        if (CurrentState = -1)
            if (Force) {
                ControlSend("{Space}",, "ahk_id " this.hCtl)
                CurrentState := this.IsChecked(pItem, false)
            } else
                return false
            if (CurrentState and not fCheck) or (not CurrentState and fCheck )
                ControlSend("{Space}",, "ahk_id " this.hCtl)
            SetKeyDelay(SavedDelay)
            return true
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: GetText
    ;         Retrieves the text/name of the specified node
    ;
    ; Parameters:
    ;         pItem         - Handle to the item
    ;
    ; returns:
    ;         The text/name of the specified Item. if the text is longer than 127, only
    ;         the first 127 characters are retrieved.
    ;
    ; Fix from just me (http://ahkscript.org/boards/viewtopic.php?f=5&t=4998#p29339)
    ;
    GetText(pItem) {
        ProcessIs32Bit := (A_PtrSize == 4)
        oRB := RemoteBuffer(WinGetPID("ahk_id " . this.hCtl), 0, 0x8|0x10|0x20|0x400)
        hProcess := oRB.hProcess
        ; Try to determine the bitness of the remote tree-view's process
        ;if (A_Is64bitOS && dllcall("Kernel32.dll\IsWow64Process", "ptr",hProcess, "uint*",WOW64)) ;TODO 判断是否32位程序 WOW64值有误
            ;ProcessIs32Bit := WOW64
        if (A_Is64bitOS) {
            dllcall("GetBinaryType", "astr",WinGetProcessPath("ahk_id " . this.hCtl), "uint*",&tp:=0)
            ProcessIs32Bit := (tp != 6)
        }
        size := ProcessIs32Bit ?  60 : 80 ; size of a TVITEMEX structure
        pTvItem := oRB.addBuffer(size)
        pText := oRB.addBuffer(256)
        ; TVITEMEX Structure
        TvItem := buffer(size, 0)
        numput("UInt", 0x1|0x10, TvItem, 0)
        if (ProcessIs32Bit) {
            numput("UInt", pItem, TvItem,  4)
            numput("UInt", pText , TvItem, 16)
            numput("UInt", 127  , TvItem, 20)
        } else {
            numput("UInt64", pItem, TvItem,  8)
            numput("UInt64", pText , TvItem, 24)
            numput("UInt", 127  , TvItem, 32)
        }
        txt := buffer(256, 0)
        oRB.write(&TvItem)
        SendMessage(TVM_GETITEMW:=0x113E,, pTvItem,, "ahk_id " this.hCtl)
        return strget(oRB.read(2), 256)
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: EditLabel
    ;         Begins in-place editing of the specified item's text, replacing the text of the
    ;         item with a single-line edit control containing the text. This method implicitly
    ;         selects and focuses the specified item.
    ;
    ; Parameters:
    ;         pItem			- Handle to the item
    ;
    ; returns:
    ;         returns the handle to the edit control used to edit the item text if successful,
    ;         or NULL otherwise. When the user completes or cancels editing, the edit control
    ;         is destroyed and the handle is no longer valid.
    ;
    EditLabel(pItem) {
        TVM_EDITLABEL := 1 ? 0x1141 : 0x110E
        return SendMessage(TVM_EDITLABEL,, pItem,, "ahk_id " this.hCtl)
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: GetCount
    ;         returns the total number of expanded items in the control
    ;
    ; Parameters:
    ;         None
    ;
    ; returns:
    ;         returns the total number of expanded items in the control
    ;
    GetCount() {
        return SendMessage(0x1105,,,, "ahk_id " this.hCtl)
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: IsChecked
    ;         Retrieves an item's checked status
    ;
    ; Parameters:
    ;         pItem			- Handle to the item
    ;
    ;         Force			- if true (default), forces the node to return a valid state.
    ;                         Since this involves toggling the state of the check box, it
    ;                         can have undesired side effects. Make this false to disable
    ;                         this feature.
    ; returns:
    ;         returns 1 if the item is checked, 0 if unchecked.
    ;
    ;         returns -1 if the checkbox state cannot be determined because no checkbox
    ;         image is currently associated with the node and Force is false.
    ;
    ; Remarks:
    ;         Due to a "feature" of Windows, a checkbox can be displayed even if no checkbox image
    ;         is associated with the node. It is important to either check the actual value returned
    ;         or make the Force parameter true.
    ;
    ;         This method makes pItem the current selection.
    ;
    IsChecked(pItem, Force:=true) {
        SavedDelay := A_KeyDelay
        SetKeyDelay(30)
        this.SetSelection(pItem)
        try
            SendMessage(0x1127, pItem,,, "ahk_id " this.hCtl)
        catch
            err := 1
        else
            err := 0
        State := ((err & 0xF000) >> 12) - 1
        if (State = -1 and Force) {
            ControlSend("{Space 2}",, "ahk_id " this.hCtl)
            SendMessage(0x1127, pItem,,, "ahk_id " this.hCtl)
            State := ((err & 0xF000) >> 12) - 1
        }
        SetKeyDelay(SavedDelay)
        return State
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: IsBold
    ;         Check if a node is in bold font
    ;
    ; Parameters:
    ;         pItem			- Handle to the item
    ;
    ; returns:
    ;         returns true if the item is in bold, false otherwise.
    ;
    IsBold(pItem) {
        try
            SendMessage(0x1127, pItem,,, "ahk_id " this.hCtl)
        catch
            return false
        else
            return true
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: IsExpanded
    ;         Check if a node has children and is expanded
    ;
    ; Parameters:
    ;         pItem			- Handle to the item
    ;
    ; returns:
    ;         returns true if the item has children and is expanded, false otherwise.
    ;
    IsExpanded(pItem) {
        try
            SendMessage(0x1127, pItem,,, "ahk_id " this.hCtl)
        catch
            return false
        else
            return true
    }
    ;----------------------------------------------------------------------------------------------
    ; Method: IsSelected
    ;         Check if a node is Selected
    ;
    ; Parameters:
    ;         pItem			- Handle to the item
    ;
    ; returns:
    ;         returns true if the item is selected, false otherwise.
    ;
    IsSelected(pItem) {
        try
            SendMessage(0x1127, pItem,,, "ahk_id " this.hCtl)
        catch
            return false
        else
            return true
    }
}

;获取当前 ControlGetText("ComboBox1", "A")
;ControlChooseString("4级", "ComboBox1")
;_ComboBox("ComboBox3", "A").selectByText()
class _ComboBox extends _Ctrl {

    __new(ctl, winTitle:="") {
        super.__new(ctl, winTitle)
    }

    ;所有选项内容
    arrText() {
        WinActive("ahk_id " . this.hwnd)
        arr := []
        els := UIA.ElementFromHandle(ControlGetHwnd(this.hCtl)).FindAll(UIA.CreatePropertyCondition("ControlType", "ListItem"))
        loop(els.length) {
            el := els.GetElement(A_Index-1)
            arr.push(el.CurrentName)
        }
        ;catch
        ;    msgbox(els.length)
        return arr
    }

    selectByText() {
        arr := this.arrText()
        idx := hyf_selectByArr(arr)[2]
        if (idx)
            ControlChooseIndex(idx, this.ctl, "ahk_id " . this.hwnd)
    }

    ;TODO
    indexOfComboBox(ctl:="ComboBox1", winTitle:="") {
        return SendMessage(CB_GETCURSEL:=0x147,,, this.Ctl, winTitle)
    }

}

;TODO 如何理解
class RemoteBuffer {
    ;size 一般多大
    ; https://docs.microsoft.com/en-us/windows/win32/procthread/process-security-and-access-rights
    ;PROCESS_VM_OPERATION:=0x8 PROCESS_VM_READ:=0x10 PROCESS_VM_WRITE:=0x20 PROCESS_QUERY_INFORMATION:=0x400
    __new(pid, size:=0, DesiredAccess:=56) { ; 0x8|0x10|0x20==56
        if !(this.hProcess := dllcall("OpenProcess", "UInt",DesiredAccess, "Int",0, "UInt",pid, "Ptr"))
            return ""
        this.arrBuffer := [] ;NOTE 可申请多个内存，所以用数组
        this.arrSize := []
        if (size)
            this.addBuffer(size)
    }

    __delete(idx:=0) {
        if (idx) {
            pBuffer := this.arrBuffer.RemoveAt(idx)
            this.arrSize.RemoveAt(idx)
            dllcall("VirtualFreeEx", "Ptr",this.hProcess, "Ptr",pBuffer, "UInt",0, "UInt",MEM_RELEASE:=0x8000)
            dllcall("CloseHandle", "Ptr",this.hProcess)
        } else { ;删除全部
            for k, pBuffer in this.arrBuffer
                dllcall("VirtualFreeEx", "Ptr",this.hProcess, "Ptr",pBuffer, "UInt",0, "UInt",MEM_RELEASE:=0x8000)
            dllcall("CloseHandle", "Ptr",this.hProcess)
        }
    }

    ;比如给 SysTabControl321 的某一项申请空间(文字内容不定长，所以不能直接用 SendMessage 获取)
    ;文字内容往往在 pBuffer + size 的后面
    addBuffer(size) {
        if !(pBuffer := dllcall("VirtualAllocEx", "UInt",this.hProcess, "UInt",0, "UInt",size, "UInt",MEM_COMMIT:=0x1000, "UInt",PAGE_READWRITE:=4, "Ptr"))
            return ""
        this.arrBuffer.push(pBuffer)
        this.arrSize.push(size)
        return pBuffer
    }

    ;NOTE size 可能和 arrSize 不同
    write(pLocalBuff, size:=0, idx:=1, offset:=0) {
        size := size ? size : this.arrSize[idx] ;TODO size是否恒等于 this.arrSize[idx]，是则可省略参数
        return dllcall("WriteProcessMemory", "Ptr",this.hProcess, "Ptr",this.arrBuffer[idx]+offset, "Ptr",pLocalBuff, "UInt",size, "UInt",0)
    }

    ;如果是单值，可直接设置 bVal=1
    read(idx:=1, bVal:=0, offset:=0, size:=0) {
        static bufLocal ;NOTE 不能少
        if (!size)
            size := this.arrSize[idx] - offset
        else
            size := min(size, this.arrSize[idx] - offset)
        bufLocal := buffer(size, 0)
        ;从 arrBuffer[idx]+offset 地址读取 size 长度内容，存到 &bufLocal 地址
        dllcall("ReadProcessMemory", "Ptr",this.hProcess, "Ptr",this.arrBuffer[idx]+offset, "Ptr",bufLocal, "UInt",size, "UInt",0)
        ;bufLocal := buffer(-1)
        return bVal ? bufLocal : bufLocal.ptr
    }

}