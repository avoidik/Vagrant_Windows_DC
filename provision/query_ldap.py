#!/usr/bin/env python3

import ldap

ldap_addr = 'ldap://windows-dc.marti.local'

con = ldap.initialize(ldap_addr, trace_level=0)
con.protocol_version = ldap.VERSION3

try:
    con.simple_bind_s()
    dse = con.read_rootdse_s()
    methods = [m.decode() for m in dse['supportedSASLMechanisms']]
    print('Supported methods:', ', '.join(methods))
except ldap.LDAPError as e:
    if type(e.message) == dict and e.message.has_key('desc'):
        print(e.message['desc'])
    else:
        print(e)

con.unbind()
