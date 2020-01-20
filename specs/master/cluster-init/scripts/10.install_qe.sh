#!/bin/bash
# Copyright (c) 2019 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
set -exuv

echo "starting 10.master.sh"

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# disabling selinux
echo "disabling selinux"
setenforce 0
sed -i -e "s/^SELINUX=enforcing$/SELINUX=disabled/g" /etc/selinux/config

CUSER=$(grep "Added user" /opt/cycle/jetpack/logs/jetpackd.log | awk '{print $6}')
CUSER=${CUSER//\'/}
CUSER=${CUSER//\`/}
# After CycleCloud 7.9 and later 
if [[ -z $CUSER ]]; then 
   CUSER=$(grep "Added user" /opt/cycle/jetpack/logs/initialize.log | awk '{print $6}' | head -1)
   CUSER=${CUSER//\`/}
fi
echo ${CUSER} > /mnt/exports/shared/CUSER
HOMEDIR=/shared/home/${CUSER}
CYCLECLOUD_SPEC_PATH=/mnt/cluster-init/QuantumESPRESSO/master

# get Quantum ESPRESSO version
QE_VERSION=$(jetpack config QE_VERSION)
# set parameters
QE_DL_URL=$(jetpack config QE_DL_URL)
QE_DL_VER=${QE_DL_URL##*/}

# resource ulimit setting
CMD1=$(grep memlock ${HOMEDIR}/.bashrc | head -2)
if [[ -z "${CMD1}" ]]; then
  (echo "ulimit -m unlimited"; echo "source /etc/profile.d/qe.sh") >> ${HOMEDIR}/.bashrc
fi

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir

# Azure VMs that have ephemeral storage mounted at /mnt/exports.
if [ ! -d ${HOMEDIR}/apps ]; then
   sudo -u ${CUSER} ln -s /mnt/exports/apps ${HOMEDIR}/apps
   chown ${CUSER}:${CUSER} /mnt/exports/apps
fi
chown ${CUSER}:${CUSER} /mnt/exports/apps | exit 0

# install packages
yum install -y perl-Digest-MD5.x86_64 redhat-lsb-core centos-release-scl
yum install -y devtoolset-8-gcc devtoolset-8-gcc-c++ devtoolset-8-gcc-gfortran

# License File Setting
LICENSE=$(jetpack config LICENSE)
KEY=$(jetpack config KEY)
(echo "export LICENSE_FILE=${LICENSE}"; echo "export KEY=${KEY}") > /etc/profile.d/qe.sh
chmod a+x /etc/profile.d/qe.sh
chown ${CUSER}:${CUSER} /etc/profile.d/qe.sh

# Don't run if we've already expanded the QuantumESPRESSO tarball. Download QuantumESPRESSO installer into tempdir and unpack it into the apps directory
if [[ ! -f ${HOMEDIR}/apps/${QE_DL_VER} ]]; then
   wget -nv ${QE_DL_URL} -O ${HOMEDIR}/apps/${QE_DL_VER}
   chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/${QE_DL_VER}
fi
#chown ${CUSER}:${CUSER} ${HOMEDIR}/apps/${QE_DL_VER}
tar zxfp ${HOMEDIR}/apps/${QE_DL_VER} -C ${HOMEDIR}/apps
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps/${QE_DL_VER%%.*}

# build and install
#set +u
#make clean
#${HOMEDIR}/apps/${QE_DL_VER%%.*}/configure --with-internal-blas --with-internal-lapack
#make all
#(export PATH=${HOME}/apps/${QE_DL_VER%%.*}/bin:$PATH) >> ${HOMEDIR}/.bashrc
#set -u

# local file settings
if [[ ! -f ${HOMEDIR}/qerun.sh ]]; then
   cp ${CYCLECLOUD_SPEC_PATH}/files/qerun.sh ${HOMEDIR}/
   chmod a+rx ${HOMEDIR}/qerun.sh
   chown ${CUSER}:${CUSER} ${HOMEDIR}/qerun.sh
fi

# file settings
set +u
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps 
cp /opt/cycle/jetpack/logs/cluster-init/QuantumESPRESSO/master/scripts/10.install_qe.sh.out ${HOMEDIR}/
chown ${CUSER}:${CUSER} ${HOMEDIR}/10.install_qe.sh.out
set -u

#clean up
popd
rm -rf $tmpdir

echo "end of 10.master.sh"
