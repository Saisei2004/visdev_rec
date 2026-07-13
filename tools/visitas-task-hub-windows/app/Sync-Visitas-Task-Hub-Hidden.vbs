Option Explicit

Dim shell, fileSystem, scriptDirectory, syncScript, command, exitCode

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
syncScript = fileSystem.BuildPath(scriptDirectory, "Sync-Visitas-Task-Hub.cmd")
command = shell.ExpandEnvironmentStrings("%ComSpec%") & " /d /c " & Chr(34) & syncScript & Chr(34)

exitCode = shell.Run(command, 0, True)
WScript.Quit exitCode
