#!/bin/bash
scenic_path='/home/carla/Scenic'
pip3 install -q "$scenic_path/" && scenic "$scenic_path/scenarios/TailLights.scenic" --simulate --2d --time 150
