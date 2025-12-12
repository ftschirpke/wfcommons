#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2021-2025 The WfCommons Team.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

import json
import math
import pathlib

from collections import defaultdict
from logging import Logger
from typing import Dict, List, Optional, Union

from .translator_with_logical_tasks import TranslatorWithLogicalTasks
from ...common import Workflow


class NextflowTranslatorWithLogicalTasks(TranslatorWithLogicalTasks):
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

        self.script = ""

        self._usage_string = """
Usage: nextflow run workflow.nf --pwd /path/to/directory [--simulate] [--help]

    Required parameters:
      --pwd         Working directory (where the workflow.nf file is located)

    Optional parameters:
      --help        Show this message and exit.
      --simulate    Use a "sleep 1" for all tasks instead of the WfBench benchmark.
"""

    def _generate_arg_parsing_code(self):
        """
        Generate the code to parse command-line argument.

        :return: The code.
        :rtype: str
        """

        code = r'''
params.simulate = false
params.pwd = null
params.help = null
pwd = null

def printUsage(error_msg, exit_code) {

    def usage_string = """
'''
        code += self._usage_string

        code += r'''
"""
    if (error_msg) {
        def RED = '\u001B[31m'
        def RESET = '\u001B[0m'
        System.err.println "${RED}Error: ${RESET}" + error_msg
    }
    System.err.println usage_string
    exit exit_code
}

def validateParams() {
    if (params.help) {
        printUsage(msg = "", exit_code=0)
    }
    if (params.pwd == null) {
        printUsage(msg = "Missing required parameter: --pwd", exit_code=1)
    }
    pwd = file(params.pwd).toAbsolutePath().toString()
    if (!file(pwd).exists()) {
        printUsage(msg = "Directory not found: ${pwd}", exit_code=1)
    }
}

// Call validation at the start
validateParams()

'''
        return code

    def _write_readme_file(self, output_folder: pathlib.Path) -> None:
        """
        Write the README  file.

        :param output_folder: The path of the output folder.
        :type output_folder: pathlib.Path
        """
        readme_file_path = output_folder.joinpath("README")
        with open(readme_file_path, "w") as out:
            out.write(f"Run the workflow in directory {str(output_folder)} using the following command:\n")

            out.write("\tnextflow run ./workflow.nf --pwd `pwd`\n")
            out.write("\n")
            out.write(self._usage_string)

    def _introduce_map(self, map_dict: Dict, map_name: str, output_folder: pathlib.Path) -> None:
        path = output_folder.joinpath(f"{map_name}.json")
        with open(path, "w") as f:
            f.write(json.dumps(map_dict, indent=4))
        self.script += f"{map_name} = jsonSlurper.parseText(file(\"${{projectDir}}/{map_name}.json\").text)\n"

    @staticmethod
    def valid_task_name(original_task_name: str) -> str:
        return original_task_name.replace('-', '_')

    @staticmethod
    def _is_resource_arg(arg: str) -> bool:
        return arg.startswith("--percent-cpu") or arg.startswith("--mem") \
            or arg.startswith("--cpu-work") or arg.startswith("--gpu-work")

    @staticmethod
    def human_readable_memory(mem_bytes: int) -> str:
        idx = 0
        memory = mem_bytes
        memory_units = ["B", "KB", "MB", "GB", "TB"]
        while memory > 1024 and idx < len(memory_units) - 1:
            memory /= 1024
            idx += 1
        memory = math.ceil(memory * 100) / 100  # ensure that it is an upper bound
        return f"{memory:.2f} {memory_units[idx]}"

    def _add_logical_task_definition(self, logical_task: str, define_outlabel: bool = False) -> None:
        """
        Add an logical task to the workflow considering it's physical tasks.

        :param logical_task: the name of the logical task
        :type logical_task: str
        """

        physical_tasks = self.logical_tasks[logical_task]

        cores_values = [task.cores for task in physical_tasks if task.cores is not None]
        if len(cores_values) == 0:
            cores = None
        else:
            cores = int(max(cores_values))
        memory_values = [task.memory for task in physical_tasks if task.memory is not None]
        if len(memory_values) == 0:
            memory = None
        else:
            memory = max(memory_values) * 4

        # creating the logical task
        self.script += f"process task_{self.valid_task_name(logical_task)}" + " {\n"
        if cores:
            self.script += f"  cpus {cores}\n"
        if memory:
            self.script += f"  memory '{self.human_readable_memory(memory)}'\n"
        if define_outlabel and self.outlabels and logical_task in self.outlabels:
            self.script += f"  outLabel {{ outlabels[{logical_task}][id] as List }}\n"
        self.script += "  input:\n"
        self.script += "    tuple val( id ), path( \"*\" )\n"
        self.script += f"  output:\n    path( \"{self.valid_task_name(logical_task)}_????????_outfile_????*\" )\n"
        self.script += "  script:\n"
        self.script += "  \"\"\"\n"
        self.script += "  ${ params.simulate ? 'sleep 1' : cmd_map[id] }\n"
        self.script += "  \"\"\"\n"
        self.script += "}\n"

    def _add_call_to_logical_task(self, logical_task_name: str) -> None:
        physical_tasks = self.logical_tasks[logical_task_name]
        parents = self.logical_parents[logical_task_name]
        for parent in parents:
            if parent == logical_task_name:
                raise RuntimeError("Iterations are not supported by Nextflow.")
            if not self.logical_task_written[parent]:
                self._add_call_to_logical_task(parent, self.logical_tasks[parent])

        # determining the channel of all raw inputs (outputs of other tasks)
        input_channels = [
            f"{self.valid_task_name(parent)}_out" for parent in parents]
        example_task = next(physical_tasks.__iter__())
        for input_file in example_task.input_files:
            if input_file in self.workflow_inputs:
                input_channels.append("workflow_inputs")
                break

        if len(input_channels) == 1:
            inputs_channel = input_channels[0]
        elif len(input_channels) != 0:
            # concatenating all the input channels into one big channel
            one_channel = input_channels.pop()
            inputs_channel = f"concatenated_FOR_{self.valid_task_name(logical_task_name)}"
            self.script += f"  {inputs_channel} = {one_channel}.concat({', '.join(input_channels)})\n"
        else:
            raise RuntimeError(f"The logical task {logical_task_name} has no inputs.")

        # creating the input channel for this logical task by grouping the outputs from the parents by id
        self.script += f"  {self.valid_task_name(logical_task_name)}_in = {inputs_channel}.flatten().flatMap{{\n"
        self.script += f"    List<String> ids = extractTaskIDforFile(it, \"{logical_task_name}\")\n"
        self.script += "    def pairs = new ArrayList()\n"
        self.script += "    for (id : ids) pairs.add([id, it])\n"
        self.script += "    return pairs\n"
        self.script += "  }"

        if isinstance(self.logical_task_input_count[logical_task_name], int):
            self.script += f".groupTuple(size: {self.logical_task_input_count[logical_task_name]})\n"
        else:
            map_name = f"{self.valid_task_name(logical_task_name)}_input_counts"
            self.script += f".map {{ id, file -> tuple( groupKey(id, {map_name}[id]), file ) }}\n"
            self.script += "  .groupTuple()\n"

        self.script += f"  {self.valid_task_name(logical_task_name)}_out = task_"
        self.script += f"{self.valid_task_name(logical_task_name)}({self.valid_task_name(logical_task_name)}_in)\n\n"

        self.logical_task_written[logical_task_name] = True

    def translate(self, output_folder: pathlib.Path, define_outlabels: bool = False) -> None:
        """
        Translate a workflow benchmark description(WfFormat) into a Nextflow workflow application.

        :param output_folder: The path to the folder in which the workflow benchmark will be generated.
        :type output_folder: pathlib.Path
        :param define_outlabels: Indicates whether outlabels should be defined (default: False)
                                 Outlabels are used to indicate which tasks merge their results.
        :type define_outlabels: bool
        """

        if self.has_iterations:
            raise RuntimeError("Iterations are not supported by Nextflow.")

        # Create the output folder
        output_folder.mkdir(parents=True)

        self.script = """
import groovy.json.JsonSlurper
def jsonSlurper = new JsonSlurper()

List<String> taskIDsForFile(Path filepath, String task_name) {
  String filename = filepath as String
  filename = filename[filename.lastIndexOf('/')+1..-1]
  return task_ids_for_file[filename][task_name]
}
"""

        self.script += self._generate_arg_parsing_code()

        # Create benchmark files
        self._copy_binary_files(output_folder)
        self._generate_input_files(output_folder)

        task_ids_for_file: Dict[str, Dict[str, List[str]]] = defaultdict(lambda: defaultdict(list))
        for task in self.tasks.values():
            id = task.task_id[-8:]  # only the 8 digits at the end of the task id
            for file in task.input_files:
                task_ids_for_file[file.file_id][task.name] = id
        self._introduce_map(task_ids_for_file, "task_ids_for_file", output_folder)

        if define_outlabels:
            self._introduce_map(self.outlabels, "outlabels", output_folder)

        cmd_map: Dict[str, str] = dict()
        for task in self.tasks.values():
            input_spec = "'\\["
            for f in task.input_files:
                input_spec += "\"" + str(output_folder.joinpath(f"data/{f.file_id}")) + "\","
            input_spec = input_spec[:-1] + "\\]'"

            # Generate output spec
            output_spec = "'\\{"
            for f in task.output_files:
                output_spec += "\"" + str(output_folder.joinpath(f"data/{f.file_id}")) + "\":" + str(f.size) + ","
            output_spec = output_spec[:-1] + "\\}'"

            cmd = str(output_folder.joinpath(f"bin/{task.program} "))

            for a in task.args:
                if "--output-files" in a:
                    cmd += f"--output-files {output_spec} "
                elif "--input-files" in a:
                    cmd += f"--input-files {input_spec} "
                else:
                    cmd += f"{a} "

            cmd_map[task.task_id] = cmd
        self._introduce_map(cmd_map, "cmd_map", output_folder)

        for logical_task_name, physical_tasks in self.logical_tasks.items():
            map_name = f"{self.valid_task_name(logical_task_name)}_args"
            task_args_map = {}
            for task in self.tasks.values():
                out_file_sizes = {file.file_id: file.size for file in task.output_files}
                out_arg = str(out_file_sizes).replace("{", "").replace("}", "").replace("'", "\\\"").replace(": ", ":")
                task_args_map[task.task_id] = {
                    "out": out_arg,
                    "resources": " ".join((arg for arg in task.args if self._is_resource_arg(arg)))
                }
            self._introduce_map(task_args_map, map_name, output_folder)

        for logical_task_name, physical_tasks in self.logical_tasks.items():
            if isinstance(self.logical_task_input_count[logical_task_name], int):
                continue
            map_name = f"{self.valid_task_name(logical_task_name)}_input_counts"
            map_items = dict()
            for physical_task in physical_tasks:
                id = physical_task.task_id[-8:]
                map_items[id] = len(physical_task.input_files)
            self._introduce_map(map_items, map_name, output_folder)

        self.logical_task_written: Dict[str, bool] = dict()
        for logical_task in self.logical_tasks:
            self._add_logical_task_definition(logical_task, define_outlabel=define_outlabels)
            self.logical_task_written[logical_task] = False

        self.script += "workflow {\n"
        self.script += "  workflow_inputs = Channel.fromPath(\"${params.indir}/*\")\n"
        self.script += "\n"
        for logical_task in self.logical_tasks:
            if not self.logical_task_written[logical_task]:
                self._add_call_to_logical_task(logical_task)
        self.script += "}\n"

        self._write_output_file(self.script, output_folder.joinpath("workflow.nf"))

        # Create the README file
        self._write_readme_file(output_folder)

        return
