#SingleInstance Force
#MapCaseSense off
#warn Unreachable, off
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

#include Class_String.ahk
#include Class_Number.ahk
#include Class_Array.ahk
#include Class_Object.ahk

#include hyaray.ahk
#include WebSocket.ahk
#include Class_Mouse.ahk
#include Class_Ctrl.ahk
#include Class_UIA.ahk
#include Class_Gdip.ahk

#include Class_CDP.ahk
#include CentBrowser.ahk

