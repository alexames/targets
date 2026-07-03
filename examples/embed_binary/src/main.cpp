// Example: reads a data file that was embedded at configure time by embed_binary().
//
// embed_binary(TARGET EmbeddedAssets FILES assets/message.txt NAMESPACE embedded_assets)
// generates "message_txt.h" (put on the target's public include path) exposing the
// file's bytes as message_txt_data / message_txt_size.

#include <cstddef>
#include <iostream>
#include <ostream>

#include "message_txt.h"

int main() {
  std::cout.write(
      reinterpret_cast<const char*>(embedded_assets::message_txt_data),
      static_cast<std::streamsize>(embedded_assets::message_txt_size));
  std::cout << "(" << embedded_assets::message_txt_size << " embedded bytes)"
            << std::endl;
  return 0;
}
