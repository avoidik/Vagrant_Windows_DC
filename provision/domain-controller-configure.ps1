param (
    $vaultServerName = 'vault-server',
    $vaultIpAddress = '192.168.56.3',
    $machineAdName = 'windows-dc'
)

#
# users
#
$vaultUserName = 'vault-user'
$vaultUserPassword = 'Z2aCbNEh6Ufx'

$basicUserName = 'basic-user'
$basicUserPassword = 'g45Y37wBrQ8n'

$vagrantUserName = 'vagrant'

$adminUserName = 'Administrator'
$adminuserPassword = 'AuNfSx5a8HZM'

$engineeringGroup = 'engineering-team'

# wait until we can access the AD. this is needed to prevent errors like:
#   Unable to find a default server with Active Directory Web Services running.
while ($true) {
    try {
        Get-ADDomain | Out-Null
        break
    } catch {
        Write-Host 'Waiting 30 seconds for the AD server to be available...'
        Start-Sleep -Seconds 30
    }
}

$adDomain = Get-ADDomain
$domain = ($adDomain.DNSRoot)
$domainDn = ($adDomain.DistinguishedName)
$usersOU = 'DomainUsers'
$usersAdPath = "OU=$usersOU,$domainDn"
$groupsOU = 'DomainGroups'
$groupsAdPath = "OU=$groupsOU,$domainDn"
$defaultUsersCN = "CN=Users,$domainDn"

# remove the non-routable vagrant nat ip address from dns.
# NB this is needed to prevent the non-routable ip address from
#    being registered in the dns server.
# NB the nat interface is the first dhcp interface of the machine.
$vagrantNatAdapter = Get-NetAdapter -Physical `
    | Where-Object {$_ | Get-NetIPAddress | Where-Object {$_.PrefixOrigin -eq 'Dhcp'}} `
    | Sort-Object -Property Name `
    | Select-Object -First 1
# deregister connection address in dns
$vagrantNatAdapter | Set-DnsClient -RegisterThisConnectionsAddress $false
# disable ipv6.
$vagrantNatAdapter | Disable-NetAdapterBinding -ComponentID ms_tcpip6

$vagrantNatIpAddress = ($vagrantNatAdapter | Get-NetIPAddress).IPv4Address

foreach($internalNatIp in $vagrantNatIpAddress) {
    if ($internalNatIp) {
        # remove the $domain nat ip address resource records from dns.
        Get-DnsServerResourceRecord -ZoneName $domain -Type 1 `
            | Where-Object {$_.RecordData.IPv4Address -eq $internalNatIp} `
            | Remove-DnsServerResourceRecord -ZoneName $domain -Force
    }
}

Set-DnsServerForwarder -IPAddress '1.1.1.1'

# flush the dns client cache.
Clear-DnsClientCache

$localNetAdapter = Get-NetAdapter -Physical `
    | Where-Object {$_ | Get-NetIPAddress | Where-Object {$_.PrefixOrigin -ne 'Dhcp'}} `
    | Sort-Object -Property Name `
    | Select-Object -First 1
# disable ipv6.
$localNetAdapter | Disable-NetAdapterBinding -ComponentID ms_tcpip6

$localIpAddress = ($localNetAdapter | Get-NetIPAddress).IPv4Address
foreach($localIp in $localIpAddress) {
    if ($localIp) {
        # remove the dc.$domain nat ip address resource record from dns.
        $dnsServerSettings = Get-DnsServerSetting -All
        $dnsServerSettings.ListeningIPAddress = @(
            $dnsServerSettings.ListeningIPAddress `
                | Where-Object {$_ -eq $localIp}
        )
        Set-DnsServerSetting $dnsServerSettings

        $shortNetAddr = $localIp.Substring(0, $localIp.LastIndexOf('.'))
        $lastOctet = $localIp.Substring($localIp.LastIndexOf('.') + 1)
        $reverseShortNet = ($shortNetAddr.ToString() -replace '^(\d+)\.(\d+)\.(\d+)$','$3.$2.$1')

        $retryFlag = $true

        while ($retryFlag) {
            try {
                Add-DNSServerPrimaryZone -NetworkID ($shortNetAddr + '.0/24') -ReplicationScope 'Domain' -DynamicUpdate 'Secure' -ErrorAction 'Stop'
                $retryFlag = $false
            }
            catch [Microsoft.Management.Infrastructure.CimException] {
                $catInfo = $Error[0].CategoryInfo.ToString()
                switch ($catInfo.Substring(0, $catInfo.IndexOf(':'))) {
                    "ResourceExists"
                    {
                        Write-Host "ReverseZone already exist"
                        $retryFlag = $false
                    }
                    "ObjectNotFound"
                    {
                        Write-Host "Waiting 30 seconds for DNS zone to be available..."
                        Start-Sleep -Seconds 30
                    }
                    default
                    {
                        Write-Host "Unknown: $catInfo"
                    }
                }
            }
            catch {
                $excClass = $Error[0].Exception.GetType().FullName
                $catInfo = $Error[0].CategoryInfo.ToString()
                Write-Host "Unhandled: $excClass"
                Write-Host "Category: $catInfo"
            }
        }

        $retryFlag = $true

        while ($retryFlag) {
            try {
                Add-DnsServerResourceRecordPtr -Name $lastOctet -ZoneName ($reverseShortNet + '.in-addr.arpa') -PtrDomainName "$machineAdName.$domain" -ErrorAction 'Stop'
                $retryFlag = $false
            }
            catch [Microsoft.Management.Infrastructure.CimException] {
                $catInfo = $Error[0].CategoryInfo.ToString()
                switch ($catInfo.Substring(0, $catInfo.IndexOf(':'))) {
                    "ResourceExists"
                    {
                        Write-Host "ReverseZonePtr already exist"
                        $retryFlag = $false
                    }
                    "ObjectNotFound"
                    {
                        Write-Host "Waiting 30 seconds for DNS zone to be available..."
                        Start-Sleep -Seconds 30
                    }
                    default
                    {
                        Write-Host "Unknown: $catInfo"
                    }
                }
            }
            catch {
                $excClass = $Error[0].Exception.GetType().FullName
                $catInfo = $Error[0].CategoryInfo.ToString()
                Write-Host "Unhandled: $excClass"
                Write-Host "Category: $catInfo"
            }
        }
    }
}

If(!(Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$groupsAdPath'")) {
    New-ADOrganizationalUnit -Name $groupsOU -Path $domainDn
}

If(!(Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$usersAdPath'")) {
    New-ADOrganizationalUnit -Name $usersOU -Path $domainDn
}

# add the vagrant user to the Enterprise Admins group.
# NB this is needed to install the Enterprise Root Certification Authority.
Add-ADGroupMember `
    -Identity 'Enterprise Admins' `
    -Members "CN=$vagrantUserName,$defaultUsersCN"

# disable all user accounts, except the ones defined here.
# $enabledAccounts = @(
#     # NB vagrant only works when this account is enabled.
#     $vagrantUserName,
#     $adminUserName
# )
# Get-ADUser -Filter {Enabled -eq $true} `
#     | Where-Object {$enabledAccounts -notcontains $_.Name} `
#     | Disable-ADAccount

# set the Administrator password.
# NB this is also an Domain Administrator account.
Set-ADAccountPassword `
    -Identity "CN=$adminUserName,$defaultUsersCN" `
    -Reset `
    -NewPassword (ConvertTo-SecureString -AsPlainText $adminuserPassword -Force)
Set-ADUser `
    -Identity "CN=$adminUserName,$defaultUsersCN" `
    -PasswordNeverExpires $true

# add vault user.
try {
    New-ADUser `
    -Path $usersAdPath `
    -Name $vaultUserName `
    -UserPrincipalName "$vaultUserName@$domain" `
    -EmailAddress "$vaultUserName@$domain" `
    -AccountPassword (ConvertTo-SecureString -AsPlainText $vaultUserPassword -Force) `
    -Enabled $true `
    -PasswordNeverExpires $true
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
    Write-Host "User $vaultUserName already exist"
}

# add user to the Domain Admins group.
Add-ADGroupMember `
    -Identity 'Domain Admins' `
    -Members "CN=$vaultUserName,$usersAdPath"

# add basic user.
try {
    New-ADUser `
        -Path $usersAdPath `
        -Name $basicUserName `
        -UserPrincipalName "$basicUserName@$domain" `
        -EmailAddress "$basicUserName@$domain" `
        -GivenName 'Basic' `
        -Surname 'User' `
        -DisplayName 'Basic User' `
        -AccountPassword (ConvertTo-SecureString -AsPlainText $basicUserPassword -Force) `
        -Enabled $true `
        -PasswordNeverExpires $true
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
    Write-Host "User $basicUserName already exist"
}

$KerberosAES128 = 0x08
$KerberosAES256 = 0x10

Set-ADUser -Identity $vaultUserName -Replace @{'msDS-SupportedEncryptionTypes'=($KerberosAES128 -bor $KerberosAES256)}
Set-ADUser -Identity $basicUserName -Replace @{'msDS-SupportedEncryptionTypes'=($KerberosAES128 -bor $KerberosAES256)}

Get-ADUser -Identity $vaultUserName -Property 'msDS-KeyVersionNumber' | Format-List msDS-KeyVersionNumber
Get-ADUser -Identity $basicUserName -Property 'msDS-KeyVersionNumber' | Format-List msDS-KeyVersionNumber

Set-ADUser -Identity $vaultUserName -ServicePrincipalNames @{Replace="HTTP/${vaultServerName}.${domain}:8200", "HTTP/${vaultServerName}.$domain"}

Add-DnsServerResourceRecordA -Name $vaultServerName -ZoneName $domain -IPv4Address $vaultIpAddress -CreatePtr

New-ADGroup -Name $engineeringGroup -Path $groupsAdPath -GroupCategory Security -GroupScope Global

Add-ADGroupMember `
    -Identity "CN=$engineeringGroup,$groupsAdPath" `
    -Members "CN=$basicUserName,$usersAdPath"

Write-Host 'basic user Group Membership'
Get-ADPrincipalGroupMembership -Identity $basicUserName `
    | Select-Object Name,DistinguishedName,SID `
    | Format-Table -AutoSize | Out-String -Width 2000

Write-Host 'vault Group Membership'
Get-ADPrincipalGroupMembership -Identity $vaultUserName `
    | Select-Object Name,DistinguishedName,SID `
    | Format-Table -AutoSize | Out-String -Width 2000

Write-Host 'vagrant Group Membership'
Get-ADPrincipalGroupMembership -Identity $vagrantUserName `
    | Select-Object Name,DistinguishedName,SID `
    | Format-Table -AutoSize | Out-String -Width 2000

Write-Host 'Enterprise Administrators'
Get-ADGroupMember `
    -Identity 'Enterprise Admins' `
    | Select-Object Name,DistinguishedName,SID `
    | Format-Table -AutoSize | Out-String -Width 2000

Write-Host 'Domain Administrators'
Get-ADGroupMember `
    -Identity 'Domain Admins' `
    | Select-Object Name,DistinguishedName,SID `
    | Format-Table -AutoSize | Out-String -Width 2000

Write-Host 'Enabled Domain User Accounts'
Get-ADUser -Filter {Enabled -eq $true} `
    | Select-Object Name,DistinguishedName,SID `
    | Format-Table -AutoSize | Out-String -Width 2000
