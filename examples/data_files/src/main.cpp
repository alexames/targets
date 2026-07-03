// Reads a runtime data file staged next to this executable by the DATA attribute (issue #27).
// The file is opened with a bare relative name, so it is found only if it was copied into the
// program's own directory. Run this from the executable's output directory.

#include <fstream>
#include <iostream>
#include <string>

int main() {
  std::ifstream in("message.txt");
  if (!in) {
    std::cerr << "DataApp: could not open staged data file 'message.txt' "
                 "(DATA staging failed)\n";
    return 1;
  }

  std::string line;
  std::getline(in, line);
  std::cout << "DataApp: staged data says: " << line << "\n";
  return 0;
}
