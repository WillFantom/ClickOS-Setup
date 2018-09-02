#!/bin/bash
set -e

## Setup script for a ClickOS Server using Xen & Ubuntu Server 16.04
## Last Updated 25/08/2018
## Will Fantom

#####################
####  VARIABLES  ####
#####################

# Paths
BASE_DIR="/root"
SCRIPT_DIR="/scripts"
INSTALLSCRIPT_DIR="/install"
APT_SOURCES="/etc/apt/sources.list"

# Xen Version
XEN_BRANCH="stable-4.11"

# Make Jobs
MAKE_JOBS=4

# Mirrors
UK_DEB="deb http://uk.archive.ubuntu.com/ubuntu/ xenial main universe"
UK_DEB_SRC="deb-src http://uk.archive.ubuntu.com/ubuntu/ xenial main universe"

# Echo Marks
CHECK="\033[0;32m\xE2\x9C\x94\033[0m"

#####################
####  FUNCTIONS  ####
#####################

# Print in bold
function echoBold {
    bold=$(tput bold)
    std=$(tput sgr0)
    echo "${bold}$1${std}"
}

# Print in bold with CheckMark
function echoCompleted {
    bold=$(tput bold)
    std=$(tput sgr0)
    echo -e "\\r${CHECK} ${bold}$1${std}"
}

# Check that the current user is 'root'
function ensureRoot {
    echoBold "Checking Root User"
    if [ "$EUID" -ne 0 ] 
        then echoBold "You must be root to run the ClickOS setup"
        exit
    fi
    echoCompleted "Root User Confirmed"
}

# Move the install script from the current dir to the install scripts dir
function moveScripts {
    echoBold "Moving Scripts"
    mkdir -p $BASE_DIR$SCRIPT_DIR$INSTALLSCRIPT_DIR
    cp ./* $BASE_DIR$SCRIPT_DIR$INSTALLSCRIPT_DIR"/"
    echoCompleted "Scripts Moved"
}

# Add UK ubunut mirrors to sources
function addMirrors {
    echoBold "Adding new Mirrors"
    echo $UK_DEB >> $APT_SOURCES
    echo $UK_DEB_SRC >> $APT_SOURCES
    apt-get update -qq
    echoCompleted "Mirrors Added"
}

# Clone all repos from github
function cloneRepos {
    echoBold "Cloning Repos"
    cd $BASE_DIR
    apt-get install git -y -qq
    if [ ! -d ./xen ]; then 
        git clone -b $XEN_BRANCH https://github.com/xen-project/xen
    fi
    if [ ! -d ./clickos ]; then 
        git clone https://github.com/sysml/clickos
    fi
    if [ ! -d ./mini-os ]; then 
        git clone https://github.com/sysml/mini-os
    fi
    if [ ! -d ./clickos-ctl ]; then 
        git clone https://github.com/sysml/clickos-ctl
    fi
    if [ ! -d ./toolchain ]; then 
        git clone https://github.com/sysml/toolchain
    fi
    echoCompleted "Cloned Repositories"
}

# Build and install Xen
function xenSetup {
    echoBold "Setting up Xen"

    #Get Deps
    apt-get install git build-essential -y -qq
    apt-get install bcc bin86 gawk bridge-utils iproute libcurl3 libcurl4-openssl-dev bzip2 module-init-tools transfig tgif -y -qq
    apt-get install texinfo texlive-latex-base texlive-latex-recommended texlive-fonts-extra texlive-fonts-recommended pciutils-dev mercurial -y -qq
    apt-get install make gcc libc6-dev zlib1g-dev python python-dev python-twisted libncurses5-dev patch libvncserver-dev libsdl-dev libjpeg-dev -y -qq 
    apt-get install iasl libbz2-dev e2fslibs-dev git-core uuid-dev ocaml ocaml-findlib libx11-dev bison flex xz-utils libyajl-dev -y -qq
    apt-get install gettext libpixman-1-dev libaio-dev markdown pandoc -y -qq
    apt-get install libglib2.0-dev libyajl-dev libpixman-1-dev libxenstore3.0 libjansson-dev git -y -qq
    apt-get build-dep xen -y -qq

    #Export Root
    export XEN_ROOT=$BASE_DIR"/xen"
    cd $XEN_ROOT

    #Build & Install
    ./configure
    make -j$MAKE_JOBS world
    make install

    #Enable Services
    /sbin/ldconfig
    update-rc.d xencommons defaults 19 18
    update-rc.d xendomains defaults 21 20
    update-rc.d xen-watchdog defaults 22 23

    #Modify GRUB default
    sed -i s/GRUB_DEFAULT=0/GRUB_DEFAULT=3/g /etc/default/grub
    update-grub

    echoCompleted "Xen Setup Complete"
}

# Build ClickOS
function clickosSetup {
    echoBold "Setting up ClickOS"

    #Export env vars
    export MINIOS_ROOT=$BASE_DIR/mini-os
    export CLICKOS_ROOT=$BASE_DIR/clickos
    export TOOLCHAIN_ROOT=$BASE_DIR/toolchain
    export CLICKOSCTL_ROOT=$BASE_DIR/clickos-ctl

    #Build Toolchain
    cd $TOOLCHAIN_ROOT
    make
    export NEWLIB_ROOT=$TOOLCHAIN_ROOT"/x86_64-root/x86_64-xen-elf"
    export LWIP_ROOT=$TOOLCHAIN_ROOT"/x86_64-root/x86_64-xen-elf"

    #Build ClickOS with MiniOS
    cd $CLICKOS_ROOT
    ./configure --enable-minios --with-xen=$XEN_ROOT --with-minios=$MINIOS_ROOT
    make -j$MAKE_JOBS minios

    #Build ClickOS Ctl
    cd  $CLICKOSCTL_ROOT
    make -j$MAKE_JOBS

    echoCompleted "ClickOS Setup Complete"
}

# Install Open vSwitch
function ovsSetup {
    echoBold "Setting up OvS"

    #Install from deb package
    apt-get install openvswitch-switch -y -qq --show-progress

    #Get device names
    IFACE_NAME=""
    BRIDGE_NAME=""
    read -p "Enter the OvS Bridge name (e.g. xnebr0)... " BRIDGE_NAME
    read -p "Enter the OVS Port name (e.g. eth0)... " IFACE_NAME

    #Chane interfaces file
    sed -i s/OvS_Bridge_Name/"$BRIDGE_NAME"/g $BASE_DIR$SCRIPT_DIR$INSTALLSCRIPT_DIR"/interfaces template"
    sed -i s/Interface_Name/"$IFACE_NAME"/g $BASE_DIR$SCRIPT_DIR$INSTALLSCRIPT_DIR"/interfaces template"
    cp $BASE_DIR$SCRIPT_DIR$INSTALLSCRIPT_DIR"/interfaces template" /etc/network/interfaces

    echoCompleted "OvS Setup Complete"
}

################
####  MAIN  ####
################

function main {
    echoBold "Setting Up ClickOS Server"

    ensureRoot
    moveScripts
    addMirrors
    cloneRepos
    xenSetup
    clickosSetup
    ovsSetup

    echoCompleted "ClickOS Server Setup Complete"
    echoBold "Rebooting..."

    reboot
}

main
