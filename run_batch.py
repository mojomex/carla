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
import carla

parser = argparse.ArgumentParser()
parser.add_argument(
    "--carla-root",
    default="/home/carla/carla",
    help="The path to the root folder of the CARLA installation (contains Dist folder)",
)
parser.add_argument(
    "--scenic-root",
    default="/home/carla/Scenic",
    help="The path to the root folder of the Scenic installation (contains scenarios folder)",
)
parser.add_argument(
    "--output-dir",
    default="/home/carla/recordings",
    help="The path to the output folder of the simulation",
)


args = parser.parse_args()


def get_carla_executable_path():
    dist_dir = join(args.carla_root, "Dist")
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
        proc = subprocess.Popen(
            [carla_executable, "-quality-level=Epic", "-RenderOffScreen"]
        )
        for i in range(30):
            print(f"Waiting for CARLA... ({(i+1) * 2}/60)")
            try:
                client = carla.Client("127.0.0.1", 2000)
                client.set_timeout(2)
                client.get_server_version()
                print(f"CARLA ready.")
                return proc
            except RuntimeError as e:
                if not "time-out" in str(e):
                    raise e

        print("Could not connect to CARLA within 60s, returning dead process")
        return subprocess.Popen(["/usr/bin/false"])

    def get_scenic_proc():
        return subprocess.Popen(
            ["/bin/sh", join(args.carla_root, "run_scenic.sh"), args.scenic_root],
            stderr=subprocess.DEVNULL,
        )

    def stop_all(procs: List[subprocess.Popen]):
        print("Stopping all processes")
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

        subprocess.run(
            ["ps -aux | grep 'run_scenic.sh' | awk '{print $2}' | xargs kill -s 9"],
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        subprocess.run(
            ["ps -aux | grep 'bin/scenic' | awk '{print $2}' | xargs kill -s 9"],
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        subprocess.run(
            ["ps -aux | grep CarlaUE4 | awk '{print $2}' | xargs kill -s 9"],
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        print("Stopped all processes")

    def start_all():
        print("Starting all processes")
        carla_proc = get_carla_proc()
        scenic_proc = get_scenic_proc()
        print("Started all processes")
        return (carla_proc, scenic_proc), time.time()

    procs, t_started = start_all()

    while True:
        try:
            time.sleep(1)
            if (
                t_started < time.time() - 120
                and os.path.getmtime(args.output_dir) < time.time() - 120
            ):
                print("No data output for 2 min, force-restarting simulator.")
                stop_all(procs)
                procs, t_started = start_all()

            if any(p.poll() is not None for p in procs):  # a process crashed
                if procs[0].poll() is not None:
                    print("CARLA crashed")
                if procs[1].poll() is not None:
                    print("Scenic crashed")
                stop_all(procs)
                procs, t_started = start_all()
        except KeyboardInterrupt:
            print("User requested exit")
            stop_all(procs)
            sys.exit(0)


main()
