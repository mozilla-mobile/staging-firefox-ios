# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
from taskgraph.transforms.base import TransformSequence
from taskgraph.util.schema import resolve_keyed_by

transforms = TransformSequence()

@transforms.add
def resolve_by_keys(config, tasks):
    for task in tasks:
        for key in (
            "worker.github-project",
            "worker.release-name",
        ):
            resolve_keyed_by(
                task,
                key,
                item_name=task["name"],
                **{
                    "level": config.params["level"],
                }
            )

        yield task

@transforms.add
def build_parameters(config, tasks):
    for task in tasks:
        worker = task.setdefault("worker", {})
        worker["git-revision"] = config.params["head_rev"]
        worker["release-name"] = worker["release-name"].format(**config.params)
        worker["git-tag"] = worker["git-tag"].format(**config.params)
        yield task
