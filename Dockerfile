FROM alpine:3.20

## install the latest openldap tools

RUN apk add --no-cache openldap \
                       openldap-backend-all \
                       openldap-overlay-all \
                       openldap-clients \
                       openldap-passwd-pbkdf2 \
                       bash && \
    mkdir -p /install /run/openldap /var/lib/openldap/openldap-data /etc/openldap/slapd.d && \
    chown -R ldap:ldap /run/openldap /var/lib/openldap/openldap-data /etc/openldap/slapd.d

ADD schema /install/schema
ADD slapd.ldif /etc/openldap/slapd.ldif
ADD entrypoint.sh /install/

RUN mkdir -p /data && chmod 755 /install/entrypoint.sh

RUN rm -rf /data/*
EXPOSE 389 636

VOLUME ["/data", "/etc/openldap/slapd.d/"]

ENTRYPOINT ["/install/entrypoint.sh"]
