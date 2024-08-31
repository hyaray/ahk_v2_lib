#Requires AutoHotKey v2.0-beta.1

; ======================================================================================================================
; Function:       Notifies about changes within folders.
;                 This is a rewrite of HotKeyIt's WatchDirectory() released at
;                    https://www.autohotkey.com/boards/viewtopic.php?t=95659
;                    https://github.com/AHK-just-me/WatchFolder
; Tested with:    AHK 2.0-beta.1 (U32/U64)
; Tested on:      Win 10 Pro x64
; Usage:          WatchFolder(Folder, UserFunc[, SubTree := False[, Watch := 3]])
; Parameters:
;     Folder      -  The full qualified path of the folder to be watched.
;                    Pass the string "**PAUSE" and set UserFunc to either True or False to pause respectively resume
;                    watching.
;                    Pass the string "**END" and an arbitrary value in UserFunc to completely stop watching anytime.
;                    If not, it will be done internally on exit.
;     UserFunc    -  The name of a user-defined function to call on changes. The function must accept at least
;                    two parameters:
;                    1: The path of the affected folder. The final backslash is not included even if it is a drive's
;                       root directory (e.g. C:).
;                    2: An array of change notifications containing the following keys:
;                       Action:  One of the integer values specified as FILE_ACTION_... (see below).
;                                In case of renaming Action is set to FILE_ACTION_RENAMED (4).
;                       Name:    The full path of the changed file or folder.
;                       OldName: The previous path in case of renaming, otherwise not used.
;                       IsDir:   True if Name is a directory; otherwise False. In case of Action 2 (removed) IsDir
;                                is always False.
;                    Pass the string "**DEL" to remove the directory from the list of watched folders.
;     SubTree     -  Set to true if you want the whole subtree to be watched (i.e. the contents of all sub-folders).
;                    Default: False - sub-folders aren't watched.
;     Watch       -  The kind of changes to watch for. This can be one or any combination of the FILE_NOTIFY_CHANGES_...
;                    values specified below.
;                    Default: 0x03 - FILE_NOTIFY_CHANGE_FILE_NAME + FILE_NOTIFY_CHANGE_DIR_NAME
; Return values:
;     Returns True on success; otherwise False.
; Change history:
;     1.0.00.00/2021-10-??/just me        -  initial release
; License:
;     The Unlicense -> http://unlicense.org/
; Remarks:
;     Due to the limits of the API function WaitForMultipleObjects() you cannot watch more than
;     MAXIMUM_WAIT_OBJECTS (64) folders simultaneously.
; MSDN:
;     ReadDirectoryChangesW          docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-readdirectorychangesw
;     FILE_NOTIFY_CHANGE_FILE_NAME   = 1   (0x00000001) : Notify about renaming, creating, or deleting a file.
;     FILE_NOTIFY_CHANGE_DIR_NAME    = 2   (0x00000002) : Notify about creating or deleting a directory.
;     FILE_NOTIFY_CHANGE_ATTRIBUTES  = 4   (0x00000004) : Notify about attribute changes.
;     FILE_NOTIFY_CHANGE_SIZE        = 8   (0x00000008) : Notify about any file-size change.
;     FILE_NOTIFY_CHANGE_LAST_WRITE  = 16  (0x00000010) : Notify about any change to the last write-time of files.
;     FILE_NOTIFY_CHANGE_LAST_ACCESS = 32  (0x00000020) : Notify about any change to the last access time of files.
;     FILE_NOTIFY_CHANGE_CREATION    = 64  (0x00000040) : Notify about any change to the creation time of files.
;     FILE_NOTIFY_CHANGE_SECURITY    = 256 (0x00000100) : Notify about any security-descriptor change.
;     FILE_NOTIFY_INFORMATION        docs.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-file_notify_information
;     FILE_ACTION_ADDED              = 1   (0x00000001) : The file was added to the directory.
;     FILE_ACTION_REMOVED            = 2   (0x00000002) : The file was removed from the directory.
;     FILE_ACTION_MODIFIED           = 3   (0x00000003) : The file was modified.
;     FILE_ACTION_RENAMED            = 4   (0x00000004) : The file was renamed (not defined by Microsoft).
;     FILE_ACTION_RENAMED_OLD_NAME   = 4   (0x00000004) : The file was renamed and this is the old name.
;     FILE_ACTION_RENAMED_NEW_NAME   = 5   (0x00000005) : The file was renamed and this is the new name.
;     GetOverlappedResult            docs.microsoft.com/en-us/windows/win32/api/ioapiset/nf-ioapiset-getoverlappedresult
;     CreateFile                     docs.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew
;     FILE_FLAG_BACKUP_SEMANTICS     = 0x02000000
;     FILE_FLAG_OVERLAPPED           = 0x40000000
; ======================================================================================================================
WatchFolder(Folder, UserFunc, SubTree := False, Watch := 0x03) {
   ; Static DummyObject := {Base: {__Delete: Func("WatchFolder").Bind("**END", "")}}
   Static Dummy := OnExit(WatchFolder.Bind("**END", "Exit"))
   Static TimerID := "**" . A_TickCount
   Static TimerFunc := WatchFolder.Bind(TimerID, "")
   Static MAXIMUM_WAIT_OBJECTS := 64
   Static MAX_DIR_PATH := 260 - 12 + 1
   Static SizeOfFNI := 0xFFFF ; size of the FILE_NOTIFY_INFORMATION structure buffer (64 KB)
   Static SizeOfOVL := 32     ; size of the OVERLAPPED structure (64-bit)
   Static FolderObj := {}
   Static EventMap := Map()
   Static WaitObjects := 0
   Static BytesRead := 0
   Static Paused := False
   ; ===================================================================================================================
   If (Folder = "")
      Return False
   SetTimer(TimerFunc, 0)
   RebuildWaitObjects := False
   ; ===================================================================================================================
   If (Folder = TimerID) { ; called by timer
      If (ObjCount := EventMap.Count) && !Paused {
         ObjIndex := DllCall("WaitForMultipleObjects", "UInt", ObjCount, "Ptr", WaitObjects, "Int", 0, "UInt", 0, "UInt")
         While (ObjIndex >= 0) && (ObjIndex < ObjCount) {
            Event := NumGet(WaitObjects, ObjIndex * A_PtrSize, "UPtr")
            Folder := EventMap[Event]
            If DllCall("GetOverlappedResult", "Ptr", Folder.Handle, "Ptr", Folder.OVL, "UIntP", &BytesRead, "Int", True) {
               Changes := []
               FNIAddr := Folder.FNI.Ptr
               FNIMax := FNIAddr + BytesRead
               OffSet := 0
               PrevIndex := 0
               PrevAction := 0
               PrevName := ""
               Loop {
                  FNIAddr += Offset
                  OffSet := NumGet(FNIAddr + 0, "UInt")
                  Action := NumGet(FNIAddr + 4, "UInt")
                  Length := NumGet(FNIAddr + 8, "UInt") // 2
                  Name   := Folder.Folder . "\" . StrGet(FNIAddr + 12, Length, "UTF-16")
                  IsDir  := InStr(FileExist(Name), "D") ? 1 : 0
                  PrevIndex := Changes.Length
                  If (Name = PrevName) {
                     If (Action = PrevAction)
                        Continue
                     If (Action = 1) && (PrevAction = 2) {
                        PrevAction := Action
                        Changes.RemoveAt(PrevIndex)
                        Continue
                     }
                  }
                  If (Action = 4)
                     Changes.Push({Action: Action, IsDir: 0, Name: "", OldName: Name})
                  Else If (Action = 5) && (PrevAction = 4) {
                     Changes[PrevIndex].Name := Name
                     Changes[PrevIndex].IsDir := IsDir
                  }
                  Else
                     Changes.Push({Action: Action, IsDir: IsDir, Name: Name, OldName: ""})
                  PrevAction := Action
                  PrevName := Name
               } Until (Offset = 0) || ((FNIAddr + Offset) > FNIMax)
               If (Changes.Length > 0)
                  Folder.Func.Call(Folder.Folder, Changes)
               DllCall("ResetEvent", "Ptr", Event)
               DllCall("ReadDirectoryChangesW", "Ptr", Folder.Handle, "Ptr", Folder.FNI, "UInt", SizeOfFNI,
                                                "Int", Folder.SubTree, "UInt", Folder.Watch, "UInt", 0,
                                                "Ptr", Folder.OVL, "Ptr", 0)
            }
            ObjIndex := DllCall("WaitForMultipleObjects", "UInt", ObjCount, "Ptr", WaitObjects, "Int", 0, "UInt", 0, "UInt")
            Sleep(0)
         }
      }
   }
   ; ===================================================================================================================
   Else If (Folder = "**PAUSE") { ; called to pause/resume watching
      Paused := !!UserFunc
      RebuildObjects := Paused
   }
   ; ===================================================================================================================
   Else If (Folder = "**END") { ; called to stop watching
      For Event, Folder In EventMap {
         DllCall("CloseHandle", "Ptr", Event)
         DllCall("CloseHandle", "Ptr", Folder.Handle)
      }
      FolderObj := {}
      EventMap := []
      Paused := False
      Return (UserFunc = "Exit" ? False : True)
   }
   ; ===================================================================================================================
   Else { ; called to add, update, or remove folders
      Folder := RTrim(Folder, "\")
      LongPath := ""
      VarSetStrCapacity(&LongPath, MAX_DIR_PATH)
      If !DllCall("GetLongPathNameW", "Str", Folder, "Ptr", StrPtr(LongPath), "UInt", MAX_DIR_PATH, "UInt")
         Return False
      VarSetStrCapacity(&LongPath, -1)
      Folder := LongPath
      If FolderObj.HasOwnProp(Folder) { ; update or remove
         Event := FolderObj.%Folder%
         DllCall("CloseHandle", "Ptr", EventMap[Event].Handle)
         DllCall("CloseHandle", "Ptr", Event)
         EventMap.Delete(Event)
         FolderObj.DeleteProp(Folder)
         RebuildWaitObjects := True
      }
      If InStr(FileExist(Folder), "D") && (UserFunc != "**DEL") && (EventMap.Count < MAXIMUM_WAIT_OBJECTS) {
         If (UserFunc Is Func) && (UserFunc.MinParams >= 2) && (Watch &= 0x017F) {
            Handle := DllCall("CreateFile", "Str", Folder . "\", "UInt", 0x01, "UInt", 0x07, "Ptr",0, "UInt", 0x03,
                                            "UInt", 0x42000000, "Ptr", 0, "UPtr")
            If (Handle > 0) {
               Event := DllCall("CreateEvent", "Ptr", 0, "Int", 1, "Int", 0, "Ptr", 0)
               FNI := Buffer(SizeOfFNI, 0)
               OVL := Buffer(SizeOfOVL, 0)
               NumPut("Ptr", Event, OVL, 8 + (A_PtrSize * 2))
               DllCall("ReadDirectoryChangesW", "Ptr", Handle, "Ptr", FNI, "UInt", SizeOfFNI, "Int", SubTree
                                              , "UInt", Watch, "UInt", 0, "Ptr", OVL, "Ptr", 0)
               EventMap[Event] := {Folder: Folder, Func: UserFunc, Handle: Handle, Subtree: !!SubTree,
                                   Watch: Watch, FNI: FNI, OVL: OVL}
               FolderObj.%Folder% := Event
               RebuildWaitObjects := True
            }
         }
      }
      If (RebuildWaitObjects) {
         WaitObjects := Buffer(MAXIMUM_WAIT_OBJECTS * A_PtrSize, 0)
         Addr := WaitObjects.Ptr
         For Event In EventMap
            Addr := NumPut("Ptr", Event, Addr)
      }
   }
   ; ===================================================================================================================
   If (EventMap.Count > 0)
      SetTimer(TimerFunc, -100)
   Return (RebuildWaitObjects) ; returns True on success, otherwise False
}
