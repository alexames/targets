# First sibling directory: its cpp_test() triggers the one-time Google Test acquisition
# (find_package(GTest) via the fake FindGTest on CMAKE_MODULE_PATH).
cpp_test(TARGET FirstTest SOURCES first_test.cpp)
