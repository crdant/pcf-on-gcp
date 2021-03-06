# generate required SSL certificates for the installation

ssl_certs () {
  echo "Creating SSL certificate for load balancers..."

  COMMON_NAME="*.${SUBDOMAIN}"
  COUNTRY="US"
  STATE="MA"
  CITY="Cambridge"
  ORGANIZATION="${DOMAIN}"
  ORG_UNIT="Cloud Foundry"
  EMAIL="${ACCOUNT}"
  ALT_NAMES="DNS:*.${SUBDOMAIN},DNS:*.${PCF_SYSTEM_DOMAIN},DNS:*.${PCF_APPS_DOMAIN},DNS:*.login.${PCF_SYSTEM_DOMAIN},DNS:*.uaa.${PCF_SYSTEM_DOMAIN}"
  SUBJECT="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${COMMON_NAME}/emailAddress=${EMAIL}"

  openssl req -new -newkey rsa:2048 -days 365 -nodes -sha256 -x509 -keyout "${KEYDIR}/${SUBDOMAIN_TOKEN}.key" -out "${KEYDIR}/${SUBDOMAIN_TOKEN}.crt" -subj "${SUBJECT}" -reqexts SAN -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=${ALT_NAMES}\n")) > /dev/null

  echo "SSL certificate for load balanacers created and stored at ${KEYDIR}/${SUBDOMAIN_TOKEN}.crt, private key stored at ${KEYDIR}/${SUBDOMAIN_TOKEN}.key."
  echo "The certificate is a wildcard for the following domains: ${ALT_NAMES}"

  echo "Creating SSL certificate for CF router..."

  COMMON_NAME="*.${SUBDOMAIN}"
  COUNTRY="US"
  STATE="MA"
  CITY="Cambridge"
  ORGANIZATION="${DOMAIN}"
  ORG_UNIT="Cloud Foundry Router"
  EMAIL="${ACCOUNT}"
  ALT_NAMES="DNS:*.${SUBDOMAIN},DNS:*.${PCF_SYSTEM_DOMAIN},DNS:*.${PCF_APPS_DOMAIN},DNS:*.login.${PCF_SYSTEM_DOMAIN},DNS:*.uaa.${PCF_SYSTEM_DOMAIN}"
  SUBJECT="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${COMMON_NAME}/emailAddress=${EMAIL}"

  openssl req -new -newkey rsa:2048 -days 365 -nodes -sha256 -x509 -keyout "${KEYDIR}/pcf-router-${SUBDOMAIN_TOKEN}.key" -out "${KEYDIR}/pcf-router-${SUBDOMAIN_TOKEN}.crt" -subj "${SUBJECT}" -reqexts SAN -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=${ALT_NAMES}\n")) > /dev/null

  echo "SSL certificate for CF router created and stored at ${KEYDIR}/pcf-router-${SUBDOMAIN_TOKEN}.crt, private key stored at ${KEYDIR}/pcf-router-${SUBDOMAIN_TOKEN}.key."
  echo "The certificate is a wildcard for the following domains: ${ALT_NAMES}"

  echo "Creating SSL certificate for Rabbit MQ..."

  COMMON_NAME="*.${SUBDOMAIN}"
  COUNTRY="US"
  STATE="MA"
  CITY="Cambridge"
  ORGANIZATION="${DOMAIN}"
  ORG_UNIT="Cloud Foundry Router"
  EMAIL="${ACCOUNT}"
  ALT_NAMES="DNS:*.${SUBDOMAIN},DNS:*.${PCF_SYSTEM_DOMAIN},DNS:*.${PCF_APPS_DOMAIN},DNS:*.login.${PCF_SYSTEM_DOMAIN},DNS:*.uaa.${PCF_SYSTEM_DOMAIN}"
  SUBJECT="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${COMMON_NAME}/emailAddress=${EMAIL}"

  openssl req -new -newkey rsa:2048 -days 365 -nodes -sha256 -x509 -keyout "${KEYDIR}/rabbit-mq-${SUBDOMAIN_TOKEN}.key" -out "${KEYDIR}/rabbit-mq-${SUBDOMAIN_TOKEN}.crt" -subj "${SUBJECT}" -reqexts SAN -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=${ALT_NAMES}\n")) > /dev/null

  echo "SSL certificate for Rabbitcreated and stored at ${KEYDIR}/rabbit-mq-${SUBDOMAIN_TOKEN}.crt, private key stored at ${KEYDIR}/rabbit-mq-${SUBDOMAIN_TOKEN}.key."
  echo "The certificate is a wildcard for the following domains: ${ALT_NAMES}"

}

ssl_requests () {
  echo "Creating SSL certificate for load balancers..."

  COMMON_NAME="*.${SUBDOMAIN}"
  COUNTRY="US"
  STATE="MA"
  CITY="Cambridge"
  ORGANIZATION="${DOMAIN}"
  ORG_UNIT="Cloud Foundry"
  EMAIL="${ACCOUNT}"
  ALT_NAMES="DNS:*.${SUBDOMAIN},DNS:*.${PCF_SYSTEM_DOMAIN},DNS:*.${PCF_APPS_DOMAIN},DNS:*.login.${PCF_SYSTEM_DOMAIN},DNS:*.uaa.${PCF_SYSTEM_DOMAIN}"
  SUBJECT="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${COMMON_NAME}/emailAddress=${EMAIL}"

  openssl req -new -newkey rsa:2048 -days 365 -nodes -sha256 -x509 -keyout "${KEYDIR}/${SUBDOMAIN_TOKEN}.key" -out "${KEYDIR}/${SUBDOMAIN_TOKEN}.crt" -subj "${SUBJECT}" -reqexts SAN -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=${ALT_NAMES}\n")) > /dev/null

  echo "SSL certificate for load balanacers created and stored at ${KEYDIR}/${SUBDOMAIN_TOKEN}.crt, private key stored at ${KEYDIR}/${SUBDOMAIN_TOKEN}.key."
  echo "The certificate is a wildcard for the following domains: ${ALT_NAMES}"

  echo "Creating SSL certificate for CF router..."

  COMMON_NAME="*.${SUBDOMAIN}"
  COUNTRY="US"
  STATE="MA"
  CITY="Cambridge"
  ORGANIZATION="${DOMAIN}"
  ORG_UNIT="Cloud Foundry Router"
  EMAIL="${ACCOUNT}"
  ALT_NAMES="DNS:*.${SUBDOMAIN},DNS:*.${PCF_SYSTEM_DOMAIN},DNS:*.${PCF_APPS_DOMAIN},DNS:*.login.${PCF_SYSTEM_DOMAIN},DNS:*.uaa.${PCF_SYSTEM_DOMAIN}"
  SUBJECT="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${COMMON_NAME}/emailAddress=${EMAIL}"

  openssl req -new -newkey rsa:2048 -days 365 -nodes -sha256 -x509 -keyout "${KEYDIR}/pcf-router-${SUBDOMAIN_TOKEN}.key" -out "${KEYDIR}/pcf-router-${SUBDOMAIN_TOKEN}.crt" -subj "${SUBJECT}" -reqexts SAN -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=${ALT_NAMES}\n")) > /dev/null

  echo "SSL certificate for CF router created and stored at ${KEYDIR}/pcf-router-${SUBDOMAIN_TOKEN}.crt, private key stored at ${KEYDIR}/pcf-router-${SUBDOMAIN_TOKEN}.key."
  echo "The certificate is a wildcard for the following domains: ${ALT_NAMES}"

}
