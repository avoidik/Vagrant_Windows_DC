param(
    $domain = 'example.com'
)

$flagFile = Join-Path $env:WINDIR 'domain-installed'

If(Test-Path $flagFile)
{
    Write-Host 'ADDSForest has already been installed'
    Exit 0
}

$restoreUserName = 'Administrator'
$restoreUserPassword = 'c42SkH#sB7L9'

$netbiosDomain = ($domain -split '\.')[0].ToUpperInvariant()

$safeModeAdminstratorPassword = ConvertTo-SecureString $restoreUserPassword -AsPlainText -Force

# make sure the Administrator has a password that meets the minimum Windows
# password complexity requirements (otherwise the AD will refuse to install).
Write-Host 'Resetting the Administrator account password and settings...'
Set-LocalUser `
    -Name $restoreUserName `
    -AccountNeverExpires `
    -Password $safeModeAdminstratorPassword `
    -PasswordNeverExpires:$true `
    -UserMayChangePassword:$true

Write-Host 'Disabling the Administrator account (we only use the vagrant account)...'
Disable-LocalUser `
    -Name $restoreUserName

Write-Host 'Installing the AD services and administration tools...'
Install-WindowsFeature AD-Domain-Services,RSAT-AD-AdminCenter,RSAT-ADDS-Tools | Out-Null

Write-Host 'Installing the AD forest (be patient, this will take more than 30m to install)...'
Import-Module ADDSDeployment
# NB ForestMode and DomainMode are set to WinThreshold (Windows Server 2016).
#    see https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/active-directory-functional-levels
Install-ADDSForest `
    -InstallDns `
    -CreateDnsDelegation:$false `
    -ForestMode 'WinThreshold' `
    -DomainMode 'WinThreshold' `
    -DomainName $domain `
    -DomainNetbiosName $netbiosDomain `
    -SafeModeAdministratorPassword $safeModeAdminstratorPassword `
    -NoRebootOnCompletion `
    -Force

New-Item -ItemType File -Force -Path $flagFile
