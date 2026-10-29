# cluster-provisioning-pipeline
Deploy clusters in an automated fashion

## Environment setup
- Setup Docker Desktop Kind K8s cluster
- Install Argo Workflows quick-start (pinned in the Makefile):

```bash
make deploy-argo-workflow
make run-argo-workflow   # port-forward argo-server :2746
```

Docs:
- [Access token](https://argo-workflows.readthedocs.io/en/latest/access-token/)
- [API Swagger](https://argo-workflows.readthedocs.io/en/latest/swagger/)

## API submitter auth

Creates the `jenkins` ServiceAccount, a Role with submit/watch permissions,
RoleBinding, and a bound token Secret (`auth/argo-api-submitter.yaml`).

```bash
make setup-argo-api-auth

# Optional: list workflows (sanity check)
ARGO_TOKEN="Bearer $(kubectl get secret jenkins.service-account-token -n argo -o=jsonpath='{.data.token}' | base64 --decode)"
curl --insecure "https://localhost:2746/api/v1/workflows/argo" -H "Authorization: $ARGO_TOKEN" | jq .
```

## Deploy and submit the provisioning pipeline

```bash
make deploy-provisioning-pipeline
# with argo-server port-forward running:
make submit-provisioning-pipeline MESSAGE='cluster request demo'
# or:
./send-api-request.sh 'cluster request demo'
```
