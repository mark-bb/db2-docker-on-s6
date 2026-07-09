#!/bin/bash
#
# FUNCTION: Starts up non-root DB2 container
#

usage() {
  echo -e "Usage example: \n$0 \n\
	  [-b | --base-image] base-image-name - like ubuntu:22.04 \n\
	  [-v | --vrm]        v.r.m           - DB2 Installation image version \n\
	  [-n | --non-root]                   - building DB2 non-root installation \n\
	  [-e | --entrypoint]                 - change entrypoint to /bin/bash \n\
	  [-m | --memory]     X_in_GB         - memory limit in GB \n\
	  " >&2; exit 1;
}

DIR="$(cd "$(dirname "$0")" && pwd -P)"
# read the options
TEMP=$(getopt -o hneb:v:m: --long help,non-root,entrypoint,base-image:,vrm:,memory: -n "$0" -- "$@")
[ $? -ne 0 ] && { echo "Terminating..." >&2; exit 1; } 

# Just for test
#echo "$TEMP"
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -b|--base-image)
            IMAGE_BASE="$2"; shift 2;;
        -v|--vrm)
            VRM="$2"; shift 2;;
        -n|--non-root)
            NON_ROOT="true"; shift;;
        -e|--entrypoint)
            ENTRYPOINT="--entrypoint=/bin/bash"; shift;;
        -m|--memory)
            MEM="$2"; shift 2;;
        --) shift; break;;
        -h|--help) usage; exit 1;;
        *) 
            echo "Internal error!" >&2; exit 1;;
    esac
done

# : ${IMAGE_BASE="redhat/ubi9"}
: ${IMAGE_BASE="ubuntu:22.04"}
[ -z "${VRM?}" ] && { echo "DB2 VRM must be specified" >&2; exit 1; }
: ${MEM="4"}

IMAGE_SUFFIX="unknown"
for img in ubuntu redhat suse amazon alma rocky red-soft debian oracle astra; do
  if printf "${IMAGE_BASE?}" | grep "${img?}" &>/dev/null; then
    IMAGE_SUFFIX="${img?}"
    break
  fi
done

if [ -n "${NON_ROOT}" ]; then
  IMAGE=db2/db2-nr-${IMAGE_SUFFIX?}:${VRM?}
  CONT=db2-nr-${IMAGE_SUFFIX?}-${VRM?}
  PRIVILEGED=""
  DATABASE_DIR="database-nr"
else
  IMAGE=db2/db2-rt-${IMAGE_SUFFIX?}:${VRM?}
  CONT=db2-rt-${IMAGE_SUFFIX?}-${VRM?}
  PRIVILEGED="--privileged"
  DATABASE_DIR="database-rt"
fi

docker stop ${CONT?}
docker rm -f ${CONT?}

# --entrypoint=/bin/bash \
#    --privileged \
#    -v ${DIR?}/distrib/db2/${VRMF?}:/tmp/distrib/db2 \
#  --hostname ${HOST?} \
# In a docker network
set -x
semmsl=250
semmni=$((256*MEM))
semmns=$((semmsl*semmni))
[ ${semmns?} -lt 256000 ] && semmns=256000

set -x
docker run -itd \
    --rm \
    ${PRIVILEGED?} \
    -m ${MEM?}GB \
    --memory-swap=$((MEM+4))GB \
    --stop-timeout 300 \
    --memory-swappiness=5 \
    --ulimit data=-1 \
    --ulimit nofile=65536 \
    --ulimit fsize=-1 \
    --sysctl kernel.shmmni=$((256*MEM)) \
    --sysctl kernel.shmmax=$((MEM*2**30)) \
    --sysctl kernel.shmall=$((2*MEM*2**30/$(getconf PAGESIZE))) \
    --sysctl kernel.sem="${semmsl?} ${semmns?} 32 ${semmni?}" \
    --sysctl kernel.msgmni=$((1024*MEM)) \
    --sysctl kernel.msgmax=65536 \
    --sysctl kernel.msgmnb=65536 \
    -v ${PWD?}/${DATABASE_DIR?}:/database \
    --env-file ${PWD?}/.env_list \
    --name ${CONT?} \
    ${ENTRYPOINT} \
    ${IMAGE}
