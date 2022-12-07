FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt install -y --no-install-recommends build-essential \
                                           cmake

COPY . /cpp_example

RUN mkdir -p /cpp_example_build && \
    cd /cpp_example_build && \
    cmake -DCMAKE_BUILD_TYPE=Debug /cpp_example && \
    make -j

RUN apt update && apt install gdb -y

CMD ["bash"]
