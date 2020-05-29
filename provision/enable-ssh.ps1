$opensshUrl = 'https://github.com/PowerShell/Win32-OpenSSH/releases/download/v8.1.0.0p1-Beta/OpenSSH-Win64.zip'
$opensshArchive = 'c:\tmp\OpenSSH-Win64.zip'
$tmpPath = Split-Path $opensshArchive -Parent
If(!(Test-Path $tmpPath))
{
    New-Item -ItemType Directory -Force -Path $tmpPath
}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
(New-Object System.Net.WebClient).DownloadFile($opensshUrl, $opensshArchive)
If(!(Test-Path $opensshArchive))
{
    throw "Unable to download OpenSSH-Win64.zip from $opensshUrl"
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($opensshArchive, $env:ProgramFiles)
$opensshProgramFiles = Join-Path $env:ProgramFiles 'OpenSSH-Win64'
If(!(Test-Path $opensshProgramFiles))
{
    throw "Missing OpenSSH-Win64 directory"
}
$opensshInstallScript = Join-Path $opensshProgramFiles 'install-sshd.ps1'
If(!(Test-Path $opensshInstallScript))
{
    throw "Missing OpenSSH-Win64 installation script"
}
$env:Path += $opensshProgramFiles

Set-Location -Path $opensshProgramFiles
& $opensshInstallScript

Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShellCommandOption -Value "/c" -PropertyType String -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install --no-progress -y git
