#!/usr/bin/bash

mkdir -p docker_cache/shaders
# docker run --rm -it  --gpus all  -e DISPLAY -e TERM   -e QT_X11_NO_MITSHM=1   -e XAUTHORITY=/tmp/.dockerxwl5d_ch.xauth -v /tmp/.dockerxwl5d_ch.xauth:/tmp/.dockerxwl5d_ch.xauth   -v /tmp/.X11-unix:/tmp/.X11-unix   -v /etc/localtime:/etc/localtime:ro  d30ba5868f0e 
docker run --rm --privileged --runtime=nvidia --gpus all --net=host --device=/dev/dri:/dev/dri \
	-e DISPLAY \
	-e QT_X11_NO_MITSHM=1 \
	-e SDL_VIDEODRIVER=x11 \
	-v "$PWD/docker_cache/shaders:/carla/home/.cache/mesa_shader_cache" \
	-v "$PWD/../dataset:/home/carla/dataset" \
	-v "$PWD/../Scenic:/home/carla/Scenic" \
	-v "$PWD:/home/carla/carla" \
	-v "$PWD/../UE4.26:/home/carla/UE4.26" \
	-it \
	carla-dev
