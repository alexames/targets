#pragma once

// Fixture header for the header-only INTERFACE library exercised by the issue #7
// regression test. Its mere presence (HEADERS with no SOURCES) must produce an INTERFACE
// library, never a STATIC library carrying dummy.cpp.
inline int header_only_answer() { return 42; }
