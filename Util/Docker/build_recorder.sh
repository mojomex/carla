#!/bin/bash

mkdir -p tmp_build
tar --exclude='.git' -czvf tmp_build/scenic.tar.gz -C ../../../Scenic .
# tar -czvf tmp_build/maps.tar.gz -C ../../Unreal/CarlaUE4/Content/Carla/Maps .
newest_carla_archive=$(ls -t ../../Dist | grep '.tar.gz' | head -1)
# cp "../../Dist/$newest_carla_archive" tmp_build/carla.tar.gz
cp ../../run_batch.py tmp_build/run_batch.py
cp ../../run_scenic.sh tmp_build/run_scenic.sh

docker build --progress=plain -t carla_recorder -f Recorder.Dockerfile .
