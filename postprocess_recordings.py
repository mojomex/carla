#!/usr/bin/python3

import time
from tqdm.contrib.concurrent import process_map
import os
import sys
import pandas
import numpy as np
import subprocess
from termcolor import colored
from PIL import Image
import PIL

ROOT = "/media/maximilianschmeller/CARLA/recordings"
SEQ_LEN = 20
IMG_H = IMG_W = 224

EXPECTED_IN_IMG_SIZE = (IMG_W * 2 + IMG_H // 3, IMG_H)


def process(path):
    print(f"{path}: Started processing")

    # If directory is still fresh, the simulation might still be in progress, back off
    if os.path.getmtime(path) >= time.time() - 30:
        print(f"{path}:  ", "Simulation maybe still in progress, re-queueing")
        return

    frame_fns = sorted([f for f in os.listdir(path) if f.endswith(".png")])
    if not frame_fns:
        print(f"{path}:  ", colored("Empty, skipping", "yellow"))
        return

    t_start = time.time()

    out_filename = frame_fns[0][len("0000_") : -len("_OOO_.png")] + ".mp4"
    if not os.path.isfile(os.path.join(path, out_filename)):
        ffmpeg_error = subprocess.run(
            [
                "ffmpeg",
                "-pattern_type",
                "glob",
                "-y",
                "-i",
                os.path.join(path, "*.png"),
                "-c:v",
                "libx264",
                "-vf",
                "fps=30,format=yuv420p",
                os.path.join(path, out_filename),
            ],
            stderr=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
        ).returncode

        print(f"{path}:  ", f"ffmpeg took {time.time() - t_start:.2f} seconds")

        if ffmpeg_error:
            print(
                f"{path}:  ",
                colored(f"ffmpeg failed (exit code {ffmpeg_error})", "red"),
            )

    # [:-1]: skip ".png"
    frame_records = [(*f.split("_")[:-1], f) for f in frame_fns]
    frame_records = [
        (int(frame), vehicle, weather, sem_state, cur_state, filename)
        for frame, vehicle, weather, sem_state, cur_state, filename in frame_records
    ]
    df = pandas.DataFrame(
        frame_records,
        columns=["frame", "vehicle", "weather", "sem_state", "cur_state", "filename"],
    )
    df["frame"] = df["frame"].astype(int)
    df = df.set_index("frame")
    df.sort_index(inplace=True)

    # Constant over whole sequence, save for generating output filenames
    vehicle = df.iloc[0]["vehicle"]
    weather = df.iloc[0]["weather"]

    # Extract sequences such that
    # * each sequence is contiguous (no skipped frames)
    # * each sequence is SEQ_LEN long
    # * sem_state is rewritten to off for the first n start frames if their cur_state is off

    start_frame = df.index[0]
    stop = df.index[-1] + 1
    while start_frame <= stop - SEQ_LEN:
        t_start = time.time()

        df_seq = df[start_frame : start_frame + SEQ_LEN]
        if len(df_seq) < SEQ_LEN:
            # There are one or more frames missing in the sequence, skip to frame after last skip (if any)
            if len(df_seq) <= 1:
                n_skip = SEQ_LEN
            else:
                n_skip = df_seq.index[-1] - df_seq.index[0]

            start_frame += n_skip
            print(f"{path}:  ", colored(f"skipped {n_skip} frames", "yellow"))
            continue

        # {previous, semantic, current}{brake, left right} --> {p, s, c}{b, l, r}
        prev_state = "OOO"
        out_states = []
        for sem_state, cur_state in zip(df_seq["sem_state"], df_seq["cur_state"]):
            out_state = ""
            for p, s, c in zip(prev_state, sem_state, cur_state):
                # If recorded state is unknown, label semantic state as unknown
                if c == "U":
                    out_state += "U"
                    continue

                # If recorded state is off and the previous state was off/unknown,
                # there is no way to know that the semantic state should be on
                # (Think of a turn signal which you start observing in its OFF phase,
                #  you cannot know it is on until it reaches its ON phase)
                if c == "O" and p in "OU":
                    out_state += "O"
                    continue

                # Otherwise, keep the given semantic label
                out_state += s
            prev_state = out_state
            out_states.append(out_state)

        assert (
            len(df_seq) == SEQ_LEN
        ), f"Expected extracted dataframe to have length {SEQ_LEN}, has {len(df_seq)} ({start_frame=} {stop=} {n_skip=})"
        df_seq = df_seq.copy()
        df_seq["sem_state"] = out_states

        img_data = np.empty((SEQ_LEN, 3, IMG_H, IMG_W), dtype=np.uint8)

        success = True
        for i, filename in enumerate(df_seq["filename"]):
            try:
                im = Image.open(os.path.join(path, filename))
            except (PIL.UnidentifiedImageError, FileNotFoundError) as e:
                print(
                    f"{path}:  ",
                    colored(f"Could not open image {filename}: {e}", "red"),
                )
                start_frame += i + 1
                success = False
                break

            assert (
                im.size == EXPECTED_IN_IMG_SIZE
            ), f"Expected image of size {EXPECTED_IN_IMG_SIZE}, got {im.size}"

            # Extract only camera image (crop out sem.seg. and brake/blinker icons)
            im = im.crop((0, 0, IMG_W, IMG_H))
            im = np.asarray(im)
            assert im.shape == (
                IMG_W,
                IMG_H,
                3,
            ), f"Expected array of size {IMG_W, IMG_H, 3}, got {im.shape}"

            # Move color axis from last to 0th dimension
            im = np.moveaxis(im, -1, 0)
            img_data[i] = im

        if not success:
            continue

        print(
            f"{path}:  ",
            f"sequence at {start_frame} took {time.time() - t_start:.2f} seconds",
        )
        t_start = time.time()

        np.save(
            os.path.join(path, f"frames_{vehicle}_{weather}_{start_frame}.npy"),
            img_data,
        )
        df_seq.to_hdf(
            os.path.join(path, f"labels_{vehicle}_{weather}_{start_frame}.h5"),
            key="labels",
        )
        start_frame += SEQ_LEN

        print(
            f"{path}:  ",
            f"saving seq. {start_frame} took {time.time() - t_start:.2f} seconds",
        )

    with open(os.path.join(path, ".processed"), "w"):
        pass


def main():
    should_stop = False

    while not should_stop:
        try:
            paths = [os.path.join(ROOT, recording) for recording in os.listdir(ROOT)]
            paths = [
                p
                for p in paths
                if os.path.isdir(p)
                and not os.path.isfile(os.path.join(p, ".processed"))
            ]

            process_map(
                process, paths, max_workers=os.cpu_count(), desc="Processing runs"
            )

        except KeyboardInterrupt:
            print("Interrupted, exiting")
            sys.exit(0)


main()
