#!/usr/bin/env bash

cd ~opc

release="6.0.4"
#curl https://raw.githubusercontent.com/DSPN/oracle-bmc-terraform-dse/$release/userdata/lcm_node.sh > lcm_node.sh
curk https://raw.githubusercontent.com/AVM-Consulting/oracle-bmc-terraform-dse/master/userdata/lcm_node.sh > lcm_node.sh

chmod +x lcm_node.sh

