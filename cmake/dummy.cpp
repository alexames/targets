// The placeholder translation unit the Targets rules give a target that has nothing of its
// own to compile: a header-only library, a codegen library whose sources appear at build
// time, or a source-less executable. MSVC will not archive a static library with no object
// file, so this file supplies one.
//
// Intentionally empty.
