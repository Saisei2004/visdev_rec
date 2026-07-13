Option Explicit

Dim shell, fileSystem, scriptDirectory, trayLauncher, wscript, command

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
trayLauncher = fileSystem.BuildPath(scriptDirectory, "Start-Visitas-Task-Hub-Tray-Hidden.vbs")
wscript = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\wscript.exe"
command = Chr(34) & wscript & Chr(34) & " //B //Nologo " & Chr(34) & trayLauncher & Chr(34)

shell.Run command, 0, False
WScript.Sleep 1500
shell.Run "http://127.0.0.1:7700/", 1, False
