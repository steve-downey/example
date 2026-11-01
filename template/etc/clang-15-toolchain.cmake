include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/clang-flags.cmake")

set(CMAKE_C_COMPILER clang-15)
set(CMAKE_CXX_COMPILER clang++-15)

# clang 15 predates the gnu++26 that clang-flags.cmake selects; stay on C++20,
# and on libc++ as before.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_FLAGS
    "-std=c++20 -Wall -Wextra -stdlib=libc++"
    CACHE STRING
    "CXX_FLAGS"
    FORCE
)
