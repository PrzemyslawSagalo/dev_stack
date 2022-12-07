#!/bin/bash

docker run --rm \
	   --name 'cpp_example' \
	   -it \
	   --platform linux/x86_64 \
	   -v "$(pwd)":/cpp_example \
           cpp_example:latest
