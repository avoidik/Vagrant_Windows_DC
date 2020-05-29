#!/usr/bin/env python3

import os
import kerberos
import requests

service = "HTTP@vault-server.marti.local"
rc, vc = kerberos.authGSSClientInit(service=service, mech_oid=kerberos.GSS_MECH_OID_SPNEGO)
kerberos.authGSSClientStep(vc, "")
kerberos_token = kerberos.authGSSClientResponse(vc)

r = requests.post("https://{}:8200/v1/auth/kerberos/login".format(os.getenv('VAULT_ADDR')),
                  headers={'authorization': 'Negotiate ' + kerberos_token})

print('Vault token:', r.json()['auth']['client_token'])
