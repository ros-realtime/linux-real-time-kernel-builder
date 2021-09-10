# Introduction

This README describes necessary steps to install ```RT_PREEMPT``` Linux kernel for the Raspberry Pi4 board, which is built by the ```rpi4-kernel-build``` Github action. RT Kernel is a part of the ROS2 real-time system. Raspberry Pi4 is a reference board used by the ROS2 real-time community for the development. Please follow [installation instructions](#deploy-new-kernel-on-raspberry-pi4). RT Kernel is configured as described in [Kernel configuration section](#kernel-configuration).

In the case you need to build your own kernel read the description below.

## Raspberry Pi 4 RT Linux kernel

Ubuntu ```raspi``` kernel is modified to produce an RT Linux kernel. Ubuntu kernel is selected to align to one of the ROS2 Tier 1 platforms.  

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
$ git clone https://github.com/ros-realtime/rt-kernel-docker-builder
$ cd rt-kernel-docker-builder
```

```bash
$ docker build [--build-arg UNAME_R=<raspi release>] [--build-arg RT_PATCH=<RT patch>] -t rtwg-image .
```

where:

* ```<raspi release>``` is in a form of ```5.4.0-1034-raspi```,  see [Ubuntu raspi Linux kernels](https://packages.ubuntu.com/search?suite=default&section=all&arch=any&keywords=linux-image-5.4&searchon=names)
* ```<RT patch>``` is in a form of ```5.4.106-rt54```, see [RT patches](http://cdn.kernel.org/pub/linux/kernel/projects/rt/5.4/older)

```bash
$ docker run -t -i rtwg-image bash
```

### Kernel configuration

There is a separate kernel configuration fragment```.config-fragment``` introduced to apply ROS2 real-time specific kernel settings:

```bash
$ cat .config-fragment
CONFIG_PREEMPT_RT=y
CONFIG_NO_HZ_FULL=y
CONFIG_HZ_1000=y
# CONFIG_AUFS_FS is not set
```

which corresponds to the following kernel configuration

```bash
# Enable CONFIG_PREEMPT_RT
 -> General Setup
  -> Preemption Model (Fully Preemptible Kernel (Real-Time))
   (X) Fully Preemptible Kernel (Real-Time)

# Enable CONFIG_HIGH_RES_TIMERS
 -> General setup
  -> Timers subsystem
   [*] High Resolution Timer Support

# Enable CONFIG_NO_HZ_FULL
 -> General setup
  -> Timers subsystem
   -> Timer tick handling (Full dynticks system (tickless))
    (X) Full dynticks system (tickless)

# Set CONFIG_HZ_1000
 -> Kernel Features
  -> Timer frequency (1000 HZ)
   (X) 1000 HZ

# Disable CONFIG_CPU_FREQ
 -> CPU Power Management
  -> CPU Frequency scaling (CPU_FREQ [=n])

# Disable CONFIG_AUFS_FS, otherwise RT kernel build might break
 x     -> File systems                                                                                                                          x
  x (1)   -> Miscellaneous filesystems (MISC_FILESYSTEMS [=y])
```

If you need to reconfigure it, run

```bash
$ cd $HOME/linux_build/linux-raspi
$ make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
```

### Kernel build

```bash
$ cd $HOME/linux_build/linux-raspi
$ make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j `nproc` deb-pkg
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

### Download and install Ubuntu 20.04 image

Follow these links to download and install Ubuntu 20.04 on your Raspberry Pi4

* https://ubuntu.com/download/raspberry-pi
* https://ubuntu.com/download/raspberry-pi/thank-you?version=20.04&architecture=arm64+raspi
* https://ubuntu.com/tutorials/create-an-ubuntu-image-for-a-raspberry-pi-on-ubuntu#2-on-your-ubuntu-machine

```bash
# initial username and password
ubuntu/ubuntu
```

### Update your system

After that you need to connect to the Internet and update your system

```bash
$ sudo apt-get update && apt-get upgrade
```

### Download RT Kernel ```deb``` packages

Go to ```Action``` tab of the project, find the latest ```RPI4 RT Kernel build```, go inside the latest workflow run, and download and unzip artifacts called ```RPI4 RT Kernel deb packages```. This archive contains four debian packages.

### Copy a new kernel to your system and install it

Assumed you have already copied all ```*.deb``` kernel packages to your ```$HOME``` directory

```bash
$ cd $HOME
$ sudo dpkg -i *.deb
```

## Adjust ```vmlinuz``` and ```initrd.img``` links

There is an extra step in compare to the x86_64 install because ```update-initramfs``` ignores new kernel

```bash
$ sudo ln -s -f /boot/vmlinuz-5.4.101-rt53 /boot/vmlinuz
$ sudo ln -s -f /boot/vmlinuz-5.4.0-1034-raspi /boot/vmlinuz.old
$ sudo ln -s -f /boot/initrd.img-5.4.101-rt53 /boot/initrd.img
$ sudo ln -s -f /boot/initrd.img-5.4.0-1034-raspi /boot/initrd.img.old
$ cd /boot
$ sudo cp vmlinuz firmware/vmlinuz
$ sudo cp vmlinuz firmware/vmlinuz.bak
$ sudo cp initrd.img firmware/initrd.img
$ sudo cp initrd.img firmware/initrd.img.bak

$ sudo reboot
```

After reboot you should see a new RT kernel installed

```bash
ubuntu@ubuntu:~$ uname -a
Linux ubuntu 5.4.101-rt53 #1 SMP PREEMPT_RT Mon May 17 12:10:16 UTC 2021 aarch64 aarch64 aarch64 GNU/Linux
```

## Intel UP2 board RT kernel build

To build ```x86_64``` Linux kernel, see [Building Realtime rt_preempt kernel for ROS 2](https://index.ros.org/doc/ros2/Tutorials/Building-Realtime-rt_preempt-kernel-for-ROS-2)

## Why is LTTNG included in the kernel?

[LTTNG](https://lttng.org/docs) stands for _Linux Trace Toolkit: next generation_ and is an open source toolkit that enables low-level kernel tracing which can be extremely useful when calculating callback times, memory usage and many other key characteristics.

As this repository is within the `ros-realtime` organization it can be assumed that most users will install ROS2 on the end system - which then they can use the `ros2_tracing` package to trace various things. Since [the `ros2_tracing` package](https://gitlab.com/ros-tracing/ros2_tracing) uses `LTTNG` as its tracer, and since [the `lttng-modules` package is not easily available](https://github.com/ros-realtime/rt-kernel-docker-builder/issues/16) for the raspberry-pi RT linux kernel we build it into the kernel here as a work around.

## References

* https://packages.ubuntu.com/search?suite=default&section=all&arch=any&keywords=linux-image-5.4&searchon=names
* http://cdn.kernel.org/pub/linux/kernel/projects/rt/5.4/older
* https://ubuntu.com/download/raspberry-pi/thank-you?version=20.04&architecture=arm64+raspi
* https://index.ros.org/doc/ros2/Tutorials/Building-Realtime-rt_preempt-kernel-for-ROS-2/

