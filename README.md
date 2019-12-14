# Startup scripts for GCE

## Before running create.sh

- setup port (80 and HTTPS) on GCE console
- setup ssh keys on GCE console

## Create instance

- use google cloud shell
- save create.sh in the cloud console
- for example, `sh create.sh hello` creates a hello instance.

![cloud_console](./imgs/startup.png)

## Startup script log

- CentOS and RHEL: `/var/log/messages`
- Debian: `/var/log/daemon.log`
- Ubuntu: `/var/log/syslog`
- SLES: `/var/log/messages`