// Public header for the Widget library. Installed to
// <prefix>/include/widget/widget.h by cpp_library(... INSTALL ...), so a downstream
// consumer can #include "widget/widget.h" after find_package(WidgetKit).
#pragma once

#include <string>

namespace widget {

// Returns a short greeting identifying the installed, exported library.
std::string widget_greeting();

// A trivial value used by the consume test to prove the linked code actually runs.
int widget_answer();

}  // namespace widget
