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
# gitpod ~/linux_build/linux-raspi-5.4.0 $ ls -la ../*.deb
# -rw-r--r-- 1 gitpod gitpod  11430676 May 17 14:40 ../linux-headers-5.4.101-rt53_5.4.101-rt53-1_arm64.deb
# -rw-r--r-- 1 gitpod gitpod 487338132 May 17 14:40 ../linux-image-5.4.101-rt53-dbg_5.4.101-rt53-1_arm64.deb
# -rw-r--r-- 1 gitpod gitpod  39355940 May 17 14:40 ../linux-image-5.4.101-rt53_5.4.101-rt53-1_arm64.deb
# -rw-r--r-- 1 gitpod gitpod   1055272 May 17 14:40 ../linux-libc-dev_5.4.101-rt53-1_arm64.deb
#
# copy deb packages to the host, or directly to the RPI4 target
# $ scp ../*.deb user@172.17.0.1:/home/user/.

FROM gitpod/workspace-full

USER root

# setup timezone
RUN echo 'Etc/UTC' > /etc/timezone && \
    ln -s -f /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    apt-get update && apt-get install -q -y tzdata && rm -rf /var/lib/apt/lists/*

ARG ARCH=arm64
ARG UNAME_R
ARG RT_PATCH
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

# install buildinfo
RUN apt-get update && apt-get install -q -y linux-buildinfo-`cat /uname_r` \
    && rm -rf /var/lib/apt/lists/*

USER gitpod

# install linux sources
RUN mkdir $HOME/linux_build && cd $HOME/linux_build \ 
    && sudo apt-get update && apt-get source linux-image-`cat /uname_r`

COPY ./getpatch.sh /getpatch.sh

# get the nearest RT patch to the kernel SUBLEVEL
# Example:
# ./getpatch.sh 101
# 5.4.102-rt53
# if $RT_PATCH is set via --build-args, take it
RUN cd $HOME/linux_build && cd `ls -d */` \
    && if test -z $RT_PATCH; then /getpatch.sh `make kernelversion | cut -d '.' -f 3` > $HOME/rt_patch; else echo $RT_PATCH > $HOME/rt_patch; fi

# download and unzip RT patch, the closest to the RPI kernel version
# check version with
# ~/linux_build/linux-raspi-5.4.0 $ make kernelversion
RUN cd $HOME/linux_build \
    && wget http://cdn.kernel.org/pub/linux/kernel/projects/rt/5.4/older/patch-`cat $HOME/rt_patch`.patch.gz \
    && gunzip patch-`cat $HOME/rt_patch`.patch.gz

# patch RPI kernel, do not fail if some patches are skipped
RUN cd $HOME/linux_build && cd `ls -d */` \
    && OUT="$(patch -p1 --forward < ../patch-`cat $HOME/rt_patch`.patch)" || echo "${OUT}" | grep "Skipping patch" -q || (echo "$OUT" && false);

# setup build environment
RUN export $(dpkg-architecture -a${ARCH}) && export CROSS_COMPILE=${triple}- \
    && cd $HOME/linux_build && cd `ls -d */` \
    && LANG=C fakeroot debian/rules printenv

WORKDIR $HOME
COPY ./.config-fragment linux_build/.

# config RT kernel and merge config fragment
RUN cd $HOME/linux_build && cd `ls -d */` \
    && cp /usr/lib/linux/`cat /uname_r`/config .config \
    && ARCH=${ARCH} CROSS_COMPILE=${triple}- ./scripts/kconfig/merge_config.sh .config $HOME/linux_build/.config-fragment

RUN cd $HOME/linux_build && cd `ls -d */` \
    && fakeroot debian/rules clean
