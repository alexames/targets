// Downstream consumer of the installed, exported WidgetKit libraries.
//
// It includes the installed public headers and links the exported targets resolved purely by
// find_package(WidgetKit) — with no knowledge of Targets. Proves the install/export flow
// end to end (issue #20) for a compiled library and for one whose only translation unit is
// the shipped placeholder: a non-zero exit fails the CI install-export job.
#include <iostream>

#include "widget/widget.h"
#include "widget/widget_traits.h"

int main() {
  std::cout << widget::widget_greeting() << "\n";
  if (widget::widget_answer() != 42) {
    std::cerr << "widget_answer() returned the wrong value\n";
    return 1;
  }
  if (widget::widget_perimeter(3) != 21) {
    std::cerr << "widget_perimeter() returned the wrong value\n";
    return 1;
  }
  return 0;
}
