#!/usr/bin/env python3

import os
import ldap
import ldap.sasl

ldap_addr = 'ldap://windows-dc.marti.local'
master_user = 'vault-user'
master_pass = 'Z2aCbNEh6Ufx'
upn = 'vault-user@marti.local'
bind_dn = 'CN=vault-user,OU=DomainUsers,DC=marti,DC=local'

#
# make sure keytab file loaded with klist, if not load it with kinit
# alternatively, set keytab_path below
#

keytab_path = os.path.expanduser("~/vault-user.keytab")

os.environ['KRB5_CLIENT_KTNAME'] = keytab_path
print("KRB5_CLIENT_KTNAME = {}".format(keytab_path))

con = ldap.initialize(ldap_addr)
con.protocol_version = ldap.VERSION3

try:
    # raw pass
    con.simple_bind_s(bind_dn, master_pass)
    print(con.whoami_s())

    # upn
    con.simple_bind_s(upn, master_pass)
    print(con.whoami_s())

    # gssapi - require upn bind
    sasl_auth = ldap.sasl.sasl({},'GSSAPI')
    con.sasl_interactive_bind_s('', sasl_auth)
    print(con.whoami_s())

    # md5
    sasl_auth = ldap.sasl.sasl(
        {
            ldap.sasl.CB_AUTHNAME: master_user,
            ldap.sasl.CB_PASS    : master_pass,
        },
        'DIGEST-MD5'
    )
    con.sasl_interactive_bind_s('', sasl_auth)
    print(con.whoami_s())

    # search
    res = con.search_s('', ldap.SCOPE_BASE, '(objectClass=*)', ['supportedSASLMechanisms'])
    print(res)

    # search
    res = con.search_s('OU=DomainUsers,DC=marti,DC=local', ldap.SCOPE_SUBTREE, '(cn=basic-user)', ['sAMAccountName', 'userPrincipalName'])
    print(res)

except ldap.LDAPError as e:
    print(e)

con.unbind()
