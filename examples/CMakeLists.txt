project(git_build_info_example VERSION 1.0.0 LANGUAGES CXX)

# A single build-info library, exposed through an aliased target. The same
# target can be linked into any number of executables.
add_git_build_info(example_build_info
  NAMESPACE example
  ALIAS example::build_info)

# Exercise the default namespace and header path derived from the target name.
add_git_build_info(default_namespace_build_info)

add_executable(print_build_info print_build_info.cc)
target_link_libraries(print_build_info PRIVATE example::build_info)

add_test(NAME print_build_info COMMAND print_build_info)
set_tests_properties(print_build_info PROPERTIES
                     PASS_REGULAR_EXPRESSION "git_dirty: +(true|false)")
