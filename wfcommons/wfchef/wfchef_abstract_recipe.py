#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2020-2022 The WfCommons Team.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

import json
import pickle
import random
import pandas as pd
import networkx as nx
import numpy as np

from logging import Logger
from typing import Any, Dict, List, Optional, Set, Union
from wfcommons.common.task import Task
from wfcommons.common.workflow import Workflow
from wfcommons.wfchef.duplicate import duplicate
from wfcommons.wfgen.abstract_recipe import WorkflowRecipe

from enum import Enum
import pathlib


class BaseMethod(Enum):
    ERROR_TABLE = 0
    SMALLEST = 1
    BIGGEST = 2
    RANDOM = 3


this_dir = pathlib.Path(__file__).resolve().parent


class WfChefWorkflowRecipe(WorkflowRecipe):
    """An abstract class of workflow recipes for creating synthetic workflow instances.

    :param name: The workflow recipe name.
    :type name: str
    :param data_footprint: The upper bound for the workflow total data footprint (in bytes).
    :type data_footprint: int
    :param num_tasks: The upper bound for the total number of tasks in the workflow.
    :type num_tasks: int
    :param runtime_factor: The factor of which tasks runtime will be increased/decreased.
    :type runtime_factor: float
    :param input_file_size_factor: The factor of which tasks input files size will be increased/decreased.
    :type input_file_size_factor: float
    :param output_file_size_factor: The factor of which tasks output files size will be increased/decreased.
    :type output_file_size_factor: float
    :param logger: The logger where to log information/warning or errors (optional).
    :type logger: Logger
    """

    def __init__(self, name: str,
                 data_footprint: Optional[int],
                 num_tasks: Optional[int],
                 exclude_graphs: Set[str] = set(),
                 runtime_factor: Optional[float] = 1.0,
                 input_file_size_factor: Optional[float] = 1.0,
                 output_file_size_factor: Optional[float] = 1.0,
                 logger: Optional[Logger] = None,
                 this_dir: Union[str, pathlib.Path] = None,
                 base_method: Optional[Enum] = BaseMethod.ERROR_TABLE) -> None:
        """Create an object of the workflow recipe."""
        super().__init__(
            name=name,
            data_footprint=data_footprint,
            num_tasks=num_tasks,
            runtime_factor=runtime_factor,
            input_file_size_factor=input_file_size_factor,
            output_file_size_factor=output_file_size_factor,
            logger=logger
        )

        self.exclude_graphs = exclude_graphs
        self.workflows: List[Workflow] = []
        self.this_dir = pathlib.Path(this_dir).resolve(strict=True)
        self.base_method = base_method

    def _workflow_recipe(self) -> Dict[str, Any]:
        """Recipe for generating synthetic instances for a workflow. Recipes can be
        generated by using the :class:`~wfcommons.wfinstances.instance_analyzer.InstanceAnalyzer`.

        :return: A recipe in the form of a dictionary in which keys are task prefixes.
        :rtype: Dict[str, Any]
        """
        if not self.workflow_recipe:
            self.workflow_recipe = json.loads(self.this_dir.joinpath("task_type_stats.json").read_text())
        return self.workflow_recipe

    @classmethod
    def from_num_tasks(cls,
                       num_tasks: int,
                       exclude_graphs: Set[str] = set(),
                       runtime_factor: Optional[float] = 1.0,
                       input_file_size_factor: Optional[float] = 1.0,
                       output_file_size_factor: Optional[float] = 1.0
                       ) -> 'WfChefWorkflowRecipe':
        """
        Instantiate a workflow recipe that will generate synthetic workflows up to the
        total number of tasks provided.

        :param num_tasks: The upper bound for the total number of tasks in the workflow.
        :type num_tasks: int
        :param exclude_graphs:
        :type exclude_graphs: Set
        :param runtime_factor: The factor of which tasks runtime will be increased/decreased.
        :type runtime_factor: float
        :param input_file_size_factor: The factor of which tasks input files size will be increased/decreased.
        :type input_file_size_factor: float
        :param output_file_size_factor: The factor of which tasks output files size will be increased/decreased.
        :type output_file_size_factor: float

        :return: A workflow recipe object that will generate synthetic workflows up to
                 the total number of tasks provided.
        :rtype: WfChefWorkflowRecipe
    
       """
        return cls(num_tasks=num_tasks,
                   exclude_graphs=exclude_graphs,
                   runtime_factor=runtime_factor,
                   input_file_size_factor=input_file_size_factor,
                   output_file_size_factor=output_file_size_factor)

    def generate_nx_graph(self) -> nx.DiGraph:
        summary_path = self.this_dir.joinpath("microstructures", "summary.json")
        summary = json.loads(summary_path.read_text())

        metric_path = self.this_dir.joinpath("microstructures", "metric", "err.csv")
        df = pd.read_csv(str(metric_path), index_col=0)
        df = df.drop(self.exclude_graphs, axis=0, errors="ignore")
        df = df.drop(self.exclude_graphs, axis=1, errors="ignore")
        for col in df.columns:
            df.loc[col, col] = np.nan

        reference_orders = [summary["base_graphs"][col]["order"] for col in df.columns]
        idx = np.argmin([abs(self.num_tasks - ref_num_tasks) for ref_num_tasks in reference_orders])
        reference = df.columns[idx]

        if self.base_method == BaseMethod.ERROR_TABLE:
            base = df.index[df[reference].argmin()]
        elif self.base_method == BaseMethod.SMALLEST:
            base = min(
                [k for k in summary["base_graphs"].keys() if summary["base_graphs"][k] not in self.exclude_graphs],
                key=lambda k: summary["base_graphs"][k]["order"]
            )
        elif self.base_method == BaseMethod.BIGGEST:
            base = max(
                [k for k in summary["base_graphs"].keys() if summary["base_graphs"][k]["order"] <= self.num_tasks and
                summary["base_graphs"][k] not in self.exclude_graphs],
                key=lambda k: summary["base_graphs"][k]["order"]
            )
        else:
            base = random.choice(
                [k for k in summary["base_graphs"].keys() if summary["base_graphs"][k]["order"] <= self.num_tasks and
                summary["base_graphs"][k] not in self.exclude_graphs]
            )
     

        graph = duplicate(self.this_dir.joinpath("microstructures"), base, self.num_tasks)
        return graph

    def build_workflow(self, workflow_name: Optional[str] = None) -> Workflow:
        """Generate a synthetic workflow instance.

        :param workflow_name: The workflow name
        :type workflow_name: int

        :return: A synthetic workflow instance object.
        :rtype: Workflow
        """
        workflow = Workflow(name=self.name + "-synthetic-instance" if not workflow_name else workflow_name,
                            makespan=0)
        graph = self.generate_nx_graph()

        task_names = {}
        for node in graph.nodes:
            if node in ["SRC", "DST"]:
                continue
            node_type = graph.nodes[node]["type"]
            task_name = self._generate_task_name(node_type)
            task = self._generate_task(node_type, task_name)
            workflow.add_task(task)

            task_names[node] = task_name

        # tasks dependencies
        for (src, dst) in graph.edges:
            if src in ["SRC", "DST"] or dst in ["SRC", "DST"]:
                continue
            workflow.add_dependency(task_names[src], task_names[dst])

            if task_names[src] not in self.tasks_children:
                self.tasks_children[task_names[src]] = []
            if task_names[dst] not in self.tasks_parents:
                self.tasks_parents[task_names[dst]] = []

            self.tasks_children[task_names[src]].append(task_names[dst])
            self.tasks_parents[task_names[dst]].append(task_names[src])

        # find leaf tasks
        leaf_tasks = []
        for node_name in workflow.nodes:
            task: Task = workflow.nodes[node_name]['task']
            if task.name not in self.tasks_children:
                leaf_tasks.append(task)

        for task in leaf_tasks:
            self._generate_task_files(task)

        workflow.nxgraph = graph
        self.workflows.append(workflow)
        return workflow

    def _load_base_graph(self) -> nx.DiGraph:
        return pickle.loads(self.this_dir.joinpath("base_graph.pickle").read_bytes())

    def _load_microstructures(self) -> Dict:
        return json.loads(self.this_dir.joinpath("microstructures.json").read_text())
