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

recipes = [
    BlastRecipe,
    BwaRecipe,
    CyclesRecipe,
    GenomeRecipe,
    MontageRecipe,
    SeismologyRecipe,
    SoykbRecipe
]


def create(idx: int = 0,
           num_of_tasks: int = 200,
           cpu_work: Union[int, Dict[str, int]] = 200,
           infile_size_factor: float = 1,
           outfile_size_factor: float = 1,
           cluster: bool = True,
           random_state: int = 0) -> None:
    recipe: Type[WfChefWorkflowRecipe] = recipes[idx]
    name = recipe.__name__
    if name.endswith("Recipe"):
        name = name[:-len("Recipe")]
    name = f"Synthetic_{name}"

    print("-" * 120)
    print(name)
    print("cpuwork:", cpu_work)
    print("input  :", infile_size_factor)
    print("output :", outfile_size_factor)

    wf: Workflow = recipe.from_num_tasks(
        num_of_tasks,
        input_file_size_factor=infile_size_factor,
        output_file_size_factor=outfile_size_factor
    ).build_workflow(random_state=random_state)
    wf.name = name

    # fix task runtimes:
    task_runtimes = defaultdict(list)
    task_input_sizes = defaultdict(list)

    for task in wf.tasks.values():
        task_runtimes[task.category].append(task.runtime)

        accum_input_size = sum([file.size for file in task.files if file.link == FileLink.INPUT])
        task_input_sizes[task.category].append(accum_input_size)

    max_task_runtimes = {category: max(runtimes) for category, runtimes in task_runtimes.items()}
    avg_task_runtimes = {category: sum(runtimes) / len(runtimes) for category, runtimes in task_runtimes.items()}
    max_task_input_sizes = {category: max(sizes) for category, sizes in task_input_sizes.items()}

    task_runtimes = defaultdict(list)

    for task in wf.tasks.values():
        accum_input_size = sum([file.size for file in task.files if file.link == FileLink.INPUT])

        runtime_deviation = task.runtime - avg_task_runtimes[task.category]
        input_size_factor = accum_input_size / max_task_input_sizes[task.category]

        task.runtime = (max_task_runtimes[task.category] * (2 + input_size_factor)) / 3 + runtime_deviation * 0.1
        task_runtimes[task.category].append(task.runtime)

    for category, runtimes in task_runtimes.items():
        print(f"{category = } => {runtimes = }")

    if cluster:
        output_dir = Path("generated_workflows").joinpath(name)
    else:
        output_dir = Path("local_inputs/").joinpath(name)

    total_insum = 0
    total_outsum = 0
    total_exchange_sum = 0
    workflow_insum = 0
    workflow_outsum = 0
    unique_files = {}
    infiles = set([file.name for task in wf.tasks.values()
                  for file in task.files if file.link == FileLink.INPUT])
    outfiles = set([file.name for task in wf.tasks.values()
                   for file in task.files if file.link == FileLink.OUTPUT])

    FTparents = {}
    FTcounts = defaultdict(int)

    for task in wf.tasks.values():
        FTparents[task.category] = set()

    for task_name, parent_names in wf.tasks_parents.items():
        task = wf.tasks[task_name]
        FTcounts[task.category] += 1
        for parent_name in parent_names:
            parent = wf.tasks[parent_name]
            FTparents[task.category].add(parent.category)

    for ptask in wf.tasks.values():
        for file in ptask.files:
            unique_files[file.name] = file.size
        insum = sum(
            [file.size for file in ptask.files if file.link == FileLink.INPUT])
        outsum = sum(
            [file.size for file in ptask.files if file.link == FileLink.OUTPUT])
        exchange_sum = sum([file.size for file in ptask.files if file.link ==
                           FileLink.INPUT and file.name in outfiles])
        workflow_insum += sum([file.size for file in ptask.files if file.link ==
                              FileLink.INPUT and file.name not in infiles])
        workflow_outsum += sum([file.size for file in ptask.files if file.link ==
                               FileLink.OUTPUT and file.name not in infiles])
        total_insum += insum
        total_outsum += outsum
        total_exchange_sum += exchange_sum
    total_unique = sum([file_size for file_size in unique_files.values()])

    print("-" * 100)
    print(f"{'Task':40} | Parents")
    for child, parents in FTparents.items():
        count_str = f"{child} ({FTcounts[child]})"
        print(f"{count_str:40} - {list(parents)}")

    print("-" * 100)
    print(f"{'TOTAL':40} - read: {total_insum/1024:14.2f} kB, write: {total_outsum/1024:14.2f} kB, unique: {total_unique/1024:14.2f} kB, exchange: {total_exchange_sum/1024:14.2f} kB")
    print(f"{'TOTAL':40} - read: {total_insum/1024**2:14.2f} MB, write: {total_outsum/1024**2:14.2f} MB, unique: {total_unique/1024**2:14.2f} MB, exchange: {total_exchange_sum/1024**2:14.2f} MB")
    print(f"{'TOTAL':40} - read: {total_insum/1024**3:14.2f} GB, write: {total_outsum/1024**3:14.2f} GB, unique: {total_unique/1024**3:14.2f} GB, exchange: {total_exchange_sum/1024**3:14.2f} GB")
    print(f"{'Workflow input':40} - {workflow_insum/1024**3:14.2f} GB ({workflow_insum})")
    print(f"{'Workflow output':40} - {workflow_outsum/1024**3:14.2f} GB ({workflow_outsum})")
    print(name)

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

    # while True:
    #     response = input(
    #         "Do you want to create the input files for this workflow? [y/n] or recalculate [r]: ").lower()
    #     if response == "y":
    #         break
    #     elif response == "r":
    #         create(idx, num_of_tasks=num_of_tasks, cpu_work=cpu_work, infile_size_factor=infile_size_factor,
    #                outfile_size_factor=outfile_size_factor, cluster=cluster)
    #         return
    #     elif response == "n":
    #         return
    #     else:
    #         print("Invalid input. Please enter 'y' or 'n'.")

    os.system(f"rm {output_dir}/*")

    bm: WorkflowBenchmark = WorkflowBenchmark(recipe, num_of_tasks)
    result_path: Path = bm.create_benchmark_from_synthetic_workflow(
        output_dir, wf, cpu_work=cpu_work, percent_cpu=0.8, mem=15 * 1024)
    translate(result_path, output_dir, cluster)


def translate(result_path, output_dir, cluster) -> None:
    nextflow = NextflowTranslator(result_path)
    output_file_path = output_dir.joinpath("main.nf")
    nextflow.translate(output_file_path)
    if not cluster:
        with open(output_file_path, "r") as f:
            content = f.read()
        content = content.replace(
            "wfbench.py", "/home/friedrich/SHK-Leser/wfcommons/wfcommons/wfbench/wfbench.py")
        with open(output_file_path, "w") as f:
            f.write(content)


TEST_WORKFLOW: bool = False
ONLY_TEST_WORKFLOW: bool = True


def main() -> None:
    # TEST
    if TEST_WORKFLOW or ONLY_TEST_WORKFLOW:
        create(idx=4, num_of_tasks=1500, cpu_work=5000, infile_size_factor=7, outfile_size_factor=2.8, random_state=0)
        if ONLY_TEST_WORKFLOW:
            return
    # BlastRecipe
    create(idx=0, num_of_tasks=400, cpu_work=5000, infile_size_factor=0.003, outfile_size_factor=26000, random_state=0)
    # BwaRecipe
    create(idx=1, num_of_tasks=1200, cpu_work=5000, infile_size_factor=1400, outfile_size_factor=1800, random_state=0)
    # CyclesRecipe
    create(idx=2, num_of_tasks=700, cpu_work=5000, infile_size_factor=14, outfile_size_factor=50, random_state=1)
    # GenomeRecipe
    create(idx=3, num_of_tasks=700, cpu_work=5000, infile_size_factor=0.015, outfile_size_factor=900, random_state=0)
    # MontageRecipe - 2500, 1, 150, 150
    create(idx=4, num_of_tasks=1350, cpu_work=5000, infile_size_factor=7, outfile_size_factor=2.8, random_state=6)
    # SeismologyRecipe
    create(idx=5, num_of_tasks=400, cpu_work=5000, infile_size_factor=7000, outfile_size_factor=6000, random_state=0)
    # SoykbRecipe
    create(idx=6, num_of_tasks=1700, cpu_work=5000, infile_size_factor=0.005, outfile_size_factor=850, random_state=0)


def la_main() -> None:
    # TEST
    if TEST_WORKFLOW or ONLY_TEST_WORKFLOW:
        create(idx=4, num_of_tasks=70, cpu_work=0, infile_size_factor=130, outfile_size_factor=200)
        if ONLY_TEST_WORKFLOW:
            return
    # BlastRecipe
    create(idx=0, cpu_work=500, infile_size_factor=0.03, outfile_size_factor=260000)
    # BwaRecipe
    create(idx=1, cpu_work=500, infile_size_factor=14000, outfile_size_factor=18000)
    # CyclesRecipe
    create(idx=2, cpu_work=500, infile_size_factor=140, outfile_size_factor=500)
    # GenomeRecipe
    create(idx=3, cpu_work=500, infile_size_factor=0.15, outfile_size_factor=9000)
    # MontageRecipe - 2500, 1, 150, 150
    create(idx=4, cpu_work=500, infile_size_factor=70, outfile_size_factor=28)
    # SeismologyRecipe
    create(idx=5, cpu_work=500, infile_size_factor=70000, outfile_size_factor=60000)
    # SoykbRecipe
    create(idx=6, cpu_work=500, infile_size_factor=0.05, outfile_size_factor=8500)


if __name__ == "__main__":
    main()
