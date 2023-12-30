; https://www.autohotkey.com/boards/viewtopic.php?f=83&t=94046
; ======================================================================================================================
;  class LVICE_XXS      - ListView in-cell editing for AHK v2 - minimal version
; ======================================================================================================================
class LVICE_XXS {

   __new(LV) {
      ;if (type(LV) != "gui.ListView")
      ;   throw error("class LVICE requires a GuiControl object of type gui.ListView!")
      this.ClickFunc := ObjBindMethod(this, "Click")
      this.DoubleClickFunc := ObjBindMethod(this, "DoubleClick")
      this.BeginLabelEditFunc := ObjBindMethod(this, "BeginLabelEdit")
      this.EndLabelEditFunc := ObjBindMethod(this, "EndLabelEdit")
      this.CommandFunc := ObjBindMethod(this, "Command")
      this.LV := LV
      this.hWnd := LV.hWnd
   }

   __delete() {
      if dllcall("IsWindow", "Ptr", this.hWnd, "uint")
         this.LV.OnNotify(-3, this.DoubleClickFunc, 0)
      this.ClickFunc := ""
      this.DoubleClickFunc := ""
      this.BeginLabelEditFunc := ""
      this.EndLabelEditFunc := ""
      this.CommandFunc := ""
   }

   ;OnClick() {
   ;    LV.OnNotify(-2, this.ClickFunc)
   ;    LV.OnNotify(-3, this.DoubleClickFunc)
   ;}

   ; -------------------------------------------------------------------------------------------------------------------
   ; NM_CLICK (list view) notification
   ; -------------------------------------------------------------------------------------------------------------------
   Click(LV, L, p*) {
      critical
      r := numget(L + (A_PtrSize * 3), 0, "int")
      c := numget(L + (A_PtrSize * 3), 4, "int")
      arr := this.getLineText(LV, r+1)
      ;CellText := LV.GetText(r + 1, c + 1)
      CellText := arr[c+1]
      A_Clipboard := CellText
      tooltip(CellText)
      SetTimer(tooltip, -1000)
      return arr
   }

   getLineText(LV, r, p*) {
       arr := []
       loop(LV.GetCount("column"))
           arr.push(LV.GetText(r, A_Index))
       return arr
   }

   ; -------------------------------------------------------------------------------------------------------------------
   ; NM_DBLCLK (list view) notification
   ; -------------------------------------------------------------------------------------------------------------------
   DoubleClick(LV, L) {
      critical
      Item := numget(L + (A_PtrSize * 3), 0, "int")
      Subitem := numget(L + (A_PtrSize * 3), 4, "int")
      CellText := LV.GetText(Item + 1, SubItem + 1)
      RC := buffer(16, 0)
      numput("int", 0, "int", SubItem, RC)
      dllcall("SendMessage", "Ptr", LV.hWnd, "uint", 0x1038, "Ptr", Item, "Ptr", RC) ; LVM_GETSUBITEMRECT
      this.CX := numget(RC, 0, "int")
      if (Subitem = 0)
         this.CW := dllcall("SendMessage", "Ptr", LV.hWnd, "uint", 0x101D, "Ptr", 0, "Ptr", 0, "int") ; LVM_GETCOLUMNWIDTH
      else
         this.CW := numget(RC, 8, "int") - this.CX
      this.CY := numget(RC, 4, "int")
      this.CH := numget(RC, 12, "int") - this.CY
      this.Item := Item
      this.Subitem := Subitem
      this.LV.OnNotify(-175, this.BeginLabelEditFunc)
      dllcall("PostMessage", "Ptr", LV.hWnd, "uint", 0x1076, "Ptr", Item, "Ptr", 0) ; LVM_EDITLABEL
   }

   ; -------------------------------------------------------------------------------------------------------------------
   ; LVN_BEGINLABELEDIT notification
   ; -------------------------------------------------------------------------------------------------------------------
   BeginLabelEdit(LV, L) {
      critical
      this.HEDT := dllcall("SendMessage", "Ptr", LV.hWnd, "uint", 0x1018, "Ptr", 0, "Ptr", 0, "UPtr")
      this.ItemText := LV.GetText(this.Item + 1, this.Subitem + 1)
      dllcall("SendMessage", "Ptr", this.HEDT, "uint", 0x00D3, "Ptr", 0x01, "Ptr", 4) ; EM_SETMARGINS, EC_LEFTMARGIN
      dllcall("SendMessage", "Ptr", this.HEDT, "uint", 0x000C, "Ptr", 0, "Ptr", strptr(this.ItemText)) ; WM_SETTEXT
      dllcall("SetWindowPos", "Ptr", this.HEDT, "Ptr", 0, "int", this.CX, "int", this.CY,
                              "int", this.CW, "int", this.CH, "uint", 0x04)
      OnMessage(0x0111, this.CommandFunc, -1)
      this.LV.OnNotify(-175, this.BeginLabelEditFunc, 0)
      this.LV.OnNotify(-176, this.EndLabelEditFunc)
      return false

   }
   ; -------------------------------------------------------------------------------------------------------------------
   ; LVN_ENDLABELEDIT notification
   ; -------------------------------------------------------------------------------------------------------------------
   EndLabelEdit(LV, L) {
      static OffText := 16 + (A_PtrSize * 4)
      critical
      this.LV.OnNotify(-176, this.EndLabelEditFunc, 0)
      OnMessage(0x0111, this.CommandFunc, 0)
      if (TxtPtr := numget(L, OffText, "UPtr")) {
         ItemText := strget(TxtPtr)
         if (ItemText != this.ItemText)
            LV.modify(this.Item + 1, "Col" . (this.Subitem + 1), ItemText)
      }
      return false
   }

   ; -------------------------------------------------------------------------------------------------------------------
   ; WM_COMMAND notification
   ; -------------------------------------------------------------------------------------------------------------------
   Command(W, L, M, H) {
      critical
      if (L = this.HEDT) {
         N := (W >> 16) & 0xFFFF
         if (N = 0x0400) || (N = 0x0300) || (N = 0x0100) { ; EN_UPDATE | EN_CHANGE | EN_SETFOCUS
            dllcall("SetWindowPos", "Ptr", L, "Ptr", 0, "int", this.CX, "int", this.CY,
                                    "int", this.CW, "int", this.CH, "uint", 0x04)
         }
      }
   }
}
