#include <iostream>

#include "greeter.h"
#include "motto.h"

int main() {
  std::cout << greeter::greeting() << std::endl;
  if (motto::lucky_number() != 7) {
    std::cerr << "lucky_number() returned the wrong value" << std::endl;
    return 1;
  }
  return 0;
}
