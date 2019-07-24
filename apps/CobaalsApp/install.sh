#!/bin/bash

make telosb

argv=("$@")

for ((i=0; i<$#; i++))
do
	sudo make telosb reinstall,${argv[i]} bsl,/dev/ttyUSB$i
done
