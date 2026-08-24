// The placeholder translation unit the Targets rules give a target that has nothing of its
// own to compile: a header-only library, a codegen library whose sources appear at build
// time, or a source-less executable. Some toolchains -- MSVC among them -- need one real
// translation unit to emit an archive, and this is it.
//
// Intentionally empty.
