#!/bin/bash

##### Collecting input params
opsc_ip=$1
cluster_name=$2
data_center_name=$3

echo In lcm_node.sh
echo opsc_ip = $opsc_ip
echo cluster_name = $cluster_name
echo data_center_name = $data_center_name

##### Turn off the firewall
service firewalld stop
chkconfig firewalld off

##### Mount disks
# Install LVM software:
yum -y update
yum -y install lvm2 dmsetup mdadm reiserfsprogs xfsprogs

# Create disk partitions for LVM:
pvcreate /dev/nvme0n1 /dev/nvme1n1 

# Create volume group upon disk partitions:
vgcreate vg-nvme /dev/nvme0n1 /dev/nvme1n1 
lvcreate --name lv --size 5.8T vg-nvme
mkfs.ext4 /dev/vg-nvme/lv
mkdir /mnt/data1
mount /dev/vg-nvme/lv /mnt/data1
mkdir -p /mnt/data1/data
mkdir -p /mnt/data1/saved_caches
mkdir -p /mnt/data1/commitlog
chmod -R 777 /mnt/data1

##### Install DSE the LCM way 
yum -y install unzip wget
#wget http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm
wget http://mirror.centos.org/centos/7/extras/x86_64/Packages/epel-release-7-9.noarch.rpm
rpm -ivh epel-release-7-9.noarch.rpm
yum -y install python-pip
pip install requests

public_ip=`curl --retry 10 icanhazip.com`
private_ip=`echo $(hostname -I)`
node_id=$private_ip
rack="rack1"

cd ~opc
release="6.0.4"
wget https://github.com/DSPN/install-datastax-ubuntu/archive/$release.zip
unzip $release.zip
cd install-datastax-ubuntu-$release/bin/lcm/

./addNode.py \
--opsc-ip $opsc_ip \
--clustername $cluster_name \
--dcname $data_center_name \
--rack $rack \
--pubip $public_ip \
--privip $private_ip \
--nodeid $node_id
#
# configure limits
#
cd /etc/security
cat limits.conf \
| grep -v 'root.*memlock.*' \
| grep -v 'root.*nofile.*' \
| grep -v 'root.*nproc.*' \
| grep -v 'root.*as.*' \
| grep -v 'cassandra.*memlock.*' \
| grep -v 'cassandra.*nofile.*' \
| grep -v 'cassandra.*nproc.*' \
| grep -v 'cassandra.*as.*' \
> limits.conf.new
cat <</EOF >> limits.conf.new
root             -      memlock          unlimited
root             -      nofile           100000
root             -      nproc            32768
root             -      as               unlimited
cassandra        -      memlock          unlimited
cassandra        -      nofile           100000
cassandra        -      nproc            32768
cassandra        -      as               unlimited
/EOF
(set -x; chown cassandra:cassandra limits.conf.new)
(set -x; diff limits.conf limits.conf.new)
(set -x; mv -f limits.conf.new limits.conf)
# TCP settings
cd /etc/sysctl.conf
cat <</EOF >> cassandra.conf
net.ipv4.tcp_keepalive_time=60
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_intvl=10
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.core.optmem_max=40960
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
vm.max_map_count = 1048575
/EOF
sysctl -p /etc/sysctl.d/cassandra.conf

# Disable CPU frequency scaling
for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
do
    [ -f $CPUFREQ ] || continue
    echo -n performance > $CPUFREQ
done

echo 0 > /proc/sys/vm/zone_reclaim_mode

echo never | tee /sys/kernel/mm/transparent_hugepage/defrag

