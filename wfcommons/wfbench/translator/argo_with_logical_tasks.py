#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2025 The WfCommons Team.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

import json
import pathlib
import yaml

from logging import Logger
from typing import Dict, Optional, Union

from .translator_with_logical_tasks import TranslatorWithLogicalTasks
from ...common import Workflow


def _normalize(s: str) -> str:
    return s.lower().replace("_", "-")


MIN_MEMORY = 1 * 1024**3  # 1 GB
DEFAULT_MEMORY = 4 * 1024**3  # 4 GB
assert DEFAULT_MEMORY >= MIN_MEMORY

MIN_CPUS = 1
DEFAULT_CPUS = 1
assert DEFAULT_CPUS >= MIN_CPUS


class ArgoTranslatorWithLogicalTasks(TranslatorWithLogicalTasks):
    """
    A WfFormat parser for creating Nextflow workflow applications that utilizes logical tasks
    and defines one Nextflow process for each logical task instead of one process for each
    physical task.

    :param workflow: Workflow benchmark object or path to the workflow benchmark JSON instance.
    :type workflow: Union[Workflow, pathlib.Path],
    :param logger: The logger where to log information/warning or errors (optional).
    :type logger: Logger
    """

    def __init__(self,
                 workflow: Union[Workflow, pathlib.Path],
                 logger: Optional[Logger] = None) -> None:
        """Create an object of the translator."""
        super().__init__(workflow, logger)

    def translate(self, output_folder: pathlib.Path, define_outlabels: bool = False,
                  persistent_volume_claim: str = "argo-pvc",
                  node_selectors: Dict[str, str] = {},
                  wfbench_image: str = "friedricht/wfbench") -> None:
        """
        Translate a workflow benchmark description(WfFormat) into a Nextflow workflow application.

        :param output_folder: The path to the folder in which the workflow benchmark will be generated.
        :type output_folder: pathlib.Path
        :param define_outlabels: Indicates whether outlabels should be defined (default: False)
                                 Outlabels are used to indicate which tasks merge their results.
        :type define_outlabels: bool
        """

        if self.has_iterations:
            raise RuntimeError("This implementation of the Argo translator does not support iterations.")

        # Create the output folder
        output_folder.mkdir(parents=True)

        # Create benchmark files
        self._copy_binary_files(output_folder)
        self._generate_input_files(output_folder)

        entrypoint_name = f"{_normalize(self.workflow.name)}-DAG"

        self.workflow_yaml = {
            "apiVersion": "argoproj.io/v1alpha1",
            "kind": "Workflow",
            "metadata": {
                "generateName": f"{_normalize(self.workflow.name)}-",
                "labels": {
                    "workflows.argoproj.io/archive-strategy": "false",
                },
                "annotations": {
                    "workflows.argoproj.io/description": self.workflow.description,
                },
            },
            "spec": {
                "entrypoint": entrypoint_name,
                "templates": [],
                "volumes": [{
                    "name": "workdir",
                    "persistentVolumeClaim": {
                        "claimName": persistent_volume_claim,
                    },
                }],
            },
        }

        templates = self.workflow_yaml["spec"]["templates"]

        generic_template_name = "generic-wfbench-template"
        workdir = "/mnt/vol"

        task_template = {
            "name": _normalize(generic_template_name),
            "inputs": {
                "parameters": [
                    {"name": "args"},
                    {"name": "cpu-limit"},
                    {"name": "mem-limit"},
                ],
            },
            "podSpecPatch": '{"containers":[{"name":"main", "resources":{"limits":{"cpu": "{{inputs.parameters.cpu-limit}}", "memory": "{{inputs.parameters.mem-limit}}"}, "requests": {"cpu": "{{inputs.parameters.cpu-limit}}", "memory": "{{inputs.parameters.mem-limit}}"}}}]}',
            "container": {
                "image": wfbench_image,
                "command": ["sh", "-c"],
                "args": [f"cd {workdir}" + " && wfbench {{inputs.parameters.args}}"],
                "volumeMounts": [
                    {"name": "workdir", "mountPath": workdir},
                ],
            },
            "nodeSelector": node_selectors,
        }
        templates.append(task_template)

        dag_template = {
            "name": entrypoint_name,
            "dag": {
                "tasks": [],
            },
        }
        tasks = dag_template["dag"]["tasks"]

        for logical_task, physical_tasks in self.logical_tasks.items():
            physical_inputs = []
            for task in physical_tasks:
                # Generate input spec
                input_spec = "'\\["
                for f in task.input_files:
                    input_spec += "\"" + str(f.file_id) + "\","
                input_spec = input_spec[:-1] + "\\]'"
                # Generate output spec
                output_spec = "'\\{"
                for f in task.output_files:
                    output_spec += "\"" + str(f.file_id) + "\":" + str(f.size) + ","
                output_spec = output_spec[:-1] + "\\}'"

                args = ""
                for a in task.args:
                    if "--output-files" in a:
                        args += f"--output-files {output_spec} "
                    elif "--input-files" in a:
                        args += f"--input-files {input_spec} "
                    else:
                        args += f"{a} "

                if args[-1] == " ":
                    args = args[:-1]

                physical_inputs.append([args, task.cores, task.memory])

            task_dict = {
                "name": _normalize(logical_task),
                "template": generic_template_name,
                "dependencies": [_normalize(dep) for dep in self.logical_parents[logical_task]],
                "arguments": {
                    "parameters": [
                        {"name": "args", "value": "{{item.args}}"},
                        {"name": "cpu-limit", "value": "{{item.cpu}}"},
                        {"name": "mem-limit", "value": "{{item.mem}}"},
                    ],
                },
                "withItems": [
                    {"args": a, "cpu": max(c, MIN_CPUS) if c else DEFAULT_CPUS,
                     "mem": int(max(m * 2, MIN_MEMORY) if m else DEFAULT_MEMORY)}
                    for a, c, m in physical_inputs
                ],
            }
            tasks.append(task_dict)

        templates.append(dag_template)

        script = yaml.dump(self.workflow_yaml, width=float("inf"))
        self._write_output_file(script, output_folder.joinpath("workflow.yaml"))

        return
