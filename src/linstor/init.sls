{% from "linstor/map.j2" import os_import %}
include:
  - {{ os_import }}
  - .storage
  - .controller