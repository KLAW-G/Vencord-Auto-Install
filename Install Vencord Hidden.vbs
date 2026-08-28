Option Explicit

Dim shell, fileSystem, scriptDirectory, powerShellScript, logFile, command, result, message
Dim silentMode, startupMode, waitForInternet, launchBranches, argument, branch

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

silentMode = False
startupMode = False
waitForInternet = False
launchBranches = ""
For Each argument In WScript.Arguments
    If LCase(argument) = "/silent" Or LCase(argument) = "-silent" Then
        silentMode = True
    End If
    If LCase(argument) = "/startup" Or LCase(argument) = "-startup" Then
        silentMode = True
        startupMode = True
        waitForInternet = True
    End If
    If LCase(argument) = "/wait-network" Then
        waitForInternet = True
    End If
    If Left(LCase(argument), 8) = "/launch:" Then
        launchBranches = Mid(argument, 9)
    End If
Next

scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
powerShellScript = fileSystem.BuildPath(scriptDirectory, "Install-Vencord-All.ps1")
If Not fileSystem.FileExists(powerShellScript) Then
    powerShellScript = fileSystem.BuildPath(fileSystem.BuildPath(scriptDirectory, "utilis"), "Install-Vencord-All.ps1")
End If
logFile = fileSystem.BuildPath(scriptDirectory, "Vencord-Install.log")

command = "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File " _
    & Quote(powerShellScript) & " -Passes 2 -LogFile " & Quote(logFile)

If waitForInternet Then
    command = command & " -WaitForInternet"
End If
If startupMode Then
    command = command & " -DisableDiscordStartup"
End If

' Window style 0 keeps PowerShell and the official installer fully hidden.
result = shell.Run(command, 0, True)

If startupMode And result = 0 And launchBranches <> "" Then
    For Each branch In Split(launchBranches, ",")
        LaunchDiscord LCase(branch)
    Next
    WScript.Sleep 10000
    EnforceDiscordStartupDisabled powerShellScript
End If

If Not silentMode Then
    If result = 0 Then
        message = "Vencord was installed twice on every detected Discord version."
        shell.Popup message, 8, "Vencord Installer", 64
    Else
        message = "Vencord installation had a problem. Check Vencord-Install.log in this folder."
        shell.Popup message, 12, "Vencord Installer", 16
    End If
End If

Function Quote(value)
    Quote = Chr(34) & value & Chr(34)
End Function

Sub LaunchDiscord(branchName)
    Dim folderName, executableName, updatePath, launchArguments

    Select Case branchName
        Case "stable"
            folderName = "Discord"
            executableName = "Discord.exe"
            launchArguments = " --processStart Discord.exe"
        Case "canary"
            folderName = "DiscordCanary"
            executableName = "DiscordCanary.exe"
            launchArguments = " --processStart DiscordCanary.exe --process-start-args " & Quote("--start-inactive")
        Case "ptb"
            folderName = "DiscordPTB"
            executableName = "DiscordPTB.exe"
            launchArguments = " --processStart DiscordPTB.exe --process-start-args " & Quote("--start-inactive")
        Case Else
            Exit Sub
    End Select

    updatePath = fileSystem.BuildPath(fileSystem.BuildPath(shell.ExpandEnvironmentStrings("%LOCALAPPDATA%"), folderName), "Update.exe")
    If fileSystem.FileExists(updatePath) Then
        shell.Run Quote(updatePath) & launchArguments, 0, False
    End If
End Sub

Sub EnforceDiscordStartupDisabled(scriptPath)
    Dim disableCommand
    disableCommand = "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File " _
        & Quote(scriptPath) & " -DisableDiscordStartupOnly"
    shell.Run disableCommand, 0, True
End Sub
