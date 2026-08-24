#pragma once

// Fixture header for the header-only library the test beside this file declares. Its
// presence (HEADERS with no SOURCES) is what leaves that library with no translation unit
// of its own, so it must be given the shipped placeholder.
inline int header_only_answer() { return 42; }
