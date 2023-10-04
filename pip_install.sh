#!/usr/bin/bash

[ ! -f ~/.skipped_first ] ||
  (echo "Updating Carla client" &&
    CC=clang-10 CXX=clang++-10 pip3 install -q PythonAPI/carla &&
    echo "Updating Scenic" &&
    pip3 install -q ../Scenic &&
    echo "Installing Requirements" &&
    pip3 install -q -r requirements.txt)
touch ~/.skipped_first
