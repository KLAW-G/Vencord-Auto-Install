Option Explicit

Dim shell, fileSystem, scriptDirectory, managerFile, mshtaPath, command

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
managerFile = fileSystem.BuildPath(scriptDirectory, "Startup-Manager.hta")
mshtaPath = fileSystem.BuildPath(shell.ExpandEnvironmentStrings("%WINDIR%\System32"), "mshta.exe")

command = Chr(34) & mshtaPath & Chr(34) & " " & Chr(34) & managerFile & Chr(34)

shell.Run command, 1, False
