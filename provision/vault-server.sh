#!/usr/bin/env bash

export DEBIAN_FRONTEND="noninteractive"

DOMAIN_NAME="$1"
DOMAIN_NAME_UPPER="${DOMAIN_NAME^^}"
MACHINE_NAME="$2"
MACHINE_IP="$3"
AD_NAME="$4"
AD_IP="$5"

VAULT_VERSION="1.4.2"

apt-get update
apt-get remove -y docker docker-engine docker.io containerd runc
apt-get install -qq -o=Dpkg::Use-Pty=0 apt-transport-https ca-certificates curl gnupg-agent software-properties-common unzip
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -qq -o=Dpkg::Use-Pty=0 docker-ce docker-ce-cli containerd.io
usermod -a -G docker vagrant
systemctl reenable docker
systemctl restart docker

apt-get install -qq -o=Dpkg::Use-Pty=0 git-core python3-pip build-essential krb5-user libkrb5-dev krb5-config libssl-dev libsasl2-dev
pip3 install requests-kerberos

curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" -o "/tmp/vault_${VAULT_VERSION}_linux_amd64.zip"
unzip -qod /usr/local/bin "/tmp/vault_${VAULT_VERSION}_linux_amd64.zip" vault
chmod +x /usr/local/bin/vault
rm -f "/tmp/vault_${VAULT_VERSION}_linux_amd64.zip"

docker run --rm -d --cap-add=IPC_LOCK --name "${MACHINE_NAME}" -p 8200:8200 \
    -e 'VAULT_DEV_ROOT_TOKEN_ID=myroot' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault

cat <<EOF > /etc/profile.d/vault.sh
export VAULT_ADDR="http://${MACHINE_IP}:8200"
export VAULT_TOKEN="myroot"
EOF

chmod +x /etc/profile.d/vault.sh

#
# kerberos configuration
#

hostnamectl set-hostname "${MACHINE_NAME}.${DOMAIN_NAME}"

cat <<EOF > /etc/hosts
127.0.0.1     localhost
${MACHINE_IP} ${MACHINE_NAME}.${DOMAIN_NAME} ${MACHINE_NAME}
# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

cat <<EOF > /etc/krb5.conf
[logging]
    kdc = SYSLOG:INFO
    admin_server = FILE=/var/log/kadm5.log
    default = FILE:/var/log/krb5.log

[libdefaults]
    default_realm = ${DOMAIN_NAME_UPPER}
    default_tkt_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 rc4-hmac
    default_tgs_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 rc4-hmac
    permitted_enctypes = aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96 rc4-hmac
    preferred_preauth_types = 18
    ticket_lifetime = 24h
    renew_lifetime = 48h
    rdns = off

[realms]
    ${DOMAIN_NAME_UPPER} = {
        kdc = ${AD_NAME}.${DOMAIN_NAME}
        admin_server = ${AD_NAME}.${DOMAIN_NAME}
        master_kdc = ${AD_NAME}.${DOMAIN_NAME}
        default_domain = ${DOMAIN_NAME}
    }

[domain_realm]
    .${DOMAIN_NAME} = ${DOMAIN_NAME_UPPER}
    ${DOMAIN_NAME} = ${DOMAIN_NAME_UPPER}
EOF

systemctl stop systemd-resolved
systemctl disable systemd-resolved

rm -f /etc/resolv.conf

cat <<EOF > /etc/resolv.conf
domain ${DOMAIN_NAME}
nameserver ${AD_IP}
EOF

sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
