#[=======================================================================[.rst:
GitBuildInfo
------------

Generate build-time Git metadata for C++ targets.

Load this module in CMake with:

.. code-block:: cmake

  include(GitBuildInfo)

Commands
^^^^^^^^

This module provides the following command:

.. command:: add_git_build_info

  Add a static library target that exposes Git metadata:

  .. code-block:: cmake

    add_git_build_info(<library>
                       [ALIAS <target>]
                       [NAMESPACE <namespace>]
                       [TYPE <type>]
                       [FUNCTION <function>]
                       [HEADER <include-path>]
                       [REPOSITORY_DIR <dir>])

  The generated source is refreshed at build time, so Git values can change
  without rerunning the CMake configure step.  Link the created target to any
  target that needs build metadata.

  ``<library>``
    Name of the static library target to create.  If ``NAMESPACE`` is omitted,
    this is also used as the C++ namespace and must be a valid C++ namespace.

  ``ALIAS <target>``
    Optional alias target for the generated library, for example
    ``my_project::build_info``.

  ``NAMESPACE <namespace>``
    C++ namespace used by the generated header and source.  Defaults to
    ``<library>``.

  ``TYPE <type>``
    Name of the generated C++ struct.  Defaults to ``BuildInfo``.

  ``FUNCTION <function>``
    Name of the generated accessor function.  Defaults to ``build_info``.

  ``HEADER <include-path>``
    Relative include path of the generated header.  Defaults to
    ``<namespace>/build_info.hh``, with ``::`` namespace separators converted
    to ``/``.

  ``REPOSITORY_DIR <dir>``
    Git work tree from which metadata is read.  Defaults to
    ``PROJECT_SOURCE_DIR``.

  The generated interface requires C++17 and provides the following members:
  ``git_branch``, ``git_tag``, ``git_describe``, ``git_commit``,
  ``git_short_commit``, and ``git_dirty``.  Untracked files do not affect
  ``git_dirty``.

Examples
^^^^^^^^

.. code-block:: cmake

  add_git_build_info(app_build_info
    NAMESPACE my_project
    ALIAS my_project::build_info)

  add_executable(my_app src/main.cc)
  target_link_libraries(my_app PRIVATE my_project::build_info)

Code can then include the generated header:

.. code-block:: cpp

  #include "my_project/build_info.hh"

  auto const& info = my_project::build_info();
#]=======================================================================]

include_guard(GLOBAL)

if(CMAKE_VERSION VERSION_LESS 3.17)
  message(FATAL_ERROR "GitBuildInfo.cmake requires CMake 3.17 or newer")
endif()

function(_git_build_info_capture output fallback)
  execute_process(
    COMMAND git ${ARGN}
    WORKING_DIRECTORY "${GIT_BUILD_INFO_REPOSITORY_DIR}"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE value
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  if(result STREQUAL "0")
    set("${output}" "${value}" PARENT_SCOPE)
  else()
    set("${output}" "${fallback}" PARENT_SCOPE)
  endif()
endfunction()

function(_git_build_info_cxx_string output value)
  set(escaped "${value}")
  string(REPLACE "\\" "\\\\" escaped "${escaped}")
  string(REPLACE "\"" "\\\"" escaped "${escaped}")
  string(REPLACE "\r" "\\r" escaped "${escaped}")
  string(REPLACE "\n" "\\n" escaped "${escaped}")
  set("${output}" "\"${escaped}\"" PARENT_SCOPE)
endfunction()

function(_git_build_info_write_if_changed path contents)
  set(previous_contents "")
  if(EXISTS "${path}")
    file(READ "${path}" previous_contents)
  endif()

  if(NOT previous_contents STREQUAL contents)
    get_filename_component(output_dir "${path}" DIRECTORY)
    file(MAKE_DIRECTORY "${output_dir}")
    file(WRITE "${path}" "${contents}")
  endif()
endfunction()

function(_git_build_info_validate_namespace namespace)
  if(namespace STREQUAL "")
    return()
  endif()

  string(REPLACE "::" ";" namespace_parts "${namespace}")
  foreach(part IN LISTS namespace_parts)
    if(NOT part MATCHES "^[A-Za-z_][A-Za-z0-9_]*$")
      message(FATAL_ERROR "Invalid C++ namespace: ${namespace}")
    endif()
  endforeach()
endfunction()

function(_git_build_info_namespace namespace open_output close_output)
  _git_build_info_validate_namespace("${namespace}")

  if(namespace STREQUAL "")
    set("${open_output}" "" PARENT_SCOPE)
    set("${close_output}" "" PARENT_SCOPE)
    return()
  endif()

  set("${open_output}" "namespace ${namespace} {\n" PARENT_SCOPE)
  set("${close_output}" "\n}  // namespace ${namespace}\n" PARENT_SCOPE)
endfunction()

function(_git_build_info_sanitize_identifier output value)
  string(REGEX REPLACE "[^A-Za-z0-9_]" "_" sanitized "${value}")
  if(sanitized MATCHES "^[0-9]")
    set(sanitized "_${sanitized}")
  endif()
  if(sanitized STREQUAL "")
    set(sanitized "build_info")
  endif()
  set("${output}" "${sanitized}" PARENT_SCOPE)
endfunction()

function(_git_build_info_validate_identifier kind value)
  if(NOT value MATCHES "^[A-Za-z_][A-Za-z0-9_]*$")
    message(FATAL_ERROR "${kind} must be a valid C++ identifier: ${value}")
  endif()
endfunction()

function(_git_build_info_generate)
  foreach(required_var
          IN
          ITEMS
          GIT_BUILD_INFO_REPOSITORY_DIR
          GIT_BUILD_INFO_NAMESPACE
          GIT_BUILD_INFO_TYPE
          GIT_BUILD_INFO_FUNCTION
          GIT_BUILD_INFO_HEADER
          GIT_BUILD_INFO_HEADER_FILE
          GIT_BUILD_INFO_SOURCE_FILE)
    if(NOT DEFINED ${required_var})
      message(FATAL_ERROR "GitBuildInfo.cmake requires ${required_var}")
    endif()
  endforeach()

  _git_build_info_capture(GIT_BRANCH "unknown" branch --show-current)
  _git_build_info_capture(GIT_COMMIT "unknown" rev-parse HEAD)
  _git_build_info_capture(GIT_SHORT_COMMIT "unknown" rev-parse --short=12 HEAD)
  _git_build_info_capture(GIT_TAG "" describe --tags --exact-match)
  _git_build_info_capture(GIT_DESCRIBE "${GIT_SHORT_COMMIT}" describe --tags
                          --always --broken)

  if(GIT_BRANCH STREQUAL "")
    set(GIT_BRANCH "DETACHED")
  endif()

  execute_process(
    COMMAND git status --porcelain --untracked-files=no
    WORKING_DIRECTORY "${GIT_BUILD_INFO_REPOSITORY_DIR}"
    RESULT_VARIABLE git_status_result
    OUTPUT_VARIABLE git_status
    ERROR_QUIET
  )
  if(git_status_result STREQUAL "0" AND NOT git_status STREQUAL "")
    set(GIT_DIRTY true)
  else()
    set(GIT_DIRTY false)
  endif()

  if(GIT_DIRTY AND NOT GIT_DESCRIBE MATCHES "-dirty$")
    set(GIT_DESCRIBE "${GIT_DESCRIBE}-dirty")
  endif()

  _git_build_info_namespace("${GIT_BUILD_INFO_NAMESPACE}" NAMESPACE_OPEN
                            NAMESPACE_CLOSE)
  _git_build_info_cxx_string(GIT_BRANCH_LITERAL "${GIT_BRANCH}")
  _git_build_info_cxx_string(GIT_TAG_LITERAL "${GIT_TAG}")
  _git_build_info_cxx_string(GIT_DESCRIBE_LITERAL "${GIT_DESCRIBE}")
  _git_build_info_cxx_string(GIT_COMMIT_LITERAL "${GIT_COMMIT}")
  _git_build_info_cxx_string(GIT_SHORT_COMMIT_LITERAL "${GIT_SHORT_COMMIT}")

  set(header_contents [=[
#pragma once

#include <string_view>

@NAMESPACE_OPEN@struct @GIT_BUILD_INFO_TYPE@ {
  std::string_view git_branch;
  std::string_view git_tag;
  std::string_view git_describe;
  std::string_view git_commit;
  std::string_view git_short_commit;
  bool git_dirty;
};

const @GIT_BUILD_INFO_TYPE@& @GIT_BUILD_INFO_FUNCTION@() noexcept;
@NAMESPACE_CLOSE@]=])

  set(source_contents [=[
#include "@GIT_BUILD_INFO_HEADER@"

@NAMESPACE_OPEN@namespace {

constexpr @GIT_BUILD_INFO_TYPE@ kBuildInfo{
    @GIT_BRANCH_LITERAL@,
    @GIT_TAG_LITERAL@,
    @GIT_DESCRIBE_LITERAL@,
    @GIT_COMMIT_LITERAL@,
    @GIT_SHORT_COMMIT_LITERAL@,
    @GIT_DIRTY@,
};

}  // namespace

const @GIT_BUILD_INFO_TYPE@& @GIT_BUILD_INFO_FUNCTION@() noexcept {
  return kBuildInfo;
}
@NAMESPACE_CLOSE@]=])

  string(CONFIGURE "${header_contents}" header_contents @ONLY)
  string(CONFIGURE "${source_contents}" source_contents @ONLY)

  _git_build_info_write_if_changed("${GIT_BUILD_INFO_HEADER_FILE}"
                                   "${header_contents}")
  _git_build_info_write_if_changed("${GIT_BUILD_INFO_SOURCE_FILE}"
                                   "${source_contents}")
endfunction()

if(GIT_BUILD_INFO_GENERATE)
  _git_build_info_generate()
  return()
endif()

function(add_git_build_info lib_target)
  set(one_value_args
      ALIAS
      FUNCTION
      HEADER
      NAMESPACE
      REPOSITORY_DIR
      TYPE)
  cmake_parse_arguments(PARSE_ARGV 1 GBI "" "${one_value_args}" "")

  if(GBI_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR
            "add_git_build_info got unknown arguments: ${GBI_UNPARSED_ARGUMENTS}")
  endif()

  if(TARGET "${lib_target}")
    message(FATAL_ERROR "add_git_build_info target already exists: ${lib_target}")
  endif()

  if(NOT DEFINED GBI_NAMESPACE)
    if(NOT lib_target MATCHES "^[A-Za-z_][A-Za-z0-9_]*$")
      message(FATAL_ERROR
              "add_git_build_info default NAMESPACE requires <library> to be "
              "a valid C++ namespace: ${lib_target}. Pass NAMESPACE explicitly.")
    endif()
    set(GBI_NAMESPACE "${lib_target}")
  endif()
  _git_build_info_validate_namespace("${GBI_NAMESPACE}")

  if(NOT DEFINED GBI_HEADER)
    string(REPLACE "::" "/" namespace_path "${GBI_NAMESPACE}")
    if(namespace_path STREQUAL "")
      _git_build_info_sanitize_identifier(namespace_path "${lib_target}")
    endif()
    set(GBI_HEADER "${namespace_path}/build_info.hh")
  endif()
  if(IS_ABSOLUTE "${GBI_HEADER}" OR GBI_HEADER MATCHES "(^|/)\\.\\.(/|$)"
     OR GBI_HEADER MATCHES "[\\\\\"]")
    message(FATAL_ERROR
            "HEADER must be a safe relative include path: ${GBI_HEADER}")
  endif()

  if(NOT DEFINED GBI_TYPE)
    set(GBI_TYPE "BuildInfo")
  endif()
  _git_build_info_validate_identifier("TYPE" "${GBI_TYPE}")

  if(NOT DEFINED GBI_FUNCTION)
    set(GBI_FUNCTION "build_info")
  endif()
  _git_build_info_validate_identifier("FUNCTION" "${GBI_FUNCTION}")

  if(NOT DEFINED GBI_REPOSITORY_DIR)
    set(GBI_REPOSITORY_DIR "${PROJECT_SOURCE_DIR}")
  endif()

  set(generated_dir "${CMAKE_CURRENT_BINARY_DIR}/generated/${lib_target}")
  set(include_dir "${generated_dir}/include")
  set(header_file "${include_dir}/${GBI_HEADER}")
  set(source_file "${generated_dir}/src/build_info.cc")
  set(generator_target "${lib_target}_generate")

  # Generate once at configure time so the header and source always exist before
  # any compilation. The build-time generator below refreshes the Git values on
  # every build; consumers therefore only need to link the library, with no
  # direct dependency on the generator.
  set(GIT_BUILD_INFO_REPOSITORY_DIR "${GBI_REPOSITORY_DIR}")
  set(GIT_BUILD_INFO_NAMESPACE "${GBI_NAMESPACE}")
  set(GIT_BUILD_INFO_TYPE "${GBI_TYPE}")
  set(GIT_BUILD_INFO_FUNCTION "${GBI_FUNCTION}")
  set(GIT_BUILD_INFO_HEADER "${GBI_HEADER}")
  set(GIT_BUILD_INFO_HEADER_FILE "${header_file}")
  set(GIT_BUILD_INFO_SOURCE_FILE "${source_file}")
  _git_build_info_generate()

  set_source_files_properties("${header_file}" "${source_file}" PROPERTIES
                              GENERATED TRUE)

  add_custom_target(
    "${generator_target}"
    COMMAND
      ${CMAKE_COMMAND} "-DGIT_BUILD_INFO_GENERATE=ON"
      "-DGIT_BUILD_INFO_REPOSITORY_DIR=${GBI_REPOSITORY_DIR}"
      "-DGIT_BUILD_INFO_NAMESPACE=${GBI_NAMESPACE}"
      "-DGIT_BUILD_INFO_TYPE=${GBI_TYPE}"
      "-DGIT_BUILD_INFO_FUNCTION=${GBI_FUNCTION}"
      "-DGIT_BUILD_INFO_HEADER=${GBI_HEADER}"
      "-DGIT_BUILD_INFO_HEADER_FILE=${header_file}"
      "-DGIT_BUILD_INFO_SOURCE_FILE=${source_file}" -P
      "${CMAKE_CURRENT_FUNCTION_LIST_FILE}"
    BYPRODUCTS "${header_file}" "${source_file}"
    WORKING_DIRECTORY "${GBI_REPOSITORY_DIR}"
    COMMENT "Generating git build metadata for ${lib_target}"
    VERBATIM)

  add_library("${lib_target}" STATIC "${source_file}")
  add_dependencies("${lib_target}" "${generator_target}")
  target_include_directories("${lib_target}" PUBLIC "${include_dir}")
  target_compile_features("${lib_target}" PUBLIC cxx_std_17)

  if(DEFINED GBI_ALIAS)
    if(TARGET "${GBI_ALIAS}")
      message(FATAL_ERROR "add_git_build_info ALIAS target already exists: ${GBI_ALIAS}")
    endif()
    add_library("${GBI_ALIAS}" ALIAS "${lib_target}")
  endif()
endfunction()
