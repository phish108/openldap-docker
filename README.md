# openldap-docker

Docker Container for running tweaked openldap service

## Installed Schemas

- cosine
- corba
- nis
- inetorgperson
- ppolicy
- qmail

- oidc-client ([OIDC Consortium](https://bitbucket.org/connect2id/server-ldap-schemas))
- oidc-session ([OIDC Consortium](https://bitbucket.org/connect2id/server-ldap-schemas))
- oidc-authz ([OIDC Consortium](https://bitbucket.org/connect2id/server-ldap-schemas))

- eduperson ([REFEDS](https://wiki.refeds.org/display/STAN/eduPerson)])
- swissedu ([Switch EduID](https://help.switch.ch/aai/support/documents/attributes/))

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
