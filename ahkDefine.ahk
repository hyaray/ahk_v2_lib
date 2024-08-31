#Requires AutoHotkey v2.0-beta
#SingleInstance Force
#warn Unreachable, off
#MapCaseSense off
SetControlDelay(-1)
SetKeyDelay(-1)
CoordMode("mouse", "window")
CoordMode("tooltip", "window")
CoordMode("pixel", "window")
CoordMode("caret", "window")
CoordMode("menu", "window")

;@Ahk2Exe-SetProductVersion %A_AhkVersion%hy

A_UserProfile := EnvGet("USERPROFILE")
A_LocalAppdata := EnvGet("LOCALAPPDATA")
;TODO 添加 A_LineDir

;map 可用.访问属性(OA首页按F4出错)
;map.prototype.DefineProp('__get', {call: (self, key, *) => self[key]})
;map.prototype.DefineProp('__set', {call: (self, key, params, value) => self[key] := value})

;@Ahk2Exe-IgnoreBegin
;@Ahk2Exe-Obey U_bits, = %A_PtrSize% * 8
;@Ahk2Exe-Obey U_type, = "%A_IsUnicode%" ? "Unicode" : "ANSI"
;@Ahk2Exe-ExeName %A_ScriptName~\.[^\.]+$%_%U_type%_%U_bits%
;@Ahk2Exe-Let vvvv = "v"
CodeVersion := "1.2.3.4"
;@Ahk2Exe-Let U_version = %A_PriorLine~U)^(.+"){1}(.+)".*$~$2%
company := "My Company"
;@Ahk2Exe-Let U_company = %A_PriorLine~U)^(.+"){3}(.+)".*$~$2%
;@Ahk2Exe-IgnoreEnd

;#include lib\JSON.ahk
;#include lib\struct.ahk

#include lib\Class_String.ahk
#include lib\Class_Number.ahk
#include lib\Class_Array.ahk
#include lib\Class_Map.ahk
#include lib\Class_Date.ahk
#include lib\Class_Timer.ahk
#include lib\Yaml.ahk
#include lib\WinHttpRequest.ahk
#include lib\Class_Gui.ahk
#include lib\LVICE_XXS.ahk
#include lib\WatchFolder.ahk

#include lib\Socket.ahk
#include lib\Class_CDP.ahk
#include lib\Class_Clipboard.ahk
#include lib\CentBrowser.ahk
#include lib\msedge.ahk
#include lib\Class_Pinyin.ahk
#include lib\hyaray.ahk
#include lib\Class_XYXY.ahk
#include lib\Class_Mouse.ahk
#include lib\Class_Ctrl.ahk
#include lib\Class_UIA.ahk
#include lib\Class_Gdip.ahk

#include lib\Explorer.ahk
