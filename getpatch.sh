#!/bin/bash

# first argument is a kernel sublevel number
# Example: Kernel version 5.4.101, SUBLEVEL number is 101
sublevel=101
if [ $# -ne 0 ]; then
       sublevel=$1
fi

# Retrieve a list of ```patch.gz``` patches, and sort them
# assumed patched are in form of patch-5.4.5-rt3.patch.gz
patch_list=`curl -s http://cdn.kernel.org/pub/linux/kernel/projects/rt/5.4/older/ | grep patch.gz | cut -d '"' -f 2 | sort -V`

# go through the list and take the nearest patch to the provided SUBLEVEL number which is equal or greater
sl=$sublevel
for patch_item in $patch_list
do
       sl=`echo $patch_item | cut -d '-' -f 2 | cut -d '.' -f 3`
       if [ $sl -ge $sublevel ]; then
               break
       fi
done

# check whether there are several RT patches with the same SUBLEVEL number exist, and take the latest
echo "$patch_list" | tr ' ' '\n' | grep patch-5.4.$sl | tail -n 1 | cut -d '-' -f 2-3 | cut -d '.' -f 1-3

