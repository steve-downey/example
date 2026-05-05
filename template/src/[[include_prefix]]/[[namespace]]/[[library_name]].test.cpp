// [[ namespace ]]/[[ library_name ]].test.cpp                        -*-C++-*-
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#include <[[ include_prefix ]]/[[ namespace ]]/[[ library_name ]].hpp>

#include <[[ include_prefix ]]/[[ namespace ]]/[[ library_name ]].hpp> // test 2nd include OK

#include <gtest/gtest.h>

TEST(Test, Fail) { SUCCEED(); }

// 03013d1f-bcc1-4d3e-9701-3ed1a15c6370
TEST(TestName, [[ sample_value ]]) { ASSERT_EQ([[ namespace ]]::[[ library_name ]](), "[[ sample_value ]]"); }
// 03013d1f-bcc1-4d3e-9701-3ed1a15c6370 end
