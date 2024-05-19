#!/usr/bin/env python3
# WIP
import click
import linstor
import json


@click.group()
def cli():
    pass


@cli.command()
def create():
    click.echo("Created")


@cli.command()
def list():
    with linstor.Linstor("linstor://localhost") as lin:  # may raise exception
        node_list_reply = lin.node_list()  # API calls will always return a list

        assert node_list_reply, "Empty return list"

        node_list = node_list_reply[0]  # NodeListResponse
        for d in node_list.data_v1:
            name = d["name"]
            status = d["connection_status"]
            type = d["type"]
            print(f"{name} {type} {status}")
            # print(d)


@cli.command()
@click.argument("pool")
def list_volumes(pool=None):
    vols = []
    with linstor.Linstor("linstor://localhost") as lin:  # may raise exception
        filter_py_stor_pools = []
        if pool:
            filter_py_stor_pools.append(pool)
        for r in lin.volume_list(filter_by_stor_pools=filter_py_stor_pools):
            for node_volume_entry in r.data_v1:
                name = node_volume_entry["name"]
                node_name = node_volume_entry["node_name"]
                in_use = node_volume_entry.get("state", {}).get("in_use", False)
                e = {"name": name, "node_name": node_name, "in_use": in_use, "vols": []}
                for vol in node_volume_entry["volumes"]:
                    vol_nr = vol["volume_number"]
                    vol_provider_kind = vol["provider_kind"]
                    device_path = vol["device_path"]
                    vol_state = vol.get("state", "Unknown!!")
                    allocated = vol["allocated_size_kib"] / 1024 / 1024
                    v = dict(
                        vol_nr=vol_nr,
                        vol_provider_kind=vol_provider_kind,
                        device_path=device_path,
                        allocated=f"{allocated:.2f} GB",
                        state=vol_state,
                    )
                    e["vols"].append(v)
                vols.append(e)
    print(json.dumps(vols, indent=4))

@cli.command()
@click.argument("pool")

@cli.command()
def test():
    with linstor.Linstor("linstor://localhost") as lin:  # may raise exception
        for r in lin.volume_list(filter_by_stor_pools=["my_pool"]):
            # for node_volume_entry in r.data_v1:
                # name = node_volume_entry["name"]
                # node_name = node_volume_entry["node_name"]
                print(json.dumps(r.data_v1, indent=4))


@cli.command()
@click.argument("node")
@click.argument("pool")
def remove_disk(node, pool):
    pass


if __name__ == "__main__":
    cli()
