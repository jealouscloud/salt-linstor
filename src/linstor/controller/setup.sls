Write helper linstor alias scripts:
    file.managed:
        - name: /etc/profile.d/linstor.sh
        - source: salt://linstor/files/linstor_aliases.sh

Install linstor-controller:
  pkg.installed:
     - name: linstor-controller

Disable linstor-controller so that drbd-reactor can handle it:
  service.disabled:
    - name: linstor-controller
    - require:
      - pkg: linstor-controller
