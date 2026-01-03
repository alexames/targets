#include "mathlib/calculator.h"
#include <iostream>
#include <exception>

int main() {
    using namespace mathlib;

    std::cout << "Calculator Example Application" << std::endl;
    std::cout << "===============================" << std::endl;

    int a = 10;
    int b = 5;

    std::cout << a << " + " << b << " = " << Calculator::add(a, b) << std::endl;
    std::cout << a << " - " << b << " = " << Calculator::subtract(a, b) << std::endl;
    std::cout << a << " * " << b << " = " << Calculator::multiply(a, b) << std::endl;

    try {
        std::cout << a << " / " << b << " = " << Calculator::divide(a, b) << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
    }

    return 0;
}
