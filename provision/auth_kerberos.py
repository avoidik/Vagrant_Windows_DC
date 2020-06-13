#!/usr/bin/env python3

import os
import kerberos
import requests

#
# make sure keytab file loaded with klist, if not load it with kinit
# alternatively, set keytab_path below
#

keytab_path = os.path.expanduser("~/basic-user.keytab")

os.environ['KRB5_CLIENT_KTNAME'] = keytab_path
print("KRB5_CLIENT_KTNAME = {}".format(keytab_path))

vault_addr  = os.getenv('VAULT_ADDR') or 'http://localhost:8200'
auth_url    = "{}/v1/auth/kerberos/login".format(vault_addr)
krb_service = "HTTP@vault-server.marti.local"

# GSSAPI authentication
gssflags = kerberos.GSS_C_MUTUAL_FLAG | kerberos.GSS_C_SEQUENCE_FLAG | kerberos.GSS_C_INTEG_FLAG | kerberos.GSS_C_CONF_FLAG
mech_oid = kerberos.GSS_MECH_OID_KRB5
_, ctx = kerberos.authGSSClientInit(service=krb_service, gssflags=gssflags, mech_oid=mech_oid)

print(kerberos.getServerPrincipalDetails('HTTP', 'vault-server.marti.local'))

try:
    kerberos.authGSSClientStep(ctx, '')
except kerberos.GSSError as e:
    print("\n".join(["Error: {} - {}".format(l[0], l[1]) for l in e.args]))
    exit()

kerberos_token = kerberos.authGSSClientResponse(ctx)

# Vault authentication
r = requests.post(auth_url, headers={'Authorization': 'Negotiate ' + kerberos_token})

print('Vault token:', r.json()['auth']['client_token'])

# Cleanup
kerberos.authGSSClientClean(ctx)
