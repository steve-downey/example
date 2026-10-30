include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/gcc-flags.cmake")

set(CMAKE_C_COMPILER gcc-11)
set(CMAKE_CXX_COMPILER g++-11)
set(GCOV_EXECUTABLE "gcov-11" CACHE STRING "GCOV executable" FORCE)

# gcc 11 predates the gnu++23 that gcc-flags.cmake selects; stay on C++20.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_FLAGS "-std=c++20 -Wall -Wextra" CACHE STRING "CXX_FLAGS" FORCE)
