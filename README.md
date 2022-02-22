# Build ```RT_PREEMPT``` kernel for Raspberry Pi 4

[![RPI4 RT Kernel build](https://github.com/ros-realtime/linux-real-time-kernel-builder/actions/workflows/rpi4-kernel-build.yml/badge.svg)](https://github.com/ros-realtime/linux-real-time-kernel-builder/actions/workflows/rpi4-kernel-build.yml)

## Introduction

This README describes necessary steps to build and install ```RT_PREEMPT``` Linux kernel for the Raspberry Pi4 board. RT Kernel is a part of the ROS2 real-time system setup. Raspberry Pi4 is a reference board used by the ROS 2 real-time community for the development. RT Kernel is configured as described in [Kernel configuration section](#kernel-configuration). Kernel is built automatically by the Github action, and the artifacts are located under the [```RPI4 RT Kernel build```](https://github.com/ros-realtime/linux-real-time-kernel-builder/actions/workflows/rpi4-kernel-build.yml). Please follow [installation instructions](#deploy-new-kernel-on-raspberry-pi4) to deploy a new kernel to the RPI4 board.

## Raspberry Pi 4 RT Linux kernel

Ubuntu ```raspi``` kernel is modified to produce an RT Linux kernel. Ubuntu is a ROS 2 Tier 1 platform and Ubuntu kernel was selected to align to it.  

## Download ready-to-use RT Kernel ```deb``` packages

RT Kernel is configured using configuration parameters from the [](.config-fragment) file. In the case you need to build your own kernel read the description below.

### Using GUI

Go to the ```Action``` tab, find the latest ```RPI4 RT Kernel build```, go inside the latest workflow run, download, and unzip artifacts called ```RPI4 RT Kernel deb packages```. This archive contains four debian packages. Follow [instructions](#deploy-new-kernel-on-raspberry-pi4) to deploy them on the RPI4.

### Using command line

Go to the [```Developer settings```](https://github.com/settings/tokens) and generate a token to access the repo via Github API. Use this token in conjunction with your Github name to retrieve build artifacts.

```bash
$ token=<my_token>
# rertieve all artifacts
$ curl -i -u <my github name>:$token -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/ros-realtime/linux-real-time-kernel-builder/actions/artifacts | grep archive_download_url
      "archive_download_url": "https://api.github.com/repos/ros-realtime/linux-real-time-kernel-builder/actions/artifacts/91829081/zip",
      "archive_download_url": "https://api.github.com/repos/ros-realtime/linux-real-time-kernel-builder/actions/artifacts/91534731/zip",

# download the latest one
$ curl -u <my github name>:$token -L -H "Accept: application/vnd.github.v3+json"  https://api.github.com/repos/ros-realtime/linux-real-time-kernel-builder/actions/artifacts/91829081/zip  --output rpi4_rt_kernel.zip

$ unzip rpi4_rt_kernel.zip
```

## Raspberry Pi 4 RT Linux kernel build

Ubuntu 20.04 ```x86_64``` based ```Dockerfile``` is developed to cross-compile a new kernel.

### Build environment

Docker container comes with cross-compilation tools installed, and a ready-to-build RT Linux kernel:

* ARMv8 cross-compilation tools
* Linux source build dependencies
* Linux source ```buildinfo```, from where kernel config is copied
* Ubuntu ```raspi``` Linux source installed under ```~/linux_build```
* RT kernel patch downloaded and applied - the nearest to the recent ```raspi``` Ubuntu kernel

It finds the latest ```raspi``` ```linux-image``` and the closest to it RT patch. If the build arguments specified it will build a corresponding kernel version instead.

### Build and run docker container

For the local build:

```bash
git clone https://github.com/ros-realtime/linux-real-time-kernel-builder
cd linux-real-time-kernel-builder
```

```bash
docker build [--build-arg UNAME_R=<raspi release>] [--build-arg RT_PATCH=<RT patch>] -t rtwg-image .
```

where:

* ```<raspi release>``` is in a form of ```5.4.0-1034-raspi```,  see [Ubuntu raspi Linux kernels](https://packages.ubuntu.com/search?suite=default&section=all&arch=any&keywords=linux-image-5.4&searchon=names)
* ```<RT patch>``` is in a form of ```5.4.106-rt54```, see [RT patches](http://cdn.kernel.org/pub/linux/kernel/projects/rt/5.4/older)

```bash
docker run -t -i rtwg-image bash
```

### Kernel configuration

There is a separate kernel configuration fragment```.config-fragment``` introduced to apply ROS2 real-time specific kernel settings. Below is an example:

```bash
$ cat .config-fragment
CONFIG_PREEMPT_RT=y
CONFIG_NO_HZ_FULL=y
CONFIG_HZ_1000=y
# CONFIG_AUFS_FS is not set
```

If you need to reconfigure it, run

```bash
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
```

Alternatively, you can modify ```.config-fragment``` and then merge your changes in the ```.config``` by running

```bash
cd $HOME/linux_build/linux-raspi-*
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./scripts/kconfig/merge_config.sh .config $HOME/linux_build/.config-fragment
```

### Kernel build

```bash
cd $HOME/linux_build/linux-raspi-*
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j `nproc` deb-pkg
```

You need 16GB free disk space to build it, it takes a while, and the results are located:

```bash
raspi ~/linux_build/linux-raspi-5.4.0 $ ls -la ../*.deb
-rw-r--r-- 1 user user  11430676 May 17 14:40 ../linux-headers-5.4.101-rt53_5.4.101-rt53-1_arm64.deb
-rw-r--r-- 1 user user 487338132 May 17 14:40 ../linux-image-5.4.101-rt53-dbg_5.4.101-rt53-1_arm64.deb
-rw-r--r-- 1 user user  39355940 May 17 14:40 ../linux-image-5.4.101-rt53_5.4.101-rt53-1_arm64.deb
-rw-r--r-- 1 user user   1055272 May 17 14:40 ../linux-libc-dev_5.4.101-rt53-1_arm64.deb
```

## Deploy new kernel on Raspberry Pi4

### Download and install Ubuntu 20.04 server image

Follow these links to download and install Ubuntu 20.04 on your Raspberry Pi4

* [Install Ubuntu on a Raspberry Pi](https://ubuntu.com/download/raspberry-pi)
* [Download Ubuntu Raspberry Pi server image](https://ubuntu.com/download/raspberry-pi/thank-you?version=20.04.3&architecture=server-arm64+raspi)
* [Create an Ubuntu image for a Raspberry Pi on Ubuntu](https://ubuntu.com/tutorials/create-an-ubuntu-image-for-a-raspberry-pi-on-ubuntu#2-on-your-ubuntu-machine)

```bash
# initial username and password
ubuntu/ubuntu
```

### Update your system

After that you need to connect to the Internet and update your system

```bash
$ sudo apt-get update && apt-get upgrade
```

### Install Ubuntu Desktop (optional)

Optionally you can install a desktop version

```bash
$ sudo apt-get update && apt-get upgrade && apt-get install ubuntu-desktop
```

### Copy a new kernel to your system and install it

Assumed you have already copied all ```*.deb``` kernel packages to your ```$HOME``` directory

```bash
cd $HOME
sudo dpkg -i *.deb

sudo reboot
```

After reboot you should see a new RT kernel installed

```bash
ubuntu@ubuntu:~$ uname -a
Linux ubuntu 5.4.101-rt53 #1 SMP PREEMPT_RT Mon May 17 12:10:16 UTC 2021 aarch64 aarch64 aarch64 GNU/Linux
```

## Intel UP2 board RT kernel build

To build ```x86_64``` Linux kernel, see [Building Realtime rt_preempt kernel for ROS 2](https://index.ros.org/doc/ros2/Tutorials/Building-Realtime-rt_preempt-kernel-for-ROS-2)

## Why is LTTng included in the kernel?

[LTTng](https://lttng.org/docs) stands for _Linux Trace Toolkit: next generation_ and is an open source toolkit that enables low-level kernel tracing which can be extremely useful when calculating callback times, memory usage and many other key characteristics.

As this repository is within the `ros-realtime` organization it can be assumed that most users will install ROS 2 on the end system - which then they can use `ros2_tracing` to trace various things. Since [`ros2_tracing`](https://gitlab.com/ros-tracing/ros2_tracing) uses LTTng as its tracer, and since [the `lttng-modules` package is not easily available](https://github.com/ros-realtime/linux-real-time-kernel-builder/issues/16) for the raspberry-pi RT linux kernel we build it into the kernel here as a work around.

## References

* [ROS Real-Time Working group documentation](https://real-time-working-group.readthedocs.io/en/rolling/Guides/Real-Time-Operating-System-Setup/Real-Time-Linux/rt_linux_index.html)
* [Ubuntu raspi linux images](https://packages.ubuntu.com/search?suite=default&section=all&arch=any&keywords=linux-image-5.4&searchon=names)
* [RT patches](http://cdn.kernel.org/pub/linux/kernel/projects/rt/5.4/older)
* [Download Ubuntu raspi image](https://ubuntu.com/download/raspberry-pi/thank-you?version=20.04&architecture=arm64+raspi)
* [Building Realtime ```RT_PREEMPT``` kernel for ROS 2](https://index.ros.org/doc/ros2/Tutorials/Building-Realtime-rt_preempt-kernel-for-ROS-2/)
