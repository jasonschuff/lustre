#!/bin/bash

lustre_version=${1-2.12}

echo "*** Robinhood prereqs done installing ***"

yum install -y git autogen rpm-build autoconf automake gcc libtool glib2-devel libattr-devel mariadb-devel mailx bison flex epel-release

echo "*** Robinhood prereqs done installing ***"

echo "*** Installing Robinhood Packages ***"

# install rbh packages
yum install -y \
    https://azurehpc.azureedge.net/rpms/robinhood-adm-3.1.6-1.x86_64.rpm \
    https://azurehpc.azureedge.net/rpms/robinhood-tools-3.1.6-1.lustre2.12.el7.x86_64.rpm \
    https://azurehpc.azureedge.net/rpms/robinhood-lustre-3.1.6-1.lustre2.12.el7.x86_64.rpm 

yum install -y https://azurehpc.azureedge.net/rpms/robinhood-webgui-3.1.6-1.x86_64.rpm

: '
yum install -y https://sourceforge.net/projects/robinhood/files/robinhood/3.1.6/RPMS/el7-lustre2.12/robinhood-lustre-3.1.6-1.lustre${lustre_version}.el7.x86_64.rpm
yum install -y https://sourceforge.net/projects/robinhood/files/robinhood/3.1.6/RPMS/robinhood-adm-3.1.6-1.x86_64.rpm
yum install -y https://sourceforge.net/projects/robinhood/files/robinhood/3.1.6/RPMS/robinhood-webgui-3.1.6-1.x86_64.rpm
'

echo "*** Robinhood packages installed ***"


weak-modules --add-kernel --no-initramfs

