# docker image to build an RT kernel for the RPI4 based on Ubuntu 20.04 RPI4 image
#
# $ docker build -t rtwg-image .
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
ARG UNAME_R=5.4.0-1034-raspi
ARG RT_PATCH=5.4.102-rt53
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

# install buildinfo
RUN apt-get update && apt-get install -q -y linux-buildinfo-${UNAME_R} \
    && rm -rf /var/lib/apt/lists/*

USER gitpod
# install linux sources
RUN mkdir $HOME/linux_build && cd $HOME/linux_build \ 
    && sudo apt-get update && apt-get source linux-image-${UNAME_R}

# download and unzip RT patch, the closest to the RPI kernel version
# check version with
# ~/linux_build/linux-raspi-5.4.0 $ make kernelversion
RUN cd $HOME/linux_build \
    && wget http://cdn.kernel.org/pub/linux/kernel/projects/rt/5.4/older/patch-${RT_PATCH}.patch.gz \
    && gunzip patch-${RT_PATCH}.patch.gz

# patch RPI kernel, do not fail if some patches are skipped
RUN cd $HOME/linux_build && cd `ls -d */` \
    && OUT="$(patch -p1 --forward < ../patch-${RT_PATCH}.patch)" || echo "${OUT}" | grep "Skipping patch" -q || (echo "$OUT" && false);

# setup build environment
RUN export $(dpkg-architecture -a${ARCH}) && export CROSS_COMPILE=${triple}- \
    && cd $HOME/linux_build && cd `ls -d */` \
    && LANG=C fakeroot debian/rules printenv

# config RPI RT kernel
# set CONFIG_PREEMPT_RT, CONFIG_NO_HZ_FULL CONFIG_HZ_1000
# already enabled CONFIG_HIGH_RES_TIMERS, CPU_FREQ_DEFAULT_GOV_PERFORMANCE
# disable CONFIG_AUFS_FS, it fails to compile
RUN cd $HOME/linux_build && cd `ls -d */` \
    && cp /usr/lib/linux/${UNAME_R}/config .config \
    && ./scripts/config -d CONFIG_PREEMPT \
    && ./scripts/config -e CONFIG_PREEMPT_RT \
    && ./scripts/config -d CONFIG_NO_HZ_IDLE \
    && ./scripts/config -e CONFIG_NO_HZ_FULL \
    && ./scripts/config -d CONFIG_HZ_250 \
    && ./scripts/config -e CONFIG_HZ_1000 \
    && ./scripts/config -d CONFIG_AUFS_FS \
    && yes '' | make ARCH=${ARCH} CROSS_COMPILE=${triple}- oldconfig 

RUN cd $HOME/linux_build && cd `ls -d */` \
    && fakeroot debian/rules clean
