#!/bin/bash
sudo virt-install \
  --name lab-router \
  --memory 1024 --vcpus 1 \
  --disk size=8,format=qcow2 \
  --cdrom /var/lib/libvirt/images/debian-13.7.0-amd64-netinst.iso \
  --os-variant debian13 \
  --network network=default,model=virtio \
  --network network=lab-users,model=virtio \
  --network network=lab-servers,model=virtio \
  --network network=lab-mgmt,model=virtio \
  --graphics spice
