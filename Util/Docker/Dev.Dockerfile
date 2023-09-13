FROM ubuntu:20.04

USER root

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update ; \
    apt-get install -y wget software-properties-common && \
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key|apt-key add - && \
    apt-add-repository "deb http://apt.llvm.org/focal/ llvm-toolchain-focal main" && \
    apt-get update
  
RUN apt-get install -y build-essential \
    clang-10 \
    lld-10 \
    g++-7 \
    cmake \
    ninja-build \
    libvulkan1 \
    python3-dev \
    python3-pip \
    python-is-python3 \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    tzdata \
    sed \
    curl \
    unzip \
    autoconf \
    libtool \
    rsync \
    libxml2-dev \
    git \
    aria2 && \
    pip3 install -Iv setuptools==47.3.1 && \
    pip3 install distro

RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/lib/llvm-10/bin/clang++ 180 && \
    update-alternatives --install /usr/bin/clang clang /usr/lib/llvm-10/bin/clang 180

RUN apt-key adv --fetch-keys "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y libsdl2-2.0 xserver-xorg libvulkan1 libomp5 --no-install-recommends
RUN apt-get install -y gdb vim python3-tk blender openscad fontconfig && fc-cache -f -v

# Enable CUDA support for NVIDIA GPUs (even when not using a CUDA base image), since evidently some versions of UE unconditionally assume
# `libcuda.so.1` exists when using the NVIDIA proprietary drivers, and will fail to initialise the Vulkan RHI if it is missing
ENV NVIDIA_DRIVER_CAPABILITIES ${NVIDIA_DRIVER_CAPABILITIES},compute

# Add the "display" driver capability for NVIDIA GPUs
# (This allows us to run the Editor from an interactive container by bind-mounting the host system's X11 socket)
ENV NVIDIA_DRIVER_CAPABILITIES ${NVIDIA_DRIVER_CAPABILITIES},display

# Enable NVENC support for use by Unreal Engine plugins that depend on it (e.g. Pixel Streaming)
# (Note that adding `video` seems to implicitly enable `compute` as well, but we include separate directives here to clearly indicate the purpose of both)
ENV NVIDIA_DRIVER_CAPABILITIES ${NVIDIA_DRIVER_CAPABILITIES},video

# Install our build prerequisites
RUN apt-get install -y --no-install-recommends \
		build-essential \
		ca-certificates \
		curl \
		git \
		git-lfs \
		python3 \
		python3-dev \
		python3-pip \
		shared-mime-info \
		software-properties-common \
		sudo \
		tzdata \
		unzip \
		xdg-user-dirs \
		zip

# Install the X11 runtime libraries required by CEF so we can cook Unreal Engine projects that use the WebBrowserWidget plugin
# (Starting in Unreal Engine 5.0, we need these installed before creating an Installed Build to prevent cooking failures related to loading the Quixel Bridge plugin)
RUN apt-get install -y --no-install-recommends \
			libasound2 \
			libatk1.0-0 \
			libatk-bridge2.0-0 \
			libcairo2 \
			libfontconfig1 \
			libfreetype6 \
			libglu1 \
			libnss3 \
			libnspr4 \
			libpango-1.0-0 \
			libpangocairo-1.0-0 \
			libsm6 \
			libxcomposite1 \
			libxcursor1 \
			libxdamage1 \
			libxi6 \
			libxkbcommon-x11-0 \
			libxrandr2 \
			libxrender1 \
			libxss1 \
			libxtst6 \
			libxv1 \
			x11-xkb-utils \
			xauth \
			xfonts-base \
			xkb-data

RUN useradd -m carla
USER carla
ENV UE4_ROOT /home/carla/UE4.26
VOLUME /home/carla/carla /home/carla/UE4.26 /home/carla/Scenic

COPY asound.conf /etc/asound.conf 
COPY container_requirements.txt /home/carla/requirements.txt
WORKDIR /home/carla
RUN pip3 install -r requirements.txt


RUN echo 'export PATH="/home/carla/.local/bin:$PATH"' >> .bashrc && echo "cd ~/carla && ./pip_install.sh && cd ~/carla" >> .bashrc

WORKDIR /home/carla/carla
ENTRYPOINT [ "/bin/bash" ]
