{% set caller = salt.pillar.get('caller') %}
{% set cluster_glob = salt.saltutil.cmd(tgt=caller, fun="pillar.get", kwarg={"key": "linstor:cluster_glob"})[caller]['ret'] %}
{% set pillars = salt.saltutil.cmd(tgt=cluster_glob, fun="pillar.get", kwarg={"key": "linstor"}) %}

Shutdown cluster:
  salt.function:
    - tgt: {{ cluster_glob | yaml_dquote}}
    - name: cmd.run
    - arg:
        - systemctl disable --now linstor-controller && systemctl stop drbd-reactor

Bootstrap cluster:
  salt.state:
    - tgt: {{ caller | yaml_dquote }}
    - sls:
      - linstor.controller.provision.make-cluster
    - require:
      - Shutdown cluster


{% for node in pillars %}
{% if node != caller %}
Share /var/cache/linstor_db.path with {{ node }}:
  salt.runner:
    - name: datashare.use
    - src:
        id: {{ caller | yaml_dquote}}
        cmd: file.read
        kwargs:
          path: /var/cache/linstor_db.path
    - target:
        id: {{ node | yaml_dquote }}
        cmd: file.write
        args:
          - /var/cache/linstor_db.path
          - __DATA__
    - require:
      - Bootstrap cluster

Bootstrap cluster node {{ node }}:
  salt.state:
    - tgt: {{ node | yaml_dquote }}
    - sls:
      - linstor.controller.provision.migrate-ha
    - require:
      - Bootstrap cluster
      - Share /var/cache/linstor_db.path with {{ node }}
      {% if last is defined %}
      - Bootstrap cluster node {{ last }}
      {% endif %}

{% set last = node %}
{% endif %}
{% endfor %}
