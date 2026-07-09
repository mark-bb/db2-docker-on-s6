# db2-docker
DB2 v11.1+ for LUW root and non-root images building
## Introduction
These files allow to create root and non-root docker container images for [DB2 for LUW](https://www.ibm.com/docs/en/db2) RDBMS.  
This was tested on DB2 for LUW 11.1, 11.5, 12.1 with the following base x86-64 OS images:
- registry.access.redhat.com/ubi7
- redhat/ubi9
- redhat/ubi10
- ubuntu:22.04
- ubuntu:24.04
- registry.suse.com/bci/bci-base:15.7
- opensuse/leap:15.6
- amazonlinux
- rockylinux/rockylinux:10-ubi
- almalinux:10

A container on a **root** image:
- contains some specific DB2 version installed inside
- the corresponding container runs as privileged
  
A container on a **non-root** image:
- doesn't contain any DB2 installed inside, just db2 installation prerequisites
- it's much smaller (~ 300MB non-root vs ~2.5GB root), but requires some DB2 installation image mounted for the 1-st run, when the corresponding DB2 code is installed during DB2 non-root instance creation in the db2inst1's home in a mounted directory
- subsequent runs don't require any DB2 installation image to be mounted unless you want to install a DB2 Fix Pack update or a major version upgrade
- can run as non-privileged
- the DB2 instance owner (its parameters like name, uid, gid are configured during the image build time) runs some scripts and commands with `sudo`
## Building images
- clone the project
- create the `distrib/db2/v.r.m.f` directory corresponding to the DB2 installation image version for Linux x86-64 downloaded at the [Download Db2 fix packs by version for Db2 for Linux, UNIX and Windows](https://www.ibm.com/support/pages/download-db2-fix-packs-version-db2-linux-unix-and-windows) link; for example, if you want to use the DB2 11.5 Mod 9 Fix Pack 0 installation image, then you must have the `distrib/db2/11.5.9.0/server_dec/db2setup` file after the image uncompression
- to build a **root** image depending on what the base OS image (these ones below are tested at least) you want to use run something like this:  
`sudo ./rebuild.sh -b ubuntu:22.04 -v 11.5.9.0 [-s some_env_file]`  
- to build a **non-root** image depending on what the base OS image (these ones below are tested at least) you want to use run something like this:  
`sudo ./rebuild-nr.sh -b ubuntu:22.04 [-s some_env_file]`  
- `some_env_file` (see the `.env_build_*` files) supports the following variables:
  - `ROOT_PASSWORD` - hashed root password
  - `SET_RELEASE`   - OS release file fake content
  - `ADD_PACKAGES`  - additional packages to install 

- you get the `db2/db2[-nr][-suffix]` image in your local registry afterwards, where:  
  - `-nr` means non-root (absent for a **root** image)  
  - `-suffix` is one of `ubuntu`, `redhat`, `suse`, `amazon` which corresponds to your base OS image selected  
## Running containers  
- **root** container:  
`sudo ./run.sh -b ubuntu:22.04 -v 11.5.9.0`  
- **non-root** container:  
`sudo ./run-nr.sh -b ubuntu:22.04 -v 11.5.9.0`
## Notes
- when you run a container with a **non-root** image for the 1-st time, you must provide the `-v v.r.m.f` flag, and the `distrib/db2/v.r.m.f` directory with the corresponding DB2 installation image must be accessible; you may omit this flag and not have the installation image in place for subsequent runs unless you want to update / upgrade this DB2 instance
- the `/database` directory must be mounted inside the container; the object placement in this directory:
  - `/database/config` - home base directories of all users including the DB2 instance owner
  - `/database/data` - the data directory (set as DFTDBPATH DBM CFG)
  - `/database/scripts/[pre|post]-start` - all executable scripts found in these directories are executed before (pre-) and after (post-) `db2start`; they are executed as root (for root images) and as DB2 instance owner (for non-root images)
- no any databases are created during the initial DB2 instance creation
- no any additional configuration attempted to configure DB2 HADR or Text Search
- the following variables are supported only at the moment:
  - `DB2INST1_PASSWORD=some_password` - DB2 instance owner password
  - `# TO_START_INSTANCE=false` - an ability not to start DB2 instance (commented out here)
  - `DB2PORT=50000` - DB2 port to listen inside the container
  - `ADDGROUPS=db2grp3:1003 db2grp2:1002` - Additional groups in the form of `group_name:group_id` separated by space created in OS
  - `ADDUSERS=db2user2:1002:hashed_password:db2grp2 db2user4:1004:hashed_password` - Additional users in the form of `user_name:user_id:hashed_password:list_of_groups`  separated by space (don't try specify root user or group - they are ignored) created in OS
- **non-root** containers cat be run with the additional `-m xG` flag to specify the total memory availabel to the container, and a number of `sysctl` entries are adjusted according to the [Kernel parameter requirements](https://www.ibm.com/docs/en/db2/12.1.x?topic=unix-kernel-parameter-requirements-linux) rules
- the following commands the DB2 instance owner can run with `sudo` in an `non-root` container (just for info):
```
cat <<EOF | tee /etc/sudoers.d/${DB2INSTANCE?}
Defaults env_keep += "DB2INST1_PASSWORD ADDUSERS ADDGROUPS"
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /setup/config.sh
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /setup/add_users_n_groups.sh
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: ${DB2_HOME?}/instance/db2rfe *
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /usr/bin/chown ${DB2INSTANCE?} ${DB2_HOME?}/global.reg
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /usr/bin/newaliases
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /usr/sbin/postfix *
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /usr/bin/newaliases
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /usr/sbin/postfix *
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /usr/bin/ssh-keygen -A
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /usr/sbin/sshd
EOF
```
- the `/setup/add_users_n_groups.sh` script just processes the `ADDGROUPS` and `ADDUSERS` variables to convert their data to the corresponding OS commands; you may use it on a running container as well setting these system variables accordingly
- the DB2 database creation (which you may run on your own) either with just `CREATE DATABASE` or `db2sampl` takes enormous time I believe (up to 45-60 min, ask IBM for that on what happens inside); so, be patient; you may look at the process with `db2diag -f` (as the DB2 instance owner in case of non-root conainer) - some messages are printed more often there than to the container's log; the same is for the database upgrade
- DB2 instance owner's and fenced user attributes like names, groups, ids can be configured during the images build with the `cfg[-nr]/utils.sh` script; you should leave them as is
- some base OS images don't have 32-bit repos configured, so your 32-bit SP/UDF/apps may fail...

