#!/usr/bin/python3

import argparse
import subprocess
import signal
from typing import List
from tqdm import tqdm
import os
import psutil
import sys
import time
from os.path import join

CARLA_ROOT = "/home/carla/carla"
SCENIC_ROOT = "/home/carla/Scenic"


def get_carla_executable_path():
    dist_dir = join(CARLA_ROOT, "Dist")
    carla_versions = [join(dist_dir, f) for f in os.listdir(dist_dir)]
    carla_versions = [f for f in carla_versions if os.path.isdir(f)]
    if not carla_versions:
        return None

    newest_version = sorted(
        carla_versions, key=lambda f: os.path.getmtime(f), reverse=True
    )[0]
    return join(newest_version, "LinuxNoEditor", "CarlaUE4.sh")


def main():
    carla_executable = get_carla_executable_path()
    if carla_executable is None:
        print("No compiled version of CARLA found, exiting.")
        sys.exit(1)

    def get_carla_proc():
        return subprocess.Popen([carla_executable, "-quality-level=Epic", "-RenderOffScreen"])

    def get_scenic_proc():
        return subprocess.Popen(["/bin/sh", join(CARLA_ROOT, "run_scenic.sh")])

    def stop_all(procs: List[subprocess.Popen]):
        running_procs = procs
        while running_procs:
            stopped_procs = []
            for p in running_procs:
                if p.poll() is not None:  # terminated
                    stopped_procs.append(p)
                    continue
                parent = psutil.Process(p.pid)
                while parent.children(True):
                    for child in parent.children(recursive=True):
                        try:
                            child.send_signal(signal.SIGINT)
                        except psutil.NoSuchProcess:
                            continue
                try:
                    parent.send_signal(signal.SIGINT)
                except psutil.NoSuchProcess:
                    stopped_procs.append(p)
                    continue
            running_procs = [p for p in running_procs if p not in stopped_procs]
            time.sleep(0.5)
        
        subprocess.run(["ps -aux | grep 'run_scenic.sh' | awk '{print $2}' | xargs kill -s 9"], shell=True)
        subprocess.run(["ps -aux | grep 'bin/scenic' | awk '{print $2}' | xargs kill -s 9"], shell=True)
        subprocess.run(["ps -aux | grep CarlaUE4 | awk '{print $2}' | xargs kill -s 9"], shell=True)

    def start_all():
        carla_proc = get_carla_proc()
        time.sleep(5)
        scenic_proc = get_scenic_proc()
        return (carla_proc, scenic_proc)

    procs = start_all()

    while True:
        try:
            if any(p.poll() is not None for p in procs):  # a process crashed
                stop_all(procs)
                procs = start_all()
        except KeyboardInterrupt:
            stop_all(procs)
            sys.exit(0)


main()
