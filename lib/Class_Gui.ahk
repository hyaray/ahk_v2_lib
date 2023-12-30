class _Gui {

    static lv_show(arr2) {
        oGG := _Gui(arr2)
        ;oGG.callback := (p*)=>msgbox(json.stringify(p, 4))
        ;oGG.title := doctype
        ;oGG.setFontSize(11)
        ;oGG.setWidth(1600)
        oGG.data_arr2()
        oGG.ListViewEx()
        oGG.lv_bindClick()
    }

    static play() {
        oGui := gui("-caption +AlwaysOnTop +Border +E0x80000 +LastFound +ToolWindow")
        oGui.OnEvent("escape", doEscape)
        oGui.OnEvent("close", doEscape)
        oGui.SetFont("cRed s22")
        oGui.MarginX := 0
        oGui.MarginY := 0
        oVideo := oGui.AddActiveX("x0 y0 w960 h600", "WMPLayer.ocx")
        oVideo.value.url:="e:\Video\大自然在说话（合集）.mp4"
        oVideo.value.uiMode := "full"                   ; no WMP controls播放器界面模式，可为Full, Mini, None, Invisible 
        oVideo.value.stretchToFit := 1                  ; video is streched to the given activex range
        oVideo.value.enableContextMenu := 1             ; 右键菜单
        oVideo.value.settings.setMode("loop", true)
        oGui.show()
        doEscape(oGui, p*) => oGui.destroy()
    }

    ;TODO
    ; mouseAnalyze() {
    ;     oGui := gui("+AlwaysOnTop +ToolWindow -caption")
    ;     oGui.AddText("section x20", "xWin")
    ;     oGui.AddText("ys", "yWin")
    ;     oGui.AddText("ys", "xScreen")
    ;     oGui.AddText("ys", "yScreen")
    ;     oGui.AddText("ys", "cl")
    ;     oGui.show()
    ; }

    ;getColor() { ; TODO
    ;    oGui := gui("+AlwaysOnTop +ToolWindow -caption")
    ;    oGui.OnEvent("escape",doEscape)
    ;    ;oGui.color
    ;}

    ;转成没层级的数组，只包含key和val
    static hyobj2arr(obj, mark:=1) {
        arr := []
        for v in obj {
            if (v["key"] == "") ;首先过滤key为空的 NOTE
                continue
            if (isobject(v.sub)) { ;为目录
                for v in A_ThisFunc(v.sub, 0)
                    arr.push(v)
            } else
                arr.push([v["key"], v.val])
        }
        return arr
    }

    ;示例见 en.meta_fields()
    __new(data) {
        this.data := deepclone(data)
        this.title := ""
        this.res := []
        this.rs := 40 ;默认行数
        this.setFontSize(13)
        this.setWidth(1200, [])
        this.querys := map()
        ;switch tp {
            ;case "lvcopy":
            ;    this.headers := []
            ;    this.data_arr2()
            ;    if (!this.headers.length)
            ;default:
        ;}
    }

    createGui(opts:="") {
        switch opts {
            case "": opts := "+resize +AlwaysOnTop +Border +LastFound +ToolWindow"
        }
        oGui := gui(opts)
        ;oGui.BackColor := "222222"
        oGui.title := this.title
        oGui.MarginX := 20
        oGui.MarginY := 20
        oGui.SetFont(format("s{1}", this.fontsize))
        oGui.OnEvent("escape", ObjBindMethod(this,"do_gui_destroy"))
        return oGui
    }

    ;复制用
    ;单击复制单元格
    ListViewEx() {
        oGui := this.createGui()
        this.oLV := oGui.AddListView(format("VScroll count grid w{1} r{2}", this.w-50,this.rs+2), this.headers)
        this.oLV.header := SendMessage(0x101F,,, this.oLV.hwnd) ; LVM_GETHEADER - get hWnd of Header control
        dllcall("UxTheme.dll\SetWindowTheme", "ptr",this.oLV.hwnd, "WStr","Explorer", "Ptr",0) ; Set 'Explorer' theme
        ControlSetStyle("^0x100", this.oLV.Header) ; toggle the HDS_FILTERBAR style
        this.oLV.OnNotify(-312, ObjBindMethod(this,"do_lv_FilterChange")) ; HDN_FILTERCHANGE
        this.oLV.name := "lv"
        this.lv_addData()
        oGui.AddButton("default center section", "确定").OnEvent("click", ObjBindMethod(this,"do_btn_click"))
        oGui.AddButton("center ys", "复制当前表格内容").OnEvent("click", ObjBindMethod(this,"do_btn_copy"))
        ;oGui.AddButton("center ys", "全选").OnEvent("click", ObjBindMethod(this,"do_btn_lv_select_all"))
        ;oGui.AddButton("center ys", "全不选").OnEvent("click", ObjBindMethod(this,"do_btn_lv_select_none"))
        oGui.AddStatusBar(, format("共有{1}项结果", this.data.length))
        oGui.show(format("w{1} center", this.w))
        this.LVICE := LVICE_XXS(this.oLV)
    }

    lv_addData() {
        this.data_querys()
        this.oLV.opt("-Redraw")
        this.oLv.delete()
        for arr in this.data1
            this.oLV.add(, arr*)
        ;设置宽度
        cntCol := this.oLV.GetCount("column")
        if (this.widths.length) {
            loop(cntCol) {
                if this.widths is integer
                    w := this.widths
                else if A_Index <= this.widths.length
                    w := this.widths[A_Index]
                else
                    w := 100
                this.oLV.ModifyCol(A_Index, w)
            }
        } else {
            ;this.oLV.ModifyCol(A_Index, 1000//cntCol)
            this.oLV.ModifyCol()
        }
        this.oLV.opt("+Redraw")
    }

    data_querys() {
        OutputDebug(format("i#{1} {2}:{3} querys={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(this.querys,4)))
        if (!this.querys.count) {
            this.data1 := this.data
            return
        }
        this.data1 := []
        for arr in this.data {
            for i, v in this.querys {
                ;OutputDebug(format("i#{1} {2}:{3} arr[{4}]={5} v={6}", A_LineFile,A_LineNumber,A_ThisFunc,i,arr[i],v))
                if (isobject(arr[i]) || !instr(arr[i],v))
                    continue 2
            }
            this.data1.push(arr)
        }
        ;OutputDebug(format("i#{1} {2}:{3} this.data1={4}", A_LineFile,A_LineNumber,A_ThisFunc,json.stringify(this.data1,4)))
    }

    lv_bindClick(method:="Click") {
        this.oLV.OnNotify(-2, ObjBindMethod(this.LVICE,method))
    }

    lv_bindDoubleClick(method:="DoubleClick") {
        this.oLV.OnNotify(-3, ObjBindMethod(this.LVICE,method))
    }

    setFontSize(size) {
        this.fontsize := size
    }

    setWidth(w, widths:=unset) {
        this.w := w.fromDPI()
        if (isset(widths)) { ;百分比
            this.widths := widths.map((p)=>this.w*p//100)
        } else {
            this.widths := []
        }
    }

    ;处理arr1或ao
    data_arr2(min_rs:=40) {
        if (this.data is array) {
            ;this.rs := this.data.length
            if (!this.data.length)
                return
            if !(this.data[1] is array) {
                if (!isobject(this.data[1])) {
                    this.headers := ["field"]
                    for v in this.data
                        this.data[A_Index] := [v]
                } else if (this.data[1] is map) { ;NOTE map
                    ;获取标题
                    this.headers := this.data[1].keys()
                    ;map转数组
                    for obj in this.data {
                        this.data[A_Index] := obj.values()
                    }
                }
            } else { ;正规数据
                this.headers := this.data[1].map((v,k)=>"f" . k)
            }
        } else if (this.data is map) {
            this.headers := ["key", "value"]
            ;this.rs := this.data.count
            this.data := this.data.items()
        }
        ;if this.rs < min_rs
            ;this.rs := min_rs
    }

    ;-----------------------------------event_do-----------------------------------
    do_gui_destroy(oGui) {
        oGui.destroy()
        if (this.HasOwnProp("callback"))
            this.callback(this.res) ;NOTE 结束后回调
    }

    ;do_gui_escape(oGui) {
    ;    this.do_gui_destroy(oGui)
    ;}

    do_lv_FilterChange(oLV, LParam) {
        static NMHDR_Size := A_PtrSize * 3,
        TypeOffset := (4 * 6) + (A_PtrSize * 3),
        FilterOffset := TypeOffset + A_PtrSize
        FilterText := ""
        FilterTextLength := 256
        i := numget(LParam, NMHDR_Size, "int")             ; get the current column index
        VarSetStrCapacity(&FilterText, FilterTextLength)            ; String buffer for HDTEXTFILTER struct
        HDTEXTFILTER := buffer(A_PtrSize * 2, 0)              ; HDTEXTFILTER struct -----------------------------------
        numput("Ptr", strptr(FilterText), HDTEXTFILTER, 0)          ; add pointer to string buffer variable
        numput("int", FilterTextLength, HDTEXTFILTER, A_PtrSize)  ; buffer size
        HDItem := buffer((4*6) + (A_PtrSize*6), 0)            ; HDITEM struct -----------------------------------------
        numput("uint", 0x100           , HDItem, 0)                 ; Set the Mask to HDI_FILTER := 0x100
        numput("uint", 0x0             , HDItem, TypeOffset)        ; Set the type to HDFT_ISSTRING := 0x0
        numput("Ptr" , HDTEXTFILTER.Ptr, HDItem, FilterOffset)      ; add pointer to HDTEXTFILTER struct
        ; send message to get the item
        SendMessage(0x120B, i, HDItem.Ptr, oLV.Header)             ; HDM_GETITEM = 0x120B
        VarSetStrCapacity(&FilterText, -1)                          ; update the internally-stored string length
        i += 1
        if (FilterText == "")
            this.querys.delete(i)
        else
            this.querys[i] := FilterText
        this.lv_addData()
        ;tooltip(LParam "column index - " i "`n`nFilter = " FilterText)
    }

    do_btn_click(ctl, param*) {
        oLV := ctl.gui["lv"]
        this.res := []
        loop(oLV.GetCount()) {
            if (SendMessage(0x102C, A_Index-1, 0x2000, oLV.hwnd)) {
                r := A_Index
                this.res.push([])
                loop(oLv.GetCount("column"))
                    this.res[-1].push(oLv.GetText(r, A_Index))
            }
        }
        this.do_gui_destroy(ctl.gui)
    }

    do_btn_copy(ctl, param*) {
        A_Clipboard := "`n".join(this.data1, A_Tab)
        tooltip(A_Clipboard)
        SetTimer(tooltip, -3000)
    }

    do_btn_lv_select_all(ctl, p*) {
        oLV := ctl.gui["lv"]
        loop(oLV.GetCount())
            oLV.modify(A_Index, "+check")
    }

    do_btn_lv_select_none(ctl, p*) {
        oLV := ctl.gui["lv"]
        loop(oLV.GetCount())
            oLV.modify(A_Index, "-check")
    }

}
