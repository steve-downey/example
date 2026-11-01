include_guard(GLOBAL)

include("${CMAKE_CURRENT_LIST_DIR}/clang-flags.cmake")

set(LLVM_ROOT "$ENV{LLVM_ROOT}" CACHE PATH "Path to LLVM installation")

set(CMAKE_C_COMPILER ${LLVM_ROOT}/bin/clang)
set(CMAKE_CXX_COMPILER ${LLVM_ROOT}/bin/clang++)

# Build against that LLVM's own libc++, on C++20 rather than the gnu++26 that
# clang-flags.cmake selects, and find the library at run time.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_FLAGS
    "-std=c++20 -Wall -Wextra -stdlib=libc++"
    CACHE STRING
    "CXX_FLAGS"
    FORCE
)
set(CMAKE_EXE_LINKER_FLAGS
    "-Wl,-rpath,${LLVM_ROOT}/lib"
    CACHE STRING
    "CMAKE_EXE_LINKER_FLAGS"
    FORCE
)
