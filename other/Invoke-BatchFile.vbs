' WSH Wrapper for Generic Commands

Option Explicit
Dim WScriptShell, Args, CmdLine

Set Args = WScript.Arguments

if Args.Count = 0 then
  WScript.Echo "Error. " & WScript.ScriptName & " No parameters passed."
  WScript.Quit(3)
end if

If Args.Count > 1 Then
  For i = 1 To Args.Count - 1
    CmdLine = CmdLine & " " & Args.Item(i)
  Next
End If

Set WScriptShell = CreateObject("WScript.Shell")

Set ExitCode = WScriptShell.Run CmdLine, 0, True

If Not IsNumeric(ExitCode) Then ExitCode = 3

set WScriptShell=Nothing 
WScript.Quit(Exitcode)

