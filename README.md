# openldap-docker

Docker Container for running tweaked openldap service

## Installed Schemas

- `corba`
- `ppolicy`
- `qmail`

- `oidc-client` ([OIDC Consortium](https://bitbucket.org/connect2id/server-ldap-schemas))
- `oidc-session` ([OIDC Consortium](https://bitbucket.org/connect2id/server-ldap-schemas))
- `oidc-authz` ([OIDC Consortium](https://bitbucket.org/connect2id/server-ldap-schemas))

- `eduperson` ([REFEDS](https://wiki.refeds.org/display/STAN/eduPerson))
- `swissedu` ([Switch EduID](https://help.switch.ch/aai/support/documents/attributes/))

## Initial Configuration

Some configuration needs to be presented on the intial run if `/data/data.mdb` is *not* present.

The configuration is set by a environment varaibles or as docker secrets (Swarm)/configs (Compose).

After the initial configuration, all environment variables can be safely removed. 

### Secret files

- `root_password` -> target: `/install/password`: The initial root password in plain text. 
- `init_config` -> target: `/install/init.conf`: The environment variables to configure the entrypoint

### Envrionment Variables

Normally these Variables are set via the `init.conf`, but could be set via the docker environment, too. 
All environment variables are needed only for initializing the directory during the first launch

- `LDAP_ADMIN` (defaults to `admin`): Sets the admin user name. 
- `LDAP_PASSWORD` (defaults to `secret`): Initializes the admin user password. 
- `LDAP_DOMAIN` (defaults to `private.domain`): initialises the root to the directory to `dc=private,dc=domain`. 

## Seeding from backups

In order to restore a directory from a backup that has been generated with 
`slapcat` one has to include the backup files in a special volume. This volumne
needs to get mouted as `/backup` in the container and must include one or two
files:

- `backup.ldif` - with the directory backup
- `config.ldif` - with the configuration backup

## Upgrading a major release 

For a major release one should backup the directory, but NOT the configuration.
The configuration tends to include breaking changes between the releases and 
should be recreated from scratch.

When restoring from a backup the Domain, root user (without domain), and the 
root password need to be provided in addition to the directory backup. This 
will prepare a fresh configuration. 

Ensure that you place a file with the admin/manager password in a file inside 
your `backup`-folder.

## Examples

Launch from scratch with defaults

```
docker run -it --rm -p 389:389 \
           -e LDAP_DOMAIN=example.com \
           -v $(pwd)/data:/data \
           -v $(pwd)/config:/etc/openldap/slapd.d \
           phish108/openldap:2.6.6-1
```

Fully recreate from backup.

```
docker run -it --rm -p 389:389 \
           -v $(pwd)/backup:/backup \
           -v $(pwd)/data:/data \
           -v $(pwd)/config:/etc/openldap/slapd.d \
           phish108/openldap:2.6.6-1
```

Upgrade from a previous release.

```
docker run -it --rm -p 389:389 \
           -e LDAP_DOMAIN=example.com \
           -e LDAP_ADMIN=manager \
           -e LDAP_PASSWORD_FILE=FILENAME_IN_BACKUP \
           -v $(pwd)/backup:/backup \
           -v $(pwd)/data:/data \
           -v $(pwd)/config:/etc/openldap/slapd.d \
           phish108/openldap:2.6.6-1
```

Launch normally.

```
docker run -it --rm -p 389:389 \
           -v $(pwd)/data:/data \
           -v $(pwd)/config:/etc/openldap/slapd.d \
           phish108/openldap:2.6.6-1
```

Composefile for running normally in a docker swarm.

```YAML
version: '3.3'
services:
  ldapserver:
    image: phish108/openldap:2.6.6-1
    networks:
      - ldapcluster
    volumes:
      - "ldapdata:/data"
      - "ldapconfig:/etc/openldap/slapd.d"
    ports:
      - "3890:389"

volumes:
  ldapdata:
    external: true
  ldapconfig:
    external: true

networks:
  ldapcluster:
    external: true
```

Composefile updating in a docker swarm

```YAML
version: '3.3'
services:
  ldapserver:
    image: phish108/openldap:2.6.6-1
    networks:
      - ldapcluster
    environment:
      LDAP_DOMAIN: example.com
      LDAP_ADMIN: Manager
      LDAP_PASSWORD_FILE: ldap_password
    volumes:
      - "ldapbackup:/backup"
      - "ldapdata:/data"
      - "ldapconfig:/etc/openldap/slapd.d"
    secrets:
      - source: ldap_password
        target: /install/ldap_password
    ports:
      - "3890:389"

volumes:
  ldapbackup:
    external: true
  ldapdata:
    external: true
  ldapconfig:
    external: true

networks:
  ldapcluster:
    external: true

secrets:
  ldap_password:
    external: true
```