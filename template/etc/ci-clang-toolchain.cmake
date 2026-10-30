include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/clang-flags.cmake")

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

# The CI image's clang builds against libc++ with its experimental library, on C++20
# rather than the gnu++26 that clang-flags.cmake selects.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_FLAGS
    "-std=c++20 -Wall -Wextra -stdlib=libc++ -fexperimental-library"
    CACHE STRING
    "CXX_FLAGS"
    FORCE
)
