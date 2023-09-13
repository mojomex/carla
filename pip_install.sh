#!/usr/bin/bash

echo "Updating Carla client"
CC=clang-10 CXX=clang++-10 pip3 install -q PythonAPI/carla
echo "Updating Scenic"
pip3 install -q ../Scenic
