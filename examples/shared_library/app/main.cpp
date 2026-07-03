// Consumer of the Greeter SHARED library.
//
// Linking this executable proves symbol export works (on MSVC the import library must be
// populated by GREETER_EXPORT), and running it proves DLL staging works: Greeter.dll is
// copied next to GreeterApp.exe after the build, so the process can start. CI runs this
// executable on windows-latest; a non-zero exit fails the job.
#include <iostream>
#include <string>

#include "greeter/greeter.h"

int main() {
  const std::string message = greeter::greeting();
  std::cout << message << std::endl;
  if (message.empty()) {
    std::cerr << "greeting() returned an empty string\n";
    return 1;
  }
  return 0;
}
