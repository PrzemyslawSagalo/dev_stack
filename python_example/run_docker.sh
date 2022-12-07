#!/bin/bash

docker run --rm \
	   --name 'python_example' \
	   -it \
	   --platform linux/x86_64 \
	   -v "$(pwd)":/python_example \
           python_example:latest
