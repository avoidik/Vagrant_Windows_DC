#!/usr/bin/env bash

if ! [ -x "$(command -v go 2> /dev/null)" ]; then

mkdir "${HOME}/golang"

tee -a "${HOME}/.profile" <<'EOF' > /dev/null
# golang configuration
export GOROOT="${HOME}/golang/go"
export GOPATH="${HOME}/go"
export PATH="${PATH}:${GOROOT}/bin"
export PATH="${PATH}:${GOPATH}/bin"
EOF
. "${HOME}/.profile"
curl -fsSL https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz -o /tmp/go1.14.2.linux-amd64.tar.gz
tar -zxf /tmp/go1.14.2.linux-amd64.tar.gz -C "${HOME}/golang"
rm -f /tmp/go1.14.2.linux-amd64.tar.gz

fi

git clone https://github.com/hashicorp/vault-plugin-auth-kerberos.git /tmp/kerberos-plugin
cd /tmp/kerberos-plugin
make bootstrap
make dev-linux-only
cp bin/login-kerb "${HOME}/go/bin"
