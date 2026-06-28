cmake_minimum_required(VERSION 3.17)
project(GitBuildInfo VERSION 0.1.1 LANGUAGES NONE)

include(cmake/GitBuildInfo.cmake)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  option(GIT_BUILD_INFO_BUILD_EXAMPLES "Build GitBuildInfo examples" ON)
  if(GIT_BUILD_INFO_BUILD_EXAMPLES)
    enable_testing()
    add_subdirectory(examples)
  endif()
endif()
