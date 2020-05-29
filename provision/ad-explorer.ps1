# install Active Directory Explorer from https://technet.microsoft.com/en-us/sysinternals/adexplorer.aspx
# NB even though you can use the Windows ADSI Edit application, I find ADExplorer nicer.
$adExplorerUrl = 'https://download.sysinternals.com/files/AdExplorer.zip'
$adExplorerHash = '97EF5001C225A869AE739C15AAB1E067B66CE85250FF4D3C265BBFAF09AC8308'
$adExplorer = 'c:\tmp\AdExplorer.zip'
$tmpPath = Split-Path $adExplorer -Parent
If(!(Test-Path $tmpPath))
{
    New-Item -ItemType Directory -Force -Path $tmpPath
}
(New-Object System.Net.WebClient).DownloadFile($adExplorerUrl, $adExplorer)
If(!(Test-Path $adExplorer))
{
    throw "Unable to download AdExplorer.zip from $adExplorerUrl"
}
$adExplorerActualHash = (Get-FileHash $adExplorer -Algorithm SHA256).Hash
if ($adExplorerHash -ne $adExplorerActualHash) {
    throw "AdExplorer.zip downloaded from $adExplorerUrl to $adExplorer has $adExplorerActualHash hash witch does not match the expected $adExplorerHash"
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$adExplorerProgramFiles = Join-Path $env:ProgramFiles 'ADExplorer'
If(!(Test-Path $adExplorerProgramFiles))
{
    New-Item -ItemType Directory -Force -Path $adExplorerProgramFiles
}
[IO.Compression.ZipFile]::ExtractToDirectory($adExplorer, $adExplorerProgramFiles)
$shortcutPath = Join-Path $adExplorerProgramFiles 'ADExplorer.exe'
If(!(Test-Path $shortcutPath))
{
    throw "ADExplorer.exe is missing"
}
$shell = New-Object -ComObject 'WScript.Shell'
$shellSpecialFolders = $shell.SpecialFolders
$shortcut = $shell.CreateShortcut((Join-Path $shellSpecialFolders.Item('AllUsersStartMenu') 'Active Directory Explorer (ADExplorer).lnk'))
$shortcut.TargetPath = $shortcutPath
$shortcut.Save()
