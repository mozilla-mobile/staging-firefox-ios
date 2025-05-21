# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import os.path

from git import Repo
from mozilla_version.ios import MobileIosVersion
from taskgraph.transforms.base import TransformSequence
from taskgraph.util.schema import resolve_keyed_by
import taskgraph


transforms = TransformSequence()

@transforms.add
def resolve_keys(config, tasks):
    for task in tasks:
        for key in ("scopes",):
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
def resolve_beta_branch_and_head(config, tasks):
    RELEASE_BRANCH_PREFIX = "release/v"

    for task in tasks:
        current_release_branch = "[SKIPPED]"
        revision = "[SKIPPED]"
        version = "[SKIPPED]"

        repo_dir = os.path.join(config.graph_config.root_dir, "../")

        if not taskgraph.fast:
            repo = Repo(repo_dir)

            remote = repo.remote()
            # Make sure we're up to date
            remote.fetch()

            current_release_branch = max(ref.remote_head for ref in remote.refs if ref.remote_head.startswith(RELEASE_BRANCH_PREFIX))
            revision = remote.refs[current_release_branch].object.hexsha
            commit = repo.commit(revision)
            file_blob = commit.tree / "version.txt"
            version = file_blob.data_stream.read().decode('utf-8').strip()
            parsed_version = MobileIosVersion.parse(version)
            if not parsed_version.is_beta:
                print("The latest release branch isn't a beta, not generating a beta release task")
                return

        worker = task.setdefault("worker", {})
        worker["branch"] = current_release_branch
        worker["revision"] = revision
        worker["version"] = version

        yield task

