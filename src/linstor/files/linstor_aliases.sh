alias linstor-nodes="linstor node list | awk 'NR > 2 {print \$2}' | grep -P --color=no '\w'"
function linstor-volumes() {
    linstor -m --output-version v1 volume list | jq -c -r '.[][] | select(.state.in_use == true) | {name: .name, node: .node_name, device_path: (.volumes[].device_path)}'
}