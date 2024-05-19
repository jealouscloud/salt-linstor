{% set cluster_glob = salt.pillar.get("linstor:cluster_glob") %}
{% set siblings = salt["mine.get"](tgt=cluster_glob, fun='network.ip_addrs') %}
Require jq package:
  pkg.installed:
     - name: jq

Temp disable drop-in:
  cmd.run:
    - onlyif: test -f /run/systemd/system/linstor-controller.service.d/reactor.conf
    - name: mv /run/systemd/system/linstor-controller.service.d/reactor.conf /tmp/reactor.conf && systemctl daemon-reload

Start controller:
  service.running:
    - name: linstor-controller
    - require:
      - Temp disable drop-in

Create cluster:
  cmd.run:
    - names:
       {% for minion, ips in siblings | dictsort %}
          {#- In this cluster, all nodes are both satellites and controllers -#}
         - (linstor node list | grep -q '{{ minion }}') || linstor node create {{ minion }} {{ ips[0] }} --node-type combined
       {% endfor %}
    - require:
      - service: Start controller

{% for pool in salt.pillar.get("linstor:storage:pools") %}
{% for minion, ips in siblings | dictsort %}
Setup storage pool {{ pool.name }} on {{ minion }}:
  cmd.run:
    - shell: /bin/bash
    - name: |
         set -eo pipefail
         storage_cfg=$(linstor -m --output-version v1 storage-pool list  | jq -r '.[][] | "\(.node_name) \(.storage_pool_name)"')
         if echo "$storage_cfg" | grep '{{ pool.name }}' | grep '{{ minion }}'; then
            exit 0 # already setup
         fi
         linstor storage-pool create {{ pool.type }} {{ minion }} {{ pool.name }} {{ pool.path }}
    - unless: linstor storage-pool list | grep {{ pool.name }} | grep {{ minion }}
    - require:
      - Create cluster
      - Require jq package
{% endfor %}
{% endfor %}

Create HA db:
  cmd.run:
    - unless: linstor volume-definition list | grep linstor_db
    - shell: /bin/bash
    - name: |
        set -exo pipefail
        linstor resource-definition create linstor_db
        linstor rd drbd-options --auto-promote=no linstor_db
        linstor rd drbd-options --quorum=majority linstor_db
        linstor rd drbd-options --on-suspended-primary-outdated=force-secondary linstor_db
        linstor rd drbd-options --on-no-quorum=io-error linstor_db
        linstor rd drbd-options --on-no-data-accessible=io-error linstor_db
        linstor rd drbd-options --rr-conflict=retry-connect linstor_db
        linstor volume-definition create linstor_db 200M
        # Create the resource on our main storage pool
        # TODO: make placement 3 (2 for testing)
        linstor resource create linstor_db --storage-pool {{ salt.pillar.get("linstor:storage:pools")[0].name }} --auto-place 2
    - require:
      - Create cluster
      - Setup storage pool*

Lock linstor_db:
  cmd.run:
    - name: drbdadm primary linstor_db

Dump linstor_db path to /var/cache:
  cmd.run:
    - shell: /bin/bash
    - unless: grep /dev /var/cache/linstor_db.path
    - name: |
        
        function linstor-volumes() {
            linstor -m --output-version v1 volume list | jq -c -r '.[][] | select(.state.in_use == true) | {name: .name, node: .node_name, device_path: (.volumes[].device_path)}'
            # {"name":"linstor_db","node":"node_hostname1","device_path":"/dev/drbd1000"}
        }
        set -exo pipefail

        path=$(linstor-volumes | jq -r 'select(.name == "linstor_db") | .device_path' | grep .)
        echo "$path" > /var/cache/linstor_db.path
    - require:
      - Create HA db
      - Lock linstor_db

Migrate to HA db:
  cmd.run:
    - unless: find  /var/lib/linstor/ -type f | grep . || exit 0 && exit 1
    - shell: /bin/bash
    - name: |
        path=$(cat /var/cache/linstor_db.path)
        mkdir -p /tmp/ha-bootstrap
        mkfs.ext4 "$path"
        mount "$path" /tmp/ha-bootstrap
        systemctl stop linstor-controller
        mv /var/lib/linstor/* /tmp/ha-bootstrap/
        umount /tmp/ha-bootstrap/
        rmdir /tmp/ha-bootstrap
        
    - require:
       - Create HA db
       - Lock linstor_db
       - Dump linstor_db path to /var/cache


Restore reactor drop-in:
  cmd.run:
    - onlyif: test -f /tmp/reactor.conf
    - name: mv /tmp/reactor.conf /run/systemd/system/linstor-controller.service.d/reactor.conf && systemctl daemon-reload
    - require:
      - Migrate to HA db

Unlock linstor_db:
  cmd.run:
    - name: drbdadm secondary linstor_db
    - require:
      - Lock linstor_db
      - Migrate to HA db