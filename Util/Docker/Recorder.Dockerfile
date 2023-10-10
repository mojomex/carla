FROM ubuntu:20.04

USER root

ENV NVIDIA_DRIVER_CAPABILITIES ${NVIDIA_DRIVER_CAPABILITIES},compute
ENV NVIDIA_DRIVER_CAPABILITIES ${NVIDIA_DRIVER_CAPABILITIES},display
ENV NVIDIA_DRIVER_CAPABILITIES ${NVIDIA_DRIVER_CAPABILITIES},video

ENV DEBIAN_FRONTEND=noninteractive
ENV CARLA_ROOT=/home/carla/carla/Dist/CARLA_Shipping_latest/LinuxNoEditor

RUN apt-get update && \
    apt-get install -y wget software-properties-common && \
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key|apt-key add - && \
    apt-add-repository "deb http://apt.llvm.org/focal/ llvm-toolchain-focal main" && \
    apt-get update && \
		apt-get install -y build-essential \
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
    pip3 install distro && \
		update-alternatives --install /usr/bin/clang++ clang++ /usr/lib/llvm-10/bin/clang++ 180 && \
    update-alternatives --install /usr/bin/clang clang /usr/lib/llvm-10/bin/clang 180 && \
		apt-key adv --fetch-keys "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub" && \
		apt-get update && \
		apt-get install -y --no-install-recommends libsdl2-2.0 xserver-xorg libvulkan1 libomp5 && \
    apt-get install -y gdb vim python3-tk blender openscad fontconfig && \
	  fc-cache -f -v && \
		apt-get install -y --no-install-recommends \
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
		zip \
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
		xkb-data && \
		addgroup --gid 1024 carla && \
		useradd -m --gid 1024 carla && \
	  mkdir -p "$CARLA_ROOT"

VOLUME /home/carla/recordings
RUN chown -R carla:carla /home/carla/

USER carla

COPY --chown=carla:carla asound.conf /etc/asound.conf 
COPY --chown=carla:carla container_requirements.txt /home/carla/carla/requirements.txt

ADD --chown=carla:carla tmp_build/carla.tar.gz "$CARLA_ROOT"
COPY --chown=carla:carla tmp_build/run_batch.py /home/carla/carla/run_batch.py
COPY --chown=carla:carla tmp_build/run_scenic.sh /home/carla/carla/run_scenic.sh

ADD --chown=carla:carla tmp_build/scenic.tar.gz /home/carla/Scenic
WORKDIR /home/carla
RUN pip3 install -r carla/requirements.txt
RUN CC=clang-10 CXX=clang++-10 pip3 install "$CARLA_ROOT/PythonAPI/carla/dist/carla-0.9.14-cp38-cp38-linux_x86_64.whl" && \
	pip3 install ./Scenic && \
	echo 'export PATH="/home/carla/.local/bin:$PATH"' >> .bashrc && \
	echo "cd ~/carla" >> .bashrc && \
	chmod +x carla/run_batch.py && \
	mkdir -p /home/carla/carla/Unreal/CarlaUE4/Content/Carla/Maps/

ADD --chown=carla:carla tmp_build/maps.tar.gz /home/carla/carla/Unreal/CarlaUE4/Content/Carla/Maps/

WORKDIR /home/carla/carla
ENTRYPOINT [ "/bin/bash" ]
#ENTRYPOINT [ "/home/carla/carla/run_batch.py" ]
