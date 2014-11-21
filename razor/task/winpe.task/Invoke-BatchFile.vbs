' WSH Wrapper for Generic Commands

' Option Explicit
Dim WScriptShell, Args, CmdLine, ExitCode

WScript.Interactive = False

Set Args = WScript.Arguments

if Args.Count = 0 then
  WScript.Echo "Error. " & WScript.ScriptName & " No parameters passed."
  WScript.Quit(3)
end if

Dim i
If Args.Count > 0 Then
  For i = 0 To Args.Count - 1
    CmdLine = CmdLine & " " & Args.Item(i)
  Next
End If

Set WScriptShell = CreateObject("WScript.Shell")

WScript.Echo CmdLine
WScriptShell.Run "cmd /c " & CmdLine, 0, False

' TODO, the following sections do not work.

If Not IsNumeric(ExitCode) Then ExitCode = 3

set WScriptShell=Nothing 
WScript.Quit(Exitcode)

