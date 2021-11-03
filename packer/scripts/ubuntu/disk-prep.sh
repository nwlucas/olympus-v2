#!/bin/sh -eux

mkfs -q -F -t ext4 -L ct-storage /dev/sdb
mkdir -p /var/lib/containers
mount -t ext4 /dev/sdb /var/lib/containers
