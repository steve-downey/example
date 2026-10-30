include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/gcc-flags.cmake")

set(CMAKE_C_COMPILER gcc-10)
set(CMAKE_CXX_COMPILER g++-10)
set(GCOV_EXECUTABLE "gcov-10" CACHE STRING "GCOV executable" FORCE)

# gcc 10 predates the gnu++23 that gcc-flags.cmake selects; stay on C++20.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_FLAGS "-std=c++20 -Wall -Wextra" CACHE STRING "CXX_FLAGS" FORCE)
