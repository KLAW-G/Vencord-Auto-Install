[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateRange(1, 5)]
    [int]$Passes = 1,
    [string]$LogFile = "",
    [switch]$WaitForInternet,
    [string]$Branches = "stable,canary,ptb",
    [switch]$DisableDiscordStartup,
    [switch]$DisableDiscordStartupOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$installerUrl = "https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe"
$checksumsUrl = "https://github.com/Vencord/Installer/releases/latest/download/checksums.sha256"
$script:LogFilePath = $LogFile

function Write-Status {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host $Message -ForegroundColor $Color
    if (-not [string]::IsNullOrWhiteSpace($script:LogFilePath)) {
        try {
            Add-Content -LiteralPath $script:LogFilePath -Value $Message -Encoding UTF8
        }
        catch {
            # Logging must never stop the installation.
        }
    }
}

function Write-Step {
    param([string]$Message)
    Write-Status -Message "`n==> $Message" -Color Cyan
}

function Wait-ForRequiredNetwork {
    Write-Step "Waiting for an internet connection"
    $failedChecks = 0

    while ($true) {
        $response = $null
        try {
            $request = [Net.HttpWebRequest]::Create("https://github.com/Vencord/Installer/releases/latest")
            $request.Method = "HEAD"
            $request.AllowAutoRedirect = $true
            $request.Timeout = 8000
            $request.ReadWriteTimeout = 8000
            $request.UserAgent = "Vencord-Auto-Installer"
            $response = $request.GetResponse()

            $statusCode = [int]$response.StatusCode
            if ($statusCode -ge 200 -and $statusCode -lt 400) {
                Write-Status -Message "[OK] Internet connection is ready." -Color Green
                return
            }
        }
        catch {
            # The machine may still be obtaining Wi-Fi/Ethernet connectivity during sign-in.
        }
        finally {
            if ($null -ne $response) {
                $response.Close()
            }
        }

        $failedChecks++
        if (($failedChecks % 12) -eq 0) {
            Write-Status -Message "Still waiting for internet access..."
        }
        Start-Sleep -Seconds 5
    }
}

function Disable-DiscordStartupEntries {
    try {
        $entryNames = @("Discord", "DiscordCanary", "DiscordPTB")
        $runPaths = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
        )

        foreach ($runPath in $runPaths) {
            if (-not (Test-Path -LiteralPath $runPath)) {
                continue
            }

            $runEntries = Get-ItemProperty -LiteralPath $runPath
            foreach ($property in $runEntries.PSObject.Properties) {
                if ($property.Name -like "PS*") {
                    continue
                }

                $command = [string]$property.Value
                if ($property.Name -like "*Discord*" -or $command -match "\\Discord(?:Canary|PTB)?\\Update\.exe") {
                    $entryNames += $property.Name
                }
            }
        }

        $entryNames = @($entryNames | Select-Object -Unique)
        $disabledData = New-Object byte[] 12
        $disabledData[0] = 3
        [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc()).CopyTo($disabledData, 4)

        $approvedPaths = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32"
        )

        foreach ($approvedPath in $approvedPaths) {
            if (-not (Test-Path -LiteralPath $approvedPath)) {
                New-Item -Path $approvedPath -Force | Out-Null
            }

            foreach ($entryName in $entryNames) {
                New-ItemProperty -LiteralPath $approvedPath `
                    -Name $entryName `
                    -Value ([byte[]]$disabledData.Clone()) `
                    -PropertyType Binary `
                    -Force | Out-Null
            }
        }

        Write-Status -Message ("[OK] Disabled Discord Startup entries: {0}" -f ($entryNames -join ", ")) -Color Green
        return 0
    }
    catch {
        Write-Status -Message ("[ERROR] Could not disable Discord Startup entries: {0}" -f $_.Exception.Message) -Color Red
        return 1
    }
}

function Get-DiscordTargets {
    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        throw "LOCALAPPDATA could not be resolved."
    }

    $candidates = @(
        [pscustomobject]@{ DisplayName = "Discord Stable"; Branch = "stable"; Folder = "Discord" },
        [pscustomobject]@{ DisplayName = "Discord Canary"; Branch = "canary"; Folder = "DiscordCanary" },
        [pscustomobject]@{ DisplayName = "Discord PTB"; Branch = "ptb"; Folder = "DiscordPTB" }
    )

    $found = @()
    foreach ($candidate in $candidates) {
        $root = Join-Path $localAppData $candidate.Folder
        $validApps = @(
            Get-ChildItem -LiteralPath $root -Directory -Filter "app-*" -ErrorAction SilentlyContinue |
                Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "resources") -PathType Container }
        )

        if ($validApps.Count -gt 0) {
            $found += [pscustomobject]@{
                DisplayName = $candidate.DisplayName
                Branch      = $candidate.Branch
                Root        = $root
            }
        }
    }

    return @($found)
}

function Invoke-VencordInstall {
    $tempFiles = @()
    $oldProgressPreference = $ProgressPreference

    try {
        if (-not [string]::IsNullOrWhiteSpace($script:LogFilePath)) {
            try {
                Set-Content -LiteralPath $script:LogFilePath -Value ("Vencord installation started: {0}" -f (Get-Date)) -Encoding UTF8
            }
            catch {
                $script:LogFilePath = ""
            }
        }

        if ($DisableDiscordStartup) {
            $disableResult = Disable-DiscordStartupEntries
            if ($disableResult -ne 0) {
                return $disableResult
            }
        }

        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        if ($WaitForInternet) {
            Wait-ForRequiredNetwork
        }

        Write-Step "Detecting installed Discord versions"
        $allowedBranches = @("stable", "canary", "ptb")
        $requestedBranches = @(
            $Branches.Split(",") |
                ForEach-Object { $_.Trim().ToLowerInvariant() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )

        if ($requestedBranches.Count -eq 0) {
            throw "No Discord branch was selected."
        }
        foreach ($requestedBranch in $requestedBranches) {
            if ($allowedBranches -notcontains $requestedBranch) {
                throw "Unsupported Discord branch: $requestedBranch"
            }
        }

        $targets = @(
            Get-DiscordTargets |
                Where-Object { $requestedBranches -contains $_.Branch }
        )

        if ($targets.Count -eq 0) {
            Write-Status -Message "None of the selected Discord versions is installed." -Color Yellow
            Write-Status -Message "Open the Startup manager and select an installed Discord version."
            return 2
        }

        foreach ($target in $targets) {
            Write-Status -Message ("[FOUND] {0} - {1}" -f $target.DisplayName, $target.Root) -Color Green
        }

        $nonce = [Guid]::NewGuid().ToString("N")
        $tempRoot = [IO.Path]::GetTempPath()
        $installerPath = Join-Path $tempRoot ("VencordInstallerCli-{0}.exe" -f $nonce)
        $checksumsPath = Join-Path $tempRoot ("VencordChecksums-{0}.sha256" -f $nonce)
        $tempFiles = @($installerPath, $checksumsPath)

        Write-Step "Downloading the official Vencord installer"
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -UseBasicParsing -Uri $checksumsUrl -OutFile $checksumsPath
        Invoke-WebRequest -UseBasicParsing -Uri $installerUrl -OutFile $installerPath

        Write-Step "Verifying the installer SHA-256 checksum"
        $checksumText = Get-Content -LiteralPath $checksumsPath -Raw
        $checksumMatch = [regex]::Match(
            $checksumText,
            "^(?<hash>[a-f0-9]{64})[ `t]+\*?VencordInstallerCli\.exe[ `t]*$",
            [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Multiline
        )

        if (-not $checksumMatch.Success) {
            throw "The official checksum file does not contain an entry for VencordInstallerCli.exe."
        }

        $expectedHash = $checksumMatch.Groups["hash"].Value.ToUpperInvariant()
        $actualHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToUpperInvariant()
        if ($actualHash -ne $expectedHash) {
            throw "Security check failed: the downloaded installer checksum does not match the official checksum."
        }
        Write-Status -Message "[OK] Checksum verified: $actualHash" -Color Green

        if ($DryRun) {
            Write-Step "Dry run complete - no Discord installation was changed (configured passes: $Passes)"
            return 0
        }

        Write-Status -Message "`nDiscord may close automatically while it is being patched." -Color Yellow
        $failed = @()

        foreach ($target in $targets) {
            $targetSucceeded = $false

            for ($pass = 1; $pass -le $Passes; $pass++) {
                Write-Step ("Installing Vencord on {0} - pass {1} of {2}" -f $target.DisplayName, $pass, $Passes)

                $outputNonce = [Guid]::NewGuid().ToString("N")
                $stdoutPath = Join-Path $tempRoot ("Vencord-{0}.stdout.log" -f $outputNonce)
                $stderrPath = Join-Path $tempRoot ("Vencord-{0}.stderr.log" -f $outputNonce)
                $tempFiles += @($stdoutPath, $stderrPath)

                try {
                    $installerProcess = Start-Process -FilePath $installerPath `
                        -ArgumentList @("-install", "-branch", $target.Branch) `
                        -WindowStyle Hidden `
                        -RedirectStandardOutput $stdoutPath `
                        -RedirectStandardError $stderrPath `
                        -Wait `
                        -PassThru
                    $installerExitCode = $installerProcess.ExitCode
                }
                catch {
                    $installerExitCode = 1
                    Write-Status -Message ("Installer process error: {0}" -f $_.Exception.Message) -Color Red
                }

                foreach ($outputPath in @($stdoutPath, $stderrPath)) {
                    if (Test-Path -LiteralPath $outputPath -PathType Leaf) {
                        foreach ($outputLine in @(Get-Content -LiteralPath $outputPath -ErrorAction SilentlyContinue)) {
                            if (-not [string]::IsNullOrWhiteSpace($outputLine)) {
                                Write-Status -Message ("    {0}" -f $outputLine) -Color DarkGray
                            }
                        }
                    }
                }

                $targetSucceeded = ($installerExitCode -eq 0)
                if ($targetSucceeded) {
                    Write-Status -Message ("[SUCCESS] {0} - pass {1}" -f $target.DisplayName, $pass) -Color Green
                }
                else {
                    Write-Status -Message ("[FAILED] {0} - pass {1} (exit code {2})" -f $target.DisplayName, $pass, $installerExitCode) -Color Red
                }
            }

            if (-not $targetSucceeded) {
                $failed += $target.DisplayName
            }
        }

        if ($failed.Count -gt 0) {
            Write-Status -Message "`nVencord could not be installed on: $($failed -join ', ')" -Color Red
            return 1
        }

        Write-Status -Message "`nVencord was installed successfully on every detected Discord version ($Passes passes each)." -Color Green
        Write-Status -Message "Open Discord and look for the Vencord section in Settings."
        return 0
    }
    catch {
        Write-Status -Message "`n[ERROR] $($_.Exception.Message)" -Color Red
        return 1
    }
    finally {
        $ProgressPreference = $oldProgressPreference
        foreach ($tempFile in $tempFiles) {
            if (Test-Path -LiteralPath $tempFile -PathType Leaf) {
                Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

if ($DisableDiscordStartupOnly) {
    exit (Disable-DiscordStartupEntries)
}

exit (Invoke-VencordInstall)
