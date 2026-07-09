# supervisord-docker
Non-root supervisord-based docker image with openssh-server, postfix, zookeeper installed as an example.
## Introduction
Whatever application can be relatively easily installed with this project.  
This project consists of installing Haribda, openssh server, postfix(commented out actually, but it's here just for demo).  
## Building the image
Here is the `cfg` directory content to understand, how the project can be adjusted for any application.
```
$ tree cfg/
cfg/
├── configs_restore.sh
├── configs_save.sh
├── install.d
│   ├── 50-openssh.sh
│   ├── 60-postfix.sh
│   ├── 70-users.sh
│   └── 80-zookeeper.sh
├── install.sh
├── shutdown.d
│   └── test.sh
├── startup.d
│   ├── ssh.sh
│   └── zookeeper.sh
├── startup.sh
├── supervisor.d
│   ├── postfix.conf
│   ├── sshd.conf
│   ├── zookeeper.conf
│   └── zookeeper.sh
├── utils.d
│   ├── supervisor.sh
│   ├── users.sh
│   └── zookeeper.sh
└── utils.sh
```
The `rebuild.sh` script is an example of building an image.  
You provide a base image name (like `-b ubuntu:22.04` or `-b redhat/ubi10`) & a secret file (with `-s` to set some variables, optionally).  
It builds an image with the `supervisor/supervisor-${IMAGE_SUFFIX?}` name, where `${IMAGE_SUFFIX?}` is derived from the base image name (like `ubuntu` or `redhat`).

The `install.sh` script is the main build script inside an image. It does the following sequentially:
- installs some additional packages, if you provided their names via secrets / env vars optionally
- installs supervisord & some additional useful packages
- runs all executable scripts in `install.d`
- runs the `configs_save.sh` script which makes a copy of all your files & directories specified in the `install.d` scripts (by adding the corresponding names to a special text file, see the examples); these files & directories are supposed to be copied to the corresponding mounts provided during the run-time once
- the `cfg/install.d/70-users.sh` script creates a container owner user, which runs the `startup.sh` script with `sudo`; this user can run whatever `sudo supervisorctl *` command to control the applications
- look at the examples of installation (`cfg/install.d/*.sh`) and startup (`cfg/startup.d/*.sh`) scripts to understand how to code your own ones
- we need java to run `Zookeeper`; since the correspoinding package can vary on different platforms and versions, we install it (and example for redhat 10) with `-s .secret-redhat10` listing its package in the `ADD_PACKAGES` variable (along with the corresponding `epel` package, since the `supervisor` package is in `epel` for this OS)
## Running containers
The `run.sh` script is an example of running a container.
It accepts the same `-b` parameter as for `rebuild.sh`, but just to derive the corresponding image. The container name is always `supervisor`.  

The `startup.sh` script is the main startup script inside a container. It does the following sequentially:
- runs the `configs_restore.sh` script which copies saved files and directories saved at the setup stage to the correspoinding mounted ones restoring their original OS permissions and modes, if the correspoinding target is empty (directory) or hase zero size (standalone file)
- runs all the executables found in the `startup.d` directory
- starts `supervisord` with all configs you prepared in the `cfg/supervisor.d/*.conf` files
