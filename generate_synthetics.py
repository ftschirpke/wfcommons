#!/usr/bin/python

import os
from collections import defaultdict
from pathlib import Path
from typing import Type, Union, Dict
from wfcommons.common.workflow import Workflow
from wfcommons.wfbench.translator.nextflow import NextflowTranslator
from wfcommons.wfchef.recipes import BlastRecipe, BwaRecipe, CyclesRecipe, GenomeRecipe, MontageRecipe, SeismologyRecipe, SoykbRecipe
from wfcommons.wfchef.wfchef_abstract_recipe import WfChefWorkflowRecipe
from wfcommons.wfbench.bench import WorkflowBenchmark
from wfcommons.common.file import FileLink

RECIPES = [
    BlastRecipe,
    BwaRecipe,
    CyclesRecipe,
    GenomeRecipe,
    MontageRecipe,
    SeismologyRecipe,
    SoykbRecipe
]

wfbench_path = None


def create(idx: int = 0,
           num_of_tasks: int = 200,
           cpu_work: Union[int, Dict[str, int]] = 200,
           infile_size_factor: float = 1,
           outfile_size_factor: float = 1,
           max_cpus: int = 8,
           cluster: bool = True,
           random_state: int = 0) -> None:
    recipe: Type[WfChefWorkflowRecipe] = RECIPES[idx]
    name = recipe.__name__
    if name.endswith("Recipe"):
        name = name[:-len("Recipe")]
    name = f"Synthetic_{name}"

    print("-" * 120)
    print(name)

    wf: Workflow = recipe.from_num_tasks(
        num_of_tasks,
        input_file_size_factor=infile_size_factor,
        output_file_size_factor=outfile_size_factor
    ).build_workflow(random_state=random_state)
    wf.name = name

    _linearize_task_runtimes(wf)

    percent_cpu = max_cpus / 10

    if cluster:
        output_dir = Path("generated_workflows").joinpath(name)
    else:
        output_dir = Path("local_inputs/").joinpath(name)

    _analyze_and_print_file_sizes(wf)

    os.system(f"rm {output_dir}/*")

    bm: WorkflowBenchmark = WorkflowBenchmark(recipe, num_of_tasks)
    result_path: Path = bm.create_benchmark_from_synthetic_workflow(
        output_dir, wf, cpu_work=cpu_work, percent_cpu=percent_cpu, mem=15 * 1024
    )

    if result_path is None:
        print("Failed to create benchmark.")
        return

    translate(result_path, output_dir, cluster)


def translate(result_path, output_dir, cluster) -> None:
    global wfbench_path

    nextflow = NextflowTranslator(result_path)
    output_file_path = output_dir.joinpath("main.nf")
    nextflow.translate(output_file_path)
    if not cluster:
        with open(output_file_path, "r") as f:
            content = f.read()

        while wfbench_path is None or not wfbench_path.exists():
            wfbench_path = input("Enter the path to the wfbench.py file: ")
            wfbench_path = Path(wfbench_path.strip())

        content = content.replace(
            "wfbench.py", str(wfbench_path.resolve()))
        with open(output_file_path, "w") as f:
            f.write(content)


def _linearize_task_runtimes(wf: Workflow) -> None:

    task_runtimes = defaultdict(list)
    task_input_sizes = defaultdict(list)

    for task in wf.tasks.values():
        task_runtimes[task.category].append(task.runtime)

        accum_input_size = sum([file.size for file in task.files if file.link == FileLink.INPUT])
        task_input_sizes[task.category].append(accum_input_size)

    min_task_runtimes = {category: min(runtimes) for category, runtimes in task_runtimes.items()}
    max_task_runtimes = {category: max(runtimes) for category, runtimes in task_runtimes.items()}

    min_task_input_sizes = {category: min(sizes) for category, sizes in task_input_sizes.items()}
    max_task_input_sizes = {category: max(sizes) for category, sizes in task_input_sizes.items()}

    task_runtimes = defaultdict(list)

    for task in wf.tasks.values():
        accum_input_size = sum([file.size for file in task.files if file.link == FileLink.INPUT])

        min_input = min_task_input_sizes[task.category]
        max_input = max_task_input_sizes[task.category]

        if max_input != min_input:
            input_size_factor = (accum_input_size - min_input) / (max_input - min_input)

            min_runtime = min_task_runtimes[task.category]
            max_runtime = max_task_runtimes[task.category]
            task.runtime = min_runtime + (max_runtime - min_runtime) * input_size_factor

        task_runtimes[task.category].append(task.runtime)


def _analyze_and_print_file_sizes(wf: Workflow) -> None:
    total_insum = 0
    total_outsum = 0
    total_exchange_sum = 0
    workflow_insum = 0
    workflow_outsum = 0
    unique_files = {}
    infiles = set((file.name for task in wf.tasks.values()
                   for file in task.files if file.link == FileLink.INPUT))
    outfiles = set((file.name for task in wf.tasks.values()
                    for file in task.files if file.link == FileLink.OUTPUT))

    task_parents = {}
    task_counts = defaultdict(int)

    for task in wf.tasks.values():
        task_parents[task.category] = set()

    for task_name, parent_names in wf.tasks_parents.items():
        task = wf.tasks[task_name]
        task_counts[task.category] += 1
        for parent_name in parent_names:
            parent = wf.tasks[parent_name]
            task_parents[task.category].add(parent.category)

    for ptask in wf.tasks.values():
        for file in ptask.files:
            unique_files[file.name] = file.size
        insum = sum(
            [file.size for file in ptask.files if file.link == FileLink.INPUT])
        outsum = sum(
            [file.size for file in ptask.files if file.link == FileLink.OUTPUT])
        exchange_sum = sum([file.size for file in ptask.files
                            if file.link == FileLink.INPUT and file.name in outfiles])
        workflow_insum += sum([file.size for file in ptask.files
                               if file.link == FileLink.INPUT and file.name not in infiles])
        workflow_outsum += sum([file.size for file in ptask.files
                                if file.link == FileLink.OUTPUT and file.name not in infiles])
        total_insum += insum
        total_outsum += outsum
        total_exchange_sum += exchange_sum
    total_unique = sum([file_size for file_size in unique_files.values()])

    print("-" * 100)
    print(f"{'Task':40} | Parents")
    for child, parents in task_parents.items():
        count_str = f"{child} ({task_counts[child]})"
        print(f"{count_str:40} - {list(parents)}")

    print("-" * 100)
    print(f"{'TOTAL':40} - read: {total_insum/1024**3:14.2f} GB, write: {total_outsum/1024**3:14.2f} GB, unique: {total_unique/1024**3:14.2f} GB, exchange: {total_exchange_sum/1024**3:14.2f} GB")

    workflow_inputs = set()
    outnames = set()
    for task in wf.tasks.values():
        for file in task.files:
            if file.link == FileLink.OUTPUT:
                outnames.add(file.name)
            elif file.link == FileLink.INPUT:
                workflow_inputs.add(file)
    insize = 0
    for file in workflow_inputs:
        if file.name not in outnames:
            insize += file.size
    print(f"Workflow input size: {insize/1024**3:14.2f} GB")


TEST_WORKFLOW: bool = False
ONLY_TEST_WORKFLOW: bool = False


def main() -> None:
    # TEST
    if TEST_WORKFLOW or ONLY_TEST_WORKFLOW:
        create(idx=4, num_of_tasks=1500, cpu_work=5000, infile_size_factor=7, outfile_size_factor=2.8, random_state=0)
        if ONLY_TEST_WORKFLOW:
            return
    # BlastRecipe
    create(idx=0, num_of_tasks=400, cpu_work=5200, infile_size_factor=0.015, outfile_size_factor=26000,
           max_cpus=8,
           random_state=0)
    # BwaRecipe
    create(idx=1, num_of_tasks=1200, cpu_work=10000, infile_size_factor=1400, outfile_size_factor=1800,
           max_cpus=15,
           random_state=0)
    # CyclesRecipe
    create(idx=2, num_of_tasks=700, cpu_work=5200, infile_size_factor=14, outfile_size_factor=40,
           random_state=0)
    # GenomeRecipe
    create(idx=3, num_of_tasks=700, cpu_work=5000, infile_size_factor=0.015, outfile_size_factor=1600,
           max_cpus=10,
           random_state=0)
    # MontageRecipe
    create(idx=4, num_of_tasks=1500, cpu_work=6000, infile_size_factor=7, outfile_size_factor=3,
           max_cpus=12,
           random_state=6)
    # SeismologyRecipe
    create(idx=5, num_of_tasks=500, cpu_work=5000, infile_size_factor=7000, outfile_size_factor=13000,
           max_cpus=8,
           random_state=0)
    # SoykbRecipe
    create(idx=6, num_of_tasks=1700, cpu_work=15000, infile_size_factor=0.005, outfile_size_factor=430,
           max_cpus=30,
           # log_cpus=True,
           random_state=0)


if __name__ == "__main__":
    main()
