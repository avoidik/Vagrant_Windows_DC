#!/usr/bin/env bash

login-kerb -disable_fast_negotiation \
    -username 'basic-user' \
    -service 'HTTP/vault-server.marti.local' \
    -realm 'MARTI.LOCAL' \
    -keytab_path 'basic-user.keytab' \
    -krb5conf_path '/etc/krb5.conf'

vault login -method=kerberos \
    username='basic-user' \
    service='HTTP/vault-server.marti.local' \
    realm='MARTI.LOCAL' \
    keytab_path='basic-user.keytab' \
    krb5conf_path='/etc/krb5.conf' \
    disable_fast_negotiation=true
