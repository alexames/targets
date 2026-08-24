#ifndef CONSUME_PORT_MOTTO_H
#define CONSUME_PORT_MOTTO_H

namespace motto {

// The library exporting this header compiles nothing of its own, so the definition lives
// here and the archive it builds holds only the shipped placeholder translation unit.
inline int lucky_number() {
  return 7;
}

}  // namespace motto

#endif  // CONSUME_PORT_MOTTO_H
