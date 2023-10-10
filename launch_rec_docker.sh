#!/usr/bin/bash

sudo addgroup --gid 1024 carla
sudo usermod -a -G carla "$USER"

RECORDING_DIR="/media/disk2tb/max/recordings"
mkdir -p $RECORDING_DIR
sudo chown -R "$USER:carla" "$RECORDING_DIR"
chmod g+rwx "$RECORDING_DIR"

docker run --rm --privileged --runtime=nvidia --gpus all --net=host --device=/dev/dri:/dev/dri \
	-v "$RECORDING_DIR:/home/carla/recordings" \
	-it \
	carla_recorder
