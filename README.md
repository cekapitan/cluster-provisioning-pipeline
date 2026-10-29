# cluster-provisioning-pipeline

Provision **local / on-prem** Kubernetes clusters with **Kubespray**, then install **Longhorn** for storage.

Cloud provisioning is out of scope for this pipeline.

## Flow

1. Validate local cluster request  
2. Build Kubespray inventory from node IPs  
3. Run Kubespray (`cluster.yml`) — skipped when `dry_run=true`  
4. Install Longhorn via Helm — skipped when `dry_run=true`  
5. Wait until nodes + `StorageClass/longhorn` are ready  

Default submits use `dry_run=true` so Kind/CI can exercise the workflow without SSH targets.

## Environment setup (management cluster)

```bash
# Kind / Docker Desktop cluster that hosts Argo
make deploy-argo-workflow
make setup-argo-api-auth
make run-argo-workflow   # port-forward :2746
make deploy-provisioning-pipeline
```

Docs:
- [Argo access token](https://argo-workflows.readthedocs.io/en/latest/access-token/)
- [Kubespray](https://kubespray.io/)
- [Longhorn](https://longhorn.io/)

## Submit a local provision (dry-run)

```bash
make submit-provisioning-pipeline \
  CLUSTER_NAME=lab-1 \
  NODE_IPS=192.168.1.11,192.168.1.12,192.168.1.13 \
  DRY_RUN=true
```

## Real local run

1. Put an SSH private key where the workflow can read it (today: replace the emptyDir `secrets` volume with a Secret mount at `/secrets/ssh-private-key`; Vault Agent later).
2. Submit with `DRY_RUN=false` and real node IPs:

```bash
make submit-provisioning-pipeline \
  CLUSTER_NAME=lab-1 \
  NODE_IPS=10.0.0.10,10.0.0.11,10.0.0.12 \
  SSH_USER=ubuntu \
  DRY_RUN=false
```

## Offline tests

```bash
make test           # unit + script dry-run
make script-dry-run # scripts only
```

CI also runs offline tests and a Kind Argo dry-run smoke job.
