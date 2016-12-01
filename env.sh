# make the environment for these scripts available in your current shell

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/personal.sh"

env

export ACCOUNT
export PROJECT
export DOMAIN

export REGION_1
export AVAILABILITY_ZONE_1
export AVAILABILITY_ZONE_2
export AVAILABILITY_ZONE_3
export STORAGE_LOCATION

export DOMAIN_TOKEN
export SUBDOMAIN
export DNS_ZONE
export DNS_TTL
export CIDR
export ALL_INTERNET

export OPS_MANAGER_VERSION
export OPS_MANAGER_VERSION_TOKEN
export PCF_VERSION
export MYSQL_VERSION
export RABBIT_VERSION
export REDIS_VERSION
export GCP_VERSION
export GCP_VERSION_TOKEN
export GCP_VERSION_NUM
export SCS_VERSION
export GEM_VERSION
export CONCOURSE_VERSION

export SSH_LOAD_BALANCER_NAME
export HTTP_LOAD_BALANCER_NAME
export WS_LOAD_BALANCER_NAME
export TCP_LOAD_BALANCER_NAME
