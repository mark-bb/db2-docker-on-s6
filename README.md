# db2-docker-on-s6
Docker images with root and non-root [IBM DB2](https://www.ibm.com/docs/en/db2) v11.1+ for Linux installations building based on [s6-overlay](https://github.com/just-containers/s6-overlay/blob/master/README.md).
## Introduction
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
- debian12
- debian13

A container with a DB2 **root** installation image runs as privileged.  
A container with a DB2 **non-root**  installation image may run as non-privileged.  
Both images contain a DB2 copy installed (DB2 root installation) or in a form of installation image ((DB2 non-root installation)) inside and are owned by the DB2 instance owner user `db2inst1`, but the s6-overlay services run as root (with a small `init-runner` binary running the `/init` script as root).  
You may build an image owned by `root` if you want just with `ln -sr Dockerfile-rt Dockerfile`.  
## Building images
- clone the project
- place a DB2 installation image version for Linux x86-64 downloaded at the [Download Db2 fix packs by version for Db2 for Linux, UNIX and Windows](https://www.ibm.com/support/pages/download-db2-fix-packs-version-db2-linux-unix-and-windows) link to the `distrib/db2` directory
- to build a DB2 **root** installation image depending on the base OS image needed run something like this:  
`sudo ./rebuild.sh -b ubuntu:22.04 -v 11.5.9 [-s some_env_file]`  
- to build a DB2 **non-root** installation image depending on the base OS image needed run something like this:  
`sudo ./rebuild-nr.sh -b redhat/ubi10 -v 12.1.4 -n [-s some-secret-file]`  
- `some-secret-file` (see the `.secret-*` files) supports the following variables:
  - `ROOT_PASSWORD` - hashed root password
  - `SET_RELEASE`   - OS release file fake content (for non-supported officially OS - use them with care)
  - `ADD_PACKAGES`  - additional packages to install 

- you get the `db2/db2-[rt|nr][-suffix]:VRM` image in your local registry afterwards, where:  
  - `[rt|nr]` means with DB2 root or non-root installation
  - `-suffix` is one of `ubuntu`, `redhat`, `suse`, `amazon` which corresponds to your base OS image selected
  - `VRM` is what you specified with the `-v` flag; it's used just to find the DB2 installation image in the `distrib/db2` directory with `ls distrib/db2/*.gz | grep -E "v${VRM?}_"`
## Running containers  
- Create the `database/` directory  
- DB2 **root** installation container:  
`sudo ./run.sh -b ubuntu:22.04 -v 11.5.9`  
- DB2 **non-root** installation container:  
`sudo ./run.sh -b ubuntu:22.04 -v 11.5.9 -n`  
## Notes
- `sshd` and `postfix` are installed and run in all containers
- the `/database` directory must be mounted inside the container; the object placement in this directory:
  - `/database/config` - home base directories of all users including the DB2 instance owner
  - `/database/data` - the data directory (set as `DFTDBPATH` DBM CFG)
  - `/database/scripts/[pre|post]-start` - all executable scripts found in these directories are executed before (pre-) and after (post-) `db2start`; they are executed as root (for images with a DB2 **root** installation) and as the DB2 instance owner (for images with a DB2 **non-root** installation)
- no any databases are created during the initial DB2 instance creation
- no any additional configuration attempted to configure DB2 HADR or Text Search
- the following variables are supported only at the moment (the `run.sh` script uses the `.env_list` file for that):
  - `DB2INST1_PASSWORD=hased_password` - DB2 instance owner hashed password (you may use `openssl passwd` for that)
  - `# TO_START_INSTANCE=false` - an ability not to start DB2 instance (commented out here)
  - `DB2PORT=50000` - DB2 port to listen inside the container
  - `ADDGROUPS=db2ictrl:1002 db2imnt:1003` - Additional groups in the form of `group_name:group_id` separated by space created in OS
  - `ADDUSERS=repoadmn:1002:$5$8myrzD/5CpVEnwT/$55N6rZyvH2OC/RKA6eOGJAs48QtdxgBpoBwdRvSIML7:db2ictrl,db2imnt maintusr:1003:$5$8myrzD/5CpVEnwT/$55N6rZyvH2OC/RKA6eOGJAs48QtdxgBpoBwdRvSIML7:db2imnt` - Additional users in the form of `user_name:user_id:hashed_password:list_of_groups` separated by space (don't try specify the root user or group - they are ignored) created in OS
- containers cat be run with the additional `-m xG` flag to specify the total memory availabel to the container, and a number of `sysctl` entries are adjusted according to the [Kernel parameter requirements](https://www.ibm.com/docs/en/db2/12.1.x?topic=unix-kernel-parameter-requirements-linux) rules
- the following commands the DB2 instance owner can run with `sudo` (just for info):
```
cat <<EOF | tee /etc/sudoers.d/${DB2INSTANCE?}
Defaults env_keep += "DB2INST1_PASSWORD ADDUSERS ADDGROUPS"
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /setup/scripts/add_users_n_groups.sh
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: ${DB2_HOME?}/instance/db2rfe *
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /usr/bin/chown ${DB2INSTANCE?} ${DB2_HOME?}/global.reg
${DB2INSTANCE?} ALL=(ALL) NOPASSWD: /command/s6-rc *
EOF
```
- the `/setup/scripts/add_users_n_groups.sh` script just processes the `ADDGROUPS` and `ADDUSERS` variables to convert their data to the corresponding OS commands; you may use it on a running container as well setting these system variables accordingly
- the DB2 database creation (which you may run on your own) either with just `CREATE DATABASE` or `db2sampl` takes enormous time I believe (up to 45-60 min, ask IBM for that on what happens inside); so, be patient; you may look at the process with `db2diag -f` (as the DB2 instance owner in case of non-root conainer) - some messages are printed more often there than to the container's log; the same is for the database upgrade
- DB2 instance owner's and fenced user attributes like names, groups, ids can be configured during the images build with the `cfg/utils.d/db2-[rt|nr].sh` scripts; you should leave them as is
- some base OS images don't have 32-bit repos configured, so your 32-bit SP/UDF/apps may fail...

