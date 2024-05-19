{# Setup storage devices before creating storage pool later -#}
{% set setup = salt.pillar.get("linstor:storage:setup", none) %}

{% if setup %}
Setup storage pool:
  cmd.run:
    - name: |
        devices=$({{ setup.devices }})
        {{ setup.command }}

    - onlyif: |
        devices=$({{ setup.devices }})
        {{ setup.onlyif }}
{% endif %}