// Example consumer of a protobuf_cpp_library target.
//
// Populates a generated message, serializes it, parses it back, and verifies the round trip
// -- the "links a small consumer that round-trips a message" check from issue #26.

#include <iostream>
#include <string>

#include "addressbook.pb.h"

int main() {
  GOOGLE_PROTOBUF_VERIFY_VERSION;

  tutorial::AddressBook book;
  tutorial::Person* person = book.add_people();
  person->set_id(42);
  person->set_name("Ada Lovelace");
  person->set_email("ada@example.com");

  std::string bytes;
  if (!book.SerializeToString(&bytes)) {
    std::cerr << "Failed to serialize AddressBook\n";
    return 1;
  }

  tutorial::AddressBook parsed;
  if (!parsed.ParseFromString(bytes)) {
    std::cerr << "Failed to parse AddressBook\n";
    return 1;
  }

  const tutorial::Person& round_tripped = parsed.people(0);
  std::cout << "Round-tripped person: id=" << round_tripped.id()
            << " name=" << round_tripped.name()
            << " email=" << round_tripped.email() << "\n";

  const bool ok = round_tripped.id() == 42 &&
                  round_tripped.name() == "Ada Lovelace" &&
                  round_tripped.email() == "ada@example.com";

  google::protobuf::ShutdownProtobufLibrary();
  return ok ? 0 : 1;
}
