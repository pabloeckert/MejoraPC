If WScript.Arguments.Count < 1 Then WScript.Quit 1

Dim args : args = ""
Dim i
For i = 0 To WScript.Arguments.Count - 1
    args = args & " " & WScript.Arguments(i)
Next

Dim script : script = WScript.ScriptFullName
script = Left(script, InStrRev(script, "\lib\"))
Dim cmd : cmd = "powershell.exe -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & script & "08-monitor.ps1""" & args

CreateObject("WScript.Shell").Run cmd, 0, False
