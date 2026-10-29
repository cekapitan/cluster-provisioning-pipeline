# Secrets (local runs)

For `DRY_RUN=false`, the workflow expects an SSH private key at:

```text
/secrets/ssh-private-key
```

Today the WorkflowTemplate mounts an `emptyDir` there so dry-runs work.
For a real local provision, replace that volume with a Kubernetes Secret (or later Vault Agent / CSI):

```yaml
volumes:
  - name: secrets
    secret:
      secretName: kubespray-ssh
      defaultMode: 0600
# Secret key must be named: ssh-private-key
```

Do not commit private keys to this repository.
