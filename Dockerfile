# A Dockerfile to build an RT kernel for the Raspberry Pi based on Ubuntu 24.04
#
# If run without parameters the Docker image is created to built RT_PREEMPT patched version of the latest 6.8 raspi kernel
# The Docker build command accepts the following build arguments:
# $ docker build [--build-arg UBUNTU_VERSION=<ubuntu name>] [--build-arg KERNEL_VERSION=<kernel version>]
#                [--build-arg UNAME_R=<raspi release>] [--build-arg RT_PATCH=<RT patch>]
#                [--build-arg LTTNG_VERSION=<LTTNG version>] -t rtwg-image .
#
# where
#   <ubuntu name> is noble, default is noble
#   <kernel version> is in a form of 6.8.0, default is 6.8.0
#   <raspi release> is in a form of 6.8.0-1005-raspi, if not defined the lastest version is taken
#     see http://ports.ubuntu.com/pool/main/l/linux-raspi/
#   <RT patch> is in a form of 6.8.2-rt11, if not defined the closest to the defined <raspi release> is taken
#     see https://cdn.kernel.org/pub/linux/kernel/projects/rt/6.8/
#   <LTTNG version> is 2.13, default is 2.13
#
# To build a Docker image for the latest raspi kernel, run
# $ docker build -t rtwg-image .
#
# To build a Docker image for the stable raspi kernel, run
# $ docker build --build-arg UBUNTU_VERSION=noble --build-arg KERNEL_VERSION=6.8.0 --build-arg UNAME_R=6.8.0-1005-raspi -t rtwg-image .
#
# After that the Docker image is prepared and ready to run
# $ docker run -it rtwg-image bash
#
# and then inside the docker
# $ cd /linux_build/linux-raspi
# $ make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-raspi -j `nproc` bindeb-pkg
#
# user /linux_build/linux-raspi $ ls -la ../*.deb
# -rw-r--r-- 1 user user   9355162 Jul  1 16:44 ../linux-headers-6.8.4-rt11-raspi_6.8.4-g75867ff0890f-4_arm64.deb
# -rw-r--r-- 1 user user  70457678 Jul  1 16:44 ../linux-image-6.8.4-rt11-raspi_6.8.4-g75867ff0890f-4_arm64.deb
# -rw-r--r-- 1 user user   1377154 Jul  1 16:44 ../linux-libc-dev_6.8.4-g75867ff0890f-4_arm64.deb
#
# copy deb packages to the host, or directly to the Raspberry Pi target
# $ scp ../*.deb <user>@172.17.0.1:/home/<user>/.

FROM ubuntu:noble

USER root
ARG DEBIAN_FRONTEND=noninteractive

# setup timezone
RUN echo 'Etc/UTC' > /etc/timezone \
    && ln -s -f /usr/share/zoneinfo/Etc/UTC /etc/localtime \
    && apt-get update && apt-get install -q -y tzdata apt-utils lsb-release software-properties-common openssh-client \
    && rm -rf /var/lib/apt/lists/*

ARG ARCH=arm64
ARG UNAME_R
ARG RT_PATCH
ARG triple=aarch64-linux-gnu
ARG KERNEL_VERSION=6.8.0
ARG UBUNTU_VERSION=noble
ARG LTTNG_VERSION=2.13
ARG KERNEL_DIR=linux-raspi

# setup arch
RUN apt-get update && apt-get install -q -y \
    gcc-${triple} \
    && dpkg --add-architecture ${ARCH} \
    && sed -i 's/deb h/deb [arch=amd64] h/g' /etc/apt/sources.list \
    && sed -i 's/deb h/deb [arch=amd64] h/g' /etc/apt/sources.list.d/* \
    && sed -i '/Components/a\Architectures: amd64' /etc/apt/sources.list.d/*.sources \
    && echo "deb [arch=$ARCH] http://ports.ubuntu.com/ubuntu-ports/ $(lsb_release -s -c) main universe restricted" >> /etc/apt/sources.list.d/ubuntu-ports.list \
    && echo "deb-src [arch=$ARCH] http://ports.ubuntu.com/ubuntu-ports/ $(lsb_release -s -c) main universe restricted" >> /etc/apt/sources.list.d/ubuntu-ports.list \
    && echo "deb [arch=$ARCH] http://ports.ubuntu.com/ubuntu-ports $(lsb_release -s -c)-updates main universe restricted" >> /etc/apt/sources.list.d/ubuntu-ports.list \
    && rm -rf /var/lib/apt/lists/*

# setup environment
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV UID=1000
ENV GID=1000

# install build deps
RUN apt-get update && apt-get build-dep -q -y linux \
    && apt-get install -q -y \
    libncurses-dev flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf \
    fakeroot \
    && rm -rf /var/lib/apt/lists/*

# remove ubuntu user to set our own
RUN userdel -r ubuntu

# setup user
RUN apt-get update && apt-get install -q -y sudo \
    && groupadd -g $GID user \
    && useradd -m -d /home/user -s /bin/bash -u $UID -g $GID user \
    && gpasswd -a user sudo \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && echo 'user\nuser\n' | passwd user \
    && rm -rf /var/lib/apt/lists/*

# install extra packages needed for the patch handling
RUN apt-get update && apt-get install -q -y wget curl gzip git bash-completion time \
    && rm -rf /var/lib/apt/lists/*

# install lttng dependencies
RUN sudo apt-get update \
    && sudo apt-get install -y libuuid1 libpopt0 libxml2 numactl

# Create a directory and set permissions
RUN mkdir -p /linux_build && chown user:user /linux_build

# Define the volume
VOLUME /linux_build

USER user

# find the latest UNAME_R and store it locally for the later usage
# if $UNAME_R is set via --build-arg, take it
RUN if test -z $UNAME_R; then UNAME_R=`curl -s http://ports.ubuntu.com/pool/main/l/linux-raspi/ | grep linux-buildinfo | grep -o -P '(?<=<a href=").*(?=">l)' | grep ${ARCH} | grep ${KERNEL_VERSION} | sort | tail -n 1 | cut -d '-' -f 3-4`-raspi; fi \
    && echo $UNAME_R > /home/user/uname_r

# Set the working directory
WORKDIR /linux_build

# install linux sources from git
RUN git config --global https.postBuffer 1048576000 \
    && git clone -b master --depth 1 --single-branch --jobs=$(($(nproc) * 2)) --progress https://git.launchpad.net/~ubuntu-kernel/ubuntu/+source/linux-raspi/+git/${UBUNTU_VERSION} ${KERNEL_DIR} \
    && cd ${KERNEL_DIR} \
    && git fetch --tag

# checkout necessary tag
RUN cd /linux_build/${KERNEL_DIR} \
    && git tag -l *`cat /home/user/uname_r | cut -d '-' -f 2`* | sort -V | tail -1 > /linux_build/tag \
    && git checkout `cat /linux_build/tag`

# install buildinfo to retrieve `raspi` kernel config
RUN cd /home/user \
    && wget http://ports.ubuntu.com/pool/main/l/linux-raspi/linux-buildinfo-${KERNEL_VERSION}-`cat /home/user/uname_r | cut -d '-' -f 2`-raspi_${KERNEL_VERSION}-`cat /linux_build/tag | cut -d '-' -f 4`_${ARCH}.deb \
    && dpkg -X *.deb /home/user/

COPY ./getpatch.sh /home/user/

# get the nearest RT patch to the kernel SUBLEVEL
# if $RT_PATCH is set via --build-arg, take it
RUN cd /linux_build/${KERNEL_DIR} \
    && if test -z $RT_PATCH; then /home/user/getpatch.sh `make kernelversion` > /home/user/rt_patch; else echo $RT_PATCH > /home/user/rt_patch; fi

# download and unzip RT patch
RUN cd /linux_build \
    && wget http://cdn.kernel.org/pub/linux/kernel/projects/rt/`echo ${KERNEL_VERSION} | cut -d '.' -f 1-2`/older/patch-`cat /home/user/rt_patch`.patch.gz \
    && gunzip patch-`cat /home/user/rt_patch`.patch.gz

# download lttng source for use later
RUN cd /home/user/ \
    && sudo apt-add-repository -s -y ppa:lttng/stable-${LTTNG_VERSION} \
    && sudo apt-get update \
    && apt-get source lttng-modules-dkms

# run lttng built-in script to configure RT kernel
RUN set -x \
    && cd `ls -d /home/user/lttng-modules-*` \
    && ./scripts/built-in.sh /linux_build/${KERNEL_DIR}

# patch kernel, do not fail if some patches are skipped
RUN cd /linux_build/${KERNEL_DIR} \
    && OUT="$(patch -p1 --forward < ../patch-`cat $HOME/rt_patch`.patch)" || echo "${OUT}" | grep "Skipping patch" -q || (echo "$OUT" && false);

# setup build environment
RUN cd /linux_build/${KERNEL_DIR} \
    && export $(dpkg-architecture -a${ARCH}) \
    && export CROSS_COMPILE=${triple}- \
    && fakeroot debian/rules clean \
    && LANG=C fakeroot debian/rules printenv

COPY ./.config-fragment /linux_build/.

# config RT kernel and merge config fragment
RUN cd /linux_build/${KERNEL_DIR} \
    && cp /home/user/usr/lib/linux/`cat /home/user/uname_r`/config .config \
    && ARCH=${ARCH} CROSS_COMPILE=${triple}- ./scripts/kconfig/merge_config.sh .config /linux_build/.config-fragment

RUN cd /linux_build/${KERNEL_DIR} \
    && fakeroot debian/rules clean
