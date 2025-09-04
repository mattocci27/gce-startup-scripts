# My startup scripts for GCE

## Before running create.sh

- setup port 80 (HTTP) for Rstudio on GCE console
- setup ssh keys on GCE console

## Usage

```
sh create.sh instance-name machine-type
```

- use google cloud shell
- save create.sh in the cloud console
- for example, `sh create.sh hello e2-small` creates an e2-small instance named hello.

![cloud_console](./imgs/startup.png)

## Startup script log

- CentOS and RHEL: `/var/log/messages`
- Debian: `/var/log/daemon.log`
- Ubuntu: `/var/log/syslog`
- SLES: `/var/log/messages`

## Related

- [Macに別れを告げて、クラウド中心の開発生活を始めるまで](https://qiita.com/cognitom/items/c489991a05f9abac748f)


I want to add one more argument to choose ARM or AMD.
if arm
  use
    --image-family ubuntu-2404-lts-arm64
   DEFAULT_MACHINE_TYPE="c4a-standard-2"

if amd
  use
    --image-family ubuntu-2404-lts-amd64
   DEFAULT_MACHINE_TYPE="e2-standard-2"
