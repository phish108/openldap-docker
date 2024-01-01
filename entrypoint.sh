#!/bin/ash

ulimit -n 8000

# If a fresh container with empty volumes arrives, set up the domain
if [ ! -f /data/data.mdb ]
then
    # check if a backup is present 
    if [ -f /backup/config.ldif ]
    then
        echo "restore config from backup"
        slapadd -b cn=config -l /backup/config.ldif -F /etc/openldap/slapd.d/
        echo "config backup restored"
    else
        echo "RootDomain is not configured"
        echo "init DB"
        # Step 8 of https://www.openldap.org/doc/admin26/quickstart.html

        if [ -f /install/init.conf ]
        then
            echo " ... using init.conf"
            . /install/init.conf
        fi

        if [ -f /install/password ]
        then
            echo " ... using predefined password file"
            LDAP_PASSWORD=`cat /install/password`
        fi

        if [ ! -z $LDAP_PASSWORD_FILE ]
        then
            if [ -f /install/$LDAP_PASSWORD_FILE ]
            then
                echo " ... using password file from install"
                LDAP_PASSWORD=$(cat /install/$LDAP_PASSWORD_FILE)
            fi
            
            if [ -f /backup/$LDAP_PASSWORD_FILE ]
            then
                echo " ... using password file from backup"
                LDAP_PASSWORD=$(cat $LDAP_PASSWORD_FILE)
            fi
        fi

        if [ -z $LDAP_DOMAIN ]
        then
            echo " ... using default domain"
            LDAP_DOMAIN=private.domain
        fi

        ROOT_DN=`echo $LDAP_DOMAIN | sed -E 's/([^\.]*)/dc=\1/g' | tr . ,`

        # create backend definition
        # $ROOT_DN
        # $ROOT_DN_USER
        if [ -z $LDAP_ADMIN ]
        then
            echo " ... using default admin"
            LDAP_ADMIN=admin
        fi

        if [ -z $LDAP_PASSWORD ]
        then
            echo " ... using default password"
            LDAP_PASSWORD=secret
        fi

        # $ROOT_DN_DC (from ROOT_DN)
        ROOT_DN_DC=`echo $ROOT_DN | sed -E 's/^.*=(.*),.*$/\1/'`

        # $ROOT_DN_ORG (from ROOT_DN (merge all dc=))
        ROOT_DN_ORG=`echo $ROOT_DN | sed -E 's/[^,]*=([^,]*)/\1/g' | tr "," "."`

        # BACKEND="database mdb\n maxsize 1073741824\n suffix \"$ROOT_DN\"\n rootdn \"cn=$ROOT_DN_USER,$ROOT_DN\"\n rootpw $ROOT_DN_PASSWORD\n directory /var/lib/openldap/openldap-data\n index mail,uid,mailAlias,cn,sn eq,sub\n index objectClass eq"

        LDAP_C_PASSWORD=$(slappasswd -h '{SSHA}' -s "$LDAP_PASSWORD")

        echo "olcSuffix: $ROOT_DN" >> /etc/openldap/slapd.ldif
        echo "olcRootDN: cn=$LDAP_ADMIN,$ROOT_DN" >> /etc/openldap/slapd.ldif
        echo "olcRootPW: $LDAP_C_PASSWORD" >> /etc/openldap/slapd.ldif

        # Step 9 of https://www.openldap.org/doc/admin26/quickstart.html
        slapadd -n 0 -l /etc/openldap/slapd.ldif -F /etc/openldap/slapd.d/

        echo "domain config set"

        if [ ! -f /backup/backup.ldif ]
        then
            echo "seed domain"
            # Step 11 of https://www.openldap.org/doc/admin26/quickstart.html

            echo "
dn: $ROOT_DN
objectClass: dcObject
objectClass: organization
objectClass: top
dc: $ROOT_DN_DC
o: $LDAP_DOMAIN

dn: cn=$LDAP_ADMIN,$ROOT_DN
objectClass: organizationalRole
cn: $LDAP_ADMIN
    " > /install/base.ldif

            slapadd -n 2 -l /install/base.ldif -F /etc/openldap/slapd.d/

            rm /install/base.ldif

            echo "domain seeded" 
        fi

        echo "init core LDAP schemas" 

        # Initialise all schemas to the latest version
        # add more core schemas
        echo "  corba " && slapadd -n 0 -l  /install/schema/corba.ldif
        echo "  ppolicy " && slapadd -n 0 -l  /install/schema/ppolicy.ldif
        echo "  qmail " && slapadd -n 0 -l  /install/schema/qmail.ldif

        # EduID Schemas
        echo "install REFEDS Schemas"
        echo "  eduperson " && slapadd -n 0 -l  /install/schema/eduperson-202208.openldap.ldif 
        echo "  swissedu " && slapadd -n 0 -l  /install/schema/swissedu-202208.openldap.ldif  

        # OAuth2 Schemas
        echo "install OIDC Schemas"
        echo "  oidc-client " && slapadd -n 0 -l /install/schema/oidc-client-schema-openldap.ldif 
        echo "  oidc-session " && slapadd -n 0 -l  /install/schema/oidc-session-schema-openldap.ldif
        echo "  oidc-authz " && slapadd -n 0 -l  /install/schema/oidc-authz-schema-openldap.ldif 

        echo "init DB completed"
    fi

    # Check if a directory backup is present 
    if [ -f /backup/backup.ldif ]
    then
        echo "restore backup"
        slapadd -b $ROOT_DN -l /backup/backup.ldif -F /etc/openldap/slapd.d/
        echo "backup restored"
    fi
fi

# ensure that the ldap user to access the config and data
chown -R ldap.ldap /etc/openldap/slapd.d
chown -R ldap.ldap /data

# start the openldap server
/usr/sbin/slapd -d stats -h "ldap:/// ldapi://%2fvar%2frun%2fopenldap%2fsocket" -u ldap -g ldap
