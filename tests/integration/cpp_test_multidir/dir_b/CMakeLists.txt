# Second sibling directory: acquisition already ran in dir_a, so this cpp_test() hits the
# run-once guard and never re-acquires GTest. It must still resolve GTest::gtest_main; before
# the fix that target was scoped to dir_a and generation failed here.
cpp_test(TARGET SecondTest SOURCES second_test.cpp)
