#!/usr/bin/env python3
"""Static checks for auth and local provisioning workflow manifests."""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def fail(msg: str) -> None:
    failures.append(msg)


def load_all(path: Path) -> list[dict]:
    docs = list(yaml.safe_load_all(path.read_text()))
    return [d for d in docs if d]


def test_argo_api_submitter() -> None:
    path = ROOT / "auth" / "argo-api-submitter.yaml"
    if not path.exists():
        fail(f"missing {path.relative_to(ROOT)}")
        return

    docs = load_all(path)
    kinds = {(d.get("kind"), d.get("metadata", {}).get("name")) for d in docs}
    expected = {
        ("ServiceAccount", "jenkins"),
        ("Role", "jenkins"),
        ("RoleBinding", "jenkins"),
        ("Secret", "jenkins.service-account-token"),
    }
    missing = expected - kinds
    if missing:
        fail(f"auth manifest missing resources: {sorted(missing)}")

    role = next(d for d in docs if d.get("kind") == "Role")
    verbs_by_resource: dict[str, set[str]] = {}
    for rule in role.get("rules", []):
        for resource in rule.get("resources", []):
            verbs_by_resource.setdefault(resource, set()).update(rule.get("verbs", []))

    workflow_verbs = verbs_by_resource.get("workflows", set())
    for required in ("create", "get", "list", "watch"):
        if required not in workflow_verbs:
            fail(f"Role jenkins missing verb '{required}' on workflows (have {sorted(workflow_verbs)})")

    template_verbs = verbs_by_resource.get("workflowtemplates", set())
    for required in ("get", "list"):
        if required not in template_verbs:
            fail(
                "Role jenkins missing verb "
                f"'{required}' on workflowtemplates (have {sorted(template_verbs)})"
            )


def test_provisioning_pipeline_template() -> None:
    path = ROOT / "workflow-templates" / "provisioning-pipeline" / "provisioning-pipeline.yaml"
    if not path.exists():
        fail(f"missing {path.relative_to(ROOT)}")
        return

    docs = load_all(path)
    if len(docs) != 1:
        fail(f"expected 1 document in provisioning-pipeline.yaml, got {len(docs)}")
        return

    doc = docs[0]
    if doc.get("kind") != "WorkflowTemplate":
        fail(f"expected WorkflowTemplate, got {doc.get('kind')}")
    if doc.get("metadata", {}).get("name") != "provisioning-pipeline":
        fail("WorkflowTemplate metadata.name must be provisioning-pipeline")

    labels = doc.get("metadata", {}).get("labels", {})
    if labels.get("provisioning.pipeline/environment") != "local":
        fail("WorkflowTemplate must be labeled environment=local")

    spec = doc.get("spec", {})
    if spec.get("entrypoint") != "provision-pipeline":
        fail(f"entrypoint is {spec.get('entrypoint')!r}, expected 'provision-pipeline'")

    params = {p["name"]: p for p in spec.get("arguments", {}).get("parameters", [])}
    for name in (
        "cluster_name",
        "node_ips",
        "ssh_user",
        "kubespray_version",
        "longhorn_version",
        "dry_run",
    ):
        if name not in params:
            fail(f"missing workflow parameter {name!r}")
    if params.get("dry_run", {}).get("value") != "true":
        fail("dry_run default must be 'true' for safe local CI")

    templates = {t.get("name"): t for t in spec.get("templates", [])}
    if "provision-pipeline" not in templates:
        fail("missing template 'provision-pipeline'")

    entry = templates["provision-pipeline"]
    source = (entry.get("script") or {}).get("source") or ""
    if "provision-local.sh" not in source:
        fail("entrypoint must invoke provision-local.sh")
    if "environment" not in str(entry.get("metrics", {})) and "local" not in source:
        # metrics labels carry environment=local
        metrics = entry.get("metrics") or {}
        blob = str(metrics)
        if "local" not in blob:
            fail("expected local environment metrics labels on entrypoint")


def test_local_profile_and_schema() -> None:
    profile = ROOT / "config" / "profiles" / "local-longhorn.yaml"
    schema = ROOT / "config" / "schemas" / "local-cluster-request.schema.json"
    if not profile.exists():
        fail("missing config/profiles/local-longhorn.yaml")
    else:
        data = yaml.safe_load(profile.read_text())
        if data.get("environment") != "local":
            fail("local-longhorn profile environment must be local")
        if data.get("provisioner") != "kubespray":
            fail("local-longhorn profile provisioner must be kubespray")
        if data.get("storage", {}).get("backend") != "longhorn":
            fail("local-longhorn profile storage.backend must be longhorn")
    if not schema.exists():
        fail("missing config/schemas/local-cluster-request.schema.json")


def test_makefile_phony_and_targets() -> None:
    makefile = (ROOT / "Makefile").read_text()
    if "PHONY:" in makefile and ".PHONY:" not in makefile:
        fail("Makefile still uses PHONY: instead of .PHONY:")
    for target in (
        "setup-argo-api-auth",
        "deploy-provisioning-scripts",
        "submit-provisioning-pipeline",
        "script-dry-run",
        "test",
    ):
        if f"{target}:" not in makefile:
            fail(f"Makefile missing target {target}")


def main() -> int:
    test_argo_api_submitter()
    test_provisioning_pipeline_template()
    test_local_profile_and_schema()
    test_makefile_phony_and_targets()

    if failures:
        print("FAIL: manifest checks")
        for item in failures:
            print(f"  - {item}")
        return 1

    print("PASS: manifest checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
