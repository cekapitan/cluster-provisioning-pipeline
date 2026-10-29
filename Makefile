# Main makefile for provisioning pipeline tasks

ARGO_WORKFLOWS_VERSION := v4.1.5
ARGO_NAMESPACE := argo
MESSAGE ?= Hello, Argo!

.PHONY: deploy-argo-workflow uninstall-argo-workflow run-argo-workflow \
	setup-argo-api-auth uninstall-argo-api-auth \
	deploy-provisioning-pipeline update-provisioning-pipeline \
	submit-provisioning-pipeline test

####### Argo Workflows (Kind / local)
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

####### Provisioning pipeline WorkflowTemplate
deploy-provisioning-pipeline:
	argo template create workflow-templates/provisioning-pipeline/provisioning-pipeline.yaml -n $(ARGO_NAMESPACE)

update-provisioning-pipeline:
	argo template update workflow-templates/provisioning-pipeline/provisioning-pipeline.yaml -n $(ARGO_NAMESPACE)

submit-provisioning-pipeline:
	./send-api-request.sh "$(MESSAGE)"

####### Tests (offline unit/static; CI also runs a Kind smoke job)
test:
	bash tests/run.sh
