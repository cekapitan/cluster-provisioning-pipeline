# Local cluster provisioning pipeline (Kubespray + Longhorn)

ARGO_WORKFLOWS_VERSION := v4.1.5
ARGO_NAMESPACE := argo

CLUSTER_NAME ?= local-demo
NODE_IPS ?= 192.168.1.11,192.168.1.12,192.168.1.13
SSH_USER ?= ubuntu
KUBESPRAY_VERSION ?= v2.26.0
LONGHORN_VERSION ?= 1.7.2
DRY_RUN ?= true

.PHONY: deploy-argo-workflow uninstall-argo-workflow run-argo-workflow \
	setup-argo-api-auth uninstall-argo-api-auth \
	deploy-provisioning-scripts \
	deploy-provisioning-pipeline update-provisioning-pipeline \
	submit-provisioning-pipeline test script-dry-run

####### Argo Workflows (Kind / local management cluster)
deploy-argo-workflow:
	kubectl create ns $(ARGO_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply --server-side -n $(ARGO_NAMESPACE) \
		-f https://github.com/argoproj/argo-workflows/releases/download/$(ARGO_WORKFLOWS_VERSION)/quick-start-postgres.yaml

uninstall-argo-workflow:
	kubectl delete ns $(ARGO_NAMESPACE) --ignore-not-found

run-argo-workflow:
	kubectl -n $(ARGO_NAMESPACE) port-forward deployment/argo-server 2746:2746

####### API submitter auth (SA + RBAC + token Secret)
setup-argo-api-auth:
	kubectl apply -f auth/argo-api-submitter.yaml

uninstall-argo-api-auth:
	kubectl delete -f auth/argo-api-submitter.yaml --ignore-not-found

####### Scripts ConfigMap + WorkflowTemplate
deploy-provisioning-scripts:
	kubectl -n $(ARGO_NAMESPACE) create configmap provisioning-scripts \
		--from-file=scripts/ \
		--dry-run=client -o yaml | kubectl apply -f -

deploy-provisioning-pipeline: deploy-provisioning-scripts
	kubectl apply -n $(ARGO_NAMESPACE) -f workflow-templates/provisioning-pipeline/provisioning-pipeline.yaml

update-provisioning-pipeline: deploy-provisioning-pipeline

submit-provisioning-pipeline:
	CLUSTER_NAME="$(CLUSTER_NAME)" \
	NODE_IPS="$(NODE_IPS)" \
	SSH_USER="$(SSH_USER)" \
	KUBESPRAY_VERSION="$(KUBESPRAY_VERSION)" \
	LONGHORN_VERSION="$(LONGHORN_VERSION)" \
	DRY_RUN="$(DRY_RUN)" \
	./send-api-request.sh

# Run the local scripts offline (no Argo / no SSH nodes)
script-dry-run:
	bash tests/test_local_scripts.sh

####### Tests
test:
	bash tests/run.sh
