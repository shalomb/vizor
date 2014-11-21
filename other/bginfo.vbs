' VBScript

Option Explicit
Dim WScript, ProcessEnvVars, SysDrive, CmdLine

Set WScriptShell = CreateObject("WScript.Shell")
Set ProcessEnvVars = WScriptShell.Environment("Process")

SysDrive = ProcessEnvVars("SYSTEMDRIVE")

CmdLine = SysDrive & "\bginfo.exe " & SysDrive & "\bgconfig.bgi /timer:0 /nolicprompt"

Set ExitCode = WScriptShell.Run CmdLine
If Not IsNumeric(ExitCode) Then ExitCode = 3

WScript.Quit(Exitcode)

