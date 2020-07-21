# Introduction
The goal is to create a Ubuntu based system with RT Linux kernel to test real-time ROS2 stack. Two boards are proposed
* Raspberry Pi 4 B+ board (ARMv8)
* Intel UP2 board (x86_64)

# Raspberry Pi 4 prebuilt kernel packages
Prebuilt kernel packages are located:  
```bash
gitpod ~/linux_build $ ls -la *deb
-rw-r--r-- 1 gitpod gitpod   411424 Jul 21 12:14 linux-buildinfo-5.4.0-1013-raspi_5.4.0-1013.13_arm64.deb
-rw-r--r-- 1 gitpod gitpod   942780 Jul 21 12:14 linux-headers-5.4.0-1013-raspi_5.4.0-1013.13_arm64.deb
-rw-r--r-- 1 gitpod gitpod  8502384 Jul 21 12:13 linux-image-5.4.0-1013-raspi_5.4.0-1013.13_arm64.deb
-rw-r--r-- 1 gitpod gitpod 30023912 Jul 21 12:14 linux-modules-5.4.0-1013-raspi_5.4.0-1013.13_arm64.deb
-rw-r--r-- 1 gitpod gitpod 11174992 Jul 21 12:14 linux-raspi-headers-5.4.0-1013_5.4.0-1013.13_arm64.deb
```
you need to copy them e.g. to the USB drive or copy directly to the micro SD card with a Raspberry Pi4 image. you can skip the next step and go to [Deploy chapter](#Deploy-a-new-kernel-on-RPI4)
# Raspberry Pi 4 kernel build
Ubuntu 20.04 x86_64 docker container is used to cross-compile a kernel. There is a Dockerfile which can be used for that purpose. If you want to build it using gitpod you need to run https://gitpod.io/#https://github.com/razr/RTWG. It will spawn a docker container automatically for you.
## create and run a docker container
For the local build:
```bash
$ git clone https://github.com/razr/RTWG.git
$ cd RTWG
$ docker build -t rtwg-image .
$ docker run -t -i rtwg-image bash
```
## setup a build environment 
Docker container is prepared to cross-compile RPI4 1013 RT kernel 
```bash
$ cd $HOME/linux_build/linux-raspi-5.4.0
$ export $(dpkg-architecture -aarm64)
$ export CROSS_COMPILE=aarch64-linux-gnu-
gitpod ~/linux_build/linux-raspi-5.4.0 $ fakeroot debian/rules printenv
dh_testdir
src package name  = linux-raspi
series            = focal
release           = 5.4.0
revisions         = 1006.6 1007.7 1008.8 1009.9 1010.10 1011.11 1012.12 1013.13
revision          = 1013.13
uploadnum         = 13
prev_revisions    = 0.0 1006.6 1007.7 1008.8 1009.9 1010.10 1011.11 1012.12
prev_revision     = 1012.12
abinum            = 1013
upstream_tag      = v5.4
gitver            =
variants          = --
flavours          =
skipabi           =
skipmodule        =
skipdbg           = true
ubuntu_log_opts   =
CONCURRENCY_LEVEL = 24
ubuntu_selftests  = breakpoints bpf cpu-hotplug efivarfs memfd memory-hotplug mount net ptrace seccomp timers powerpc user ftrace
bin package name  = linux-image-5.4.0-1013
hdr package name  = linux-headers-5.4.0-1013
doc package name  = linux-raspi-doc
do_doc_package            = true
do_doc_package_content    = false
do_source_package         = true
do_source_package_content = false
do_libc_dev_package       = true
do_flavour_image_package  = true
do_flavour_header_package = true
do_common_headers_indep   = true
do_full_source            = false
do_tools                  = true
do_any_tools              =
do_linux_tools            =
 do_tools_cpupower         =
 do_tools_perf             =
 do_tools_bpftool          =
 do_tools_x86              =
 do_tools_host             = false
do_cloud_tools            =
 do_tools_hyperv           =
any_signed                =
 uefi_signed               =
 opal_signed               =
 sipl_signed               =
full_build                = false
libc_dev_version          =
DEB_HOST_GNU_TYPE         = x86_64-linux-gnu
DEB_BUILD_GNU_TYPE        = x86_64-linux-gnu
DEB_HOST_ARCH             = amd64
DEB_BUILD_ARCH            = amd64
arch                      = amd64
kmake                     = make ARCH= CROSS_COMPILE= KERNELVERSION=5.4.0-1013- CONFIG_DEBUG_SECTION_MISMATCH=y KBUILD_BUILD_VERSION=13 LOCALVERSION= localver-extra= CFLAGS_MODULE=-DPKG_ABI=1013
```
## kernel build 
```bash
gitpod ~/linux_build/linux-raspi-5.4.0 $ fakeroot debian/rules clean
gitpod ~/linux_build/linux-raspi-5.4.0 $ fakeroot debian/rules binary
```
It takes a while to build and the results are located:
```bash
gitpod ~/linux_build/linux-raspi-5.4.0 $ ls -la ../*.deb
-rw-r--r-- 1 gitpod gitpod   411424 Jul 21 12:14 ../linux-buildinfo-5.4.0-1013-raspi_5.4.0-1013.13_arm64.deb
-rw-r--r-- 1 gitpod gitpod   942780 Jul 21 12:14 ../linux-headers-5.4.0-1013-raspi_5.4.0-1013.13_arm64.deb
-rw-r--r-- 1 gitpod gitpod  8502384 Jul 21 12:13 ../linux-image-5.4.0-1013-raspi_5.4.0-1013.13_arm64.deb
-rw-r--r-- 1 gitpod gitpod 30023912 Jul 21 12:14 ../linux-modules-5.4.0-1013-raspi_5.4.0-1013.13_arm64.deb
-rw-r--r-- 1 gitpod gitpod 11174992 Jul 21 12:14 ../linux-raspi-headers-5.4.0-1013_5.4.0-1013.13_arm64.deb
```
# Deploy a new kernel on RPI4
## download and install Ubuntu 20.04 image 
Follow these links to download and install Ubuntu 20.04 on your RPI4
* https://ubuntu.com/download/raspberry-pi
* https://ubuntu.com/download/raspberry-pi/thank-you?version=20.04&architecture=arm64+raspi
* https://ubuntu.com/tutorials/create-an-ubuntu-image-for-a-raspberry-pi-on-ubuntu#2-on-your-ubuntu-machine
```bash
# initial username and password
ubuntu/ubuntu
```
## update your system
After that you need to connect to the Internet and update your system. After that kernel 1008 will be replaces with a kernel 1013
```bash
$ uname -a
Linux ubuntu 5.4.0-1008-raspi #08 SMP Sat Jun 15 11:15:22 CEST 2020 aarch64 aarch64 aarch64 GNU/Linux
$ sudo apt-get update && apt-get upgrade
$ uname -a
$ uname -a
Linux ubuntu 5.4.0-1013-raspi #13 SMP Sat Jul 16 21:00:11 CEST 2020 aarch64 aarch64 aarch64 GNU/Linux
```
## copy a new kernel to your system and install it
Assumed you have already copied all *.deb packages to your ```$HOME/ubuntu``` directory
```bash
$ cd $HOME/ubuntu
$ sudo dpkg -i *.deb
$ sudo reboot
```
After reboot you should see a new kernel version installed
```bash
$ uname -a
Linux ubuntu 5.4.0-1013-raspi #13 SMP Sat Jul 18 22:05:32 CEST 2020 aarch64 aarch64 aarch64 GNU/Linux
```
