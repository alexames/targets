#include <shared_dep.hpp>

int cached_value() { return shared_dep_value() + 1; }
