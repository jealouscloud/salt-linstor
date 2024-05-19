Check that nothing is in /var/lib/linstor:
  cmd.run:
    - name: find  /var/lib/linstor/ -type f | grep -q . && exit 1 || exit 0

Migrate to HA managed volume by making linstor dir immutable:
  cmd.run:
    - unless: lsattr -d /var/lib/linstor | grep -- '-i-
    - shell: /bin/bash
    - name: |
         set -ex
         chattr +i /var/lib/linstor # only if on LINSTOR >= 1.14.0
    - require:
      - Check that nothing is in /var/lib/linstor

Reload systemd:
  cmd.run:
    - name: systemctl daemon-reload

Add linstor mount service:
  file.managed:
    - name: /etc/systemd/system/var-lib-linstor.mount
    - contents: |
        [Unit]
        Description=Filesystem for the LINSTOR controller

        [Mount]
        # you can use the minor like /dev/drbdX or the udev symlink
        What={{ salt.file.read("/var/cache/linstor_db.path") }}
        Where=/var/lib/linstor
    - onchanges:
        - Reload systemd

Configure drbd-reactor:
  file.managed:
    - name: /etc/drbd-reactor.d/linstor_db.toml
    - contents: |
        [[promoter]]
        id = "linstor_db"
        [promoter.resources.linstor_db]
        start = ["var-lib-linstor.mount", "linstor-controller.service"]
    - require:
      - Add linstor mount service

Start / enable drbd-reactor:
  service.running:
    - name: drbd-reactor
    - enable: True
    - require: 
        - Migrate to HA managed volume by making linstor dir immutable
        - Configure drbd-reactor

Restart linstor-satellite:
  module.run:
    - service.restart:
      - name: linstor-satellite
    - require: 
      - Start / enable drbd-reactor

Modify linstor-satellite LS_KEEP_RES:
  file.managed:
    - name: /etc/systemd/system/linstor-satellite.service.d/override.conf
    - makedirs: true
    - contents: |
        [Service]
        Environment=LS_KEEP_RES=linstor_db
    - onchanges:
      - Reload systemd
      - Restart linstor-satellite

