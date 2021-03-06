# Copyright (c) 2020 Hiroshi Tanaka, hirtanak@gmail.com @hirtanak
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
CYCLECLOUD_SPEC_PATH=/mnt/cluster-init/QCMD/master

# get Quantum ESPRESSO version
QE_VERSION=$(jetpack config QE_VERSION)
# set parameters
QE_DL_URL=$(jetpack config QE_DL_URL)
QE_DL_VER=${QE_DL_URL##*/}

# Create tempdir
tmpdir=$(mktemp -d)
pushd $tmpdir

# Azure VMs that have ephemeral storage mounted at /mnt/exports.
if [ ! -d ${HOMEDIR}/apps ]; then
   sudo -u ${CUSER} ln -s /mnt/exports/apps ${HOMEDIR}/apps
   chown ${CUSER}:${CUSER} /mnt/exports/apps
fi
chown -R ${CUSER}:${CUSER} /mnt/exports/apps | exit 0

yum install -y htop

set +u
CMD=$(grep PS1 ${HOMEDIR}/.bashrc) | exit 0
#CMD1=$(grep "Getting latest auth configuration" /opt/cycle/jetpack/logs/initialize.log | head -1 | awk '{print $9}') | exit 0
(grep "Getting latest auth configuration" /opt/cycle/jetpack/logs/initialize.log | head -1 | awk '{print $9}') > ${HOMEDIR}/hostname
CMD2=$(cat ${HOMEDIR}/hostname) && (echo "${CMD2##*\?cluster\=}") > ${HOMEDIR}/hostname
CMD2=$(cat ${HOMEDIR}/hostname)
if [[ -z ${CMD}  ]]; then
   (echo "export PS1='[\\u@${CMD2} \\h \\W]'") >> ${HOMEDIR}/.bashrc
fi
set -u

# file settings
chown -R ${CUSER}:${CUSER} ${HOMEDIR}/apps
cp /opt/cycle/jetpack/logs/cluster-init/QuantumESPRESSO/master/scripts/10.master.sh.out ${HOMEDIR}/
chown ${CUSER}:${CUSER} ${HOMEDIR}/10.master.sh.out

#clean up
popd
rm -rf $tmpdir


echo "end of 10.master.sh"
