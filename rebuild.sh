#!/bin/bash
#
# Function: Builds a DB2 non-root image.
#

usage() {
  echo -e "Usage example: \n$0 \n\
          [-b | --base-image]  base-image-name - like ubuntu:22.04 \n\
	  [-v | --vrm]         v.r.m           - DB2 Installation image version \n\
	  [-s | --secret-file] some_env_file   - will be mounted to /run/secrets/secret (optional) \n\
	  [-n | --non-root]                    - building DB2 non-root installation \n\
          " >&2; exit 1;
}

DIR="$(cd "$(dirname "$0")" && pwd -P)"
# read the options
TEMP=$(getopt -o hnb:v:s: --long help,non-root,base-image:vrm:secret-file: -n "$0" -- "$@")
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
        -s|--secret-file)
            SECRET_FILE="$2"; shift 2;;
        -n|--non-root)
            NON_ROOT="true"; shift;;
        --) shift; break;;
        -h|--help) usage; exit 1;;
        *)
            echo "Internal error!" >&2; exit 1;;
    esac
done

# : ${IMAGE_BASE="redhat/ubi9"}
: ${IMAGE_BASE="ubuntu:22.04"}
[ -z "${VRM?}" ] && { echo "DB2 VRM must be specified" >&2; exit 1; }
[ -n "${SECRET_FILE}" ] && SECRET="--secret id=secret,src=${SECRET_FILE}" || SECRET=""
DB2DISTR=$(ls distrib/db2/*.gz | grep -E "v${VRM?}_")
[ -z "${DB2DISTR?}" ] && { echo "No DB2 installation image found for the ${VRM?} arg" >&2; exit 1; }

IMAGE_SUFFIX="unknown"
for img in ubuntu redhat suse amazon alma rocky red-soft debian oracle astra; do
  if printf "${IMAGE_BASE?}" | grep "${img?}" &>/dev/null; then
    IMAGE_SUFFIX="${img?}"
    break
  fi
done

S6_USER_CONTENTS_DIR="${DIR?}/cfg/s6-rc.d/user/contents.d"
CFG_INSTALL_DIR="${DIR?}/cfg/install.d"
if [ -n "${NON_ROOT}" ]; then
  # Building DB2 non-root installation
  IMAGE=db2/db2-nr-${IMAGE_SUFFIX?}:${VRM?}
  CONT=db2-nr-${IMAGE_SUFFIX?}-${VRM?}
  for tf in db2-rt db2-rt-init; do rm -f "${S6_USER_CONTENTS_DIR?}/${tf?}"; done
  for tf in db2-nr db2-nr-init; do touch "${S6_USER_CONTENTS_DIR?}/${tf?}"; done
  chmod -x "${CFG_INSTALL_DIR?}/70-db2-rt.sh"
  chmod +x "${CFG_INSTALL_DIR?}/70-db2-nr.sh"
else
  # Building DB2 root installation
  IMAGE=db2/db2-rt-${IMAGE_SUFFIX?}:${VRM?}
  CONT=db2-rt-${IMAGE_SUFFIX?}-${VRM?}
  for tf in db2-rt db2-rt-init; do touch "${S6_USER_CONTENTS_DIR?}/${tf?}"; done
  for tf in db2-nr db2-nr-init; do rm -f "${S6_USER_CONTENTS_DIR?}/${tf?}"; done
  chmod +x "${CFG_INSTALL_DIR?}/70-db2-rt.sh"
  chmod -x "${CFG_INSTALL_DIR?}/70-db2-nr.sh"
fi

docker stop ${CONT?}
docker rm -f ${CONT?}
docker rmi ${IMAGE} --force
set -x
docker build \
	-f Dockerfile \
	--no-cache \
	${SECRET?} \
	-t ${IMAGE?} \
	--build-arg DB2_VRM=${VRM?} \
	--build-arg IMAGE_BASE=${IMAGE_BASE?} \
	--progress=plain \
	.
