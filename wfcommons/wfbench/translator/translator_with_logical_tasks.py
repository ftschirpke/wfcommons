#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2021-2025 The WfCommons Team.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

import logging
import pathlib
from collections import defaultdict
from typing import Dict, MutableSet, Optional, Tuple, Union

from ...common import File, Task, Workflow
from .abstract_translator import Translator

this_dir = pathlib.Path(__file__).resolve().parent


class TranslatorWithLogicalTasks(Translator):
    """
    An abstract class of WfFormat parser for creating workflow benchmark applications
    where multiple physical tasks are grouped by their logical tasks (also called abstract tasks or templates)

    :param workflow: Workflow benchmark object or path to the workflow benchmark JSON instance.
    :type workflow: Union[Workflow, pathlib.Path]
    :param logger: The logger where to log information/warning or errors (optional).
    :type logger: logging.Logger
    """

    def __init__(self,
                 workflow: Union[Workflow, pathlib.Path],
                 logger: Optional[logging.Logger] = None) -> None:
        """Create an object of the translator with logcal task groupings."""

        super().__init__(workflow, logger)

        self.logical_tasks: Dict[str, MutableSet[Task]] = defaultdict(set)
        for task_id, task in self.tasks.items():
            assert task_id == task.task_id, "Task ID should match"
            assert task.category is None and task.name is not None, "This implementation assumes that logical tasks are identified via the name and task.category is not used anymore"

            logical_task: str = task.name
            self.logical_tasks[logical_task].add(task)

        self.logical_parents: Dict[str, MutableSet[str]] = defaultdict(set)
        self.logical_children: Dict[str, MutableSet[str]] = defaultdict(set)
        for task in self.tasks.values():
            for parent in self.task_parents[task.task_id]:
                parent = self.tasks[parent]
                self.logical_parents[task.name].add(parent.name)
            for child in self.task_children[task.task_id]:
                child = self.tasks[child]
                self.logical_children[task.name].add(child.name)

        self.has_iterations: bool = any(
            logical_task in logical_parents
            for logical_task, logical_parents in self.logical_parents.items()
        )

        self.logical_task_input_count: Dict[str, Union[int, Tuple[int, int]]] = dict()
        for logical_task, physical_tasks in self.logical_tasks.items():
            input_counts = {task.task_id: len(task.input_files) for task in physical_tasks}
            if max(input_counts.values()) == min(input_counts.values()):
                self.logical_task_input_count[logical_task] = max(input_counts.values())
            else:
                self.logical_task_input_count[logical_task] = (min(input_counts.values()), max(input_counts.values()))

        self.task_edges: Dict[Tuple[Task, Task], MutableSet[File]] = defaultdict(set)
        self.logical_edges: Dict[Tuple[str, str], MutableSet[File]] = defaultdict(set)
        self.workflow_inputs: MutableSet[File] = set()
        self.workflow_outputs: MutableSet[File] = set()
        for task in self.tasks.values():
            inputs_found_in_parents = set()
            for parent in self.task_parents[task.task_id]:
                parent = self.tasks[parent]
                for file in parent.output_files:
                    if file in task.input_files:
                        self.task_edges[(parent, task)].add(file)
                        self.logical_edges[(parent.name, task.name)].add(file)
                        inputs_found_in_parents.add(file)

            outputs_found_in_children = set()
            for child in self.task_children[task.task_id]:
                child = self.tasks[child]
                for file in child.input_files:
                    if file in task.output_files:
                        self.task_edges[(task, child)].add(file)
                        self.logical_edges[(task.name, child.name)].add(file)
                        outputs_found_in_children.add(file)

            for infile in task.input_files:
                if infile not in inputs_found_in_parents:
                    self.task_edges[(None, task)].add(infile)
                    self.logical_edges[(None, task.name)].add(infile)
                    self.workflow_inputs.add(infile)
            for outfile in task.output_files:
                if outfile not in outputs_found_in_children:
                    self.task_edges[(task, None)].add(outfile)
                    self.logical_edges[(task.name, None)].add(outfile)
                    self.workflow_outputs.add(outfile)
