#!/bin/bash

# md5sum /path/to/your/file: Computes the MD5 hash of the file.
# awk '{print $1}': Filters out only the hash part from the md5sum output.
# xxd -r -p: Converts the hexadecimal hash into binary.
# base64: Encodes the binary hash in base64 format.
md5sum /path/to/your/file | awk '{print $1}' | xxd -r -p | base64
