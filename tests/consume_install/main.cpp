// Downstream consumer of the installed, exported WidgetKit::Widget library.
//
// It includes the installed public header and links the exported target resolved purely by
// find_package(WidgetKit) — with no knowledge of Targets. Proves the install/export flow
// end to end (issue #20): a non-zero exit fails the CI install-export job.
#include <iostream>

#include "widget/widget.h"

int main() {
  std::cout << widget::widget_greeting() << "\n";
  if (widget::widget_answer() != 42) {
    std::cerr << "widget_answer() returned the wrong value\n";
    return 1;
  }
  return 0;
}
