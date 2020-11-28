FROM gitpod/workspace-full

USER root

# setup timezone
RUN echo 'Etc/UTC' > /etc/timezone && \
    ln -s -f /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && apt-get install -q -y tzdata && rm -rf /var/lib/apt/lists/*

ARG ARCH=arm64
ARG UNAME_R=5.4.0-1022-raspi
ARG triple=aarch64-linux-gnu

# setup arch
RUN apt-get update && apt-get install -q -y \
    gcc-${triple} \
    && dpkg --add-architecture ${ARCH} \
    && sed -i 's/deb h/deb [arch=amd64] h/g' /etc/apt/sources.list \
    && add-apt-repository -n -s "deb [arch=$ARCH] http://ports.ubuntu.com/ubuntu-ports/ $(lsb_release -s -c) main universe restricted" \
    && add-apt-repository -n -s "deb [arch=$ARCH] http://ports.ubuntu.com/ubuntu-ports $(lsb_release -s -c)-updates main universe restricted" \
    && rm -rf /var/lib/apt/lists/*

# setup keys

# setup environment
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# install build deps
RUN apt-get update && apt-get build-dep -q -y linux linux-image-${UNAME_R} \
    && apt-get install -q -y \
    libncurses-dev flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf \
    fakeroot \
    && rm -rf /var/lib/apt/lists/*

USER gitpod
# install linux sources
RUN mkdir $HOME/linux_build && cd $HOME/linux_build \ 
    && sudo apt-get update && apt-get source linux-image-${UNAME_R}

# setup build environment
RUN export $(dpkg-architecture -a${ARCH}) && export CROSS_COMPILE=${triple}- \
    && cd $HOME/linux_build && cd `ls -d */` \
    && LANG=C fakeroot debian/rules printenv

