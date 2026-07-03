# toolchain_hygiene.cmake
# Opt-in, per-target toolchain hygiene knobs for cpp_target (issue #23): warning level,
# warnings-as-errors, sanitizers, and link-time optimization.
#
# Everything here is OFF by default. A target gets these flags only when it explicitly opts
# in via cpp_target's WARNINGS / WERROR / SANITIZERS / LTO keywords, so no existing target
# changes behavior. Every flag is compiler-aware -- translated per MSVC / GCC / Clang via
# CXX_COMPILER_ID generator expressions -- and no-ops (or warns) where a toolchain cannot
# honor it. These are compile/link settings, so they apply only to compiled targets; a
# header-only INTERFACE library has no compile step and rejects them upstream (see issue #13).
#
# Each flag is wrapped in its OWN generator expression (rather than a single expression
# expanding to a ';'-list) so that the flags remain distinct list elements in the
# COMPILE_OPTIONS/LINK_OPTIONS properties and every generator expression stays bracket-
# balanced.

include_guard(GLOBAL)

# Validate the WARNINGS level. An empty value (the keyword omitted) is allowed and means
# "inject nothing", identical to "default". RULE names the calling rule for diagnostics.
#
# The accepted levels are defined inside the function (not as a module-scope variable):
# this module uses include_guard(GLOBAL), so its body runs only in the first directory
# scope that includes Targets, and a module-scope set() would be invisible to targets
# declared in other directories. Function bodies are global, so this stays correct
# everywhere.
#   off     -> silence warnings  (/W0 on MSVC, -w on GCC/Clang)
#   default -> inject nothing    (the compiler/CMake default; identical to omitting WARNINGS)
#   strict  -> a high level      (/W4 on MSVC, -Wall -Wextra -Wpedantic on GCC/Clang)
function(_targets_validate_warnings RULE LEVEL)
  if("${LEVEL}" STREQUAL "")
    return()
  endif()
  set(_levels off default strict)
  if(NOT "${LEVEL}" IN_LIST _levels)
    string(REPLACE ";" ", " _levels_pretty "${_levels}")
    message(FATAL_ERROR
      "${RULE}: WARNINGS '${LEVEL}' is not a valid level. Choose one of: ${_levels_pretty}.")
  endif()
endfunction()

# Apply the opt-in hygiene knobs to a single compiled target (never an INTERFACE library).
# Arguments are passed by keyword:
#   TARGET     <name>                 the compiled target to configure (required)
#   WARNINGS   <off|default|strict>   warning level (empty/absent -> inject nothing)
#   WERROR                            treat warnings as errors
#   SANITIZERS <name>...              e.g. address undefined thread
#   LTO                               enable interprocedural optimization when supported
function(_targets_apply_toolchain_hygiene)
  set(options WERROR LTO)
  set(one_value_args TARGET WARNINGS)
  set(multi_value_args SANITIZERS)
  cmake_parse_arguments(PARSE_ARGV 0 h "${options}" "${one_value_args}" "${multi_value_args}")

  # --- Warning level ---------------------------------------------------------------------
  # Flags are gated per-compiler with generator expressions so MSVC-only and GCC/Clang-only
  # forms never leak to the wrong toolchain. "default" (and an omitted WARNINGS) inject
  # nothing, preserving the compiler/CMake default.
  if(h_WARNINGS STREQUAL "strict")
    target_compile_options(${h_TARGET} PRIVATE
      "$<$<CXX_COMPILER_ID:MSVC>:/W4>"
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wall>"
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wextra>"
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Wpedantic>")
  elseif(h_WARNINGS STREQUAL "off")
    target_compile_options(${h_TARGET} PRIVATE
      "$<$<CXX_COMPILER_ID:MSVC>:/W0>"
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-w>")
  endif()

  # --- Warnings as errors ----------------------------------------------------------------
  if(h_WERROR)
    target_compile_options(${h_TARGET} PRIVATE
      "$<$<CXX_COMPILER_ID:MSVC>:/WX>"
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-Werror>")
  endif()

  # --- Sanitizers ------------------------------------------------------------------------
  # GCC/Clang accept a comma-separated sanitizer list and require the SAME flag at COMPILE
  # and LINK time (the flag both instruments code and pulls in the runtime). MSVC provides
  # only AddressSanitizer, as a compile option (its linker links the runtime automatically);
  # every other sanitizer is skipped there with a warning.
  if(h_SANITIZERS)
    string(REPLACE ";" "," _san_csv "${h_SANITIZERS}")
    target_compile_options(${h_TARGET} PRIVATE
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-fsanitize=${_san_csv}>"
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-fno-omit-frame-pointer>")
    target_link_options(${h_TARGET} PRIVATE
      "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-fsanitize=${_san_csv}>")

    if("address" IN_LIST h_SANITIZERS)
      # MSVC AddressSanitizer is incompatible with the Debug runtime checks (/RTC1, part of
      # CMake's default CMAKE_CXX_FLAGS_DEBUG) and with edit-and-continue debug info (/ZI,
      # which this library itself injects in Debug); cl.exe hard-errors (D8016) on those
      # combinations. Gate the flag to non-Debug configurations so an opted-in Debug build
      # is a clean no-op instead of a compile error -- honoring "no-op where unsupported" --
      # while Release / RelWithDebInfo get real ASan. This also means /fsanitize=address and
      # the Debug-only /ZI never coexist.
      target_compile_options(${h_TARGET} PRIVATE
        "$<$<AND:$<CXX_COMPILER_ID:MSVC>,$<NOT:$<CONFIG:Debug>>>:/fsanitize=address>")
    endif()

    # On MSVC, report (once, at configure time) the sanitizers that will not be applied:
    # everything other than address is unsupported, and address itself is limited to
    # non-Debug configurations (see above). CMAKE_CXX_COMPILER_ID is known at configure time,
    # so these diagnostics fire only for an actual MSVC build.
    if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
      set(_unsupported "")
      foreach(_san IN LISTS h_SANITIZERS)
        if(NOT _san STREQUAL "address")
          list(APPEND _unsupported "${_san}")
        endif()
      endforeach()
      if(_unsupported)
        string(REPLACE ";" ", " _unsupported "${_unsupported}")
        message(WARNING
          "cpp_target: '${h_TARGET}' requested sanitizer(s) MSVC does not support: "
          "${_unsupported}. MSVC only provides AddressSanitizer (/fsanitize=address); the "
          "unsupported sanitizer(s) were skipped.")
      endif()
      if("address" IN_LIST h_SANITIZERS)
        message(STATUS
          "cpp_target: '${h_TARGET}' enables MSVC AddressSanitizer for non-Debug "
          "configurations only; Debug is skipped because its runtime checks (/RTC1) are "
          "incompatible with /fsanitize=address. Build Release or RelWithDebInfo for ASan.")
      endif()
    endif()
  endif()

  # --- Link-time optimization (IPO) ------------------------------------------------------
  # Use CMake's INTERPROCEDURAL_OPTIMIZATION target property, gated on check_ipo_supported()
  # so it degrades to a warning where the toolchain cannot do it instead of failing the
  # build.
  if(h_LTO)
    include(CheckIPOSupported)
    check_ipo_supported(RESULT _ipo_ok OUTPUT _ipo_err LANGUAGES CXX)
    if(_ipo_ok)
      set_target_properties(${h_TARGET} PROPERTIES INTERPROCEDURAL_OPTIMIZATION ON)
    else()
      message(WARNING
        "cpp_target: '${h_TARGET}' requested LTO but interprocedural optimization is not "
        "supported by this toolchain; skipping. Details: ${_ipo_err}")
    endif()
  endif()
endfunction()
