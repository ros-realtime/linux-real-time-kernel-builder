# docker image to build an RT kernel for the RPI4 based on Ubuntu 20.04 RPI4 image
#
# it finds and takes the latest raspi image and the closest to it RT patch
# if the build arguments defined it will build a corresponding version instead
# $ docker build [--build-args UNAME_R=<raspi release>] [--build-args RT_PATCH=<RT patch>] -t rtwg-image .
#
# where <raspi release> is in a form of 5.4.0-1034-raspi, 
#     see https://packages.ubuntu.com/search?suite=default&section=all&arch=any&keywords=linux-image-5.4&searchon=names
# and <RT patch> is in a form of 5.4.106-rt54, 
#     see http://cdn.kernel.org/pub/linux/kernel/projects/rt/5.4/older
#
# $ docker run -it rtwg-image bash 
#
# and then inside the docker
# $ $HOME/linux_build && cd `ls -d */`
# $ make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j `nproc` deb-pkg
# 
# user ~/linux_build/linux-raspi-5.4.0 $ ls -la ../*.deb
# -rw-r--r-- 1 user user  11430676 May 17 14:40 ../linux-headers-5.4.101-rt53_5.4.101-rt53-1_arm64.deb
# -rw-r--r-- 1 user user 487338132 May 17 14:40 ../linux-image-5.4.101-rt53-dbg_5.4.101-rt53-1_arm64.deb
# -rw-r--r-- 1 user user  39355940 May 17 14:40 ../linux-image-5.4.101-rt53_5.4.101-rt53-1_arm64.deb
# -rw-r--r-- 1 user user   1055272 May 17 14:40 ../linux-libc-dev_5.4.101-rt53-1_arm64.deb
#
# copy deb packages to the host, or directly to the RPI4 target
# $ scp ../*.deb <user>@172.17.0.1:/home/<user>/.

FROM ubuntu:focal

USER root
ARG DEBIAN_FRONTEND=noninteractive

# setup timezone
RUN echo 'Etc/UTC' > /etc/timezone \
    && ln -s -f /usr/share/zoneinfo/Etc/UTC /etc/localtime \
    && apt-get update && apt-get install -q -y tzdata apt-utils lsb-release software-properties-common \
    && rm -rf /var/lib/apt/lists/*

ARG ARCH=arm64
ARG UNAME_R
ARG RT_PATCH
ARG triple=aarch64-linux-gnu
ARG LTTNG=2.12

# setup arch
RUN apt-get update && apt-get install -q -y \
    gcc-${triple} \
    && dpkg --add-architecture ${ARCH} \
    && sed -i 's/deb h/deb [arch=amd64] h/g' /etc/apt/sources.list \
    && add-apt-repository -n -s "deb [arch=$ARCH] http://ports.ubuntu.com/ubuntu-ports/ $(lsb_release -s -c) main universe restricted" \
    && add-apt-repository -n -s "deb [arch=$ARCH] http://ports.ubuntu.com/ubuntu-ports $(lsb_release -s -c)-updates main universe restricted" \
    && rm -rf /var/lib/apt/lists/*

# setup environment
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# find the latest UNAME_R and store it locally for the later usage
# Example:
# apt-cache search -n linux-buildinfo-.*-raspi | sort | tail -n 1 | cut -d '-' -f 3-5
# 5.4.0-1034-raspi
# if $UNAME_R is set via --build-args, take it
RUN apt-get update \
    && if test -z $UNAME_R; then UNAME_R=`apt-cache search -n linux-buildinfo-.*-raspi | sort | tail -n 1 | cut -d '-' -f 3-5`; fi \
    && echo $UNAME_R > /uname_r \
    && rm -rf /var/lib/apt/lists/*

# install build deps
RUN apt-get update && apt-get build-dep -q -y linux linux-image-`cat /uname_r` \
    && apt-get install -q -y \
    libncurses-dev flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf \
    fakeroot \
    && rm -rf /var/lib/apt/lists/*

# install buildinfo to retieve `raspi` kernel config
RUN apt-get update && apt-get install -q -y linux-buildinfo-`cat /uname_r` \
    && rm -rf /var/lib/apt/lists/*

# setup user
RUN apt-get update && apt-get install -q -y sudo \
    && useradd -m -d /home/user -s /bin/bash user \
    && gpasswd -a user sudo \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && echo 'user\nuser\n' | passwd user \
    && rm -rf /var/lib/apt/lists/*

# install extra packages needed for the patch handling
RUN apt-get update && apt-get install -q -y wget curl gzip \
    && rm -rf /var/lib/apt/lists/*

USER user
WORKDIR /home/user/linux_build

# install linux sources
RUN sudo apt-get update \
    && sudo chown user:user /home/user/linux_build \
    && apt-get source linux-image-`cat /uname_r` \
    && sudo rm -rf /var/lib/apt/lists/*

# install lttng dependencies
RUN sudo apt-get update \
  && sudo apt-get install -y libuuid1 libpopt0 liburcu6 libxml2 numactl

COPY ./getpatch.sh /getpatch.sh

# get the nearest RT patch to the kernel SUBLEVEL
# Example:
# ./getpatch.sh 101
# 5.4.102-rt53
# if $RT_PATCH is set via --build-args, take it
# get kernel SUBLEVEL via
# $ make kernelversion
RUN cd `ls -d */` \
    && if test -z $RT_PATCH; then /getpatch.sh `make kernelversion | cut -d '.' -f 3` > $HOME/rt_patch; else echo $RT_PATCH > $HOME/rt_patch; fi

# download and unzip RT patch, the closest to the RPI kernel version
RUN wget http://cdn.kernel.org/pub/linux/kernel/projects/rt/5.4/older/patch-`cat $HOME/rt_patch`.patch.gz \
    && gunzip patch-`cat $HOME/rt_patch`.patch.gz

# patch `raspi` kernel, do not fail if some patches are skipped
RUN cd `ls -d */` \
    && OUT="$(patch -p1 --forward < ../patch-`cat $HOME/rt_patch`.patch)" || echo "${OUT}" | grep "Skipping patch" -q || (echo "$OUT" && false);

# setup build environment
RUN cd `ls -d */` \
    && export $(dpkg-architecture -a${ARCH}) \
    && export CROSS_COMPILE=${triple}- \
    && LANG=C fakeroot debian/rules printenv

COPY ./.config-fragment .

# config RT kernel and merge config fragment
RUN cd `ls -d */` \
    && cp /usr/lib/linux/`cat /uname_r`/config .config \
    && ARCH=${ARCH} CROSS_COMPILE=${triple}- ./scripts/kconfig/merge_config.sh .config $HOME/linux_build/.config-fragment

RUN cd `ls -d */` \
    && fakeroot debian/rules clean

# download lttng source for use later
# TODO(flynneva): make script to auto-determine which version to get?
RUN cd $HOME \
  && wget https://lttng.org/files/lttng-modules/lttng-modules-latest-${LTTNG}.tar.bz2 \
  && tar -xf *.tar.bz2 

# run lttng built-in script to configure RT kernel
RUN set -x \
  && export KERNEL_DIR=`ls -d */` \
  && cd $HOME \
  && cd `ls -d lttng-*/` \
  && ./scripts/built-in.sh ${HOME}/linux_build/${KERNEL_DIR} \
  && ./scripts/rt-patch-version.sh ${HOME}/linux_build/${KERNEL_DIR}
