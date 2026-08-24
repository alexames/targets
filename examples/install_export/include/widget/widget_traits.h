// Public header for the WidgetTraits library, which has no translation unit of its own.
// Installed to <prefix>/include/widget/widget_traits.h alongside widget.h, and reached
// through the imported target WidgetKit::WidgetTraits after find_package(WidgetKit).
#pragma once

namespace widget {

// The number of sides a widget has.
constexpr int kWidgetSides = 7;

// Returns the perimeter of a regular widget with the given side length. Defined here
// because the library exporting this header compiles nothing of its own.
inline int widget_perimeter(int side_length) {
  return kWidgetSides * side_length;
}

}  // namespace widget
