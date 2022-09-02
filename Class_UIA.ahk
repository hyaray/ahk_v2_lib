/* @description UI Automation class wrapper, based on https://github.com/neptercn/UIAutomation/blob/master/UIA2.ahk
* @author thqby, neptercn(v1 version)
* @date 2021/11/24
* @version 1.0.35

NOTE NOTE NOTE 思路：
说明：
    1. 窗口、控件、控件选项(比如 ComboBox 的每个选项)在 UIA 里全是 element, 获取方式是一样的，结构见 https://github.com/snoopwpf/snoopwpf 或 inspect.exe
    2. 主要类有
        UIA: 核心类，element pattern condition 等创建的方法基本上都在此
        IUIAutomationElement: element 的相关方法
        IUIAutomation***Pattern: element 可进行的操作，比如 Invoke(Button) SetValue(Edit) Select(SelectionItem)
        IUIAutomationCacheRequest: 批量获取信息时用此缓存加速
            rst := UIA.CreateCacheRequest()
            rst.AddProperty(30005)
            elWin := UIA.ElementFromHandleBuildCache(WinGetID("A"), rst)
            msgbox(elWin.GetCachedPropertyValue(30005))
        每个类都有个 __ 属性(用在 comcall)，其他基本上全是方法

使用步骤：
    1.获取【窗口】或【控件】el(为 IUIAutomationElement 类的实例，获取方式见 IUIAutomationElement_instance 下面的方法)
        2.1简单的推荐直接用 ElementFromHandle(hwnd) ElementFromPoint(xScreen, yScreen) GetFocusedElement()
        2.2 ElementFromPoint(xScreen, yScreen) 有时会获取很大的元素，要用 ElementFromPointEx()
        2.2如果是非标准窗口，一般先获取整个窗口控件 elWin := UIA.ElementFromHandle(hwnd)，再【搜索】特定的控件
        搜索方法：
            ①只搜索一次：
               推荐用封装的函数 UIA.FindElement(WinGetID("A"), 控件名, 其他字段值, 其他字段名(默认"name"))
               不需要保存 elWin，而是一次性用完就丢。
               比如Excel的【查找和替换】对话框，可用下面方法获取 Name="范围(H)": 的 ComboBox
               el := UIA.FindElement(WinGetID("A"), "ComboBox", "范围(H):")
               如果值不是精确匹配，比如查找部分匹配的，用 FindControlEx
               TIM 选择表情
                   el := UIA.FindElement(WinGetID("A"), "ComboBox", "选择表情", "LegacyIAccessibleDescription")
               TabItem
                   el := elTab.FindControl("TabItem", ComValue(0xB,-1), "SelectionItemIsSelected")
               ListItem
                   el := elTab.FindControl("ListItem", ComValue(0xB,-1), "SelectionItemIsSelected")
            ②多次搜索控件：
                1.先获取 elWin := UIA.ElementFromHandle(hwnd)
                2.指定匹配条件 condition (NOTE CreatePropertyConditionEx 可以搭配 PropertyConditionFlags 实现部分匹配)
                    单条件
                        控件类型
                            cond := UIA.CreatePropertyCondition("ControlType", "Button")
                        控件文本
                            cond := UIA.CreatePropertyCondition("Name", "确定")
                        控件值
                            cond := UIA.CreatePropertyCondition("ValueValue", "值")
                        控件AutomationId
                            cond := UIA.CreatePropertyCondition("AutomationId", "value")
                        boolean判断
                            cond := UIA.CreatePropertyCondition("SelectionItemIsSelected", ComValue(0xB,-1))) ;boolean(判断属性是否为boolean可用 ~= "Is[A-Z]") 需要转成 ComValue
                     组合条件(And|Or)
                     两个条件可用 And 组合
                         cond := UIA.CreateAndCondition(UIA.CreatePropertyCondition("ControlType", "Button"), UIA.CreatePropertyCondition("Name", "确定"))
                         cond := UIA.CreateOrCondition(UIA.CreatePropertyConditionEx("Name", "树"), UIA.CreatePropertyCondition("ValueValue", "树"))
                     更多条件用 array/obj，见 UIA.PropertyCondition([{ControlType: 50000, Name: "edit"}, {ControlType: 50004, Name: "edit", flags: 3}])
                3.指定搜索范围 scope 见 TreeScope(默认所有子孙节点:4)
                4.开始搜索
                查找单个
                    elWin.FindFirst(cond, scope)
                查找全部
                    for el in elWin.FindAll(cond, 4=子孙|2=儿子)
        2.3如果是 SysTreeView321 等控件，获取当前选中项
             _TreeView.getPath() 
        2.4根据结构来获取元素 vw := UIA.ControlViewWalker()
            某元素的父亲 GetParent()
            某元素的下/上一个兄弟节点 GetNext()/GetPrev()
            某元素的第1个儿子 GetFirst()
            某元素的最后1个儿子 GetLast()
            某元素的第N个儿子 GetFirst() 再 GetNext，可否优化 TODO
            某元素的所有子孙 FindAll(cond, 4=子孙|2=儿子)
    4.获取控件的属性(查看控件所有属性见 IUIAutomation_p，获取方法，见 IUIAutomationElement_vt)
        常用属性 见 allProperty
        获取 Tab 下所有 TabItem 名称
            elTab.getTabItems()
        获取 Table 下所有 数据 名称
            elTable.getTableData()
        获取 Tree 下所有 ListItem 名称
            elTable.getTreeData()
    5.操作控件，见类 IUIAutomationPattern 上方相关说明，可操作列表见 IUIAutomationPattern_vt
        激活控件
            el.SetFocus()
        Button/RadioButton/CheckBox/ComboBox/TabItem/ListItem/MenuItem
            点击
                el.GetCurrentPattern("Invoke").Invoke() TODO 经常会失败，用下面两个方式处理。MenuItem在_UBF.login()会卡死。
                el.ClickByControl()
                el.ClickByMouse()
            切换选择(增加了先判断) 每个选择项都是个控件，需要先找到选项项的控件(比如 ComboBox 要先点击，才会出现 ListItem)
                elCombobox.ComboboxSelectListItem(name) ; https://stackoverflow.com/questions/5814779/selecting-combobox-item-using-ui-automation
                el.SetChecked(true)
        修改文字
            el.GetCurrentPattern("Value").SetValue("hello")
    6.遍历
        见 GetNext 上下文(一般用 FindAll)
    7.事件监听 TODO
        UIA.AddAutomationEventHandler("Text_TextChanged", el, TreeScope_Element:=1, rst, handler)

https://www.codeproject.com/Articles/141842/Automate-your-UI-using-Microsoft-Automation-Framew
NOTE 客户端程序员指南 https://docs.microsoft.com/en-us/windows/win32/winauto/uiauto-clientsoverview
是 acc 的升级版，区别 https://docs.microsoft.com/en-us/windows/win32/winauto/uiauto-msaa
https://docs.microsoft.com/en-us/dotnet/framework/ui-automation/
https://docs.microsoft.com/en-us/dotnet/desktop/wpf/controls/ui-automation-of-a-wpf-custom-control?redirectedfrom=MSDN&view=netframeworkdesktop-4.8

nepter
   https://github.com/neptercn/UIAutomation
   https://www.autohotkey.com/board/topic/94619-ahk-l-screen-reader-a-tool-to-get-text-anywhere

https://github.com/jethrow/UIA_Interface
https://github.com/sancarn/Inspect.exe_AHK

NOTE c#版的封装库 https://github.com/FlaUI/FlaUI

https://www.cnblogs.com/ellie-test/p/4427323.html
https://www.cnblogs.com/ellie-test/p/4430533.html

https://www.autohotkey.com/boards/viewtopic.php?p=135520
https://www.autohotkey.com/boards/viewtopic.php?p=300069

https://v.youku.com/v_show/id_XNTcyNDM2NjA0.html?spm=a2h0c.8166622.PhoneSokuUgc_8.dtitle
https://v.youku.com/v_show/id_XMTM2MjE3NTAwMA==.html?spm=a2h0c.8166622.PhoneSokuUgc_1.dtitle

https://www.youtube.com/watch?v=yJmpNuic7bQ
https://www.youtube.com/watch?v=tLoo707k0yI
https://www.youtube.com/watch?v=V8iHQXq6kXA

uu
作用：
    1.订阅事件。
    2.创建条件。条件是用于缩小UI自动化元素的搜索范围的对象。
    3.直接从桌面（根元素）或从屏幕坐标或窗口句柄获取UI Automation元素。
    4.创建可用于导航UI自动化元素层次结构的tree walker对象。
    5.转换数据类型。

TODO 对win7的Chrome，UIA支持不好
*/

#include ComVar.ahk

; BSTR wrapper, convert BSTR to AHK string and free it
BSTR(ptr) {
    static _ := dllcall("LoadLibrary", "str","oleaut32.dll")
    if (ptr) {
        s := strget(ptr)
        dllcall("oleaut32\SysFreeString", "ptr",ptr)
        return s
    }
}

; NativeArray is C style array, zero-based index, it has `__Item` and `__Enum` property
class NativeArray {
    __New(ptr, count, type:="ptr") {
        static _ := dllcall("LoadLibrary", "str","ole32.dll")
        static bits := { UInt: 4, UInt64: 8, Int: 4, Int64: 8, Short: 2, UShort: 2, Char: 1, UChar: 1, Double: 8, Float: 4, Ptr: A_PtrSize, UPtr: A_PtrSize }
		this.size := (this.count := count) * (bit := bits.%type%), this.ptr := ptr || dllcall("ole32\CoTaskMemAlloc", "uint", this.size, "ptr")
        this.DefineProp("__Item", { get: (s, i) => numget(s, i*bit, type) })
        this.DefineProp("__Enum", { call: (s, i) => (i == 1
        ? (i := 0, (&v) => i < count ? (v := numget(s, i*bit, type), ++i) : false)
        : (i := 0, (&k, &v) => (i < count ? (k := i, v := numget(s, i*bit, type), ++i) : false))
        )})
    }
    __Delete() => dllcall("ole32\CoTaskMemFree", "ptr",this)
}

class IUIABase {
    __New(ptr) {
        if !(this.ptr := ptr)
            throw ValueError('Invalid IUnknown interface pointer', -2, this.__Class)
    }
    __Delete() => this.Release()
    __Item => (ObjAddRef(this.ptr), ComValue(0xd, this.ptr))
    AddRef() => ObjAddRef(this.ptr)
    Release() => this.ptr ? ObjRelease(this.ptr) : 0
}

class UIA {
    static ptr := ComObjValue(this.__ := ComObject("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}"))
    ; https://docs.microsoft.com/zh-cn/windows/win32/winauto/uiauto-controltype-ids
    static ControlType := { Button:50000, Calendar:50001, CheckBox:50002, ComboBox:50003, Edit:50004, Hyperlink:50005, Image:50006, ListItem:50007, List:50008, Menu:50009, MenuBar:50010, MenuItem:50011, ProgressBar:50012, RadioButton:50013, ScrollBar:50014, Slider:50015, Spinner:50016, StatusBar:50017, Tab:50018, TabItem:50019, Text:50020, ToolBar:50021, ToolTip:50022, Tree:50023, TreeItem:50024, Custom:50025, Group:50026, Thumb:50027, DataGrid:50028, DataItem:50029, Document:50030, SplitButton:50031, Window:50032, Pane:50033, Header:50034, HeaderItem:50035, Table:50036, TitleBar:50037, Separator:50038, SemanticZoom:50039, AppBar:50040,
    50000:"Button", 50001:"Calendar", 50002:"CheckBox", 50003:"ComboBox", 50004:"Edit", 50005:"Hyperlink", 50006:"Image", 50007:"ListItem", 50008:"List", 50009:"Menu", 50010:"MenuBar", 50011:"MenuItem", 50012:"ProgressBar", 50013:"RadioButton", 50014:"ScrollBar", 50015:"Slider", 50016:"Spinner", 50017:"StatusBar", 50018:"Tab", 50019:"TabItem", 50020:"Text", 50021:"ToolBar", 50022:"ToolTip", 50023:"Tree", 50024:"TreeItem", 50025:"Custom", 50026:"Group", 50027:"Thumb", 50028:"DataGrid", 50029:"DataItem", 50030:"Document", 50031:"SplitButton", 50032:"Window", 50033:"Pane", 50034:"Header", 50035:"HeaderItem", 50036:"Table", 50037:"TitleBar", 50038:"Separator", 50039:"SemanticZoom", 50040:"AppBar" }
    static ControlPattern := { Invoke: 10000, Selection: 10001, Value: 10002, RangeValue: 10003, Scroll: 10004, ExpandCollapse: 10005, Grid: 10006, GridItem: 10007, MultipleView: 10008, Window: 10009, SelectionItem: 10010, Dock: 10011, Table: 10012, TableItem: 10013, Text: 10014, Toggle: 10015, Transform: 10016, ScrollItem: 10017, LegacyIAccessible: 10018, ItemContainer: 10019, VirtualizedItem: 10020, SynchronizedInput: 10021, ObjectModel: 10022, Annotation: 10023, Styles: 10025, Spreadsheet: 10026, SpreadsheetItem: 10027, TextChild: 10029, Drag: 10030, DropTarget: 10031, TextEdit: 10032, CustomNavigation: 10033,
    10000: "Invoke", 10001: "Selection", 10002: "Value", 10003: "RangeValue", 10004: "Scroll", 10005: "ExpandCollapse", 10006: "Grid", 10007: "GridItem", 10008: "MultipleView", 10009: "Window", 10010: "SelectionItem", 10011: "Dock", 10012: "Table", 10013: "TableItem", 10014: "Text", 10015: "Toggle", 10016: "Transform", 10017: "ScrollItem", 10018: "LegacyIAccessible", 10019: "ItemContainer", 10020: "VirtualizedItem", 10021: "SynchronizedInput", 10022: "ObjectModel", 10023: "Annotation", 10025: "Styles", 10026: "Spreadsheet", 10027: "SpreadsheetItem", 10029: "TextChild", 10030: "Drag", 10031: "DropTarget", 10032: "TextEdit", 10033: "CustomNavigation" }
    static Event := { ToolTipOpened: 20000, ToolTipClosed: 20001, StructureChanged: 20002, MenuOpened: 20003, AutomationPropertyChanged: 20004, AutomationFocusChanged: 20005, AsyncContentLoaded: 20006, MenuClosed: 20007, LayoutInvalidated: 20008, Invoke_Invoked: 20009, SelectionItem_ElementAddedToSelection: 20010, SelectionItem_ElementRemovedFromSelection: 20011, SelectionItem_ElementSelected: 20012, Selection_Invalidated: 20013, Text_TextSelectionChanged: 20014, Text_TextChanged: 20015, Window_WindowOpened: 20016, Window_WindowClosed: 20017, MenuModeStart: 20018, MenuModeEnd: 20019, InputReachedTarget: 20020, InputReachedOtherElement: 20021, InputDiscarded: 20022, SystemAlert: 20023, LiveRegionChanged: 20024, HostedFragmentRootsInvalidated: 20025, Drag_DragStart: 20026, Drag_DragCancel: 20027, Drag_DragComplete: 20028, DropTarget_DragEnter: 20029, DropTarget_DragLeave: 20030, DropTarget_Dropped: 20031, TextEdit_TextChanged: 20032, TextEdit_ConversionTargetChanged: 20033, Changes: 20034, Notification: 20035, ActiveTextPositionChanged: 20036 }
    static Property := {
        RuntimeId: 30000,	; VT_I4 | VT_ARRAY (VT_EMPTY)
        BoundingRectangle: 30001,	; VT_R8 | VT_ARRAY ([0,0,0,0])
        ProcessId: 30002,	; VT_I4 (0)
        ControlType: 30003,	; VT_I4 (UIA_CustomControlTypeId)
        LocalizedControlType: 30004,	; VT_BSTR (empty string) The string should contain only lowercase characters. Correct: "button", Incorrect: "Button"
        Name: 30005,	; VT_BSTR (empty string)
        AcceleratorKey: 30006,	; VT_BSTR (empty string)
        AccessKey: 30007,	; VT_BSTR (empty string)
        HasKeyboardFocus: 30008,	; VT_BOOL (FALSE)
        IsKeyboardFocusable: 30009,	; VT_BOOL (FALSE)
        IsEnabled: 30010,	; VT_BOOL (FALSE)
        AutomationId: 30011,	; VT_BSTR (empty string)
        ClassName: 30012,	; VT_BSTR (empty string)
        HelpText: 30013,	; VT_BSTR (empty string)
        ClickablePoint: 30014,	; VT_R8 | VT_ARRAY (VT_EMPTY)
        Culture: 30015,	; VT_I4 (0)
        IsControlElement: 30016,	; VT_BOOL (TRUE)
        IsContentElement: 30017,	; VT_BOOL (TRUE)
        LabeledBy: 30018,	; VT_UNKNOWN (NULL)
        IsPassword: 30019,	; VT_BOOL (FALSE)
        NativeWindowHandle: 30020,	; VT_I4 (0)
        ItemType: 30021,	; VT_BSTR (empty string)
        IsOffscreen: 30022,	; VT_BOOL (FALSE)
        Orientation: 30023,	; VT_I4 (0 (OrientationType_None))
        FrameworkId: 30024,	; VT_BSTR (empty string)
        IsRequiredForForm: 30025,	; VT_BOOL (FALSE)
        ItemStatus: 30026,	; VT_BSTR (empty string)
        IsDockPatternAvailable: 30027,	; VT_BOOL
        IsExpandCollapsePatternAvailable: 30028,	; VT_BOOL
        IsGridItemPatternAvailable: 30029,	; VT_BOOL
        IsGridPatternAvailable: 30030,	; VT_BOOL
        IsInvokePatternAvailable: 30031,	; VT_BOOL
        IsMultipleViewPatternAvailable: 30032,	; VT_BOOL
        IsRangeValuePatternAvailable: 30033,	; VT_BOOL
        IsScrollPatternAvailable: 30034,	; VT_BOOL
        IsScrollItemPatternAvailable: 30035,	; VT_BOOL
        IsSelectionItemPatternAvailable: 30036,	; VT_BOOL
        IsSelectionPatternAvailable: 30037,	; VT_BOOL
        IsTablePatternAvailable: 30038,	; VT_BOOL
        IsTableItemPatternAvailable: 30039,	; VT_BOOL
        IsTextPatternAvailable: 30040,	; VT_BOOL
        IsTogglePatternAvailable: 30041,	; VT_BOOL
        IsTransformPatternAvailable: 30042,	; VT_BOOL
        IsValuePatternAvailable: 30043,	; VT_BOOL
        IsWindowPatternAvailable: 30044,	; VT_BOOL
        ValueValue: 30045,	; VT_BSTR (empty string)
        ValueIsReadOnly: 30046,	; VT_BOOL (TRUE)
        RangeValueValue: 30047,	; VT_R8 (0)
        RangeValueIsReadOnly: 30048,	; VT_BOOL (TRUE)
        RangeValueMinimum: 30049,	; VT_R8 (0)
        RangeValueMaximum: 30050,	; VT_R8 (0)
        RangeValueLargeChange: 30051,	; VT_R8 (0)
        RangeValueSmallChange: 30052,	; VT_R8 (0)
        ScrollHorizontalScrollPercent: 30053,	; VT_R8 (0)
        ScrollHorizontalViewSize: 30054,	; VT_R8 (100)
        ScrollVerticalScrollPercent: 30055,	; VT_R8 (0)
        ScrollVerticalViewSize: 30056,	; VT_R8 (100)
        ScrollHorizontallyScrollable: 30057,	; VT_BOOL (FALSE)
        ScrollVerticallyScrollable: 30058,	; VT_BOOL (FALSE)
        SelectionSelection: 30059,	; VT_UNKNOWN | VT_ARRAY (empty array)
        SelectionCanSelectMultiple: 30060,	; VT_BOOL (FALSE)
        SelectionIsSelectionRequired: 30061,	; VT_BOOL (FALSE)
        GridRowCount: 30062,	; VT_I4 (0)
        GridColumnCount: 30063,	; VT_I4 (0)
        GridItemRow: 30064,	; VT_I4 (0)
        GridItemColumn: 30065,	; VT_I4 (0)
        GridItemRowSpan: 30066,	; VT_I4 (1)
        GridItemColumnSpan: 30067,	; VT_I4 (1)
        GridItemContainingGrid: 30068,	; VT_UNKNOWN (NULL)
        DockDockPosition: 30069,	; VT_I4 (DockPosition_None)
        ExpandCollapseExpandCollapseState: 30070,	; VT_I4 (ExpandCollapseState_LeafNode)
        MultipleViewCurrentView: 30071,	; VT_I4 (0)
        MultipleViewSupportedViews: 30072,	; VT_I4 | VT_ARRAY (empty array)
        WindowCanMaximize: 30073,	; VT_BOOL (FALSE)
        WindowCanMinimize: 30074,	; VT_BOOL (FALSE)
        WindowWindowVisualState: 30075,	; VT_I4 (WindowVisualState_Normal)
        WindowWindowInteractionState: 30076,	; VT_I4 (WindowInteractionState_Running)
        WindowIsModal: 30077,	; VT_BOOL (FALSE)
        WindowIsTopmost: 30078,	; VT_BOOL (FALSE)
        SelectionItemIsSelected: 30079,	; VT_BOOL (FALSE)
        SelectionItemSelectionContainer: 30080,	; VT_UNKNOWN (NULL)
        TableRowHeaders: 30081,	; VT_UNKNOWN | VT_ARRAY (empty array)
        TableColumnHeaders: 30082,	; VT_UNKNOWN | VT_ARRAY (empty array)
        TableRowOrColumnMajor: 30083,	; VT_I4 (RowOrColumnMajor_Indeterminate)
        TableItemRowHeaderItems: 30084,	; VT_UNKNOWN | VT_ARRAY (empty array)
        TableItemColumnHeaderItems: 30085,	; VT_UNKNOWN | VT_ARRAY (empty array)
        ToggleToggleState: 30086,	; VT_I4 (ToggleState_Indeterminate)
        TransformCanMove: 30087,	; VT_BOOL (FALSE)
        TransformCanResize: 30088,	; VT_BOOL (FALSE)
        TransformCanRotate: 30089,	; VT_BOOL (FALSE)
        IsLegacyIAccessiblePatternAvailable: 30090,	; VT_BOOL
        LegacyIAccessibleChildId: 30091,	; VT_I4 (0)
        LegacyIAccessibleName: 30092,	; VT_BSTR (empty string)
        LegacyIAccessibleValue: 30093,	; VT_BSTR (empty string)
        LegacyIAccessibleDescription: 30094,	; VT_BSTR (empty string)
        LegacyIAccessibleRole: 30095,	; VT_I4 (0)
        LegacyIAccessibleState: 30096,	; VT_I4 (0)
        LegacyIAccessibleHelp: 30097,	; VT_BSTR (empty string)
        LegacyIAccessibleKeyboardShortcut: 30098,	; VT_BSTR (empty string)
        LegacyIAccessibleSelection: 30099,	; VT_UNKNOWN | VT_ARRAY (empty array)
        LegacyIAccessibleDefaultAction: 30100,	; VT_BSTR (empty string)
        AriaRole: 30101,	; VT_BSTR (empty string)
        AriaProperties: 30102,	; VT_BSTR (empty string)
        IsDataValidForForm: 30103,	; VT_BOOL (FALSE)
        ControllerFor: 30104,	; VT_UNKNOWN | VT_ARRAY (empty array)
        DescribedBy: 30105,	; VT_UNKNOWN | VT_ARRAY (empty array)
        FlowsTo: 30106,	; VT_UNKNOWN | VT_ARRAY (empty array)
        ProviderDescription: 30107,	; VT_BSTR (empty string)
        IsItemContainerPatternAvailable: 30108,	; VT_BOOL
        IsVirtualizedItemPatternAvailable: 30109,	; VT_BOOL
        IsSynchronizedInputPatternAvailable: 30110,	; VT_BOOL
        OptimizeForVisualContent: 30111,	; VT_BOOL (FALSE)
        IsObjectModelPatternAvailable: 30112,	; VT_BOOL
        AnnotationAnnotationTypeId: 30113,	; VT_I4 (0)
        AnnotationAnnotationTypeName: 30114,	; VT_BSTR (empty string)
        AnnotationAuthor: 30115,	; VT_BSTR (empty string)
        AnnotationDateTime: 30116,	; VT_BSTR (empty string)
        AnnotationTarget: 30117,	; VT_UNKNOWN (NULL)
        IsAnnotationPatternAvailable: 30118,	; VT_BOOL
        IsTextPattern2Available: 30119,	; VT_BOOL
        StylesStyleId: 30120,	; VT_I4 (0)
        StylesStyleName: 30121,	; VT_BSTR (empty string)
        StylesFillColor: 30122,	; VT_I4 (0)
        StylesFillPatternStyle: 30123,	; VT_BSTR (empty string)
        StylesShape: 30124,	; VT_BSTR (empty string)
        StylesFillPatternColor: 30125,	; VT_I4 (0)
        StylesExtendedProperties: 30126,	; VT_BSTR (empty string)
        IsStylesPatternAvailable: 30127,	; VT_BOOL
        IsSpreadsheetPatternAvailable: 30128,	; VT_BOOL
        SpreadsheetItemFormula: 30129,	; VT_BSTR (empty string)
        SpreadsheetItemAnnotationObjects: 30130,	; VT_UNKNOWN | VT_ARRAY (empty array)
        SpreadsheetItemAnnotationTypes: 30131,	; VT_I4 | VT_ARRAY (empty array)
        IsSpreadsheetItemPatternAvailable: 30132,	; VT_BOOL
        Transform2CanZoom: 30133,	; VT_BOOL (FALSE)
        IsTransformPattern2Available: 30134,	; VT_BOOL
        LiveSetting: 30135,	; VT_I4 (0)
        IsTextChildPatternAvailable: 30136,	; VT_BOOL
        IsDragPatternAvailable: 30137,	; VT_BOOL
        DragIsGrabbed: 30138,	; VT_BOOL (FALSE)
        DragDropEffect: 30139,	; VT_BSTR (empty string)
        DragDropEffects: 30140,	; VT_BSTR | VT_ARRAY (empty array)
        IsDropTargetPatternAvailable: 30141,	; VT_BOOL
        DropTargetDropTargetEffect: 30142,	; VT_BSTR (empty string)
        DropTargetDropTargetEffects: 30143,	; VT_BSTR | VT_ARRAY (empty array)
        DragGrabbedItems: 30144,	; VT_UNKNOWN | VT_ARRAY (empty array)
        Transform2ZoomLevel: 30145,	; VT_R8 (1)
        Transform2ZoomMinimum: 30146,	; VT_R8 (1)
        Transform2ZoomMaximum: 30147,	; VT_R8 (1)
        FlowsFrom: 30148,	; VT_UNKNOWN | VT_ARRAY (empty array)
        IsTextEditPatternAvailable: 30149,	; VT_BOOL
        IsPeripheral: 30150,	; VT_BOOL (FALSE)
        IsCustomNavigationPatternAvailable: 30151,	; VT_BOOL
        PositionInSet: 30152,	; VT_I4 (0)
        SizeOfSet: 30153,	; VT_I4 (0)
        Level: 30154,	; VT_I4 (0)
        AnnotationTypes: 30155,	; VT_I4 | VT_ARRAY (empty array)
        AnnotationObjects: 30156,	; VT_I4 | VT_ARRAY (empty array)
        LandmarkType: 30157,	; VT_I4 (0)
        LocalizedLandmarkType: 30158,	; VT_BSTR (empty string)
        FullDescription: 30159,	; VT_BSTR (empty string)
        FillColor: 30160,	; VT_I4 (0)
        OutlineColor: 30161,	; VT_I4 | VT_ARRAY (0)
        FillType: 30162,	; VT_I4 (0)
        VisualEffects: 30163,	; VT_I4 (0) VisualEffects_Shadow: 0x1 VisualEffects_Reflection: 0x2 VisualEffects_Glow: 0x4 VisualEffects_SoftEdges: 0x8 VisualEffects_Bevel: 0x10
        OutlineThickness: 30164,	; VT_R8 | VT_ARRAY (VT_EMPTY)
        CenterPoint: 30165,	; VT_R8 | VT_ARRAY (VT_EMPTY)
        Rotation: 30166,	; VT_R8 (0)
        Size: 30167,	; VT_R8 | VT_ARRAY (VT_EMPTY)
        HeadingLevel: 30173,	; VT_I4 (HeadingLevel_None)
        IsDialog: 30174	; VT_BOOL (FALSE)
    }
    static PropertyConditionFlags := {
        None: 0,
        IgnoreCase: 1,
        MatchSubstring: 2
    }
    static TextAttribute := {
        AnimationStyle: 40000,	; VT_I4 (AnimationStyle_None)
        BackgroundColor: 40001,	; VT_I4 (0)
        BulletStyle: 40002,	; VT_I4 (BulletStyle_None)
        CapStyle: 40003,	; VT_I4 (CapStyle_None)
        Culture: 40004,	; VT_I4 (locale of the application UI)
        FontName: 40005,	; VT_BSTR (empty string)
        FontSize: 40006,	; VT_R8 (0)
        FontWeight: 40007,	; VT_I4 (0)
        ForegroundColor: 40008,	; VT_I4 (0)
        HorizontalTextAlignment: 40009,	; VT_I4 (HorizontalTextAlignment_Left)
        IndentationFirstLine: 40010,	; VT_R8 (0)
        IndentationLeading: 40011,	; VT_R8 (0)
        IndentationTrailing: 40012,	; VT_R8 (0)
        IsHidden: 40013,	; VT_BOOL (FALSE)
        IsItalic: 40014,	; VT_BOOL (FALSE)
        IsReadOnly: 40015,	; VT_BOOL (FALSE)
        IsSubscript: 40016,	; VT_BOOL (FALSE)
        IsSuperscript: 40017,	; VT_BOOL (FALSE)
        MarginBottom: 40018,	; VT_R8 (0)
        MarginLeading: 40019,	; VT_R8 (0)
        MarginTop: 40020,	; VT_R8
        MarginTrailing: 40021,	; VT_R8 (0)
        OutlineStyles: 40022,	; VT_I4 (OutlineStyles_None)
        OverlineColor: 40023,	; VT_I4 (0)
        OverlineStyle: 40024,	; VT_I4 (TextDecorationLineStyle_None)
        StrikethroughColor: 40025,	; VT_I4 (0)
        StrikethroughStyle: 40026,	; VT_I4 (TextDecorationLineStyle_None)
        Tabs: 40027,	; VT_ARRAY	VT_R8 (empty array)
        TextFlowDirections: 40028,	; VT_I4 (FlowDirections_Default)
        UnderlineColor: 40029,	; VT_I4 (0)
        UnderlineStyle: 40030,	; VT_I4 (TextDecorationLineStyle_None)
        AnnotationTypes: 40031,	; VT_ARRAY	VT_I4 (empty array)
        AnnotationObjects: 40032,	; VT_UNKNOWN (empty array)
        StyleName: 40033,	; VT_BSTR (empty string)
        StyleId: 40034,	; VT_I4 (0)
        Link: 40035,	; VT_UNKNOWN (NULL)
        IsActive: 40036,	; VT_BOOL (FALSE)
        SelectionActiveEnd: 40037,	; VT_I4 (ActiveEnd_None)
        CaretPosition: 40038,	; VT_I4 (CaretPosition_Unknown)
        CaretBidiMode: 40039,	; VT_I4 (CaretBidiMode_LTR)
        LineSpacing: 40040,	; VT_BSTR ("LineSpacingAttributeDefault")
        BeforeParagraphSpacing: 40041,	; VT_R8 (0)
        AfterParagraphSpacing: 40042,	; VT_R8 (0)
    }
    static TreeScope := {
        None: 0,
        Element: 1,
        Children: 2,
        Descendants: 4,
        Subtree: 7,
        Parent: 8,
        Ancestors: 16
    }

    static CaretGetPosEx(&x, &y) {
        res := CaretGetPos(&x, &y)
        if (res) {
            return res
        } else {
            if (this.GetFocusedElement().CurrentControlType == 50004) ;Edit
                return true
        }
    }

    ;arrFind 为 FindElement 所有参数
    static FindAndSetChecked(hwnd, arrFind, bChecked, method:="") {
        if (el := this.FindElement(hwnd, arrFind*)) {
            el.SetChecked(bChecked)
            return el
        }
    }

    ;简易场景：由 hwnd 获取的 elWin 仅查找一次
    ;如果 elWin 要进行多次查找的，则用 elWin.FindControl
    ;为了区分名称，所以用了 FindElement
    ;TODO 为了 ControlClick，增加了dllcall 添加 hwnd
    static FindElement(hwnd, ControlType, value:="", field:="Name", msWait:=0) { ; <2021-02-10 14:29:46> By hyaray
        if (!dllcall("GetParent", "UInt",hwnd)) {
            bIsWindow := true
        } else {
            hwnd1 := hwnd
            arr := [hwnd1]
            loop 3
                arr.push(getWinIndex(hwnd1))
            for v in arr
                arr[A_Index] := [getWinInfo("ahk_id " . v)]
            ;msgbox(json.stringify(arr, 4))
            if (1)
                bIsWindow := true
        }
        return this.ElementFromHandle(hwnd, bIsWindow).FindControl(ControlType, value, field, msWait)
        getWinIndex(id) {
            loop {
                id := dllcall("GetWindow", "uint",id, "int",2) ;1=上级窗口，比如谷歌翻译后，有个小弹框
                if (dllcall("IsWindowVisible", "uint",id) == 1)
                    break
            }
            return id
        }
        ;获取窗口的常见信息
        getWinInfo(winTitle:="") {
            obj := map()
            idA := WinExist(winTitle)
            WinGetPos(&winX, &winY, &width, &height)
            obj["winX"] := winX
            obj["winY"] := winY
            obj["winExe"] := WinGetProcessName()
            obj["winExeClean"] := StrReplace(RegExReplace(obj["winExe"], "i)_?(x?(64))?(\.\w+)?$"), A_Space, "_")
            obj["winID"] := idA
            obj["winPID"] := WinGetPID()
            obj["winIsVisible"] := dllcall("IsWindowVisible", "uint",idA)
            obj["winStyle"] := format("0x{:X}", WinGetStyle() & 0xFFFFFFFF)
            ;obj["winExStyle"] := WinGetExStyle()
            obj["winTitle"] := StrReplace(WinGetTitle(), " - Cent Browser")
            ;obj["winText"] := WinGetText()
            obj["winClass"] := WinGetClass()
            obj["winPath"] := RegExReplace(WinGetProcessPath(), "^\w", "$L0")
            try
                obj["winCtl"] := ControlGetClassNN(ControlGetFocus())
            if (width) {
                obj["width"] := width
                obj["height"] := height
            }
            return obj
        }
    }

    /**
    * Create Property Condition from AHK Object
    * @param obj Object or Map or Array contains multiple Property Conditions. default operator (Object, Map): `and`, default operator (Array): `or`, default flags: 0
    * #### example
    * `[{ControlType: 50000, Name: "edit"}, {ControlType: 50004, Name: "edit", flags: 3}]` is same as `{0:{ControlType: 50000, Name: "edit"}, 1:{ControlType: 50004, Name: "edit", flags: 3}, operator: "or"}`
    * 
    * {0: {ControlType: 50004, Name: "edit"}, operator: "not"}
    * @returns IUIAutomationCondition
    */
    static PropertyCondition(obj) {
        return conditionbuilder(obj)
        conditionbuilder(obj) {
            switch Type(obj) {
                case "Object":
                    operator := obj.DeleteProp("operator") || "and"
                    flags := obj.DeleteProp("flags") || 0
                    count := ObjOwnPropCount(obj), obj := obj.OwnProps()
                case "Array":
                    operator := "or", flags := 0, count := obj.length
                case "Map":
                    operator := obj.Delete("operator") || "and"
                    flags := obj.Delete("flags") || 0
                    count := obj.count
                default:
                    throw TypeError("Invalid parameter type", -3)
            }
            arr := ComObjArray(0xd, count), i := 0
            for k, v in obj {
                if !(k is integer)
                    k := this.Property.%k%
                if (k >= 30000) {
                    if (k == 30003 && v is string)
                        v := this.ControlType.%v%
                    t := flags ? this.CreatePropertyConditionEx(k, v, flags) : this.CreatePropertyCondition(k, v)
                    arr[i++] := t[]
                } else
                    t := conditionbuilder(v), arr[i++] := t[]
            }
            if (count == 1) {
                if (operator = "not")
                    return this.CreateNotCondition(t)
                return t
            } else {
                switch operator, false {
                    case "and":
                        return this.CreateAndConditionFromArray(arr)
                    case "or":
                        return this.CreateOrConditionFromArray(arr)
                    default:
                        return this.CreateFalseCondition()
                }
            }
        }
    }

    ; Compares two UI Automation elements to determine whether they represent the same underlying UI element.
    static CompareElements(el1, el2) => (comcall(3, this, "ptr",el1, "ptr",el2, "int*",&areSame:=0), areSame)

    ; Compares two integer arrays containing run-time identifiers (IDs) to determine whether their content is the same and they belong to the same UI element.
    static CompareRuntimeIds(runtimeId1, runtimeId2) => (comcall(4, this, "ptr",runtimeId1, "ptr",runtimeId2, "int*",&areSame:=0), areSame)

    ; Retrieves the UI Automation element that represents the desktop.
    static GetRootElement() => (comcall(5, this, "ptr*",&root:=0), IUIAutomationElement(root))

    ; Retrieves a UI Automation element for the specified window.
    static ElementFromHandle(hwnd, asWin:=false) {
        comcall(6, this, "ptr",hwnd, "ptr*",&element:=0)
        ;TODO 暂时记录 hwnd(不能是控件) 给 ClickByControl 用
        if (asWin)
            this.hwnd := hwnd
        return IUIAutomationElement(element)
    }

    ; Retrieves the UI Automation element at the specified point on the desktop.
    ;如果有多个控件嵌套，用改进版的 ElementFromPointEx
    ;cm 0=window 1=screen
    static ElementFromPoint(xScreen:=unset, yScreen:=unset, cm:=0) {
        if (!isset(xScreen) || !isset(yScreen)) {
            cmMouse := A_CoordModeMouse
            CoordMode("mouse", "screen")
            MouseGetPos(&xScreen, &yScreen)
            CoordMode("mouse", cmMouse)
        } else if (cm == 0) {
            WinGetPos(&x, &y,,, "A")
            xScreen += x
            yScreen += y
        }
        comcall(7, this, "int64",xScreen|yScreen<<32, "ptr*",&element:=0)
        return IUIAutomationElement(element)
    }

    /*
    static SmallestElementFromPoint(x="", y="", activateChromiumAccessibility=False, windowEl="") {
        if (isobject(windowEl)) {
            element := this.ElementFromPoint(x, y, activateChromiumAccessibility)
            bound := element.CurrentBoundingRectangle
            elementSize := (bound.r-bound.l)*(bound.b-bound.t)
            prevElementSize := 0
            stack := [windowEl]
            loop {
                bound := stack[1].CurrentBoundingRectangle
                if ((x >= bound.l) && (x <= bound.r) && (y >= bound.t) && (y <= bound.b)) { ; If parent is not in bounds, then children arent either
                    if ((newSize := (bound.r-bound.l)*(bound.b-bound.t)) < elementSize) {
                        element := stack[1]
                        elementSize := newSize
                    }
                    for _, childEl in stack[1].FindAll(this.__UIA.TrueCondition, 0x2) {
                        bound := childEl.CurrentBoundingRectangle
                        if ((x >= bound.l) && (x <= bound.r) && (y >= bound.t) && (y <= bound.b)) {
                            stack.push(childEl)
                            if ((newSize := (bound.r-bound.l)*(bound.b-bound.t)) < elementSize)
                                elementSize := newSize, element := childEl
                        }
                    }
                }
                stack.RemoveAt(1)
            } until !stack.MaxIndex()
            return element
        } else {
            element := this.ElementFromPoint(x, y, activateChromiumAccessibility)
            bound := element.CurrentBoundingRectangle
            elementSize := (bound.r-bound.l)*(bound.b-bound.t)
            prevElementSize := 0
            for k, v in element.FindAll(this.__UIA.TrueCondition) {
                bound := v.CurrentBoundingRectangle
                if ((x >= bound.l) && (x <= bound.r) && (y >= bound.t) && (y <= bound.b) && ((newSize := (bound.r-bound.l)*(bound.b-bound.t)) < elementSize)) {
                    element := v
                    elementSize := newSize
                }
            }
            return element
        }
    }
*/

    ;ElementFromPoint 有时获取的是很大的父元素，此方法通过遍历来获取精确的子元素
    ;cm 0=window 1=screen
    ;TODO 多层结构如何处理？
    static ElementFromPointEx(xScreen:=unset, yScreen:=unset, cm:=0) {
        if (!isset(xScreen) || !isset(yScreen)) {
            cmMouse := A_CoordModeMouse
            CoordMode("mouse", "screen")
            MouseGetPos(&xScreen, &yScreen)
            CoordMode("mouse", cmMouse)
        } else if (cm == 0) {
            WinGetPos(&x, &y,,, "A")
            xScreen += x
            yScreen += y
        }
        rvw := this.RawViewWalker()
        cond := this.CreateTrueCondition()
        ;优先从 ElementFromPoint 里搜索
        elBase := this.ElementFromPoint() ;不一定在此框架内
        return findInSons(elBase)
        findInSons(elBase, mk:=0) {
            try
                rvw.GetFirstChildElement(elBase)
            catch { ;没儿子
                ;if (mk == 1)
                ;    msgbox("no son",,0x40000)
                return elBase
            } else {
                elSon := rvw.GetFirstChildElement(elBase)
                loop {
                    if (elSon.ContainXY(xScreen, yScreen, 1)) {
                        el := findInSons(elSon, 1)
                        if (el)
                            return el
                    }
                    try {
                        elSon := rvw.GetNextSiblingElement(elSon)
                    } catch {
                        if (elBase.CurrentName != "")
                            return elBase ;TODO 儿子不全，返回父亲
                        break
                    }
                }
            }
        }
    }

    ; Retrieves the UI Automation element that has the input focus.
    ;TODO Tim 里有问题
    static GetFocusedElement() => (comcall(8, this, "ptr*",&element:=0), IUIAutomationElement(element))

    ; Retrieves the UI Automation element that has the input focus, prefetches the requested properties and control patterns, and stores the prefetched items in the cache.
    static GetRootElementBuildCache(cacheRequest) => (comcall(9, this, "ptr",cacheRequest, "ptr*",&root:=0), IUIAutomationElement(root))

    ; Retrieves a UI Automation element for the specified window, prefetches the requested properties and control patterns, and stores the prefetched items in the cache.
    static ElementFromHandleBuildCache(hwnd, cacheRequest) => (comcall(10, this, "ptr",hwnd, "ptr",cacheRequest, "ptr*",&element:=0), IUIAutomationElement(element))

    ; Retrieves the UI Automation element at the specified point on the desktop, prefetches the requested properties and control patterns, and stores the prefetched items in the cache.
    static ElementFromPointBuildCache(pt, cacheRequest) => (comcall(11, this, "int64",pt, "ptr",cacheRequest, "ptr*",&element:=0), IUIAutomationElement(element))

    ; Retrieves the UI Automation element that has the input focus, prefetches the requested properties and control patterns, and stores the prefetched items in the cache.
    static GetFocusedElementBuildCache(cacheRequest) => (comcall(12, this, "ptr",cacheRequest, "ptr*",&element:=0), IUIAutomationElement(element))

    ; Retrieves a tree walker object that can be used to traverse the Microsoft UI Automation tree.
    static CreateTreeWalker(pCondition) => (comcall(13, this, "ptr",pCondition, "ptr*",&walker:=0), IUIAutomationTreeWalker(walker))

    ; Retrieves an IUIAutomationTreeWalker interface used to discover control elements.
    static ControlViewWalker() => (comcall(14, this, "ptr*",&walker:=0), IUIAutomationTreeWalker(walker))

    ; Retrieves an IUIAutomationTreeWalker interface used to discover content elements.
    static ContentViewWalker() => (comcall(15, this, "ptr*",&walker:=0), IUIAutomationTreeWalker(walker))

    ; Retrieves a tree walker object used to traverse an unfiltered view of the UI Automation tree.
    static RawViewWalker() => (comcall(16, this, "ptr*",&walker:=0), IUIAutomationTreeWalker(walker))

    ; Retrieves a predefined IUIAutomationCondition interface that selects all UI elements in an unfiltered view.
    static RawViewCondition() => (comcall(17, this, "ptr*",&condition:=0), IUIAutomationCondition(condition))

    ; Retrieves a predefined IUIAutomationCondition interface that selects control elements.
    static ControlViewCondition() => (comcall(18, this, "ptr*",&condition:=0), IUIAutomationCondition(condition))

    ; Retrieves a predefined IUIAutomationCondition interface that selects content elements.
    static ContentViewCondition() => (comcall(19, this, "ptr*",&condition:=0), IUIAutomationCondition(condition))

    ; Creates a cache request.
    ; After obtaining the IUIAutomationCacheRequest interface, use its methods to specify properties and control patterns to be cached when a UI Automation element is obtained.
    static CreateCacheRequest() => (comcall(20, this, "ptr*",&cacheRequest:=0), IUIAutomationCacheRequest(cacheRequest))

    ; Retrieves a predefined condition that selects all elements.
    static CreateTrueCondition() => (comcall(21, this, "ptr*",&newCondition:=0), IUIAutomationBoolCondition(newCondition))

    ; Creates a condition that is always false.
    ; This method exists only for symmetry with IUIAutomation,,CreateTrueCondition. A false condition will never enable a match with UI Automation elements, and it cannot usefully be combined with any other condition.
    static CreateFalseCondition() => (comcall(22, this, "ptr*",&newCondition:=0), IUIAutomationBoolCondition(newCondition))

    ; Creates a condition that selects elements that have a property with the specified value.
    ; NOTE 是boolean，value要用 ComValue(0xB,-1)
    static CreatePropertyCondition(propertyId, value) {
        if !(propertyId is integer)
            propertyId := this.property.%propertyId%
        if (propertyId == 30003 && value is String)
            value := this.ControlType.%value%
        if (A_PtrSize == 4) {
            v := ComVar(value,, true)
            comcall(23, this, "int",propertyId, "int64",numget(v,0,"int64"), "int64",numget(v,8,"int64"), "ptr*",&newCondition:=0)
        } else
            comcall(23, this, "int",propertyId, "ptr",ComVar(value,, true), "ptr*",&newCondition:=0)
        return IUIAutomationPropertyCondition(newCondition)
    }

    ; Creates a condition that selects elements that have a property with the specified value, using optional flags.
    static CreatePropertyConditionEx(propertyId, value, flags:=2) {
        if !(propertyId is integer)
            propertyId := this.property.%propertyId%
        if (propertyId == 30003 && value is String)
            value := this.ControlType.%value%
        if (A_PtrSize == 4) {
            v := ComVar(value)
            comcall(24, this, "int",propertyId, "int64",numget(v,0,"int64"), "int64",numget(v,8,"int64"), "int",flags, "ptr*",&newCondition:=0)
        } else
            comcall(24, this, "int",propertyId, "ptr",ComVar(value,,true), "int",flags, "ptr*",&newCondition:=0)
        return IUIAutomationPropertyCondition(newCondition)
    }

    ; The Create**Condition** method calls AddRef on each pointers. This means you can call Release on those pointers after the call to Create**Condition** returns without invalidating the pointer returned from Create**Condition**. When you call Release on the pointer returned from Create**Condition**, UI Automation calls Release on those pointers.

    ; Creates a condition that selects elements that match both of two conditions.
    static CreateAndCondition(condition1, condition2) => (comcall(25, this, "ptr",condition1, "ptr",condition2, "ptr*",&newCondition:=0), IUIAutomationAndCondition(newCondition))

    ; Creates a condition that selects elements based on multiple conditions, all of which must be true.
    static CreateAndConditionFromArray(conditions) => (comcall(26, this, "ptr",conditions, "ptr*",&newCondition:=0), IUIAutomationAndCondition(newCondition))

    ; Creates a condition that selects elements based on multiple conditions, all of which must be true.
    static CreateAndConditionFromNativeArray(conditions, conditionCount) => (comcall(27, this, "ptr",conditions, "int",conditionCount, "ptr*",&newCondition:=0), IUIAutomationAndCondition(newCondition))

    ; Creates a combination of two conditions where a match exists if either of the conditions is true.
    static CreateOrCondition(condition1, condition2) => (comcall(28, this, "ptr",condition1, "ptr",condition2, "ptr*",&newCondition:=0), IUIAutomationOrCondition(newCondition))

    ; Creates a combination of two or more conditions where a match exists if any of the conditions is true.
    static CreateOrConditionFromArray(conditions) => (comcall(29, this, "ptr",conditions, "ptr*",&newCondition:=0), IUIAutomationOrCondition(newCondition))

    ; Creates a combination of two or more conditions where a match exists if any one of the conditions is true.
    static CreateOrConditionFromNativeArray(conditions, conditionCount) => (comcall(30, this, "ptr",conditions, "ptr",conditionCount, "ptr*",&newCondition:=0), IUIAutomationOrCondition(newCondition))

    ; Creates a condition that is the negative of a specified condition.
    static CreateNotCondition(condition) => (comcall(31, this, "ptr",condition, "ptr*",&newCondition:=0), IUIAutomationNotCondition(newCondition))

    ; Note,  Before implementing an event handler, you should be familiar with the threading issues described in Understanding Threading Issues. http,//msdn.microsoft.com/en-us/library/ee671692(v=vs.85).aspx
    ; A UI Automation client should not use multiple threads to add or remove event handlers. Unexpected behavior can result if one event handler is being added or removed while another is being added or removed in the same client process.
    ; It is possible for an event to be delivered to an event handler after the handler has been unsubscribed, if the event is received simultaneously with the request to unsubscribe the event. The best practice is to follow the Component Object Model (COM) standard and avoid destroying the event handler object until its reference count has reached zero. Destroying an event handler immediately after unsubscribing for events may result in an access violation if an event is delivered late.

    ; Registers a method that handles Microsoft UI Automation events.
    static AddAutomationEventHandler(eventId, element, scope, cacheRequest, handler) => comcall(32, this, "int",eventId, "ptr",element, "int",scope, "ptr",cacheRequest ? cacheRequest : 0, "ptr",handler)

    ; Removes the specified UI Automation event handler.
    static RemoveAutomationEventHandler(eventId, element, handler) => comcall(33, this, "int",eventId, "ptr",element, "ptr",handler)

    ; Registers a method that handles property-changed events.
    ; The UI item specified by element might not support the properties specified by the propertyArray parameter.
    ; This method serves the same purpose as IUIAutomation,,AddPropertyChangedEventHandler, but takes a normal array of property identifiers instead of a SAFEARRAY.
    static AddPropertyChangedEventHandlerNativeArray(element, scope, cacheRequest, handler, propertyArray, propertyCount) => comcall(34, this, "ptr",element, "int",scope, "ptr",cacheRequest, "ptr",handler, "ptr",propertyArray, "int",propertyCount)

    ; Registers a method that handles property-changed events.
    ; The UI item specified by element might not support the properties specified by the propertyArray parameter.
    static AddPropertyChangedEventHandler(element, scope, cacheRequest, handler, propertyArray) => comcall(35, this, "ptr",element, "int",scope, "ptr",cacheRequest, "ptr",handler, "ptr",propertyArray)

    ; Removes a property-changed event handler.
    static RemovePropertyChangedEventHandler(element, handler) => comcall(36, this, "ptr",element, "ptr",handler)

    ; Registers a method that handles structure-changed events.
    static AddStructureChangedEventHandler(element, scope, cacheRequest, handler) => comcall(37, this, "ptr",element, "int",scope, "ptr",cacheRequest ? cacheRequest : 0, "ptr",handler)

    ; Removes a structure-changed event handler.
    static RemoveStructureChangedEventHandler(element, handler) => comcall(38, this, "ptr",element, "ptr",handler)

    ; Registers a method that handles focus-changed events.
    ; Focus-changed events are system-wide; you cannot set a narrower scope.
    static AddFocusChangedEventHandler(cacheRequest, handler) => comcall(39, this, "ptr",cacheRequest ? cacheRequest : 0, "ptr",handler)

    ; Removes a focus-changed event handler.
    static RemoveFocusChangedEventHandler(handler) => comcall(40, this, "ptr",handler)

    ; Removes all registered Microsoft UI Automation event handlers.
    static RemoveAllEventHandlers() => comcall(41, this)

    ; Converts an array of integers to a SAFEARRAY.
    static IntNativeArrayToSafeArray(array, arrayCount) => (comcall(42, this, "ptr",array, "int",arrayCount, "ptr*",&safeArray:=0), ComValue(0x2003, safeArray))

    ; Converts a SAFEARRAY of integers to an array.
    static IntSafeArrayToNativeArray(intArray) => (comcall(43, this, "ptr",intArray, "ptr*",&array:=0, "int*",&arrayCount:=0), NativeArray(array, arrayCount, "int"))

    ; Creates a VARIANT that contains the coordinates of a rectangle.
    ; The returned VARIANT has a data type of VT_ARRAY | VT_R8.
    static RectToVariant(rc) => (comcall(44, this, "ptr",rc, "ptr",var:=ComVar()), var)

    ; Converts a VARIANT containing rectangle coordinates to a RECT.
    static VariantToRect(var) {
        if (A_PtrSize == 4)
            comcall(45, this, "int64",numget(var,0,"int64"), "int64",numget(var,8,"int64"), "ptr",rc := NativeArray(0, 4, "Int"))
        else
            comcall(45, this, "ptr",var, "ptr",rc := NativeArray(0, 4, "Int"))
        return rc
    }

    ; Converts a SAFEARRAY containing rectangle coordinates to an array of type RECT.
    static SafeArrayToRectNativeArray(rects) => (comcall(46, this, "ptr",rects, "ptr*",&rectArray:=0, "int*",&rectArrayCount:=0), NativeArray(rectArray, rectArrayCount, "int"))

    ; Creates a instance of a proxy factory object.
    ; Use the IUIAutomationProxyFactoryMapping interface to enter the proxy factory into the table of available proxies.
    static CreateProxyFactoryEntry(factory) => (comcall(47, this, "ptr",factory, "ptr*",&factoryEntry:=0), IUIAutomationProxyFactoryEntry(factoryEntry))

    ; Retrieves an object that represents the mapping of Window classnames and associated data to individual proxy factories. This property is read-only.
    static ProxyFactoryMapping() => (comcall(48, this, "ptr*",&factoryMapping:=0), IUIAutomationProxyFactoryMapping(factoryMapping))

    ; The programmatic name is intended for debugging and diagnostic purposes only. The string is not localized.
    ; This property should not be used in string comparisons. To determine whether two properties are the same, compare the property identifiers directly.

    ; Retrieves the registered programmatic name of a property.
    static GetPropertyProgrammaticName(property) => (comcall(49, this, "int",property, "ptr*",&name:=0), BSTR(name))

    ; Retrieves the registered programmatic name of a control pattern.
    static GetPatternProgrammaticName(pattern) => (comcall(50, this, "int",pattern, "ptr*",&name:=0), BSTR(name))

    ; This method is intended only for use by Microsoft UI Automation tools that need to scan for properties. It is not intended to be used by UI Automation clients.
    ; There is no guarantee that the element will support any particular control pattern when asked for it later.

    ; Retrieves the control patterns that might be supported on a UI Automation element.
    static PollForPotentialSupportedPatterns(pElement, &patternIds, &patternNames) {
        comcall(51, this, "ptr",pElement, "ptr*",&patternIds:=0, "ptr*",&patternNames:=0)
        patternIds := ComValue(0x2003, patternIds), patternNames := ComValue(0x2008, patternNames)
    }

    ; Retrieves the properties that might be supported on a UI Automation element.
    static PollForPotentialSupportedProperties(pElement, &propertyIds, &propertyNames) {
        comcall(52, this, "ptr",pElement, "ptr*",&propertyIds:=0, "ptr*",&propertyNames:=0)
        propertyIds := ComValue(0x2003, propertyIds), propertyNames := ComValue(0x2008, propertyNames)
    }

    ; Checks a provided VARIANT to see if it contains the Not Supported identifier.
    ; After retrieving a property for a UI Automation element, call this method to determine whether the element supports the retrieved property. CheckNotSupported is typically called after calling a property retrieving method such as GetCurrentPropertyValue.
    static CheckNotSupported(value) {
        if (A_PtrSize == 4)
            value := ComVar(value,,true), comcall(53, this, "int64",numget(value,0,"int64"), "int64",numget(value,8,"int64"), "int*",&isNotSupported:=0)
        else
            comcall(53, this, "ptr",ComVar(value,,true), "int*",&isNotSupported:=0)
        return isNotSupported
    }

    ; Retrieves a static token object representing a property or text attribute that is not supported. This property is read-only.
    ; This object can be used for comparison with the results from IUIAutomationElement,,GetCurrentPropertyValue or IUIAutomationTextRange,,GetAttributeValue.
    static ReservedNotSupportedValue() => (comcall(54, this, "ptr*",&notSupportedValue:=0), ComValue(0xd, notSupportedValue))

    ; Retrieves a static token object representing a text attribute that is a mixed attribute. This property is read-only.
    ; The object retrieved by IUIAutomation,,ReservedMixedAttributeValue can be used for comparison with the results from IUIAutomationTextRange,,GetAttributeValue to determine if a text range contains more than one value for a particular text attribute.
    static ReservedMixedAttributeValue() => (comcall(55, this, "ptr*",&mixedAttributeValue:=0), ComValue(0xd, mixedAttributeValue))

    ; This method enables UI Automation clients to get IUIAutomationElement interfaces for accessible objects implemented by a Microsoft Active Accessiblity server.
    ; This method may fail if the server implements UI Automation provider interfaces alongside Microsoft Active Accessibility support.
    ; The method returns E_INVALIDARG if the underlying implementation of the Microsoft UI Automation element is not a native Microsoft Active Accessibility server; that is, if a client attempts to retrieve the IAccessible interface for an element originally supported by a proxy object from Oleacc.dll, or by the UIA-to-MSAA Bridge.

    ; Retrieves a UI Automation element for the specified accessible object from a Microsoft Active Accessibility server.
    static ElementFromIAccessible(accessible, childId) => (comcall(56, this, "ptr",accessible, "int",childId, "ptr*",&element:=0), IUIAutomationElement(element))

    ; Retrieves a UI Automation element for the specified accessible object from a Microsoft Active Accessibility server, prefetches the requested properties and control patterns, and stores the prefetched items in the cache.
    static ElementFromIAccessibleBuildCache(accessible, childId, cacheRequest) => (comcall(57, this, "ptr",accessible, "int",childId, "ptr",cacheRequest, "ptr*",&element:=0), IUIAutomationElement(element))
}

class IUIAutomationAndCondition extends IUIAutomationCondition {
    ChildCount => (comcall(3, this, "int*",&childCount:=0), childCount)
    GetChildrenAsNativeArray() => (comcall(4, this, "ptr*",&childArray:=0, "int*",&childArrayCount:=0), NativeArray(childArray, childArrayCount))
    GetChildren() => (comcall(5, this, "ptr*",&childArray:=0), ComValue(0x200d, childArray))
}

class IUIAutomationAnnotationPattern extends IUIABase {
    CurrentAnnotationTypeId => (comcall(3, this, "int*",&retVal:=0), retVal)
    CurrentAnnotationTypeName => (comcall(4, this, "ptr*",&retVal:=0), BSTR(retVal))
    CurrentAuthor => (comcall(5, this, "ptr*",&retVal:=0), BSTR(retVal))
    CurrentDateTime => (comcall(6, this, "ptr*",&retVal:=0), BSTR(retVal))
    CurrentTarget => (comcall(7, this, "ptr*",&retVal:=0), IUIAutomationElement(retVal))
    CachedAnnotationTypeId => (comcall(8, this, "int*",&retVal:=0), retVal)
    CachedAnnotationTypeName => (comcall(9, this, "ptr*",&retVal:=0), BSTR(retVal))
    CachedAuthor => (comcall(10, this, "ptr*",&retVal:=0), BSTR(retVal))
    CachedDateTime => (comcall(11, this, "ptr*",&retVal:=0), BSTR(retVal))
    CachedTarget => (comcall(11, this, "ptr*",&retVal:=0), IUIAutomationElement(retVal))
}

class IUIAutomationBoolCondition extends IUIAutomationCondition {
    Value => (comcall(3, this, "int*",&boolVal:=0), boolVal)
}

class IUIAutomationCacheRequest extends IUIABase {
    ; Adds a property to the cache request.
    AddProperty(propertyId) {
        if (type(propertyId) == "Array") {
            for pid in propertyId
                comcall(3, this, "int",pid)
        } else {
            if !(propertyId is integer)
                propertyId := UIA.property.%propertyId%
            comcall(3, this, "int",propertyId)
        }
    }

    ; Adds a control pattern to the cache request. Adding a control pattern that is already in the cache request has no effect.
    AddPattern(patternId) => comcall(4, this, "int",patternId)

    ; Creates a copy of the cache request.
    Clone() => (comcall(5, this, "ptr*",&clonedRequest:=0), IUIAutomationCacheRequest(clonedRequest))

    TreeScope {
        get => (comcall(6, this, "int*",&scope:=0), scope)
        set => comcall(7, this, "int",Value)
    }

    TreeFilter {
        get => (comcall(8, this, "ptr*",&filter:=0), IUIAutomationCondition(filter))
        set => comcall(9, this, "ptr",Value)
    }

    AutomationElementMode {
        get => (comcall(10, this, "int*",&mode:=0), mode)
        set => comcall(11, this, "int",Value)
    }
}

class IUIAutomationCondition extends IUIABase {
}

class IUIAutomationCustomNavigationPattern extends IUIABase {
    Navigate(direction) => (comcall(3, this, "int",direction, "ptr*",&pRetVal:=0), IUIAutomationElement(pRetVal))
}

class IUIAutomationDockPattern extends IUIABase {
    ; Sets the dock position of this element.
    SetDockPosition(dockPos) => comcall(3, this, "int",dockPos)

    ; Retrieves the `dock position` of this element within its docking container.
    CurrentDockPosition => (comcall(4, this, "int*",&retVal:=0), retVal)

    ; Retrieves the `cached dock` position of this element within its docking container.
    CachedDockPosition => (comcall(5, this, "int*",&retVal:=0), retVal)
}

class IUIAutomationDragPattern extends IUIABase {
    CurrentIsGrabbed => (comcall(3, this, "int*",&retVal:=0), retVal)
    CachedIsGrabbed => (comcall(4, this, "int*",&retVal:=0), retVal)
    CurrentDropEffect => (comcall(5, this, "ptr*",&retVal:=0), BSTR(retVal))
    CachedDropEffect => (comcall(6, this, "ptr*",&retVal:=0), BSTR(retVal))
    CurrentDropEffects => (comcall(7, this, "ptr*",&retVal:=0), ComValue(0x2008, retVal))
    CachedDropEffects => (comcall(8, this, "ptr*",&retVal:=0), ComValue(0x2008, retVal))
    GetCurrentGrabbedItems() => (comcall(9, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))
    GetCachedGrabbedItems() => (comcall(10, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))
}

class IUIAutomationDropTargetPattern extends IUIABase {
    CurrentDropTargetEffect => (comcall(3, this, "ptr*",&retVal:=0), BSTR(retVal))
    CachedDropTargetEffect => (comcall(4, this, "ptr*",&retVal:=0), BSTR(retVal))
    CurrentDropTargetEffects => (comcall(5, this, "ptr*",&retVal:=0), ComValue(0x2008, retVal))
    CachedDropTargetEffects => (comcall(6, this, "ptr*",&retVal:=0), ComValue(0x2008, retVal))
}

;TODO 判断两个元素相同 UIA.CompareElements(el0, el1)
class IUIAutomationElement extends IUIABase {
    /**
    * Find or wait target control element.
    * @param ControlType target control type, such as 'button' or UIA.ControlType.Button
    * @param value The property value. boolean should use ComValue(0xB,-1)
    * @param propertyId The property identifier. `Name`(default)
    * @param waittime Waiting time for control element to appear.
    this 生成后出现的元素，用此方法也能获取，说明 this 是动态的
    */
    FindControl(ControlType, value, field:="Name", msWait:=0) {
        if !(ControlType is integer) {
            if (ControlType == "") { ;NOTE 非 Control 比如obsidian的【警报】
                cond := UIA.CreatePropertyCondition(UIA.property.%field%, value)
            } else {
                ControlType := UIA.ControlType.%ControlType%
                cond := UIA.CreateAndCondition(UIA.CreatePropertyCondition(30003,ControlType), UIA.CreatePropertyCondition(UIA.property.%field%, value))
            }
        }
        endtime := A_TickCount + msWait
        loop {
            if (el := this.FindFirst(cond))
                return el
            else if (A_TickCount > endtime)
                return
        }
    }
    ;【包含】 ControlType 并【包含】 value 的控件(非精确查找)
    FindControlEx(ControlType, value, field:="Name", msWait:=0) {
        if !(ControlType is integer)
            ControlType := UIA.ControlType.%ControlType%
        cond := UIA.CreateAndCondition(UIA.CreatePropertyCondition(30003,ControlType), UIA.CreatePropertyConditionEx("Name",value))
        endtime := A_TickCount + msWait
        loop {
            if (el := this.FindFirst(cond))
                return el
            else if (A_TickCount > endtime)
                return
        }
    }
    ;由于直接 Invoke|DoDefaultAction|Toggle 会无效，故增加了以下两个点击方式
    ;并且 GetBoundingRectangle 增加了获取中间坐标的选项
    ;NOTE 如果有 xOffset，则是相对于左/或右边缘，yOffset 同理
    ;TODO 如果 ElementFromHandle 传入控件id会出错
    ClickByControl(xOffset:=0, yOffset:=0) {
        aRect := this.GetBoundingRectangle()
        if (xOffset == 0)
            x := aRect[1] + aRect[3]//2
        else if (xOffset < 0)
            x := aRect[1] + xOffset
        else if (xOffset > 0)
            x := aRect[1] + aRect[3] + xOffset
        if (yOffset == 0)
            y := aRect[2] + aRect[4]//2
        else if (yOffset < 0)
            y := aRect[2] + yOffset
        else if (yOffset > 0)
            y := aRect[2] + aRect[4] + yOffset
        ;转成 client
        WinActive("ahk_id " . UIA.hwnd)
        WinGetClientPos(&xClient, &yClient) ;this.GetFatherWindow(1))
        x -= xClient
        y -= yClient
        ControlClick(format("X{1} Y{2}", x,y))
        return [x,y]
    }
    ClickByMouse(bStay:=false, xOffset:=0, yOffset:=0, cnt:=1) { ;优先用 ClickByControl 备用 TODO Button IsInvokePatternAvailable=false
        aRect := this.GetBoundingRectangle()
        if (xOffset == 0)
            x := aRect[1] + aRect[3]//2
        else if (xOffset < 0)
            x := aRect[1] + xOffset
        else if (xOffset > 0) {
            if (xOffset < 1) ;小数
                x := aRect[1] + aRect[3] * xOffset
            else
                x := aRect[1] + aRect[3] + xOffset

        }
        if (yOffset == 0)
            y := aRect[2] + aRect[4]//2
        else if (yOffset < 0)
            y := aRect[2] + yOffset
        else
            y := aRect[2] + aRect[4] + yOffset
        cmMouse := A_CoordModeMouse
        CoordMode("mouse", "Screen")
        ;记录原位置
        MouseGetPos(&x0, &y0)
        MouseMove(x, y, 0)
        sleep(20)
        click(cnt)
        ;回到原位置
        if (!bStay)
            MouseMove(x0, y0, 0)
        CoordMode("mouse", cmMouse)
        return [x,y]
    }
    ;tp=1 则返回中心点坐标[x,y](screen)
    GetBoundingRectangle(tp:=0) {
        obj := this.CurrentBoundingRectangle
        if (tp)
            return [(obj.left+obj.right)//2, (obj.top+obj.bottom)//2]
        else ;[x,y,w,h]
            return [obj.left,obj.top,obj.right-obj.left,obj.bottom-obj.top]
    }
    GetControlType() { ;字符串的控件类型 CurrentControlType 转成字符串
        return UIA.ControlType.%this.CurrentControlType%
    }
    ;ClickByControl 需要获取所在窗口
    GetFatherWindow(bHwnd:=false) {
        vw := UIA.ControlViewWalker()
        elParent := vw.GetParentElement(this)
        loop {
            ct := elParent.CurrentControlType
            if (!elParent.CurrentNativeWindowHandle || (ct!=50032 && ct!=50033)) { ;TODO 待验证
                elParent := vw.GetParentElement(elParent)
                continue
            }
            return bHwnd ? elParent.CurrentNativeWindowHandle : elParent
        }
    }
    GetWindow(bHwnd:=false) {
        vw := UIA.ControlViewWalker()
        elParent := vw.GetParentElement(this)
        while(elParent.CurrentControlType != 50032)
            elParent := vw.GetParentElement(elParent)
        return bHwnd ? elParent.CurrentNativeWindowHandle : elParent
    }
    GetParent(tp:=0) { ;NOTE 用 tp=0 会比较好理解
        return this._ViewWalker(tp, "GetParentElement")
    }
    GetNext(tp:=0) {
        return this._ViewWalker(tp, "GetNextSiblingElement")
    }
    GetPrev(tp:=0) {
        return this._ViewWalker(tp, "GetPreviousSiblingElement")
    }
    GetFirst(tp:=0) {
        return this._ViewWalker(tp, "GetFirstChildElement")
    }
    GetLast(tp:=0) {
        return this._ViewWalker(tp, "GetLastChildElement")
    }
    ;TODO 找不到出错无法用 try，如何先判断是否有 Next
    _ViewWalker(tp, method) {
        switch tp {
        case 0: return UIA.RawViewWalker().%method%(this)
        case 1: return UIA.ControlViewWalker().%method%(this)
        case 2: return UIA.ContentViewWalker().%method%(this)
        }
    }
    GetRuntimeIdEx() { ;获取和 inspect 同格式的 RuntimeId
        arr := this.GetRuntimeId()
        res := ""
        for v in arr
            res .= format("{:X}", v) . ","
        return rtrim(res, ",")
    }
    ;arrFind 为 FindControl的所有参数
    FindAndSetChecked(arrFind, bChecked, method:="") {
        if (el := this.FindControl(arrFind*)) {
            el.SetChecked(bChecked, method)
            return el
        }
    }
    ;点击Text右侧以激活 Edit控件，并设置值
    ;arrFind 用于 FindControl 的所有参数
    FindByBeside(arrFind, arrOffset:=30, value:=unset) {
        if (type(arrFind) == "String")
            arrFind := ["Text", arrFind]
        if !isobject(arrOffset)
            arrOffset := [arrOffset]
        this.FindControl(arrFind*).ClickByControl(arrOffset*)
        sleep(100)
        elFocus := UIA.GetFocusedElement()
        if (isset(value)) {
            if (isobject(value)) ;函数
                elFocus.GetCurrentPattern("Value").SetValue(value(elFocus))
            else
                elFocus.GetCurrentPattern("Value").SetValue(value)
        }
        return elFocus
    }
    ComboboxSelectListItem(name) {
        this.ClickByControl()
        sleep(100)
        elListItem := this.FindControl("ListItem", name)
        if (!elListItem)
            throw ValueError(format('failed to find ListItem of "{1}"', name))
        elListItem.GetCurrentPattern("SelectionItem").select()
        send("{enter}") ;TODO 如何优化
    }
    ;NOTE NOTE NOTE method 一般用 ClickByControl ClickByMouse 备用
    SetChecked(bChecked, method:="") {
        if (this.GetControlType() ~= "i)^(Button|RadioButton|CheckBox|ComboBox)$") {
            oTG := this.GetCurrentPattern("toggle")
            if (oTG.CurrentToggleState != bChecked) {
                if (method == "")
                    oTG.Toggle()
                else
                    this.%method%() ;作为补充
            }
        } else if (this.GetControlType() ~= "i)^(ListItem|TabItem)$") {
            if (this.GetCurrentPropertyValue("SelectionItemIsSelected") != bChecked)
                if (method == "")
                    this.GetCurrentPattern("SelectionItem").Select()
                else
                    this.%method%() ;作为补充
        }
    }
    ;包含坐标
    ContainXY(xScreen:=unset, yScreen:=unset, cm:=0) { ;cm 0=windows 1=screen
        if !isset(xScreen) {
            cmMouse := A_CoordModeMouse
            CoordMode("mouse", "screen")
            MouseGetPos(&xScreen, &yScreen)
            CoordMode("mouse", cmMouse)
        } else if (cm == 0) {
            WinGetPos(&x, &y,,, "A")
            xScreen += x
            yScreen += y
        }
        aRect := this.GetBoundingRectangle()
        res := xScreen >= aRect[1] && xScreen <= aRect[1]+aRect[3] && yScreen >= aRect[2] && yScreen <= aRect[2]+aRect[4]
        return res
    }

    GetAllCurrentPropertyValue() {
        infos := {}
        for k, v in UIA.Property.OwnProps() {
            v := this.GetCurrentPropertyValue(v)
            if (v is ComObjArray) {
                arr := []
                for t in v
                    arr.push(t)
                v := arr
            }
            infos.%k% := v
        }
        return infos
    }

    ;"IsOffscreen",
    ;"IsKeyboardFocusable",
    ;"HasKeyboardFocus",
    ;"AccessKey",
    ;"ProcessId",
    ;"RuntimeId",
    ;"automationid",
    ;"FrameworkId",
    ;"ClassName",
    ;"NativeWindowHandle",
    ;"ProviderDescription",
    ;"IsPassword",
    ;"HelpText",
    ;"IsDialog",
    ;"IsAnnotationPatternAvailable",
    ;"IsDragPatternAvailable",
    ;"IsDockPatternAvailable",
    ;"IsDropTargetPatternAvailable",
    ;"IsExpandCollapsePatternAvailable",
    ;"IsGridPatternAvailable",
    ;"IsGridItemPatternAvailable",
    ;"IsInvokePatternAvailable",
    ;"IsItemContainerPatternAvailable",
    ;"IsLegacyIAccessiblePatternAvailable",
    ;"IsMultipleViewPatternAvailable",
    ;"IsObjectModelPatternAvailable",
    ;"IsRangeValuePatternAvailable",
    ;"IsScrollPatternAvailable",
    ;"IsScrollItemPatternAvailable",
    ;"IsSelectionItemPatternAvailable",
    ;"IsSelectionPatternAvailable",
    ;"IsSpreadsheetPatternAvailable",
    ;"IsSpreadsheetItemPatternAvailable",
    ;"IsStylesPatternAvailable",
    ;"IsSynchronizedInputPatternAvailable",
    ;"IsTablePatternAvailable",
    ;"IsTableItemPatternAvailable",
    ;"IsTextChildPatternAvailable",
    ;"IsTextEditPatternAvailable",
    ;"IsTextPatternAvailable",
    ;"IsTextPattern2Available",
    ;"IsTogglePatternAvailable",
    ;"IsTransformPatternAvailable",
    ;"IsTransformPattern2Available",
    ;"IsValuePatternAvailable",
    ;"IsVirtualizedItemPatternAvailable",
    ;"IsWindowPatternAvailable",
    ;NOTE 可以用来比较同个元素前后的差异！！
    ;allProperty1(bDeleteNull:=true) {
    ;    arr := [
    ;        "name",
    ;        "ControlType",
    ;        "LocalizedControlType",
    ;        "BoundingRectangle",
    ;        "IsEnabled",
    ;    ]
    ;    rst := UIA.CreateCacheRequest()
    ;    for propertyId in arr
    ;        rst.AddProperty(propertyId)
    ;    obj := map()
    ;    for propertyId in arr
    ;        obj[propertyId] := this.GetCachedPropertyValue(propertyId)
    ;    return obj
    ;}

    ;NOTE 可以用来比较同个元素前后的差异！！
    allProperty(bDeleteNull:=true) {
        aRect := this.GetBoundingRectangle()
        obj := map()
        obj["name"] := this.CurrentName
        obj["ControlType"] := this.GetControlType()
        obj["LocalizedControlType"] := this.CurrentLocalizedControlType
        obj["BoundingRectangle"] := format("xm:{1} ym:{2} l:{3} t:{4} w:{5} h:{6}", aRect[1]+aRect[3]//2, aRect[2]+aRect[4]//2,aRect*)
        obj["CurrentBoundingRectangle"] := format("l:{1} t:{2} r:{3} b:{4}", aRect[1], aRect[2], aRect[1]+aRect[3], aRect[2]+aRect[4])
        obj["IsEnabled"] := this.CurrentIsEnabled
        obj["IsOffscreen"] := this.CurrentIsOffscreen
        obj["IsKeyboardFocusable"] := this.CurrentIsKeyboardFocusable
        obj["HasKeyboardFocus"] := this.CurrentHasKeyboardFocus
        obj["AccessKey"] := this.CurrentAccessKey
        obj["ProcessId"] := this.CurrentProcessId
        obj["RuntimeId"] := this.GetRuntimeIdEx()
        obj["automationid"] := this.CurrentAutomationId ;NOTE 多个控件可能是同个 automationid
        obj["FrameworkId"] := this.CurrentFrameworkId
        obj["ClassName"] := this.CurrentClassName
        obj["NativeWindowHandle"] := this.CurrentNativeWindowHandle, ;hCtl
        obj["ProviderDescription"] := this.CurrentProviderDescription
        obj["IsPassword"] := this.CurrentIsPassword
        obj["HelpText"] := this.CurrentHelpText
        obj["IsDialog"] := this.CurrentIsDialog
        obj["IsAnnotationPatternAvailable"] := this.GetCurrentPropertyValue("IsAnnotationPatternAvailable")
        obj["IsDragPatternAvailable"] := this.GetCurrentPropertyValue("IsDragPatternAvailable")
        obj["IsDockPatternAvailable"] := this.GetCurrentPropertyValue("IsDockPatternAvailable")
        obj["IsDropTargetPatternAvailable"] := this.GetCurrentPropertyValue("IsDropTargetPatternAvailable")
        obj["IsExpandCollapsePatternAvailable"] := this.GetCurrentPropertyValue("IsExpandCollapsePatternAvailable")
        if (obj["IsGridPatternAvailable"] := this.GetCurrentPropertyValue("IsGridPatternAvailable")) {
            obj["GridRowCount"] := this.GetCurrentPropertyValue("GridRowCount")
            obj["GridColumnCount"] := this.GetCurrentPropertyValue("GridColumnCount")
        }
        if (obj["IsGridItemPatternAvailable"] := this.GetCurrentPropertyValue("IsGridItemPatternAvailable")) {
            obj["GridItemRow"] := this.GetCurrentPropertyValue("GridItemRow")
            obj["GridItemColumn"] := this.GetCurrentPropertyValue("GridItemColumn")
            obj["GridItemRowSpan"] := this.GetCurrentPropertyValue("GridItemRowSpan")
            obj["GridItemColumnSpan"] := this.GetCurrentPropertyValue("GridItemColumnSpan")
            obj["GridItemContainingGrid"] := this.GetCurrentPropertyValue("GridItemContainingGrid")
        }
        obj["IsInvokePatternAvailable"] := this.GetCurrentPropertyValue("IsInvokePatternAvailable")
        obj["IsItemContainerPatternAvailable"] := this.GetCurrentPropertyValue("IsItemContainerPatternAvailable")
        if (obj["IsLegacyIAccessiblePatternAvailable"] := this.GetCurrentPropertyValue("IsLegacyIAccessiblePatternAvailable")) {
            obj["LegacyIAccessibleChildId"] := this.GetCurrentPropertyValue("LegacyIAccessibleChildId")
            obj["LegacyIAccessibleName"] := this.GetCurrentPropertyValue("LegacyIAccessibleName")
            obj["LegacyIAccessibleValue"] := this.GetCurrentPropertyValue("LegacyIAccessibleValue")
            obj["LegacyIAccessibleDescription"] := this.GetCurrentPropertyValue("LegacyIAccessibleDescription")
            obj["LegacyIAccessibleRole"] := this.GetCurrentPropertyValue("LegacyIAccessibleRole")
            obj["LegacyIAccessibleState"] := this.GetCurrentPropertyValue("LegacyIAccessibleState")
            obj["LegacyIAccessibleHelp"] := this.GetCurrentPropertyValue("LegacyIAccessibleHelp")
            obj["LegacyIAccessibleKeyboardShortcut"] := this.GetCurrentPropertyValue("LegacyIAccessibleKeyboardShortcut")
            ;obj["LegacyIAccessibleSelection"] := this.GetCurrentPropertyValue("LegacyIAccessibleSelection") ;TODO value 为 ComVar
            obj["LegacyIAccessibleDefaultAction"] := this.GetCurrentPropertyValue("LegacyIAccessibleDefaultAction")
        }
        if (obj["IsMultipleViewPatternAvailable"] := this.GetCurrentPropertyValue("IsMultipleViewPatternAvailable")) {
            obj["MultipleViewCurrentView"] := this.GetCurrentPropertyValue("MultipleViewCurrentView")
            obj["MultipleViewSupportedViews"] := this.GetCurrentPropertyValue("MultipleViewSupportedViews")
        }
        obj["IsObjectModelPatternAvailable"] := this.GetCurrentPropertyValue("IsObjectModelPatternAvailable")
        if (obj["IsRangeValuePatternAvailable"] := this.GetCurrentPropertyValue("IsRangeValuePatternAvailable")) {
            obj["RangeValueValue"] := this.GetCurrentPropertyValue("RangeValueValue")
            obj["RangeValueIsReadOnly"] := this.GetCurrentPropertyValue("RangeValueIsReadOnly")
            obj["RangeValueMinimum"] := this.GetCurrentPropertyValue("RangeValueMinimum")
            obj["RangeValueMaximum"] := this.GetCurrentPropertyValue("RangeValueMaximum")
            obj["RangeValueLargeChange"] := this.GetCurrentPropertyValue("RangeValueLargeChange")
            obj["RangeValueSmallChange"] := this.GetCurrentPropertyValue("RangeValueSmallChange")
        }
        if (obj["IsScrollPatternAvailable"] := this.GetCurrentPropertyValue("IsScrollPatternAvailable")) {
            obj["ScrollHorizontalScrollPercent"] := this.GetCurrentPropertyValue("ScrollHorizontalScrollPercent")
            obj["ScrollHorizontalViewSize"] := this.GetCurrentPropertyValue("ScrollHorizontalViewSize")
            obj["ScrollVerticalScrollPercent"] := this.GetCurrentPropertyValue("ScrollVerticalScrollPercent")
            obj["ScrollVerticalViewSize"] := this.GetCurrentPropertyValue("ScrollVerticalViewSize")
            obj["ScrollHorizontallyScrollable"] := this.GetCurrentPropertyValue("ScrollHorizontallyScrollable")
            obj["ScrollVerticallyScrollable"] := this.GetCurrentPropertyValue("ScrollVerticallyScrollable")
        }
        obj["IsScrollItemPatternAvailable"] := this.GetCurrentPropertyValue("IsScrollItemPatternAvailable")
        if (obj["IsSelectionItemPatternAvailable"] := this.GetCurrentPropertyValue("IsSelectionItemPatternAvailable")) {
            obj["SelectionItemIsSelected"] := this.GetCurrentPropertyValue("SelectionItemIsSelected")
            ;obj["SelectionItemSelectionContainer"] := this.GetCurrentPropertyValue("SelectionItemSelectionContainer") ;TODO value 为 ComVar
        }
        if (obj["IsSelectionPatternAvailable"] := this.GetCurrentPropertyValue("IsMultipleViewPatternAvailable")) {
            obj["SelectionSelection"] := this.GetCurrentPropertyValue("SelectionSelection")
            obj["SelectionCanSelectMultiple"] := this.GetCurrentPropertyValue("SelectionCanSelectMultiple")
            obj["SelectionIsSelectionRequired"] := this.GetCurrentPropertyValue("SelectionIsSelectionRequired")
        }
        obj["IsSpreadsheetPatternAvailable"] := this.GetCurrentPropertyValue("IsSpreadsheetPatternAvailable")
        obj["IsSpreadsheetItemPatternAvailable"] := this.GetCurrentPropertyValue("IsSpreadsheetItemPatternAvailable")
        obj["IsStylesPatternAvailable"] := this.GetCurrentPropertyValue("IsStylesPatternAvailable")
        obj["IsSynchronizedInputPatternAvailable"] := this.GetCurrentPropertyValue("IsSynchronizedInputPatternAvailable")
        if (obj["IsTablePatternAvailable"] := this.GetCurrentPropertyValue("IsTablePatternAvailable")) {
            obj["TableRowHeaders"] := this.GetCurrentPropertyValue("TableRowHeaders")
            obj["TableColumnHeaders"] := this.GetCurrentPropertyValue("TableColumnHeaders")
            obj["TableRowOrColumnMajor"] := this.GetCurrentPropertyValue("TableRowOrColumnMajor")
            obj["TableItemRowHeaderItems"] := this.GetCurrentPropertyValue("TableItemRowHeaderItems")
            obj["TableItemColumnHeaderItems"] := this.GetCurrentPropertyValue("TableItemColumnHeaderItems")
        }
        obj["IsTableItemPatternAvailable"] := this.GetCurrentPropertyValue("IsTableItemPatternAvailable")
        obj["IsTextChildPatternAvailable"] := this.GetCurrentPropertyValue("IsTextChildPatternAvailable")
        obj["IsTextEditPatternAvailable"] := this.GetCurrentPropertyValue("IsTextEditPatternAvailable")
        obj["IsTextPatternAvailable"] := this.GetCurrentPropertyValue("IsTextPatternAvailable")
        obj["IsTextPattern2Available"] := this.GetCurrentPropertyValue("IsTextPattern2Available")
        if (obj["IsTogglePatternAvailable"] := this.GetCurrentPropertyValue("IsTogglePatternAvailable")) {
            obj["ToggleToggleState"] := this.GetCurrentPropertyValue("ToggleToggleState")
            ;obj["CurrentToggleState"] := op.CurrentToggleState ;TODO CheckBox
        }
        if (obj["IsTransformPatternAvailable"] := this.GetCurrentPropertyValue("IsTransformPatternAvailable")) {
            obj["TransformCanMove"] := this.GetCurrentPropertyValue("TransformCanMove")
            obj["TransformCanResize"] := this.GetCurrentPropertyValue("TransformCanResize")
            obj["TransformCanRotate"] := this.GetCurrentPropertyValue("TransformCanRotate")
        }
        obj["IsTransformPattern2Available"] := this.GetCurrentPropertyValue("IsTransformPattern2Available")
        if (obj["IsValuePatternAvailable"] := this.GetCurrentPropertyValue("IsValuePatternAvailable")) {
            obj["ValueValue"] :=  this.GetCurrentPropertyValue("ValueValue")
            obj["ValueIsReadOnly"] :=  this.GetCurrentPropertyValue("ValueIsReadOnly")
        }
        obj["IsVirtualizedItemPatternAvailable"] := this.GetCurrentPropertyValue("IsVirtualizedItemPatternAvailable")
        if (obj["IsWindowPatternAvailable"] := this.GetCurrentPropertyValue("IsWindowPatternAvailable")) {
            obj["WindowCanMaximize"] := this.GetCurrentPropertyValue("WindowCanMaximize")
            obj["WindowCanMinimize"] := this.GetCurrentPropertyValue("WindowCanMinimize")
            obj["WindowIsModal"] := this.GetCurrentPropertyValue("WindowIsModal")
            obj["WindowWindowInteractionState"] := this.GetCurrentPropertyValue("WindowWindowInteractionState")
            obj["WindowWindowVisualState"] := this.GetCurrentPropertyValue("WindowWindowVisualState")
        }
        obj["AcceleratorKey"] :=  this.CurrentAcceleratorKey
        if (bDeleteNull) {
            arr := []
            for k, v in obj {
                if (v == "") || (k ~= "Is[A-Z]" && !v) ;NOTE 不显示 false 的
                    arr.push(k)
            }
            for v in arr
                obj.delete(v)
        }
        return obj
    }

    compareUIE(obj0) {
        if (type(obj0) == "IUIAutomationElement")
            obj0 := obj0.allProperty()
        obj0.default := ""
        obj1 := this.allProperty()
        obj1.default := ""
        objRes := map()
        for k, v in obj1 {
            if (v != obj0[k])
                objRes[k] := [obj0[k], v]
        }
        for k, v in obj0 { ;记录 obj0 中独有的内容
            if (v != obj1[k] && !objRes.has(k))
                objRes[k] := [v, "null"]
        }
        return (objRes.count) ? objRes : map()
        objToTable(obj, charItem:="`t") {
            if !obj.count
                return ""
            res := ""
            ;记录第1项的类型
            for k, v in obj {
                tp := type(v)
                break
            }
            if (tp == "Array") {
                for k, arr1 in obj {
                    res .= k
                    for v in arr1
                        res .= charItem . v
                    res := rtrim(res, charItem) .  "`n"
                }
            }
            return res
        }
    }

    ;bSec 为显示秒数，0则一直显示，直到按下任意键
    ;_UIADo.seeUIE(el)
    see(bSec:=0) {
        obj := this.allProperty()
        s := ""
        for k, v in obj {
            if (v != "")
                s .= format("{1}=`t{2}`n", k,v)
        }
        tooltip(s,,, 9)
        if (bSec)
            SetTimer(func("tooltip").bind(,,, 9), -(bSec*1000))
        else { ;
            ih := InputHook()
            ih.VisibleNonText := false
            ih.KeyOpt("{all}", "E")
            ih.start()
            suspend true
            ih.wait()
            suspend false
            tooltip(,,, 9)
        }
    }

    getTabItems(bName:=true) {
        ;获取 elTab
        if (this.CurrentControlType == UIA.ControlType.Tab)
            elTab := this
        else if (this.CurrentControlType == UIA.ControlType.TabItem)
            elTab := this.GetParent()
        arr := []
        for el in elTab.FindAll(UIA.CreateTrueCondition(), 2)
            arr.push(bName ? el.CurrentName : el)
        return arr
    }

    getTreeData() {
        oRV := UIA.RawViewWalker()
        elTree := oRV.GetParentElement(this)
        loop(2) {
            if (elTree.CurrentControlType != "Tree")
                elTree := oRV.GetParentElement(elTree)
            else
                break
        }
        funGetValue := (el)=>el.GetCurrentPropertyValue("ValueValue") ? el.GetCurrentPropertyValue("ValueValue") : el.GetFirst().GetCurrentPropertyValue("ValueValue")
        elItem := oRV.GetFirstChildElement(oRV.GetLastChildElement(elTree))
        ;arrX := [elItem.GetBoundingRectangle()[1]]
        arr := []
        loop {
            ;if (elItem.GetBoundingRectangle()[1] > arrX[1])
            ;    arrX.push(elItem.GetBoundingRectangle()[1])
            arr.push(funGetValue(elItem))
            try
                elItem := oRV.GetNextSiblingElement(elItem)
            catch
                break
        }
        return arr
    }

    ;通过 elField 获取表格内容
    ;tp 0=obj 1=arrData 2=arrTable
    getTableData(tp:=false) {
        oRV := UIA.RawViewWalker()
        elTable := oRV.GetParentElement(this)
        loop(2) {
            if (elTable.CurrentControlType != "Table")
                elTable := oRV.GetParentElement(elTable)
            else
                break
        }
        ;获取标题
        elHeader := oRV.GetFirstChildElement(elTable)
        arrField := []
        for el in elHeader.FindAll(UIA.CreateTrueCondition(), 2)
            arrField.push(el.CurrentName)
        OutputDebug(json.stringify(arrField))
        ;获取数据
        elBody := oRV.GetLastChildElement(elTable)
        ;_UIADo.seeUIE(elBody)
        elLine := oRV.GetFirstChildElement(elBody)
        ;_UIADo.seeUIE(elLine)
        ;NOTE 获取值的方法
        elItem := oRV.GetFirstChildElement(elLine)
        if (elItem.CurrentName ~= " row \d+$")
            funGetValue := (el)=>el.GetCurrentPropertyValue("ValueValue")
        else
            funGetValue := (el)=>el.CurrentName
        if (tp == 2)
            arr2 := [arrField]
        else if (tp == 1)
            arr2 := []
        loop {
            if (tp == 0) {
                obj := map()
                elItem := oRV.GetFirstChildElement(elLine)
                obj[arrField[1]] := arr.push(funGetValue(elItem))
                loop(arrField.length-1) {
                    elItem := oRV.GetNextSiblingElement(elItem)
                    obj[arrField[A_Index+1]] := funGetValue(elItem)
                }
                arr2.push(obj)
            } else {
                arr := [] ;记录每行数据
                elItem := oRV.GetFirstChildElement(elLine)
                arr.push(funGetValue(elItem))
                loop(arrField.length-1) {
                    elItem := oRV.GetNextSiblingElement(elItem)
                    arr.push(funGetValue(elItem))
                }
                arr2.push(arr)
            }
            try
                elLine := oRV.GetNextSiblingElement(elLine)
            catch
                break
        }
        return arr2
    }

    ;TODO 待完善
    ;判断两个元素是否相同
    ; https://docs.microsoft.com/zh-cn/dotnet/api/system.windows.automation.automationelement.equals
    equals(el) {
        return this.GetRuntimeIdEx() == el.GetRuntimeIdEx()
    }

    ; Sets the keyboard focus to this UI Automation element.
    SetFocus() => comcall(3, this)

    ; Retrieves the unique identifier assigned to the UI element.
    ; The identifier is only guaranteed to be unique to the UI of the desktop on which it was generated. Identifiers can be reused over time.
    ; The format of run-time identifiers might change in the future. The returned identifier should be treated as an opaque value and used only for comparison; for example, to determine whether a Microsoft UI Automation element is in the cache.
    GetRuntimeId() => (comcall(4, this, "ptr*",&runtimeId:=0), ComValue(0x2003, runtimeId))

    ; The scope of the search is relative to the element on which the method is called. Elements are returned in the order in which they are encountered in the tree.
    ; This function cannot search for ancestor elements in the Microsoft UI Automation tree; that is, TreeScope_Ancestors is not a valid value for the scope parameter.
    ; When searching for top-level windows on the desktop, be sure to specify TreeScope_Children in the scope parameter, not TreeScope_Descendants. A search through the entire subtree of the desktop could iterate through thousands of items and lead to a stack overflow.
    ; If your client application might try to find elements in its own user interface, you must make all UI Automation calls on a separate thread.

    ;TODO 在 HR 人事界面 elText.GetParent().GetNext() 后面 .FindFirst(condEdit) 无效，只能用 .GetFirst()
    ; Retrieves the first child or descendant element that matches the specified condition.
    FindFirst(condition, scope:=4) {
        comcall(5, this, "int",scope, "ptr",condition, "ptr*",&found:=0)
        if (found)
            return IUIAutomationElement(found)
        ;throw TargetError("Target element not found.")
    }

    ; Returns all UI Automation elements that satisfy the specified condition.
    ;TODO 为什么有儿子，但.length==0，比如U9料品里的页签文字
    FindAll(condition, scope:=4) {
        comcall(6, this, "int",scope, "ptr",condition, "ptr*",&found:=0)
        if (found)
            return IUIAutomationElementArray(found)
        throw TargetError("Target elements not found.")
    }

    ; Retrieves the first child or descendant element that matches the specified condition, prefetches the requested properties and control patterns, and stores the prefetched items in the cache.
    FindFirstBuildCache(condition, cacheRequest, scope := 4) {
        comcall(7, this, "int",scope, "ptr",condition, "ptr",cacheRequest, "ptr*",&found:=0)
        if (found)
            return IUIAutomationElement(found)
        throw TargetError("Target element not found.")
    }

    ; Returns all UI Automation elements that satisfy the specified condition, prefetches the requested properties and control patterns, and stores the prefetched items in the cache.
    FindAllBuildCache(condition, cacheRequest, scope := 4) {
        comcall(8, this, "int",scope, "ptr",condition, "ptr",cacheRequest, "ptr*",&found:=0)
        if (found)
            return IUIAutomationElementArray(found)
        throw TargetError("Target elements not found.")
    }

    ; Retrieves a  UI Automation element with an updated cache.
    ; The original UI Automation element is unchanged. The  IUIAutomationElement interface refers to the same element and has the same runtime identifier.
    BuildUpdatedCache(cacheRequest) => (comcall(9, this, "ptr",cacheRequest, "ptr*",&updatedElement:=0), IUIAutomationElement(updatedElement))

    ; Microsoft UI Automation properties of the double type support Not a Number (NaN) values. When retrieving a property of the double type, a client can use the _isnan function to determine whether the property is a NaN value.

    ; Retrieves the current value of a property for this UI Automation element.
    GetCurrentPropertyValue(propertyId) {
        if !(propertyId is integer)
            propertyId := UIA.property.%propertyId%
        comcall(10, this, "int",propertyId, "ptr",val:=ComVar())
        return val[]
    }

    ; Retrieves a property value for this UI Automation element, optionally ignoring any default value.
    ; Passing FALSE in the ignoreDefaultValue parameter is equivalent to calling IUIAutomationElement,,GetCurrentPropertyValue.
    ; If the Microsoft UI Automation provider for the element itself supports the property, the value of the property is returned. Otherwise, if ignoreDefaultValue is FALSE, a default value specified by UI Automation is returned.
    ; This method returns a failure code if the requested property was not previously cached.
    GetCurrentPropertyValueEx(propertyId, ignoreDefaultValue) => (comcall(11, this, "int",propertyId, "int",ignoreDefaultValue, "ptr",val:=ComVar()), val[])

    ; Retrieves a property value from the cache for this UI Automation element.
    GetCachedPropertyValue(propertyId) {
        if !(propertyId is integer)
            propertyId := UIA.property.%propertyId%
        comcall(12, this, "int",propertyId, "ptr",val:=ComVar())
        return val[]
    }

    ; Retrieves a property value from the cache for this UI Automation element, optionally ignoring any default value.
    GetCachedPropertyValueEx(propertyId, ignoreDefaultValue, retVal) => (comcall(13, this, "int",propertyId, "int",ignoreDefaultValue, "ptr",val:=ComVar()), val[])

    ; Retrieves the control pattern interface of the specified pattern on this UI Automation element.
    GetCurrentPatternAs(patternId, riid) {	; not completed
        if (patternId is integer)
            name := UIA.ControlPattern.%patternId%
        else
            patternId := UIA.ControlPattern.%(name := patternId)%
        comcall(14, this, "int",patternId, "ptr",riid, "ptr*",&patternObject:=0)
        return IUIAutomation%name%Pattern(patternObject)
    }

    ; Retrieves the control pattern interface of the specified pattern from the cache of this UI Automation element.
    GetCachedPatternAs(patternId, riid) {	; not completed
        if (patternId is integer)
            name := UIA.ControlPattern.%patternId%
        else
            patternId := UIA.ControlPattern.%(name := patternId)%
        comcall(15, this, "int",patternId, "ptr",riid, "ptr*",&patternObject:=0)
        return IUIAutomation%name%Pattern(patternObject)
    }

    ; Retrieves the IUnknown interface of the specified control pattern on this UI Automation element.
    ; This method gets the specified control pattern based on its availability at the time of the call.
    ; For some forms of UI, this method will incur cross-process performance overhead. Applications can reduce overhead by caching control patterns and then retrieving them by using IUIAutomationElement,,GetCachedPattern.
    GetCurrentPattern(patternId) {
        if (patternId is integer)
            name := UIA.ControlPattern.%patternId%
        else
            patternId := UIA.ControlPattern.%(name := patternId)%
        comcall(16, this, "int",patternId, "ptr*",&patternObject:=0)
        return IUIAutomation%name%Pattern(patternObject)
    }

    ; Retrieves from the cache the IUnknown interface of the specified control pattern of this UI Automation element.
    GetCachedPattern(patternId) {
        if (patternId is integer)
            name := UIA.ControlPattern.%patternId%
        else
            patternId := UIA.ControlPattern.%(name := patternId)%
        comcall(17, this, "int",patternId, "ptr*",&patternObject:=0)
        if (patternObject)
            return IUIAutomation%name%Pattern(patternObject)
    }

    ; Retrieves from the cache the parent of this UI Automation element.
    GetCachedParent() => (comcall(18, this, "ptr*",&parent:=0), IUIAutomationElement(parent))

    ; Retrieves the cached child elements of this UI Automation element.
    ; The view of the returned collection is determined by the TreeFilter property of the IUIAutomationCacheRequest that was active when this element was obtained.
    ; Children are cached only if the scope of the cache request included TreeScope_Subtree, TreeScope_Children, or TreeScope_Descendants.
    ; If the cache request specified that children were to be cached at this level, but there are no children, the value of this property is 0. However, if no request was made to cache children at this level, an attempt to retrieve the property returns an error.
    GetCachedChildren() => (comcall(19, this, "ptr*",&children:=0), IUIAutomationElementArray(children))

    ; Retrieves the identifier of the process that hosts the element.
    CurrentProcessId => (comcall(20, this, "int*",&retVal:=0), retVal)

    ; Retrieves the control type of the element.
    ; Control types describe a known interaction model for UI Automation elements without relying on a localized control type or combination of complex logic rules. This property cannot change at run time unless the control supports the IUIAutomationMultipleViewPattern interface. An example is the Win32 ListView control, which can change from a data grid to a list, depending on the current view.
    CurrentControlType => (comcall(21, this, "int*",&retVal:=0), retVal)

    ; Retrieves a localized description of the control type of the element.
    CurrentLocalizedControlType => (comcall(22, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the name of the element.
    CurrentName => (comcall(23, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the accelerator key for the element.
    CurrentAcceleratorKey => (comcall(24, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the access key character for the element.
    ; An access key is a character in the text of a menu, menu item, or label of a control such as a button that activates the attached menu function. For example, the letter "O" is often used to invoke the Open file common dialog box from a File menu. Microsoft UI Automation elements that have the access key property set always implement the Invoke control pattern.
    CurrentAccessKey => (comcall(25, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Indicates whether the element has keyboard focus.
    CurrentHasKeyboardFocus => (comcall(26, this, "int*",&retVal:=0), retVal)

    ; Indicates whether the element can accept keyboard focus.
    CurrentIsKeyboardFocusable => (comcall(27, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the element is enabled.
    CurrentIsEnabled => (comcall(28, this, "int*",&retVal:=0), retVal)

    ; Retrieves the Microsoft UI Automation identifier of the element.
    ; The identifier is unique among sibling elements in a container, and is the same in all instances of the application.
    CurrentAutomationId => (comcall(29, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the class name of the element.
    ; The value of this property is implementation-defined. The property is useful in testing environments.
    CurrentClassName => (comcall(30, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the help text for the element. This information is typically obtained from tooltips.
    ; Caution  Do not retrieve the CachedHelpText property from a control that is based on the SysListview32 class. Doing so could cause the system to become unstable and data to be lost. A client application can discover whether a control is based on SysListview32 by retrieving the CachedClassName or CurrentClassName property from the control.
    CurrentHelpText => (comcall(31, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the culture identifier for the element.
    CurrentCulture => (comcall(32, this, "int*",&retVal:=0), retVal)

    ; Indicates whether the element is a control element.
    CurrentIsControlElement => (comcall(33, this, "int*",&retVal:=0), retVal)

    ; Indicates whether the element is a content element.
    ; A content element contains data that is presented to the user. Examples of content elements are the items in a list box or a button in a dialog box. Non-content elements, also called peripheral elements, are typically used to manipulate the content in a composite control; for example, the button on a drop-down control.
    CurrentIsContentElement => (comcall(34, this, "int*",&retVal:=0), retVal)

    ; Indicates whether the element contains a disguised password.
    ; This property enables applications such as screen-readers to determine whether the text content of a control should be read aloud.
    CurrentIsPassword => (comcall(35, this, "int*",&retVal:=0), retVal)

    ; Retrieves the window handle of the element.
    CurrentNativeWindowHandle => (comcall(36, this, "ptr*",&retVal:=0), retVal)

    ; Retrieves a description of the type of UI item represented by the element.
    ; This property is used to obtain information about items in a list, tree view, or data grid. For example, an item in a file directory view might be a "Document File" or a "Folder".
    CurrentItemType => (comcall(37, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Indicates whether the element is off-screen.
    CurrentIsOffscreen => (comcall(38, this, "int*",&retVal:=0), retVal)

    ; Retrieves a value that indicates the orientation of the element.
    ; This property is supported by controls such as scroll bars and sliders that can have either a vertical or a horizontal orientation.
    CurrentOrientation => (comcall(39, this, "int*",&retVal:=0), retVal)

    ; Retrieves the name of the underlying UI framework. The name of the UI framework, such as "Win32", "WinForm", or "DirectUI".
    CurrentFrameworkId => (comcall(40, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Indicates whether the element is required to be filled out on a form.
    CurrentIsRequiredForForm => (comcall(41, this, "int*",&retVal:=0), retVal)

    ; Retrieves the description of the status of an item in an element.
    ; This property enables a client to ascertain whether an element is conveying status about an item. For example, an item associated with a contact in a messaging application might be "Busy" or "Connected".
    CurrentItemStatus => (comcall(42, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the coordinates of the rectangle that completely encloses the element, in screen coordinates.
    CurrentBoundingRectangle => (comcall(43, this, "ptr",retVal := NativeArray(0, 4, "int")), {left: retVal[0], top: retVal[1], right: retVal[2], bottom: retVal[3]})

    ; This property maps to the Accessible Rich Internet Applications (ARIA) property.

    ; Retrieves the element that contains the text label for this element.
    ; This property could be used to retrieve, for example, the static text label for a combo box.
	CurrentLabeledBy => (comcall(44, this, "ptr*",&retVal:=0), IUIAutomationElement(retVal))

    ; Retrieves the Accessible Rich Internet Applications (ARIA) role of the element.
    CurrentAriaRole => (comcall(45, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the ARIA properties of the element.
    CurrentAriaProperties => (comcall(46, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Indicates whether the element contains valid data for a form.
    CurrentIsDataValidForForm => (comcall(47, this, "int*",&retVal:=0), retVal)

    ; Retrieves an array of elements for which this element serves as the controller.
	CurrentControllerFor => (comcall(48, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves an array of elements that describe this element.
	CurrentDescribedBy => (comcall(49, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves an array of elements that indicates the reading order after the current element.
	CurrentFlowsTo => (comcall(50, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves a description of the provider for this element.
    CurrentProviderDescription => (comcall(51, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the cached ID of the process that hosts the element.
    CachedProcessId => (comcall(52, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates the control type of the element.
    CachedControlType => (comcall(53, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached localized description of the control type of the element.
    CachedLocalizedControlType => (comcall(54, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the cached name of the element.
    CachedName => (comcall(55, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the cached accelerator key for the element.
    CachedAcceleratorKey => (comcall(56, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the cached access key character for the element.
    CachedAccessKey => (comcall(57, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; A cached value that indicates whether the element has keyboard focus.
    CachedHasKeyboardFocus => (comcall(58, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the element can accept keyboard focus.
    CachedIsKeyboardFocusable => (comcall(59, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the element is enabled.
    CachedIsEnabled => (comcall(60, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached UI Automation identifier of the element.
    CachedAutomationId => (comcall(61, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the cached class name of the element.
    CachedClassName => (comcall(62, this, "ptr*",&retVal:=0), BSTR(retVal))

    ;
    CachedHelpText => (comcall(63, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the cached help text for the element.
    CachedCulture => (comcall(64, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the element is a control element.
    CachedIsControlElement => (comcall(65, this, "int*",&retVal:=0), retVal)

    ; A cached value that indicates whether the element is a content element.
    CachedIsContentElement => (comcall(66, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the element contains a disguised password.
    CachedIsPassword => (comcall(67, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached window handle of the element.
    CachedNativeWindowHandle => (comcall(68, this, "ptr*",&retVal:=0), retVal)

    ; Retrieves a cached string that describes the type of item represented by the element.
    CachedItemType => (comcall(69, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves a cached value that indicates whether the element is off-screen.
    CachedIsOffscreen => (comcall(70, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates the orientation of the element.
    CachedOrientation => (comcall(71, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached name of the underlying UI framework associated with the element.
    CachedFrameworkId => (comcall(72, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves a cached value that indicates whether the element is required to be filled out on a form.
    CachedIsRequiredForForm => (comcall(73, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached description of the status of an item within an element.
    CachedItemStatus => (comcall(74, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the cached coordinates of the rectangle that completely encloses the element.
	CachedBoundingRectangle => (comcall(75, this, "ptr",retVal := NativeArray(0, 4, "int")), {left: retVal[0], top: retVal[1], right: retVal[2], bottom: retVal[3]})

    ; Retrieves the cached element that contains the text label for this element.
	CachedLabeledBy => (comcall(76, this, "ptr*",&retVal:=0), IUIAutomationElement(retVal))

    ; Retrieves the cached ARIA role of the element.
    CachedAriaRole => (comcall(77, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves the cached ARIA properties of the element.
    CachedAriaProperties => (comcall(78, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves a cached value that indicates whether the element contains valid data for the form.
    CachedIsDataValidForForm => (comcall(79, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached array of UI Automation elements for which this element serves as the controller.
	CachedControllerFor => (comcall(80, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves a cached array of elements that describe this element.
	CachedDescribedBy => (comcall(81, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves a cached array of elements that indicate the reading order after the current element.
	CachedFlowsTo => (comcall(82, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves a cached description of the provider for this element.
    CachedProviderDescription => (comcall(83, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves a point on the element that can be clicked.
    ; A client application can use this method to simulate clicking the left or right mouse button. For example, to simulate clicking the right mouse button to display the context menu for a control,
    ; • Call the GetClickablePoint method to find a clickable point on the control.
    ; • Call the SendInput function to send a right-mouse-down, right-mouse-up sequence.
	GetClickablePoint() {
		if (comcall(84, this, "int64*",&clickable:=0, "int*",&gotClickable:=0), gotClickable)
			return {x: clickable & 0xffff, y: clickable >> 32}
		throw TargetError('The element has no clickable point')
	}

    ;; IUIAutomationElement2
    CurrentOptimizeForVisualContent => (comcall(85, this, "int*",&retVal:=0), retVal)
    CachedOptimizeForVisualContent => (comcall(86, this, "int*",&retVal:=0), retVal)
    CurrentLiveSetting => (comcall(87, this, "int*",&retVal:=0), retVal)
    CachedLiveSetting => (comcall(88, this, "int*",&retVal:=0), retVal)
	CurrentFlowsFrom => (comcall(89, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))
	CachedFlowsFrom => (comcall(90, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ;; IUIAutomationElement3
    ShowContextMenu() => comcall(91, this)
    CurrentIsPeripheral => (comcall(92, this, "int*",&retVal:=0), retVal)
    CachedIsPeripheral => (comcall(93, this, "int*",&retVal:=0), retVal)

    ;; IUIAutomationElement4
    CurrentPositionInSet => (comcall(94, this, "int*",&retVal:=0), retVal)
    CurrentSizeOfSet => (comcall(95, this, "int*",&retVal:=0), retVal)
    CurrentLevel => (comcall(96, this, "int*",&retVal:=0), retVal)
    CurrentAnnotationTypes => (comcall(97, this, "ptr*",&retVal:=0), ComValue(0x2003, retVal))
	CurrentAnnotationObjects => (comcall(98, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))
    CachedPositionInSet => (comcall(99, this, "int*",&retVal:=0), retVal)
    CachedSizeOfSet => (comcall(100, this, "int*",&retVal:=0), retVal)
    CachedLevel => (comcall(101, this, "int*",&retVal:=0), retVal)
    CachedAnnotationTypes => (comcall(102, this, "ptr*",&retVal:=0), ComValue(0x2003, retVal))
	CachedAnnotationObjects => (comcall(103, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ;; IUIAutomationElement5
    CurrentLandmarkType => (comcall(104, this, "int*",&retVal:=0), retVal)
    CurrentLocalizedLandmarkType => (comcall(105, this, "ptr*",&retVal:=0), BSTR(retVal))
    CachedLandmarkType => (comcall(106, this, "int*",&retVal:=0), retVal)
    CachedLocalizedLandmarkType => (comcall(107, this, "ptr*",&retVal:=0), BSTR(retVal))

    ;; IUIAutomationElement6
    CurrentFullDescription => (comcall(108, this, "ptr*",&retVal:=0), BSTR(retVal))
    CachedFullDescription => (comcall(109, this, "ptr*",&retVal:=0), BSTR(retVal))

    ;; IUIAutomationElement7
    ; IUIAutomationCondition, TreeTraversalOptions, IUIAutomationElement, TreeScope
    FindFirstWithOptions(condition, traversalOptions, root, scope := 4) {
        if (comcall(110, this, "int",scope, "ptr",condition, "int",traversalOptions, "ptr",root, "ptr*",&found:=0), found)
            return IUIAutomationElement(found)
        throw TargetError("Target element not found.")
    }
    FindAllWithOptions(condition, traversalOptions, root, scope := 4) {
        if (comcall(111, this, "int",scope, "ptr",condition, "int",traversalOptions, "ptr",root, "ptr*",&found:=0), found)
            return IUIAutomationElementArray(found)
        throw TargetError("Target elements not found.")
    }

    ; TreeScope, IUIAutomationCondition, IUIAutomationCacheRequest, TreeTraversalOptions, IUIAutomationElement
    FindFirstWithOptionsBuildCache(condition, cacheRequest, traversalOptions, root, scope := 4) {
        if (comcall(112, this, "int",scope, "ptr",condition, "ptr",cacheRequest, "int",traversalOptions, "ptr",root, "ptr*",&found:=0), found)
            return IUIAutomationElement(found)
        throw TargetError("Target element not found.")
    }
    FindAllWithOptionsBuildCache(condition, cacheRequest, traversalOptions, root, scope := 4) {
        if (comcall(113, this, "int",scope, "ptr",condition, "ptr",cacheRequest, "int",traversalOptions, "ptr",root, "ptr*",&found:=0), found)
            return IUIAutomationElementArray(found)
        throw TargetError("Target elements not found.")
    }
    GetCurrentMetadataValue(targetId, metadataId) => (comcall(114, this, "int",targetId, "int",metadataId, "ptr",returnVal:=ComVar()), returnVal[])

    ;; IUIAutomationElement8
    CurrentHeadingLevel => (comcall(115, this, "int*",&retVal:=0), retVal)
    CachedHeadingLevel => (comcall(116, this, "int*",&retVal:=0), retVal)

    ;; IUIAutomationElement9
    CurrentIsDialog => (comcall(117, this, "int*",&retVal:=0), retVal)
    CachedIsDialog => (comcall(118, this, "int*",&retVal:=0), retVal)
}

class IUIAutomationElementArray extends IUIABase {
    ; Retrieves the number of elements in the collection.
    length => (comcall(3, this, "int*",&length:=0), length)

    ; Retrieves a Microsoft UI Automation element from the collection.
    ; 'index' base of 0
    GetElement(index) => (comcall(4, this, "int",index, "ptr*",&element:=0), IUIAutomationElement(element))

    __enum(n) {
        l := this.length
        _i := 0
        if (n == 1)
            return (&v) => (_i<l ? v:=this.GetElement(_i++) : false)
        else if (n == 2)
            return (&i,&v) => (_i<l ? (v:=this.GetElement(i:=_i++)) : false)
    }

}

class IUIAutomationExpandCollapsePattern extends IUIABase {
    ; This is a blocking method that returns after the element has been collapsed.
    ; There are cases when a element that is marked as a leaf node might not know whether it has children until either the IUIAutomationExpandCollapsePattern,,Collapse or the IUIAutomationExpandCollapsePattern,,Expand method is called. This behavior is possible with a tree view control that does delayed loading of its child items. For example, Microsoft Windows Explorer might display the expand icon for a node even though there are currently no child items; when the icon is clicked, the control polls for child items, finds none, and removes the expand icon. In these cases clients should listen for a property-changed event on the IUIAutomationExpandCollapsePattern,,CurrentExpandCollapseState property.

    ; Displays all child nodes, controls, or content of the element.
    Expand(ms:=1000) {
        endtime := A_TickCount + ms
        while (A_TickCount < endtime) {
            try {
                comcall(3, this)
                return true
            }
            sleep(100)
        }
    }

    ; Hides all child nodes, controls, or content of the element.
    Collapse() => comcall(4, this)

    ; Retrieves a value that indicates the state, expanded or collapsed, of the element.
    CurrentExpandCollapseState => (comcall(5, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates the state, expanded or collapsed, of the element.
    CachedExpandCollapseState => (comcall(6, this, "int*",&retVal:=0), retVal)
}

class IUIAutomationGridItemPattern extends IUIABase {
    ; Retrieves the element that contains the grid item.
    CurrentContainingGrid => (comcall(3, this, "ptr*",&retVal:=0), IUIAutomationElement(retVal))

    ; Retrieves the zero-based index of the row that contains the grid item.
    CurrentRow => (comcall(4, this, "int*",&retVal:=0), retVal)

    ; Retrieves the zero-based index of the column that contains the item.
    CurrentColumn => (comcall(5, this, "int*",&retVal:=0), retVal)

    ; Retrieves the number of rows spanned by the grid item.
    CurrentRowSpan => (comcall(6, this, "int*",&retVal:=0), retVal)

    ; Retrieves the number of columns spanned by the grid item.
    CurrentColumnSpan => (comcall(7, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached element that contains the grid item.
    CachedContainingGrid => (comcall(8, this, "ptr*",&retVal:=0), IUIAutomationElement(retVal))

    ; Retrieves the cached zero-based index of the row that contains the item.
    CachedRow => (comcall(9, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached zero-based index of the column that contains the grid item.
    CachedColumn => (comcall(10, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached number of rows spanned by a grid item.
    CachedRowSpan => (comcall(11, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached number of columns spanned by the grid item.
    CachedColumnSpan => (comcall(12, this, "int*",&retVal:=0), retVal)
}

class IUIAutomationGridPattern extends IUIABase {
    ; Retrieves a UI Automation element representing an item in the grid.
    GetItem(row, column) => (comcall(3, this, "int",row, "int",column, "ptr*",&element:=0), IUIAutomationGridItemPattern(element))

    ; Hidden rows and columns, depending on the provider implementation, may be loaded in the Microsoft UI Automation tree and will therefore be reflected in the row count and column count properties. If the hidden rows and columns have not yet been loaded they are not counted.

    ; Retrieves the number of rows in the grid.
    CurrentRowCount => (comcall(4, this, "int*",&retVal:=0), retVal)

    ; The number of columns in the grid.
    CurrentColumnCount => (comcall(5, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached number of rows in the grid.
    CachedRowCount => (comcall(6, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached number of columns in the grid.
    CachedColumnCount => (comcall(7, this, "int*",&retVal:=0), retVal)
}

class IUIAutomationInvokePattern extends IUIABase {
    ; Invokes the action of a control, such as a button click.
    ; Calls to this method should return immediately without blocking. However, this behavior depends on the implementation.
    ; NOTE 如果是打开对话框，则可能会卡死
    Invoke() => comcall(3, this)
}

class IUIAutomationItemContainerPattern extends IUIABase {
    ; IUIAutomationItemContainerPattern

    ; Retrieves an element within a containing element, based on a specified property value.
    ; The provider may return an actual IUIAutomationElement interface or a placeholder if the matching element is virtualized.
    ; This method returns E_INVALIDARG if the property requested is not one that the container supports searching over. It is expected that most containers will support Name property, and if appropriate for the container, AutomationId and IsSelected.
    ; This method can be slow, because it may need to traverse multiple objects to find a matching one. When used in a loop to return multiple items, no specific order is defined so long as each item is returned only once (that is, the loop should terminate). This method is also item-centric, not UI-centric, so items with multiple UI representations need to be hit only once.
    ; When the propertyId parameter is specified as 0 (zero), the provider is expected to return the next item after pStartAfter. If pStartAfter is specified as NULL with a propertyId of 0, the provider should return the first item in the container. When propertyId is specified as 0, the value parameter should be VT_EMPTY.
    FindItemByProperty(pStartAfter, propertyId, value) {
        if (A_PtrSize == 4) {
            value := ComVar(value,, true)
            comcall(3, this, "ptr",pStartAfter, "int",propertyId, "int64",numget(value,0,"int64"), "int64",numget(value,8,"int64"), "ptr*",&pFound:=0)
        } else {
            comcall(3, this, "ptr",pStartAfter, "int",propertyId, "ptr",ComVar(value,,true), "ptr*",&pFound:=0)
        }
        if (pFound)
            return IUIAutomationElement(pFound)
        throw TargetError("Target elements not found.")
    }
}

class IUIAutomationLegacyIAccessiblePattern extends IUIABase {

    ; IUIAutomationLegacyIAccessiblePattern

    ; Performs a Microsoft Active Accessibility selection.
    Select(flagsSelect) => comcall(3, this, "int",flagsSelect)

    ; Performs the Microsoft Active Accessibility default action for the element.
    DoDefaultAction() => comcall(4, this)

    ; Sets the Microsoft Active Accessibility value property for the element. This method is supported only for some elements (usually edit controls).
    SetValue(szValue) => comcall(5, this, "wstr",szValue)

    ; Retrieves the Microsoft Active Accessibility child identifier for the element. If the element is not a child element, CHILDID_SELF (0) is returned.
    CurrentChildId => (comcall(6, this, "int*",&pRetVal:=0), pRetVal)

    ; Retrieves the Microsoft Active Accessibility name property of the element. The name of an element can be used to find the element in the element tree when the automation ID property is not supported on the element.
    CurrentName => (comcall(7, this, "ptr*",&pszName:=0), BSTR(pszName))

    ; Retrieves the Microsoft Active Accessibility value property.
    CurrentValue => (comcall(8, this, "ptr*",&pszValue:=0), BSTR(pszValue))

    ; Retrieves the Microsoft Active Accessibility description of the element.
    CurrentDescription => (comcall(9, this, "ptr*",&pszDescription:=0), BSTR(pszDescription))

    ; Retrieves the Microsoft Active Accessibility role identifier of the element.
    CurrentRole => (comcall(10, this, "uint*",&pdwRole:=0), pdwRole)

    ; Retrieves the Microsoft Active Accessibility state identifier for the element.
    CurrentState => (comcall(11, this, "uint*",&pdwState:=0), pdwState)

    ; Retrieves the Microsoft Active Accessibility help string for the element.
    CurrentHelp => (comcall(12, this, "ptr*",&pszHelp:=0), BSTR(pszHelp))

    ; Retrieves the Microsoft Active Accessibility keyboard shortcut property for the element.
    CurrentKeyboardShortcut => (comcall(13, this, "ptr*",&pszKeyboardShortcut:=0), BSTR(pszKeyboardShortcut))

    ; Retrieves the Microsoft Active Accessibility property that identifies the selected children of this element.
    GetCurrentSelection() => (comcall(14, this, "ptr*",&pvarSelectedChildren:=0), IUIAutomationElementArray(pvarSelectedChildren))

    ; Retrieves the Microsoft Active Accessibility default action for the element.
    CurrentDefaultAction => (comcall(15, this, "ptr*",&pszDefaultAction:=0), BSTR(pszDefaultAction))

    ; Retrieves the cached Microsoft Active Accessibility child identifier for the element.
    CachedChildId => (comcall(16, this, "int*",&pRetVal:=0), pRetVal)

    ; Retrieves the cached Microsoft Active Accessibility name property of the element.
    CachedName => (comcall(17, this, "ptr*",&pszName:=0), BSTR(pszName))

    ; Retrieves the cached Microsoft Active Accessibility value property.
    CachedValue => (comcall(18, this, "ptr*",&pszValue:=0), BSTR(pszValue))

    ; Retrieves the cached Microsoft Active Accessibility description of the element.
    CachedDescription => (comcall(19, this, "ptr*",&pszDescription:=0), BSTR(pszDescription))

    ; Retrieves the cached Microsoft Active Accessibility role of the element.
    CachedRole => (comcall(20, this, "uint*",&pdwRole:=0), pdwRole)

    ; Retrieves the cached Microsoft Active Accessibility state identifier for the element.
    CachedState => (comcall(21, this, "uint*",&pdwState:=0), pdwState)

    ; Retrieves the cached Microsoft Active Accessibility help string for the element.
    CachedHelp => (comcall(22, this, "ptr*",&pszHelp:=0), BSTR(pszHelp))

    ; Retrieves the cached Microsoft Active Accessibility keyboard shortcut property for the element.
    CachedKeyboardShortcut => (comcall(23, this, "ptr*",&pszKeyboardShortcut:=0), BSTR(pszKeyboardShortcut))

    ; Retrieves the cached Microsoft Active Accessibility property that identifies the selected children of this element.
    GetCachedSelection() => (comcall(24, this, "ptr*",&pvarSelectedChildren:=0), IUIAutomationElementArray(pvarSelectedChildren))

    ; Retrieves the Microsoft Active Accessibility default action for the element.
    CachedDefaultAction => (comcall(25, this, "ptr*",&pszDefaultAction:=0), BSTR(pszDefaultAction))

    ; Retrieves an IAccessible object that corresponds to the Microsoft UI Automation element.
    ; This method returns NULL if the underlying implementation of the UI Automation element is not a native Microsoft Active Accessibility server; that is, if a client attempts to retrieve the IAccessible interface for an element originally supported by a proxy object from OLEACC.dll, or by the UIA-to-MSAA Bridge.
    GetIAccessible() => (comcall(26, this, "ptr*",&ppAccessible:=0), ComValue(0xd, ppAccessible))
}

class IUIAutomationMultipleViewPattern extends IUIABase {
    ; Retrieves the name of a control-specific view.
    GetViewName(view) => (comcall(3, this, "int",view, "ptr*",&name:=0), BSTR(name))

    ; Sets the view of the control.
    SetCurrentView(view) => comcall(4, this, "int",view)

    ; Retrieves the control-specific identifier of the current view of the control.
    CurrentCurrentView => (comcall(5, this, "int*",&retVal:=0), retVal)

    ; Retrieves a collection of control-specific view identifiers.
    GetCurrentSupportedViews() => (comcall(6, this, "ptr*",&retVal:=0), ComValue(0x2003, retVal))

    ; Retrieves the cached control-specific identifier of the current view of the control.
    CachedCurrentView => (comcall(7, this, "int*",&retVal:=0), retVal)

    ; Retrieves a collection of control-specific view identifiers from the cache.
    GetCachedSupportedViews() => (comcall(8, this, "ptr*",&retVal:=0), ComValue(0x2003, retVal))
}

class IUIAutomationNotCondition extends IUIAutomationCondition {
    GetChild() => (comcall(3, this, "ptr*",&condition:=0), IUIAutomationCondition(condition))
}

class IUIAutomationObjectModelPattern extends IUIABase {
    GetUnderlyingObjectModel() => (comcall(3, this, "ptr*",&retVal:=0), ComValue(0xd, retVal))
}

class IUIAutomationOrCondition extends IUIAutomationAndCondition {
}

class IUIAutomationPropertyCondition extends IUIAutomationCondition {
    PropertyId => (comcall(3, this, "int*",&propertyId:=0), propertyId)
    PropertyValue => (comcall(4, this, "ptr",propertyValue:=ComVar()), propertyValue[])
    PropertyConditionFlags => (comcall(5, this, "int*",&flags:=0), flags)
}

class IUIAutomationProxyFactory extends IUIABase {
    CreateProvider(hwnd, idObject, idChild) => (comcall(3, this, "ptr",hwnd, "int",idObject, "int",idChild, "ptr*",&provider:=0), ComValue(0xd, provider))
    ProxyFactoryId => (comcall(4, this, "ptr*",&factoryId:=0), BSTR(factoryId))
}

class IUIAutomationProxyFactoryEntry extends IUIABase {
    ProxyFactory() => (comcall(3, this, "ptr*",&factory:=0), IUIAutomationProxyFactory(factory))
    ClassName {
        get => (comcall(4, this, "ptr*",&classname:=0), BSTR(classname))
        set => (comcall(9, this, "wstr",Value))
    }
    ImageName {
        get => (comcall(5, this, "ptr*",&imageName:=0), BSTR(imageName))
        set => (comcall(10, this, "wstr",Value))
    }
    AllowSubstringMatch {
        get => (comcall(6, this, "int*",&allowSubstringMatch:=0), allowSubstringMatch)
        set => (comcall(11, this, "int",Value))
    }
    CanCheckBaseClass {
        get => (comcall(7, this, "int*",&canCheckBaseClass:=0), canCheckBaseClass)
        set => (comcall(12, this, "int",Value))
    }
    NeedsAdviseEvents {
        get => (comcall(8, this, "int*",&adviseEvents:=0), adviseEvents)
        set => (comcall(13, this, "int",Value))
    }
    SetWinEventsForAutomationEvent(eventId, propertyId, winEvents) => comcall(14, this, "int",eventId, "Int",propertyId, "ptr",winEvents)
    GetWinEventsForAutomationEvent(eventId, propertyId) => (comcall(15, this, "int",eventId, "Int",propertyId, "ptr*",&winEvents:=0), ComValue(0x200d, winEvents))
}

class IUIAutomationProxyFactoryMapping extends IUIABase {
    Count => (comcall(3, this, "uint*",&count:=0), count)
    GetTable() => (comcall(4, this, "ptr*",&table:=0), ComValue(0x200d, table))
    GetEntry(index) => (comcall(5, this, "int",index, "ptr*",&entry:=0), IUIAutomationProxyFactoryEntry(entry))
    SetTable(factoryList) => comcall(6, this, "ptr",factoryList)
    InsertEntries(before, factoryList) => comcall(7, this, "uint",before, "ptr",factoryList)
    InsertEntry(before, factory) => comcall(8, this, "uint",before, "ptr",factory)
    RemoveEntry(index) => comcall(9, this, "uint",index)
    ClearTable() => comcall(10, this)
    RestoreDefaultTable() => comcall(11, this)
}

class IUIAutomationRangeValuePattern extends IUIABase {
    ; Sets the value of the control.
    SetValue(val) => comcall(3, this, "double",val)

    ; Retrieves the value of the control.
    CurrentValue => (comcall(4, this, "double*",&retVal:=0), retVal)

    ; Indicates whether the value of the element can be changed.
    CurrentIsReadOnly => (comcall(5, this, "int*",&retVal:=0), retVal)

    ; Retrieves the maximum value of the control.
    CurrentMaximum => (comcall(6, this, "double*",&retVal:=0), retVal)

    ; Retrieves the minimum value of the control.
    CurrentMinimum => (comcall(7, this, "double*",&retVal:=0), retVal)

    ; The LargeChange and SmallChange property can support a Not a Number (NaN) value. When retrieving this property, a client can use the _isnan function to determine whether the property is a NaN value.

    ; Retrieves the value that is added to or subtracted from the value of the control when a large change is made, such as when the PAGE DOWN key is pressed.
    CurrentLargeChange => (comcall(8, this, "double*",&retVal:=0), retVal)

    ; Retrieves the value that is added to or subtracted from the value of the control when a small change is made, such as when an arrow key is pressed.
    CurrentSmallChange => (comcall(9, this, "double*",&retVal:=0), retVal)

    ; Retrieves the cached value of the control.
    CachedValue => (comcall(10, this, "double*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the value of the element can be changed.
    CachedIsReadOnly => (comcall(11, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached maximum value of the control.
    CachedMaximum => (comcall(12, this, "double*",&retVal:=0), retVal)

    ; Retrieves the cached minimum value of the control.
    CachedMinimum => (comcall(13, this, "double*",&retVal:=0), retVal)

    ; Retrieves, from the cache, the value that is added to or subtracted from the value of the control when a large change is made, such as when the PAGE DOWN key is pressed.
    CachedLargeChange => (comcall(14, this, "double*",&retVal:=0), retVal)

    ; Retrieves, from the cache, the value that is added to or subtracted from the value of the control when a small change is made, such as when an arrow key is pressed.
    CachedSmallChange => (comcall(15, this, "double*",&retVal:=0), retVal)
}

class IUIAutomationScrollItemPattern extends IUIABase {
    ; Scrolls the content area of a container object to display the UI Automation element within the visible region (viewport) of the container.
    ; This method does not provide the ability to specify the position of the element within the viewport.
    ScrollIntoView() => comcall(3, this)
}

class IUIAutomationScrollPattern extends IUIABase {
    ; Scrolls the visible region of the content area horizontally and vertically.
    Scroll(horizontalAmount, verticalAmount) => comcall(3, this, "int",horizontalAmount, "int",verticalAmount)

    ; Sets the horizontal and vertical scroll positions as a percentage of the total content area within the UI Automation element.
    ; This method is useful only when the content area of the control is larger than the visible region.
    SetScrollPercent(horizontalPercent, verticalPercent) => comcall(4, this, "double",horizontalPercent, "double",verticalPercent)

    ; Retrieves the horizontal scroll position.
    CurrentHorizontalScrollPercent => (comcall(5, this, "double*",&retVal:=0), retVal)

    ; Retrieves the vertical scroll position.
    CurrentVerticalScrollPercent => (comcall(6, this, "double*",&retVal:=0), retVal)

    ; Retrieves the horizontal size of the viewable region of a scrollable element.
    CurrentHorizontalViewSize => (comcall(7, this, "double*",&retVal:=0), retVal)

    ; Retrieves the vertical size of the viewable region of a scrollable element.
    CurrentVerticalViewSize => (comcall(8, this, "double*",&retVal:=0), retVal)

    ; Indicates whether the element can scroll horizontally.
    ; This property can be dynamic. For example, the content area of the element might not be larger than the current viewable area, meaning that the property is FALSE. However, resizing the element or adding child items can increase the bounds of the content area beyond the viewable area, making the property TRUE.
    CurrentHorizontallyScrollable => (comcall(9, this, "int*",&retVal:=0), retVal)

    ; Indicates whether the element can scroll vertically.
    CurrentVerticallyScrollable => (comcall(10, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached horizontal scroll position.
    CachedHorizontalScrollPercent => (comcall(11, this, "double*",&retVal:=0), retVal)

    ; Retrieves the cached vertical scroll position.
    CachedVerticalScrollPercent => (comcall(12, this, "double*",&retVal:=0), retVal)

    ; Retrieves the cached horizontal size of the viewable region of a scrollable element.
    CachedHorizontalViewSize => (comcall(13, this, "double*",&retVal:=0), retVal)

    ; Retrieves the cached vertical size of the viewable region of a scrollable element.
    CachedVerticalViewSize => (comcall(14, this, "double*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the element can scroll horizontally.
    CachedHorizontallyScrollable => (comcall(15, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the element can scroll vertically.
    CachedVerticallyScrollable => (comcall(16, this, "int*",&retVal:=0), retVal)
}

class IUIAutomationSelectionItemPattern extends IUIABase {
    ; Clears any selected items and then selects the current element.
    Select() => comcall(3, this)

    ; Adds the current element to the collection of selected items.
    AddToSelection() => comcall(4, this)

    ; Removes this element from the selection.
    ; An error code is returned if this element is the only one in the selection and the selection container requires at least one element to be selected.
    RemoveFromSelection() => comcall(5, this)

    ; Indicates whether this item is selected.
    CurrentIsSelected => (comcall(6, this, "int*",&retVal:=0), retVal)

    ; Retrieves the element that supports IUIAutomationSelectionPattern and acts as the container for this item.
    CurrentSelectionContainer => (comcall(7, this, "ptr*",&retVal:=0), IUIAutomationElement(retVal))

    ; A cached value that indicates whether this item is selected.
    CachedIsSelected => (comcall(8, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached element that supports IUIAutomationSelectionPattern and acts as the container for this item.
    CachedSelectionContainer => (comcall(9, this, "ptr*",&retVal:=0), IUIAutomationElement(retVal))
}

class IUIAutomationSelectionPattern extends IUIABase {
    ; Retrieves the selected elements in the container.
    GetCurrentSelection() => (comcall(3, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Indicates whether more than one item in the container can be selected at one time.
    CurrentCanSelectMultiple => (comcall(4, this, "int*",&retVal:=0), retVal)

    ; Indicates whether at least one item must be selected at all times.
    CurrentIsSelectionRequired => (comcall(5, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached selected elements in the container.
    GetCachedSelection() => (comcall(6, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves a cached value that indicates whether more than one item in the container can be selected at one time.
    CachedCanSelectMultiple => (comcall(7, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether at least one item must be selected at all times.
    CachedIsSelectionRequired => (comcall(8, this, "int*",&retVal:=0), retVal)
}

class IUIAutomationSpreadsheetPattern extends IUIABase {
    GetItemByName(name) => (comcall(3, this, "wstr",name, "ptr*",&element:=0), IUIAutomationElement(element))
}

class IUIAutomationSpreadsheetItemPattern extends IUIABase {
    CurrentFormula => (comcall(3, this, "ptr*",&retVal:=0), BSTR(retVal))
    GetCurrentAnnotationObjects() => (comcall(4, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))
    GetCurrentAnnotationTypes() => (comcall(5, this, "ptr*",&retVal:=0), ComValue(0x2003, retVal))
    CachedFormul => (comcall(6, this, "ptr*",&retVal:=0), BSTR(retVal))
    GetCachedAnnotationObjects() => (comcall(7, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))
    GetCachedAnnotationTypes() => (comcall(8, this, "ptr*",&retVal:=0), ComValue(0x2003, retVal))
}

class IUIAutomationStylesPattern extends IUIABase {
    CurrentStyleId => (comcall(3, this, "int*",&retVal:=0), retVal)
    CurrentStyleName => (comcall(4, this, "ptr*",&retVal:=0), BSTR(retVal))
    CurrentFillColor => (comcall(5, this, "int*",&retVal:=0), retVal)
    CurrentFillPatternStyle => (comcall(6, this, "ptr*",&retVal:=0), BSTR(retVal))
    CurrentShape => (comcall(7, this, "ptr*",&retVal:=0), BSTR(retVal))
    CurrentFillPatternColor => (comcall(8, this, "int*",&retVal:=0), retVal)
    CurrentExtendedProperties => (comcall(9, this, "ptr*",&retVal:=0), BSTR(retVal))
    GetCurrentExtendedPropertiesAsArray() {
        comcall(10, this, "ptr*",&propertyArray:=0, "int*",&propertyCount:=0), arr := []
        for p in NativeArray(propertyArray, propertyCount) {
            arr.push({
                PropertyName: BSTR(numget(p, 0, "ptr")),
                PropertyValue: BSTR(numget(p, A_PtrSize, "ptr"))
            })
        }
        return arr
    }
    CachedStyleId => (comcall(11, this, "int*",&retVal:=0), retVal)
    CachedStyleName => (comcall(12, this, "ptr*",&retVal:=0), BSTR(retVal))
    CachedFillColor => (comcall(13, this, "int*",&retVal:=0), retVal)
    CachedFillPatternStyle => (comcall(14, this, "ptr*",&retVal:=0), BSTR(retVal))
    CachedShape => (comcall(15, this, "ptr*",&retVal:=0), BSTR(retVal))
    CachedFillPatternColor => (comcall(16, this, "int*",&retVal:=0), retVal)
    CachedExtendedProperties => (comcall(17, this, "ptr*",&retVal:=0), BSTR(retVal))
    GetCachedExtendedPropertiesAsArray() {
        comcall(18, this, "ptr*",&propertyArray:=0, "int*",&propertyCount:=0), arr := []
        for p in NativeArray(propertyArray, propertyCount)
            arr.push({
                PropertyName: BSTR(numget(p, "ptr")),
                PropertyValue: BSTR(numget(p, A_PtrSize, "ptr"))
            })
        return arr
    }
}

class IUIAutomationSynchronizedInputPattern extends IUIABase {
    ; Causes the Microsoft UI Automation provider to start listening for mouse or keyboard input.
    ; When matching input is found, the provider checks whether the target element matches the current element. If they match, the provider raises the UIA_InputReachedTargetEventId event; otherwise it raises the UIA_InputReachedOtherElementEventId or UIA_InputDiscardedEventId event.
    ; After receiving input of the specified type, the provider stops checking for input and continues as normal.
    ; If the provider is already listening for input, this method returns E_INVALIDOPERATION.
    StartListening(inputType) => comcall(3, this, "int",inputType)

    ; Causes the Microsoft UI Automation provider to stop listening for mouse or keyboard input.
    Cancel() => comcall(4, this)
}

class IUIAutomationTableItemPattern extends IUIABase {
    ; Retrieves the row headers associated with a table item or cell.
    GetCurrentRowHeaderItems() => (comcall(3, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves the column headers associated with a table item or cell.
    GetCurrentColumnHeaderItems() => (comcall(4, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves the cached row headers associated with a table item or cell.
    GetCachedRowHeaderItems() => (comcall(5, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves the cached column headers associated with a table item or cell.
    GetCachedColumnHeaderItems() => (comcall(6, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))
}

class IUIAutomationTablePattern extends IUIABase {
    ; Retrieves a collection of UI Automation elements representing all the row headers in a table.
    GetCurrentRowHeaders() => (comcall(3, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves a collection of UI Automation elements representing all the column headers in a table.
    GetCurrentColumnHeaders() => (comcall(4, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves the primary direction of traversal for the table.
    CurrentRowOrColumnMajor => (comcall(5, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached collection of UI Automation elements representing all the row headers in a table.
    GetCachedRowHeaders() => (comcall(6, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves a cached collection of UI Automation elements representing all the column headers in a table.
    GetCachedColumnHeaders() => (comcall(7, this, "ptr*",&retVal:=0), IUIAutomationElementArray(retVal))

    ; Retrieves the cached primary direction of traversal for the table.
    CachedRowOrColumnMajor => (comcall(8, this, "int*",&retVal:=0), retVal)
}

class IUIAutomationTextChildPattern extends IUIABase {
    TextContainer => (comcall(3, this, "ptr*",&container:=0), IUIAutomationElement(container))
    TextRange => (comcall(4, this, "ptr*",&range:=0), IUIAutomationTextRange(range))
}

class IUIAutomationTextEditPattern extends IUIABase {
    GetActiveComposition() => (comcall(3, this, "ptr*",&range:=0), IUIAutomationTextRange(range))
    GetConversionTarget() => (comcall(4, this, "ptr*",&range:=0), IUIAutomationTextRange(range))
}

class IUIAutomationTextPattern extends IUIABase {
    ; Retrieves the degenerate (empty) text range nearest to the specified screen coordinates.
    /*
    * A text range that wraps a child object is returned if the screen coordinates are within the coordinates of an image, hyperlink, Microsoft Excel spreadsheet, or other embedded object.
    * Because hidden text is not ignored, this method retrieves a degenerate range from the visible text closest to the specified coordinates.
    * The implementation of RangeFromPoint in Windows Internet Explorer 9 does not return the expected result. Instead, clients should,
    * 1. Call the GetVisibleRanges method to retrieve an array of visible text ranges.Call the GetVisibleRanges method to retrieve an array of visible text ranges.
    * 2. Call the GetVisibleRanges method to retrieve an array of visible text ranges.For each text range in the array, call IUIAutomationTextRange,,GetBoundingRectangles to retrieve the bounding rectangles.
    * 3. Call the GetVisibleRanges method to retrieve an array of visible text ranges.Check the bounding rectangles to find the text range that occupies the particular screen coordinates.
    */
    RangeFromPoint(pt) => (comcall(3, this, "int64",pt, "ptr*",&range:=0), IUIAutomationTextRange(range))

    ; Retrieves a text range enclosing a child element such as an image, hyperlink, Microsoft Excel spreadsheet, or other embedded object.
    ; If there is no text in the range that encloses the child element, a degenerate (empty) range is returned.
    ; The child parameter is either a child of the element associated with a IUIAutomationTextPattern or from the array of children of a IUIAutomationTextRange.
    RangeFromChild(child) => (comcall(4, this, "ptr",child, "ptr*",&range:=0), IUIAutomationTextRange(range))

    ; Retrieves a collection of text ranges that represents the currently selected text in a text-based control.
    ; If the control supports the selection of multiple, non-contiguous spans of text, the ranges collection receives one text range for each selected span.
    ; If the control contains only a single span of selected text, the ranges collection receives a single text range.
    ; If the control contains a text insertion point but no text is selected, the ranges collection receives a degenerate (empty) text range at the position of the text insertion point.
    ; If the control does not contain a text insertion point or does not support text selection, ranges is set to NULL.
    ; Use the IUIAutomationTextPattern,,SupportedTextSelection property to test whether a control supports text selection.
    GetSelection() => (comcall(5, this, "ptr*",&ranges:=0), IUIAutomationTextRangeArray(ranges))

    ; Retrieves an array of disjoint text ranges from a text-based control where each text range represents a contiguous span of visible text.
    ; If the visible text consists of one contiguous span of text, the ranges array will contain a single text range that represents all of the visible text.
    ; If the visible text consists of multiple, disjoint spans of text, the ranges array will contain one text range for each visible span, beginning with the first visible span, and ending with the last visible span. Disjoint spans of visible text can occur when the content of a text-based control is partially obscured by an overlapping window or other object, or when a text-based control with multiple pages or columns has content that is partially scrolled out of view.
    ; IUIAutomationTextPattern,,GetVisibleRanges retrieves a degenerate (empty) text range if no text is visible, if all text is scrolled out of view, or if the text-based control contains no text.
    GetVisibleRanges() => (comcall(6, this, "ptr*",&ranges:=0), IUIAutomationTextRangeArray(ranges))

    ; Retrieves a text range that encloses the main text of a document.
    ; Some auxiliary text such as headers, footnotes, or annotations might not be included.
    DocumentRange() => (comcall(7, this, "ptr*",&range:=0), IUIAutomationTextRange(range))

    ; Retrieves a value that specifies the type of text selection that is supported by the control.
    SupportedTextSelection => (comcall(8, this, "int*",&supportedTextSelection:=0), supportedTextSelection)
}

class IUIAutomationTextRange extends IUIABase {
    ; Retrieves a IUIAutomationTextRange identical to the original and inheriting all properties of the original.
    ; The range can be manipulated independently of the original.
    Clone() => (comcall(3, this, "ptr*",&clonedRange:=0), IUIAutomationTextRange(clonedRange))

    ; Retrieves a value that specifies whether this text range has the same endpoints as another text range.
    ; This method compares the endpoints of the two text ranges, not the text in the ranges. The ranges are identical if they share the same endpoints. If two text ranges have different endpoints, they are not identical even if the text in both ranges is exactly the same.
    Compare(range) => (comcall(4, this, "ptr",range, "int*",&areSame:=0), areSame)

    ; Retrieves a value that specifies whether the start or end endpoint of this text range is the same as the start or end endpoint of another text range.
    CompareEndpoints(srcEndPoint, range, targetEndPoint) => (comcall(5, this, "int",srcEndPoint, "ptr",range, "int",targetEndPoint, "int*",&compValue:=0), compValue)

    ; Normalizes the text range by the specified text unit. The range is expanded if it is smaller than the specified unit, or shortened if it is longer than the specified unit.
    ; Client applications such as screen readers use this method to retrieve the full word, sentence, or paragraph that exists at the insertion point or caret position.
    ; Despite its name, the ExpandToEnclosingUnit method does not necessarily expand a text range. Instead, it "normalizes" a text range by moving the endpoints so that the range encompasses the specified text unit. The range is expanded if it is smaller than the specified unit, or shortened if it is longer than the specified unit. If the range is already an exact quantity of the specified units, it remains unchanged. The following diagram shows how ExpandToEnclosingUnit normalizes a text range by moving the endpoints of the range.
    ; ExpandToEnclosingUnit defaults to the next largest text unit supported if the specified text unit is not supported by the control. The order, from smallest unit to largest, is as follows, Character Format Word Line Paragraph Page Document
    ; ExpandToEnclosingUnit respects both visible and hidden text.
    ExpandToEnclosingUnit(textUnit) => comcall(6, this, "int",textUnit)

    ; Retrieves a text range subset that has the specified text attribute value.
    ; The FindAttribute method retrieves matching text regardless of whether the text is hidden or visible. Use UIA_IsHiddenAttributeId to check text visibility.
    FindAttribute(attr, val, backward) {
        if (A_PtrSize == 4) {
            val := ComVar(val,, true)
            comcall(7, this, "int",attr, "int64",numget(val,0,"int64"), "int64",numget(val,8,"int64"), "int",backward, "ptr*",&found:=0)
        } else {
            comcall(7, this, "int",attr, "ptr",ComVar(val,,true), "int",backward, "ptr*",&found:=0)
        }
        if (found)
            return IUIAutomationTextRange(found)
        throw TargetError("Target textrange not found.")
    }

    ; Retrieves a text range subset that contains the specified text. There is no differentiation between hidden and visible text.
    FindText(text, backward, ignoreCase) {
        if (comcall(8, this, "wstr",text, "int",backward, "int",ignoreCase, "ptr*",&found:=0), found)
            return IUIAutomationTextRange(found)
        throw TargetError("Target textrange not found.")
    }

    ; Retrieves the value of the specified text attribute across the entire text range.
    ; The type of value retrieved by this method depends on the attr parameter. For example, calling GetAttributeValue with the attr parameter set to UIA_FontNameAttributeId returns a string that represents the font name of the text range, while calling GetAttributeValue with attr set to UIA_IsItalicAttributeId would return a boolean.
    ; If the attribute specified by attr is not supported, the value parameter receives a value that is equivalent to the IUIAutomation,,ReservedNotSupportedValue property.
    ; A text range can include more than one value for a particular attribute. For example, if a text range includes more than one font, the FontName attribute will have multiple values. An attribute with more than one value is called a mixed attribute. You can determine if a particular attribute is a mixed attribute by comparing the value retrieved from GetAttributeValue with the UIAutomation,,ReservedMixedAttributeValue property.
    ; The GetAttributeValue method retrieves the attribute value regardless of whether the text is hidden or visible. Use UIA_ IsHiddenAttributeId to check text visibility.
    GetAttributeValue(attr) => (comcall(9, this, "int",attr, "ptr",val:=ComVar()), val[])

    ; Retrieves a collection of bounding rectangles for each fully or partially visible line of text in a text range.
    GetBoundingRectangles() => (comcall(10, this, "ptr*",&boundingRects:=0), ComValue(0x2005, boundingRects))

    ; Returns the innermost UI Automation element that encloses the text range.
    GetEnclosingElement() => (comcall(11, this, "ptr*",&enclosingElement:=0), IUIAutomationElement(enclosingElement))

    ; Returns the plain text of the text range.
    GetText(maxLength := -1) => (comcall(12, this, "int",maxLength, "ptr*",&text:=0), BSTR(text))

    ; Moves the text range forward or backward by the specified number of text units .
    /*
    * IUIAutomationTextRange,,Move moves the text range to span a different part of the text; it does not alter the text in any way.
    * For a non-degenerate (non-empty) text range, IUIAutomationTextRange,,Move normalizes and moves the range by performing the following steps.
    * The text range is collapsed to a degenerate (empty) range at the starting endpoint.
    * If necessary, the resulting text range is moved backward in the document to the beginning of the requested text unit boundary.
    * The text range is moved forward or backward in the document by the requested number of text unit boundaries.
    * The text range is expanded from the degenerate state by moving the ending endpoint forward by one requested text unit boundary.
    * If any of the preceding steps fail, the text range is left unchanged. If the text range cannot be moved as far as the requested number of text units, but can be moved by a smaller number of text units, the text range is moved by the smaller number of text units and moved is set to the number of text units moved.
    * For a degenerate text range, IUIAutomationTextRange,,Move simply moves the text insertion point by the specified number of text units.
    * When moving a text range, IUIAutomationTextRange,,Move ignores the boundaries of any embedded objects in the text.
    * IUIAutomationTextRange,,Move respects both hidden and visible text.
    * If a text-based control does not support the text unit specified by the unit parameter, IUIAutomationTextRange,,Move substitutes the next larger supported text unit. The size of the text units, from smallest unit to largest, is as follows.
    * Character
    * Format
    * Word
    * Line
    * Paragraph
    * Page
    * Document
    */
    Move(unit, count) => (comcall(13, this, "int",unit, "int",count, "int*",&moved:=0), moved)

    ; Moves one endpoint of the text range the specified number of text units within the document range.
    MoveEndpointByUnit(endpoint, unit, count) {	; TextPatternRangeEndpoint , TextUnit
        comcall(14, this, "int",endpoint, "int",unit, "int",count, "int*",&moved:=0)	; TextPatternRangeEndpoint,TextUnit
        return moved
    }

    ; Moves one endpoint of the current text range to the specified endpoint of a second text range.
    ; If the endpoint being moved crosses the other endpoint of the same text range, that other endpoint is moved also, resulting in a degenerate (empty) range and ensuring the correct ordering of the endpoints (that is, the start is always less than or equal to the end).
    MoveEndpointByRange(srcEndPoint, range, targetEndPoint) {	; TextPatternRangeEndpoint , IUIAutomationTextRange , TextPatternRangeEndpoint
        comcall(15, this, "int",srcEndPoint, "ptr",range, "int",targetEndPoint)
    }

    ; Selects the span of text that corresponds to this text range, and removes any previous selection.
    ; If the Select method is called on a text range object that represents a degenerate (empty) text range, the text insertion point moves to the starting endpoint of the text range.
    Select() => comcall(16, this)

    ; Adds the text range to the collection of selected text ranges in a control that supports multiple, disjoint spans of selected text.
    ; The text insertion point moves to the newly selected text. If AddToSelection is called on a text range object that represents a degenerate (empty) text range, the text insertion point moves to the starting endpoint of the text range.
    AddToSelection() => comcall(17, this)

    ; Removes the text range from an existing collection of selected text in a text container that supports multiple, disjoint selections.
    ; The text insertion point moves to the area of the removed highlight. Providing a degenerate text range also moves the insertion point.
    RemoveFromSelection() => comcall(18, this)

    ; Causes the text control to scroll until the text range is visible in the viewport.
    ; The method respects both hidden and visible text. If the text range is hidden, the text control will scroll only if the hidden text has an anchor in the viewport.
    ; A Microsoft UI Automation client can check text visibility by calling IUIAutomationTextRange,,GetAttributeValue with the attr parameter set to UIA_IsHiddenAttributeId.
    ScrollIntoView(alignToTop) => comcall(19, this, "int",alignToTop)

    ; Retrieves a collection of all embedded objects that fall within the text range.
    GetChildren() => (comcall(20, this, "ptr*",&children:=0), IUIAutomationElementArray(children))
}

class IUIAutomationTextRangeArray extends IUIABase {
    ; Retrieves the number of text ranges in the collection.
    Length => (comcall(3, this, "int*",&length:=0), length)

    ; Retrieves a text range from the collection.
    GetElement(index) => (comcall(4, this, "int",index, "ptr*",&element:=0), IUIAutomationTextRange(element))
}

;pp
; 各种控件和支持的 pattern 类型 https://docs.microsoft.com/en-us/windows/win32/winauto/uiauto-controlpatternmapping
; https://docs.microsoft.com/en-us/windows/win32/winauto/uiauto-controlpatternsoverview
;控件模式
;   Grid 控件模式：呈现表格界面的控件使用 来公开表中的行数和列数，并使客户端能够从表中检索项目。
;   Selection SysTreeView321可用 https://docs.microsoft.com/en-us/windows/win32/winauto/uiauto-implementingselection
;   Invoke 控件模式：按钮等可调用的控件
;   Scroll 控件模式：用于具有滚动条的控件（例如列表框，列表视图或组合框）
;   文本控件模式 https://docs.microsoft.com/en-us/windows/win32/winauto/uiauto-about-text-and-textrange-patterns
;   主查 Text 和 TextRange 两种控件模式，后者可以指定部分内容
;可以询问控件所支持的【控件模式】，然后通过所支持的控件模式公开的属性，方法，事件和结构与控件进行交互。
;因为每个控件模式代表一个单独的功能，所以可以【组合控件模式】以描述特定控件支持的全部功能集。
;方法：操控控件
;属性和事件：提供状态和功能信息
;提供者和客户中的控制模式
;   接口没有直接暴露给客户端，而是由UI Automation核心用来实现另一组客户端接口。
;   例如，提供程序公开滚动功能，通过UI自动化 IScrollProvider 和 UI自动化公开通过功能给客户 IUIAutomationScrollPattern
;某些控件并不总是支持相同的控件模式集，比如多行的滚动功能，内容足够多才会启用
class IUIAutomationTogglePattern extends IUIABase {
    ; Cycles through the toggle states of the control.
    ; A control cycles through its states in this order, ToggleState_On, ToggleState_Off and, if supported, ToggleState_Indeterminate.
    Toggle() => comcall(3, this)

    ; Retrieves the state of the control.
    CurrentToggleState => (comcall(4, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached state of the control.
    CachedToggleState => (comcall(5, this, "int*",&retVal:=0), retVal)
}

class IUIAutomationTransformPattern extends IUIABase {
    ; An element cannot be moved, resized or rotated such that its resulting screen location would be completely outside the coordinates of its container and inaccessible to the keyboard or mouse. For example, when a top-level window is moved completely off-screen or a child object is moved outside the boundaries of the container's viewport, the object is placed as close to the requested screen coordinates as possible with the top or left coordinates overridden to be within the container boundaries.

    ; Moves the UI Automation element.
    Move(x, y) => comcall(3, this, "double",x, "double",y)

    ; Resizes the UI Automation element.
    ; When called on a control that supports split panes, this method can have the side effect of resizing other contiguous panes.
    Resize(width, height) => comcall(4, this, "double",width, "double",height)

    ; Rotates the UI Automation element.
    Rotate(degrees) => comcall(5, this, "double",degrees)

    ; Indicates whether the element can be moved.
    CurrentCanMove => (comcall(6, this, "int*",&retVal:=0), retVal)

    ; Indicates whether the element can be resized.
    CurrentCanResize => (comcall(7, this, "int*",&retVal:=0), retVal)

    ; Indicates whether the element can be rotated.
    CurrentCanRotate => (comcall(8, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the element can be moved.
    CachedCanMove => (comcall(9, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the element can be resized.
    CachedCanResize => (comcall(10, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the element can be rotated.
    CachedCanRotate => (comcall(11, this, "int*",&retVal:=0), retVal)
}

class IUIAutomationTreeWalker extends IUIABase {
    ; The structure of the Microsoft UI Automation tree changes as the visible UI elements on the desktop change.
    ; An element can have additional child elements that do not match the current view condition and thus are not returned when navigating the element tree.

    ; Retrieves the parent element of the specified UI Automation element.
    GetParentElement(element) => (comcall(3, this, "ptr",element, "ptr*",&parent:=0), IUIAutomationElement(parent))

    ; Retrieves the first child element of the specified UI Automation element.
    GetFirstChildElement(element) => (comcall(4, this, "ptr",element, "ptr*",&first:=0), IUIAutomationElement(first))

    ; Retrieves the last child element of the specified UI Automation element.
    GetLastChildElement(element) => (comcall(5, this, "ptr",element, "ptr*",&last:=0), IUIAutomationElement(last))

    ; Retrieves the next sibling element of the specified UI Automation element, and caches properties and control patterns.
    GetNextSiblingElement(element) => (comcall(6, this, "ptr",element, "ptr*",&next:=0), IUIAutomationElement(next))

    ; Retrieves the previous sibling element of the specified UI Automation element, and caches properties and control patterns.
    GetPreviousSiblingElement(element) => (comcall(7, this, "ptr",element, "ptr*",&previous:=0), IUIAutomationElement(previous))

    ; Retrieves the ancestor element nearest to the specified Microsoft UI Automation element in the tree view.
    ; The element is normalized by navigating up the ancestor chain in the tree until an element that satisfies the view condition (specified by a previous call to IUIAutomationTreeWalker,,Condition) is reached. If the root element is reached, the root element is returned, even if it does not satisfy the view condition.
    ; This method is useful for applications that obtain references to UI Automation elements by hit-testing. The application might want to work only with specific types of elements, and can use IUIAutomationTreeWalker,,Normalize to make sure that no matter what element is initially retrieved (for example, when a scroll bar gets the input focus), only the element of interest (such as a content element) is ultimately retrieved.
    NormalizeElement(element) => (comcall(8, this, "ptr",element, "ptr*",&normalized:=0), IUIAutomationElement(normalized))

    ; Retrieves the parent element of the specified UI Automation element, and caches properties and control patterns.
    GetParentElementBuildCache(element, cacheRequest) => (comcall(9, this, "ptr",element, "ptr",cacheRequest, "ptr*",&parent:=0), IUIAutomationElement(parent))

    ; Retrieves the first child element of the specified UI Automation element, and caches properties and control patterns.
    GetFirstChildElementBuildCache(element, cacheRequest) => (comcall(10, this, "ptr",element, "ptr",cacheRequest, "ptr*",&first:=0), IUIAutomationElement(first))

    ; Retrieves the last child element of the specified UI Automation element, and caches properties and control patterns.
    GetLastChildElementBuildCache(element, cacheRequest) => (comcall(11, this, "ptr",element, "ptr",cacheRequest, "ptr*",&last:=0), IUIAutomationElement(last))

    ; Retrieves the next sibling element of the specified UI Automation element, and caches properties and control patterns.
    GetNextSiblingElementBuildCache(element, cacheRequest) => (comcall(12, this, "ptr",element, "ptr",cacheRequest, "ptr*",&next:=0), IUIAutomationElement(next))

    ; Retrieves the previous sibling element of the specified UI Automation element, and caches properties and control patterns.
    GetPreviousSiblingElementBuildCache(element, cacheRequest) => (comcall(13, this, "ptr",element, "ptr",cacheRequest, "ptr*",&previous:=0), IUIAutomationElement(previous))

    ; Retrieves the ancestor element nearest to the specified Microsoft UI Automation element in the tree view, prefetches the requested properties and control patterns, and stores the prefetched items in the cache.
    NormalizeElementBuildCache(element, cacheRequest) => (comcall(14, this, "ptr",element, "ptr",cacheRequest, "ptr*",&normalized:=0), IUIAutomationElement(normalized))

    ; Retrieves the condition that defines the view of the UI Automation tree. This property is read-only.
    ; The condition that defines the view. This is the interface that was passed to CreateTreeWalker.
    Condition() => (comcall(15, this, "ptr*",&condition:=0), IUIAutomationCondition(condition))
}

class IUIAutomationValuePattern extends IUIABase {
    ; Sets the value of the element.
    ; The CurrentIsEnabled property must be TRUE, and the IUIAutomationValuePattern,,CurrentIsReadOnly property must be FALSE.
    SetValue(val) => comcall(3, this, "wstr",val)

    ; Retrieves the value of the element.
    ; Single-line edit controls support programmatic access to their contents through IUIAutomationValuePattern. However, multiline edit controls do not support this control pattern, and their contents must be retrieved by using IUIAutomationTextPattern.
    ; This property does not support the retrieval of formatting information or substring values. IUIAutomationTextPattern must be used in these scenarios as well.
    CurrentValue => (comcall(4, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Indicates whether the value of the element is read-only.
    CurrentIsReadOnly => (comcall(5, this, "int*",&retVal:=0), retVal)

    ; Retrieves the cached value of the element.
    CachedValue => (comcall(6, this, "ptr*",&retVal:=0), BSTR(retVal))

    ; Retrieves a cached value that indicates whether the value of the element is read-only.
    ; This property must be TRUE for IUIAutomationValuePattern,,SetValue to succeed.
    CachedIsReadOnly => (comcall(7, this, "int*",&retVal:=0), retVal)
}

class IUIAutomationVirtualizedItemPattern extends IUIABase {
    ; Creates a full UI Automation element for a virtualized item.
    ; A virtualized item is represented by a placeholder automation element in the UI Automation tree. The Realize method causes the provider to make full information available for the item so that a full UI Automation element can be created for the item.
    Realize() => comcall(3, this)
}

class IUIAutomationWindowPattern extends IUIABase {
    ; Closes the window.
    ; When called on a split pane control, this method closes the pane and removes the associated split. This method may also close all other panes, depending on implementation.
    Close() => comcall(3, this)

    ; Causes the calling code to block for the specified time or until the associated process enters an idle state, whichever completes first.
    WaitForInputIdle(milliseconds) => (comcall(4, this, "int",milliseconds, "int*",&success:=0), success)

    ; Minimizes, maximizes, or restores the window.
    SetWindowVisualState(state) => comcall(5, this, "int",state)

    ; Indicates whether the window can be maximized.
    CurrentCanMaximize => (comcall(6, this, "int*",&retVal:=0), retVal)

    ; Indicates whether the window can be minimized.
    CurrentCanMinimize => (comcall(7, this, "int*",&retVal:=0), retVal)

    ; Indicates whether the window is modal.
    CurrentIsModal => (comcall(8, this, "int*",&retVal:=0), retVal)

    ; Indicates whether the window is the topmost element in the z-order.
    CurrentIsTopmost => (comcall(9, this, "int*",&retVal:=0), retVal)

    ; Retrieves the visual state of the window; that is, whether it is in the normal, maximized, or minimized state.
    CurrentWindowVisualState => (comcall(10, this, "int*",&retVal:=0), retVal)

    ; Retrieves the current state of the window for the purposes of user interaction.
    CurrentWindowInteractionState => (comcall(11, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the window can be maximized.
    CachedCanMaximize => (comcall(12, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the window can be minimized.
    CachedCanMinimize => (comcall(13, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the window is modal.
    CachedIsModal => (comcall(14, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates whether the window is the topmost element in the z-order.
    CachedIsTopmost => (comcall(15, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates the visual state of the window; that is, whether it is in the normal, maximized, or minimized state.
    CachedWindowVisualState => (comcall(16, this, "int*",&retVal:=0), retVal)

    ; Retrieves a cached value that indicates the current state of the window for the purposes of user interaction.
    CachedWindowInteractionState => (comcall(17, this, "int*",&retVal:=0), retVal)
}

/*	event handle sample
* HandleAutomationEvent(pself,sender,eventId) ; IUIAutomationElement , EVENTID
* HandleFocusChangedEvent(pself,sender) ; IUIAutomationElement
* HandlePropertyChangedEvent(pself,sender,propertyId,newValue) ; IUIAutomationElement, PROPERTYID, VARIANT
* HandleStructureChangedEvent(pself,sender,changeType,runtimeId) ; IUIAutomationElement, StructureChangeType, SAFEARRAY
*/
IUIA_EventHandler(funcobj) {
    if !HasMethod(funcobj, "Call")
        throw TypeError("it is not a func", -2)
    buf := buffer(A_PtrSize * 5)
    cb1 := CallbackCreate(EventHandler, "F", 3)
    cb2 := CallbackCreate(EventHandler, "F", 1)
    cb3 := CallbackCreate(funcobj, "F")
    numput("ptr",buf.Ptr + A_PtrSize, "ptr",cb1, "ptr",cb2, "ptr",cb2, "ptr",cb3, buf)
    buf.DefineProp("__Delete", { call: (p*) => (CallbackFree(cb1), CallbackFree(cb2), CallbackFree(cb3)) })
    return buf

    EventHandler(self, param1:=0, param2:=0) {
        static str := "                                        "
        if (param1) {
            dllcall('ole32\StringFromGUID2', "ptr",param1, "wstr", str, "int",80)
            switch str, false {
                case "{00000000-0000-0000-C000-000000000046}", "{146c3c17-f12e-4e22-8c27-f894b9b79c69}", "{40cd37d4-c756-4b0c-8c6f-bddfeeb13b50}", "{e81d1b4e-11c5-42f8-9754-e7036c79f054}", "{c270f6b5-5c69-4290-9745-7a7f97169468}": return numput("ptr",self, param2) * 0
                default: return 0x80004002
            }
        }
    }
}

IUIA_RuntimeIdToString(runtimeId) {
    str := ""
    for v in runtimeId
        str .= "." Format("{:X}", v)
    return LTrim(str, ".")
}

IUIA_RuntimeIdFromString(str) {
    t := StrSplit(str, ".")
    arr := ComObjArray(3, t.Length)
    for v in t
        arr[A_Index - 1] := integer("0x" v)
    return arr
}
