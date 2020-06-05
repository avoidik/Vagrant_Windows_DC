#!/usr/bin/env bash

DOMAIN_NAME="$1"
DOMAIN_NAME_UPPER="${DOMAIN_NAME^^}"
MACHINE_NAME="$2"
DOMAIN_IP="$3"

DOMAIN_DN="DC=marti,DC=local"

MASTER_USER="vault-user"
MASTER_PASS="Z2aCbNEh6Ufx"

SERVICE_USER="basic-user"
SERVICE_PASS="g45Y37wBrQ8n"

. /etc/profile.d/vault.sh

vault policy write engineers -<<'EOF'
path "secret/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

vault auth disable kerberos
vault auth enable \
    -passthrough-request-headers=Authorization \
    -allowed-response-headers=www-authenticate \
    kerberos

rm -f "${MASTER_USER}.keytab"
printf "%b" "add_entry -password -p ${MASTER_USER}@${DOMAIN_NAME_UPPER} -e aes256-cts -k 2\n${MASTER_PASS}\nwrite_kt ${MASTER_USER}.keytab\nquit" | ktutil
printf "%b" "read_kt ${MASTER_USER}.keytab\nlist -e\nquit" | ktutil

#klist -k -t -K -e "${MASTER_USER}.keytab"
kinit -V -k -t "${MASTER_USER}.keytab" "${MASTER_USER}"
#kvno -k "${MASTER_USER}.keytab" "${MASTER_USER}"

ldapsearch -x -b '' -s base supportedSASLMechanisms -H "ldap://${DOMAIN_NAME}"
ldapsearch -LLL -Y GSSAPI -H "ldap://${DOMAIN_NAME}" -b "${DOMAIN_DN}" "(sAMAccountName=${MASTER_USER})" 'msDS-KeyVersionNumber'

base64 "${MASTER_USER}.keytab" > "${MASTER_USER}.keytab.base64"

vault write auth/kerberos/config \
    keytab=@"${MASTER_USER}.keytab.base64" \
    service_account="${MASTER_USER}"

vault auth disable ldap
vault auth enable ldap
vault write auth/ldap/config \
    binddn="${MASTER_USER}@${DOMAIN_NAME}" \
    bindpass="${MASTER_PASS}" \
    groupdn="OU=DomainGroups,${DOMAIN_DN}" \
    groupfilter='(&(objectClass=group)(member:1.2.840.113556.1.4.1941:={{.UserDN}}))' \
    groupattr='cn' \
    userdn="OU=DomainUsers,${DOMAIN_DN}" \
    userattr='sAMAccountName' \
    upndomain="${DOMAIN_NAME_UPPER}" \
    url="ldap://${DOMAIN_IP}"

vault write auth/ldap/groups/engineering-team \
    policies=engineers

vault write auth/kerberos/config/ldap \
    binddn="${MASTER_USER}@${DOMAIN_NAME}" \
    bindpass="${MASTER_PASS}" \
    groupdn="OU=DomainGroups,${DOMAIN_DN}" \
    groupfilter='(&(objectClass=group)(member:1.2.840.113556.1.4.1941:={{.UserDN}}))' \
    groupattr='cn' \
    userdn="OU=DomainUsers,${DOMAIN_DN}" \
    userattr='sAMAccountName' \
    upndomain="${DOMAIN_NAME_UPPER}" \
    url="ldap://${DOMAIN_IP}"

vault write auth/kerberos/groups/engineering-team \
    policies=engineers

rm -f "${SERVICE_USER}.keytab"
printf "%b" "add_entry -password -p ${SERVICE_USER}@${DOMAIN_NAME_UPPER} -e aes256-cts -k 2\n${SERVICE_PASS}\nwrite_kt ${SERVICE_USER}.keytab\nquit" | ktutil
printf "%b" "read_kt ${SERVICE_USER}.keytab\nlist -e\nquit" | ktutil

#klist -k -t -K -e "${SERVICE_USER}.keytab"
#kinit -V -k -t "${SERVICE_USER}.keytab" "${SERVICE_USER}"
#kvno -k "${SERVICE_USER}.keytab" "${SERVICE_USER}"

vault login -method=kerberos \
    username="${SERVICE_USER}" \
    service="HTTP/${MACHINE_NAME}.${DOMAIN_NAME}" \
    realm="${DOMAIN_NAME_UPPER}" \
    keytab_path="${SERVICE_USER}.keytab" \
    krb5conf_path='/etc/krb5.conf' \
    disable_fast_negotiation=true
