install linbit drbd repo:
  pkgrepo.managed:
    - ppa: linbit/linbit-drbd9-stack

Install linstore packages:
  pkg.installed:
    - names:
        - drbd-dkms
        - drbd-utils
        - drbd-reactor # ha
        - lvm2
        - linstor-satellite
        - linstor-client
    - require:
      - pkgrepo: install linbit drbd repo

Install snapshot shipping dependencies:
  pkg.installed:
    - names:
      - thin-send-recv
      - zstd
    - require:
      - Install linstore packages