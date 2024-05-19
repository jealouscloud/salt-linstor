# linstor salt state - WIP
configure linstor drbd storage cluster with drbd-reactor

https://github.com/jealouscloud/salt-linstor

## Salt dependencies
- The orchestrator makes use of https://github.com/jealouscloud/salt-runner-datashare and therefore must be added to the salt master.

## Cluster setup
Instructions expect linstor nodes setup as 'linsto1', 'linsto2', etc.

```sh
# wipe previous failure
salt '*linsto*' cmd.run 'vgremove -y linstor_vg; pvremove /dev/vdb'
# continue to or start here if  fresh
salt '*linsto*' state.apply linstor;
salt-run state.orchestrate _orch.provision.linstor.cluster pillar="{\"caller\":\"$(salt 'linsto1' --preview | awk '{print $2}')\"}"
```

## multipass
```
snap install multipass
apt install libvirt-daemon-system
snap connect multipass:libvirt
multipass set local.driver=libvirt
```

https://github.com/canonical/multipass/issues/135#issuecomment-391141480
```
pool=mypool
virsh vol-create-as --pool=$pool --name=l1 --capacity=50GB --format=raw
virsh vol-create-as --pool=$pool --name=l2 --capacity=50GB --format=raw
virsh vol-create-as --pool=$pool --name=l3 --capacity=50GB --format=raw

virsh attach-device --live linsto1 /dev/stdin < l1
virsh attach-device --live linsto2 /dev/stdin < l2
virsh attach-device --live linsto3 /dev/stdin < l3

root@multipass-linstor:~/disks# cat l1 
<disk type='volume' device='disk'>
  <driver name='qemu' type='raw'/> 
  <source pool='mypool' volume='l1'/>
  <serial>myserial</serial>
  <target dev='vde'/>
</disk>

```

multipass-script() {
    tgt="$1"
    script="$2"
    multipass transfer "$script" "$tgt":/home/ubuntu/
    multipass exec "$tgt" -- sudo bash $(basename "$script")
}


multipass-salt() {
    tgt="$1"
    multipass transfer bootstrap-salt.sh "$tgt":/home/ubuntu/
    multipass exec "$tgt" -- sudo bash ./bootstrap-salt.sh -A $(hostname -I | awk '{print $1}')
}

minion-enroll:
  curl -o bootstrap-salt.sh -L https://bootstrap.saltproject.io; sudo bash ./bootstrap-salt.sh -A $(hostname -I | awk '{print $1}')

multipass launch --name linsto1 --cpus 6 --disk 55G --memory 12G
multipass launch --name linsto2 --cpus 6 --disk 55G --memory 12G
multipass launch --name linsto3 --cpus 6 --disk 55G --memory 12G


eval multipass exec grounded-cowbird $(cat minion-enroll)


multipass start --all
multipass-script linsto1 make-drives.sh; multipass-script linsto2 make-drives.sh; multipass-script linsto3 make-drives.sh; salt 'linsto*' cmd.run 'vgchange -ay' 
salt 'linsto*' state.apply hostsfile
salt 'linsto*' state.apply linstor
salt-run state.orchestrate _orch.provision.linstor.cluster pillar="{\"caller\":\"$(salt 'linsto1' --preview | awk '{print $2}')\"}"


## Snapshots

linstor resource toggle-disk linsto1 linstor_db --storage-pool ha_pool --migrate-from linsto2
