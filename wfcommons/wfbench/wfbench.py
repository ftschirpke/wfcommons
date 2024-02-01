#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Copyright (c) 2021-2023 The WfCommons Team.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

import argparse
import pathlib
import os
import subprocess
import time
import json
import signal
import sys
import pandas as pd
import numpy as np

from io import StringIO

from filelock import FileLock
from typing import List, Optional

this_dir = pathlib.Path(__file__).resolve().parent


def lock_core(path_locked: pathlib.Path,
              path_cores: pathlib.Path) -> int:
    """
    Lock cores in use.

    :param path_locked:
    :type path_locked: pathlib.Path
    :param path_cores:
    :type path_cores: pathlib.Path

    :return:
    :rtype: int
    """
    all_cores = set(range(os.cpu_count()))
    path_locked.touch(exist_ok=True)
    path_cores.touch(exist_ok=True)

    while True:
        with FileLock(path_locked) as lock:
            try:
                lock.acquire()
                taken_cores = {
                    int(line) for line in path_cores.read_text().splitlines() if line.strip()}
                available = all_cores - taken_cores
                if available:
                    core = available.pop()
                    taken_cores.add(core)
                    path_cores.write_text("\n".join(map(str, taken_cores)))
                    return core

                print("All Cores are taken", flush=True)
            finally:
                lock.release()
        time.sleep(1)


def unlock_core(path_locked: pathlib.Path,
                path_cores: pathlib.Path,
                core: int) -> None:
    """
    Unlock cores after execution is done.

    :param path_locked:
    :type path_locked: pathlib.Path
    :param path_cores:
    :type path_cores: pathlib.Path
    :param core:
    :type core: int
    """
    with FileLock(path_locked) as lock:
        lock.acquire()
        try:
            taken_cores = {
                int(line) for line in path_cores.read_text().splitlines()
                if int(line) != core
            }
            path_cores.write_text("\n".join(map(str, taken_cores)))
        finally:
            lock.release()


def cpu_mem_benchmark(cpu_threads: Optional[int] = 5,
                      mem_threads: Optional[int] = 5,
                      cpu_work: Optional[int] = 100,
                      core: Optional[int] = None,
                      total_mem: Optional[float] = None) -> List:
    """
    Run cpu and memory benchmark.

    :param cpu_threads:
    :type cpu_threads: Optional[int]
    :param mem_threads:
    :type mem_threads: Optional[int]
    :param cpu_work:
    :type cpu_work: Optional[int]
    :param core:
    :type core: Optional[int]
    :param total_mem:
    :type total_mem: Optional[float]

    :return:
    :rtype: List
    """
    mem_per_thread = total_mem / mem_threads if total_mem else total_mem
    perc = 100.0 / os.cpu_count() if os.cpu_count() else 100.0
    total_mem = f"{mem_per_thread}M" if total_mem else f"{perc}%"
    cpu_work_per_thread = int(cpu_work / cpu_threads)

    cpu_procs = []
    cpu_prog = [
        f"{this_dir.joinpath('cpu-benchmark')}", f"{cpu_work_per_thread}"]
    mem_prog = ["stress-ng", "--vm", f"{mem_threads}",
                "--vm-bytes", f"{total_mem}", "--vm-keep"]

    for i in range(cpu_threads):
        print(f"[WfBench-Debug] Starting CPU Benchmark {i+1}/{cpu_threads}: {cpu_prog}", flush=True)
        cpu_proc = subprocess.Popen(cpu_prog)
        if core:
            os.sched_setaffinity(cpu_proc.pid, {core})
        cpu_procs.append(cpu_proc)
    print("[WfBench-Debug] All CPU Benchmarks started, waiting for them to finish...", flush=True)

    return cpu_procs  # skip mem benchmark for now
    mem_proc = subprocess.Popen(mem_prog)
    if core:
        os.sched_setaffinity(mem_proc.pid, {core})

    return cpu_procs


def get_available_gpus():
    proc = subprocess.Popen(["nvidia-smi", "--query-gpu=utilization.gpu", "--format=csv"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, _ = proc.communicate()
    df = pd.read_csv(StringIO(stdout.decode("utf-8")), sep=" ")
    return df[df["utilization.gpu"] <= 5].index.to_list()


def gpu_benchmark(work, device):
    gpu_prog = [f"CUDA_DEVICE_ORDER=PCI_BUS_ID CUDA_VISIBLE_DEVICES={device} {this_dir.joinpath('gpu-benchmark')} {work}"]
    subprocess.Popen(gpu_prog, shell=True)


def get_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("name", help="Task Name")
    parser.add_argument("--percent-cpu", default=0.5, type=float,
                        help="percentage related to the number of cpu threads.")
    parser.add_argument("--path-lock", default=None, help="Path to lock file.")
    parser.add_argument("--path-cores", default=None,
                        help="Path to cores file.")
    parser.add_argument("--cpu-work", default=None, help="Amount of CPU work.")
    parser.add_argument("--gpu-work", default=None, help="Amount of GPU work.")
    parser.add_argument("--time", default=None, help="Time limit (in seconds) to complete the task (overrides CPU and GPU works)")
    parser.add_argument("--mem", default=None, help="Max amount (in MB) of memory consumption.")
    parser.add_argument("--out", help="output files name.")
    return parser


MAX_BUFFER_SIZE = 102400  # 100KB
FLUSH_SIZE = 10485760  # 10MB


def io_read_benchmark_user_input_data_size(inputs, memory_limit=None):
    if memory_limit is None:
        memory_limit = MAX_BUFFER_SIZE
    else:
        memory_limit = min(memory_limit, MAX_BUFFER_SIZE)
    print("[WfBench] Starting IO Read Benchmark...", flush=True)
    buffer = bytearray(memory_limit)
    for file in inputs:
        with open(file, "rb") as fp:
            print(f"[WfBench]   Reading '{file}'", flush=True)
            while fp.readinto(buffer):
                pass
    print("[WfBench] Completed IO Read Benchmark!\n", flush=True)


def io_write_benchmark_user_input_data_size(outputs, memory_limit=None):
    if memory_limit is None:
        memory_limit = MAX_BUFFER_SIZE
    else:
        memory_limit = min(memory_limit, MAX_BUFFER_SIZE)
    for file_name, file_size in outputs.items():
        print(f"[WfBench] Writing output file '{file_name}'\n", flush=True)
        file_size_todo = file_size
        with open(file_name, "wb", buffering=memory_limit) as fp:
            written = 0
            while file_size_todo > 0:
                chunk_size = min(file_size_todo, memory_limit)
                buffer = np.random.randint(0, 255, chunk_size, dtype=np.uint8)
                w = fp.write(buffer)
                file_size_todo -= w
                written += w
                if written > FLUSH_SIZE:
                    # force os to flush, otherwise memory consumption will be too high
                    os.fsync(fp.fileno())
                    written = 0
        print(f"[WfBench-Debug] Successfully wrote output file '{file_name}'\n", flush=True)


def main():
    """Main program."""
    parser = get_parser()
    args, other = parser.parse_known_args()

    core = None
    if args.path_lock and args.path_cores:
        path_locked = pathlib.Path(args.path_lock)
        path_cores = pathlib.Path(args.path_cores)
        core = lock_core(path_locked, path_cores)

    print(f"[WfBench] Starting {args.name} Benchmark\n", flush=True)

    if args.mem:
        args.mem = int(args.mem) / 2 if args.mem else None
    mem_bytes = int(args.mem) * 1024 * 1024 if args.mem else None

    if args.out:
        io_read_benchmark_user_input_data_size(other, memory_limit=mem_bytes)

    if args.gpu_work:
        print("[WfBench] Starting GPU Benchmark...", flush=True)
        available_gpus = get_available_gpus()  # checking for available GPUs

        if not available_gpus:
            print("No GPU available", flush=True)
        else:
            device = available_gpus[0]
            print(f"Running on GPU {device}", flush=True)
            gpu_benchmark(args.gpu_work, device, time=args.time)

    if args.cpu_work:
        print("[WfBench] Starting CPU and Memory Benchmarks...", flush=True)
        if core:
            print(f"[WfBench]  {args.name} acquired core {core}", flush=True)

        threads = int(10 * max(args.percent_cpu, 0.1))

        cpu_procs = cpu_mem_benchmark(cpu_threads=threads,
                                      mem_threads=threads,
                                      cpu_work=sys.maxsize if args.time else int(args.cpu_work),
                                      core=core,
                                      total_mem=args.mem / 4 if args.mem else None)

        if args.time:
            time.sleep(int(args.time))
            for proc in cpu_procs:
                os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        else:
            for proc in cpu_procs:
                proc.wait()

        # mem_kill = subprocess.Popen(["killall", "stress-ng"])
        # mem_kill.wait()
        print("[WfBench] Completed CPU Benchmarks!\n", flush=True)

    if args.out:
        outputs = json.loads(args.out.replace("'", '"'))
        io_write_benchmark_user_input_data_size(outputs, memory_limit=mem_bytes)
        print("[WfBench-Debug] Completed IO Write Benchmark!\n", flush=True)

    if core:
        print("[WfBench-Debug] Unlocking core", flush=True)
        unlock_core(path_locked, path_cores, core)

    print("WfBench Benchmark completed!", flush=True)


if __name__ == "__main__":
    main()
