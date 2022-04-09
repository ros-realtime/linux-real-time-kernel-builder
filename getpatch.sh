#!/bin/bash

# first argument is a kernel version, script takes sublevel and calculates the nearest patch to the provided SUBLEVEL
# Kernel version 5.4.174, SUBLEVEL number is 174
major_minor=5.4
sublevel=174
if [ $# -ne 0 ]; then
       major_minor=`echo $1 | cut -d '.' -f 1-2`
       sublevel=`echo $1 | cut -d '.' -f 3`
fi

# Retrieve a list of ```patch.gz``` patches, and sort them
# assumed patched are in form of patch-5.4.177-rt69.patch.gz
patch_list=`curl -s http://cdn.kernel.org/pub/linux/kernel/projects/rt/$major_minor/older/ | grep patch.gz | cut -d '"' -f 2 | sort -V`

# go through the list and take the nearest patch to the provided SUBLEVEL number which is equal or greater
sl=$sublevel
for patch_item in $patch_list
do
       sl=`echo $patch_item | cut -d '-' -f 2 | cut -d '.' -f 3`
       if [ $sl -ge $sublevel ]; then
               break
       fi
done

# check whether there are several RT patches exist with the same SUBLEVEL number, and take the latest
echo "$patch_list" | tr ' ' '\n' | grep patch-$major_minor.$sl | tail -n 1 | cut -d '-' -f 2-3 | cut -d '.' -f 1-3
