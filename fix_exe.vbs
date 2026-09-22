' Fix EXE association via VBScript - works even when .exe association is broken
' Run: double-click this file, or Task Manager -> File -> Run new task -> wscript.exe fix_exe.vbs

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

If Not WshShell.Run("net session", 0, True) = 0 Then
    ' Not admin, try elevate
    On Error Resume Next
    CreateObject("Shell.Application").ShellExecute "wscript.exe", """" & WScript.ScriptFullName & """", "", "runas", 1
    If Err.Number <> 0 Then
        MsgBox "Please right-click and Run as Administrator, or run via Task Manager as admin", 16, "Admin Required"
    End If
    WScript.Quit
End If

MsgBox "Fixing EXE association now - Click OK to continue. Explorer will restart.", 64, "EXE Fix"

' Delete user overrides
On Error Resume Next
WshShell.RegDelete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.exe\"
WshShell.RegDelete "HKCU\Software\Classes\.exe\"
WshShell.RegDelete "HKCU\Software\Classes\exefile\"

' Restore core keys
WshShell.RegWrite "HKCR\.exe\", "exefile", "REG_SZ"
WshShell.RegWrite "HKCR\.exe\Content Type", "application/x-msdownload", "REG_SZ"
WshShell.RegWrite "HKCR\.exe\PersistentHandler\", "{098f2470-bae0-11cd-b579-08002b30bfeb}", "REG_SZ"

WshShell.RegWrite "HKCR\exefile\", "Application", "REG_SZ"
WshShell.RegWrite "HKCR\exefile\DefaultIcon\", "%1", "REG_SZ"
WshShell.RegWrite "HKCR\exefile\shell\open\command\", """%1"" %*", "REG_SZ"
WshShell.RegWrite "HKCR\exefile\shell\open\command\IsolatedCommand", """%1"" %*", "REG_SZ"

' Also HKLM
WshShell.RegWrite "HKLM\SOFTWARE\Classes\.exe\", "exefile", "REG_SZ"
WshShell.RegWrite "HKLM\SOFTWARE\Classes\.exe\Content Type", "application/x-msdownload", "REG_SZ"
WshShell.RegWrite "HKLM\SOFTWARE\Classes\exefile\shell\open\command\", """%1"" %*", "REG_SZ"

' Remove DisallowRun
WshShell.RegDelete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun"
WshShell.RegDelete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun"

' Fix assoc and ftype via cmd
WshShell.Run "cmd /c assoc .exe=exefile", 0, True
WshShell.Run "cmd /c ftype exefile=""%1"" %*", 0, True

MsgBox "EXE association restored! Now restarting Explorer..." & vbCrLf & "Try opening any .exe file. If still fails, restart PC and run full antivirus scan.", 64, "Fix Complete - Restarting Explorer"

WshShell.Run "taskkill /f /im explorer.exe", 0, True
WScript.Sleep 1500
WshShell.Run "explorer.exe", 0, False

MsgBox "Done! Log: Try opening exe now. If still broken, run fix_exe.bat as admin for deeper IFEO check.", 64, "EXE Fix Done"
