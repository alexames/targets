// In-tree header fixture for the cpp_target source_group regression test (issue #6).
// It lives under the target's HEADER_DIR, so it must be routed through
// source_group(TREE ...) rather than the flat "Generated Files" group.
#pragma once
int in_tree();
