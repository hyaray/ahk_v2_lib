# ahk_v2_lib
`AutoHotkey64.exe` and v2-beta libs

`AutoHotkey64.exe` is base on [thqby/AutoHotkey_H](https://github.com/thqby/AutoHotkey_H),
and compiled `ahkDefine.ahk` using [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe) to avoid some problems.

compile commandline: `"Ahk2Exe.exe" /in "d:\ahkDefine.ahk" /out "D:\AutoHotkey64.exe" /base "c:\AutoHotkey\AutoHotkey64.exe" /resourceid #2`
`/resourceid #2` is the key param.
