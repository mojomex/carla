#!/bin/bash

if [ -z "$1" ] 
then
  echo "Usage: $0 <scenic_path>"
fi

scenic_path=$1
scenic "$scenic_path/scenarios/TailLights.scenic" --simulate --2d --time 160
