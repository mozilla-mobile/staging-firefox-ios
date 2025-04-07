from taskgraph.transforms.task import payload_builder
from voluptuous import Optional, Required

@payload_builder(
    "scriptworker-tree",
    schema={
        Required("bump"): bool,
        Optional("bump-files"): [str],
        Optional("push"): bool,
        Optional("branch"): str,
    },
)
def build_version_bump_payload(config, task, task_def):
    worker = task["worker"]
    task_def["tags"]["worker-implementation"] = "scriptworker"

    scopes = task_def.setdefault("scopes", [])
    scope_prefix = f"project:mobile:{config.params['project']}:treescript:action"
    task_def["payload"] = {}

    if worker["bump"]:
        if not worker["bump-files"]:
            raise Exception("Version Bump requested without bump-files")

        bump_info = {}
        bump_info["next_version"] = config.params["next_version"]
        bump_info["files"] = worker["bump-files"]
        task_def["payload"]["version_bump_info"] = bump_info
        scopes.append(f"{scope_prefix}:version_bump")

    if worker["push"]:
        task_def["payload"]["push"] = True

    if worker.get("force-dry-run"):
        task_def["payload"]["dry_run"] = True

    if worker.get("branch"):
        task_def["payload"]["branch"] = worker["branch"]
