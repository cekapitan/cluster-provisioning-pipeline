# Workflow templates

## provisioning-pipeline

Local/on-prem only. One workflow pod runs `scripts/provision-local.sh`:

| Stage | Purpose |
|------|---------|
| validate-request | Check cluster name + node IPs |
| prepare-inventory | Generate Kubespray `hosts.yaml` + group_vars |
| run-kubespray | Ansible `cluster.yml` (or plan when dry-run) |
| install-longhorn | Helm install Longhorn as default StorageClass |
| wait-cluster-ready | Nodes Ready + `StorageClass/longhorn` |

Profile defaults live in `config/profiles/local-longhorn.yaml`.
