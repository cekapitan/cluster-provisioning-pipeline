#!/usr/bin/env python3
"""Static checks for auth and workflow manifests."""

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

    secret = next(d for d in docs if d.get("kind") == "Secret")
    if secret.get("type") != "kubernetes.io/service-account-token":
        fail("token Secret must be type kubernetes.io/service-account-token")
    sa_name = secret.get("metadata", {}).get("annotations", {}).get(
        "kubernetes.io/service-account.name"
    )
    if sa_name != "jenkins":
        fail(f"token Secret annotation SA name is {sa_name!r}, expected 'jenkins'")


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

    spec = doc.get("spec", {})
    if spec.get("entrypoint") != "provision-pipeline":
        fail(f"entrypoint is {spec.get('entrypoint')!r}, expected 'provision-pipeline'")

    templates = {t.get("name"): t for t in spec.get("templates", [])}
    for name in ("provision-pipeline", "ingest-json", "start-provisioning"):
        if name not in templates:
            fail(f"missing template {name!r}")

    steps_template = templates.get("provision-pipeline", {})
    step_names = [
        step.get("name")
        for group in steps_template.get("steps", [])
        for step in group
    ]
    if step_names != ["ingest-json", "start-provisioning"]:
        fail(f"unexpected step order: {step_names}")


def test_makefile_phony_and_targets() -> None:
    makefile = (ROOT / "Makefile").read_text()
    if "PHONY:" in makefile and ".PHONY:" not in makefile:
        fail("Makefile still uses PHONY: instead of .PHONY:")
    for target in (
        "setup-argo-api-auth",
        "submit-provisioning-pipeline",
        "test",
    ):
        if f"{target}:" not in makefile:
            fail(f"Makefile missing target {target}")


def main() -> int:
    test_argo_api_submitter()
    test_provisioning_pipeline_template()
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
