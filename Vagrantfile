#Vagrant 1.6+ natively supports Windows guests over WinRM.
Vagrant.require_version '>= 1.6'

$machine_ad        = 'windows-dc'
$machine_vault     = 'vault-server'
$domain            = 'marti.local' # Set example domain
$domain_ip_address = '192.168.56.2'
$timezone          = 'FLE Standard Time' # Bulgaria local time , use tzutil /l in PS to review the timezones
$vault_ip_address  = '192.168.56.3'

Vagrant.configure('2') do |config|

    config.vm.define $machine_ad do |nodeconfig|
        nodeconfig.vm.box         = 'gusztavvargadr/windows-server-2016-standard'
        nodeconfig.vm.box_version = '2005.0.0'
        nodeconfig.vm.hostname    = $machine_ad # do not set this to vagrant

        #WinRM settings
        nodeconfig.winrm.transport       = :plaintext
        nodeconfig.winrm.basic_auth_only = true
        nodeconfig.vm.guest              = :windows
        nodeconfig.vm.communicator       = 'winrm'
        nodeconfig.winrm.username        = 'vagrant'
        nodeconfig.winrm.password        = 'vagrant'

        nodeconfig.vm.network :private_network, ip: $domain_ip_address

        # Configure VirtualBox
        nodeconfig.vm.provider :virtualbox do |v|
            v.gui          = true
            v.name         = $machine_ad
            v.cpus         = 2
            v.memory       = 2048
            v.linked_clone = true
            v.customize    ['modifyvm', :id, '--clipboard', 'bidirectional']
            v.customize    ['modifyvm', :id, '--audio', 'none']
        end

        nodeconfig.vm.synced_folder '.', '/vagrant'

        # Installing AD DS
        nodeconfig.vm.provision 'shell', path: 'provision/domain-controller.ps1', args: [$domain]
        nodeconfig.vm.provision 'shell', reboot: true
        nodeconfig.vm.provision 'shell', path: 'provision/domain-controller-configure.ps1', args: [$machine_vault, $vault_ip_address, $machine_ad]
        nodeconfig.vm.provision 'shell', reboot: true
        nodeconfig.vm.provision 'shell', path: 'provision/base.ps1', args: [$timezone]
        nodeconfig.vm.provision 'shell', path: 'provision/enable-ssh.ps1'
        nodeconfig.vm.provision 'shell', path: 'provision/ad-explorer.ps1'
    end

    config.vm.define $machine_vault do |nodeconfig|
        nodeconfig.vm.box      = 'bento/ubuntu-18.04'
        nodeconfig.vm.hostname = $machine_vault

        nodeconfig.vm.network :private_network, ip: $vault_ip_address

        nodeconfig.vm.provider :virtualbox do |v|
            v.name      = $machine_vault
            v.cpus      = 1
            v.memory    = 1024
            v.customize ['modifyvm', :id, '--audio', 'none']
        end

        nodeconfig.vm.synced_folder '.', '/vagrant'

        nodeconfig.vm.provision 'shell', path: 'provision/vault-server.sh', args: [$domain, $machine_vault, $vault_ip_address, $machine_ad, $domain_ip_address]
        nodeconfig.vm.provision 'shell', path: 'provision/vault-config.sh', args: [$domain, $machine_vault, $domain_ip_address]
    end

end
