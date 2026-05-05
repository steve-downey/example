// testinstall/test.cpp                                               -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include <iostream>
#include <[[ include_prefix ]]/[[ namespace ]]/[[ library_name ]].hpp>

int main() {
    std::cout << "[[ library_name ]]: |" << [[ namespace ]]::[[ library_name ]]() << '|' << '\n';
    return 0;
}
