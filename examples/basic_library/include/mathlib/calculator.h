#ifndef MATHLIB_CALCULATOR_H
#define MATHLIB_CALCULATOR_H

namespace mathlib {

class Calculator {
public:
    static int add(int a, int b);
    static int subtract(int a, int b);
    static int multiply(int a, int b);
    static double divide(int a, int b);
};

} // namespace mathlib

#endif // MATHLIB_CALCULATOR_H
