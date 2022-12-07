cmake_minimum_required(VERSION 3.0.0)

project(molbiolib)

SET(VERSION_MAJOR "1")
SET(VERSION_MINOR "0")
SET(VERSION_PATCH "0")
SET(VERSION "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

set(COMPILER_FLAGS "--std=c++17")
set(COMPILER_RELEASE_FLAGS "-O3")
set(CMAKE_CXX_FLAGS "-pthread -pg") # TODO: remove -pg for prod

add_executable(main_exec main.cpp)

