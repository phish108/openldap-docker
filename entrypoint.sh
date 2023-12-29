#!/bin/ash

ulimit -n 8000

#  /etc/openldap/slapd.d/cn=config | grep mdb > /dev/null
# if [ "$?" != "0" ]
#then

# If a fresh container with empty volumes arrives, set up the domain
if [ ! -f /data/data.mdb ]
then
    echo "RootDomain is not configured"
    echo "init DB"

    if [ -f /install/init.conf ]
    then
        . /install/init.conf
    fi

    if [ -f /install/password ]
    then
        LDAP_PASSWORD=`cat /install/password`
    fi

    if [ -z $LDAP_DOMAIN ]
    then
        LDAP_DOMAIN=private.domain
    fi

    ROOT_DN=`echo $LDAP_DOMAIN | sed -E 's/([^\.]*)/dc=\1/g' | tr . ,`

    # create backend definition
    # $ROOT_DN
    # $ROOT_DN_USER
    if [ -z $LDAP_ADMIN ]
    then
        LDAP_ADMIN=admin
    fi

    if [ -z $LDAP_PASSWORD ]
    then
        LDAP_PASSWORD=secret
    fi
    # ROOT_DN_PASSWORD=`slappasswd -s $ROOT_DN_PASSWORD`

    # $ROOT_DN_DC (from ROOT_DN)
    ROOT_DN_DC=`echo $ROOT_DN | sed -E 's/^.*=(.*),.*$/\1/'`

    # $ROOT_DN_ORG (from ROOT_DN (merge all dc=))
    ROOT_DN_ORG=`echo $ROOT_DN | sed -E 's/[^,]*=([^,]*)/\1/g' | tr "," "."`

    # BACKEND="database mdb\n maxsize 1073741824\n suffix \"$ROOT_DN\"\n rootdn \"cn=$ROOT_DN_USER,$ROOT_DN\"\n rootpw $ROOT_DN_PASSWORD\n directory /var/lib/openldap/openldap-data\n index mail,uid,mailAlias,cn,sn eq,sub\n index objectClass eq"

    BACKEND="olcSuffix: $ROOT_DN\\nolcRootDN: cn=$LDAP_ADMIN,$ROOT_DN\\nolcRootPW: $LDAP_PASSWORD"
    FULLBACKEND=`slapcat -n 0 | sed -e "/olcDatabase:.*mdb/a $BACKEND"`

    ROOTENTRY="dn: $ROOT_DN\\nobjectClass: dcObject\\nobjectClass: organization\\nobjectClass: top\\ndc: $ROOT_DN_DC\\no: $ROOT_DN_ORG\\n\\ndn: cn=$LDAP_ADMIN,$ROOT_DN\\nobjectClass: organizationalRole\\nobjectClass: simpleSecurityObject\\ndescription: LDAP administrator\\ncn: $LDAP_ADMIN\\nuserPassword: $LDAP_PASSWORD\\n"

    echo "suffix $ROOT_DN" >> /etc/openldap/slapd.conf

    # Remove the configuration
    rm -rf /etc/openldap/slapd.d/*

    # Replace the configuration
    
    echo "$FULLBACKEND" | slapadd -n 0 -F /etc/openldap/slapd.d

    echo -e $ROOTENTRY | slapadd -n 1

    echo "URI ldapi://%2fvar%2frun%2fopenldap%2fsocket" >> /etc/openldap/ldap.conf
fi

# Initialise all schemas to the latest version
slapadd -n 0 -l  /install/schema/cosine.ldif -f /etc/openldap/slapd.conf -F /etc/openldap/slapd.d/
slapadd -n 0 -l  /install/schema/corba.ldif
slapadd -n 0 -l  /install/schema/nis.ldif
slapadd -n 0 -l  /install/schema/inetorgperson.ldif
slapadd -n 0 -l  /install/schema/ppolicy.ldif
slapadd -n 0 -l  /install/schema/qmail.ldif

# EduID Schema
slapadd -n 0 -l  /install/schema/eduperson-202208.openldap.ldif
slapadd -n 0 -l  /install/schema/swissedu-202208.openldap.ldif 

# OAuth2 Schema
slapadd -n 0 -l /install/schema/oidc-client-schema-openldap.ldif
slapadd -n 0 -l  /install/schema/oidc-session-schema-openldap.ldif
slapadd -n 0 -l  /install/schema/oidc-authz-schema-openldap.ldif

# allow the ldap user to access the config and data
chown -R ldap.ldap /etc/openldap/slapd.d
chown -R ldap.ldap /data

/usr/sbin/slapd -d stats -h "ldap:/// ldapi://%2fvar%2frun%2fopenldap%2fsocket" -u ldap -g ldap
# exec /bin/ash
