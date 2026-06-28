# GitBuildInfo

GitBuildInfo provides the `add_git_build_info()` CMake command for generating
build-time Git metadata for C++ targets.

The command creates a small static library target. The generated source is
refreshed at build time, so branch, tag, describe, commit, and dirty-state
values can change without rerunning CMake configure.

## Synopsis

```cmake
include(cmake/GitBuildInfo.cmake)

add_git_build_info(<library>
                   [ALIAS <target>]
                   [NAMESPACE <namespace>]
                   [TYPE <type>]
                   [FUNCTION <function>]
                   [HEADER <include-path>]
                   [REPOSITORY_DIR <dir>])
```

## Command

### `add_git_build_info`

```cmake
add_git_build_info(<library> ...)
```

Adds a static library target named `<library>`. The target compiles a generated
C++ source file and publishes the generated include directory with
`target_include_directories(... PUBLIC ...)`.

Link this target to any executable or library that needs build metadata:

```cmake
add_git_build_info(my_build_info)

add_executable(my_app src/main.cc)
target_link_libraries(my_app PRIVATE my_build_info)
```

The target requires C++17 because the generated interface uses
`std::string_view`.

## Options

`ALIAS <target>`
: Add `<target>` as an alias for the generated static library, for example
  `my_project::build_info`.

`NAMESPACE <namespace>`
: C++ namespace used by the generated header and source. If omitted, `<library>`
  is used and must be a valid C++ namespace. Nested namespaces such as
  `my_project::build` are accepted.

`TYPE <type>`
: Name of the generated C++ struct. Defaults to `BuildInfo`. The value must be a
  valid C++ identifier.

`FUNCTION <function>`
: Name of the generated accessor function. Defaults to `build_info`. The value
  must be a valid C++ identifier.

`HEADER <include-path>`
: Relative include path of the generated header. Defaults to
  `<namespace>/build_info.hh`, with `::` namespace separators converted to `/`.
  The path must be a safe relative path.

`REPOSITORY_DIR <dir>`
: Git work tree from which metadata is read. Defaults to `PROJECT_SOURCE_DIR`.

## Generated Interface

The generated header declares the configured struct and accessor function:

```cpp
namespace <namespace> {

struct <type> {
  std::string_view git_branch;
  std::string_view git_tag;
  std::string_view git_describe;
  std::string_view git_commit;
  std::string_view git_short_commit;
  bool git_dirty;
};

const <type>& <function>() noexcept;

}  // namespace <namespace>
```

With default names:

```cpp
#include "my_build_info/build_info.hh"

auto const& info = my_build_info::build_info();
```

With an explicit namespace:

```cmake
add_git_build_info(my_build_info NAMESPACE my_project)
```

```cpp
#include "my_project/build_info.hh"

auto const& info = my_project::build_info();
```

## Git Values

GitBuildInfo reads the following values during the build:

`git_branch`
: Current branch name, or `DETACHED` when the work tree is not on a branch.

`git_tag`
: Exact tag for `HEAD`, or an empty string when `HEAD` is not exactly tagged.

`git_describe`
: Result of `git describe --tags --always --broken`. When the work tree is
  dirty, `-dirty` is appended if it is not already present.

`git_commit`
: Full commit hash for `HEAD`.

`git_short_commit`
: Short commit hash for `HEAD`, using 12 characters.

`git_dirty`
: `true` when `git status --porcelain --untracked-files=no` reports any tracked
  change. Untracked files do not affect this value.

If a Git command fails, string fields fall back to `unknown` where applicable,
and `git_dirty` falls back to `false`.

## FetchContent

```cmake
include(FetchContent)

FetchContent_Declare(
  GitBuildInfo
  GIT_REPOSITORY https://github.com/your-org/git-build-info.git
  GIT_TAG v0.1.0)
FetchContent_MakeAvailable(GitBuildInfo)

add_git_build_info(my_build_info)

add_executable(my_app src/main.cc)
target_link_libraries(my_app PRIVATE my_build_info)
```

## Example

The `examples/` directory contains a runnable example:

```sh
cmake -S . -B build
cmake --build build
ctest --test-dir build
./build/examples/print_build_info
```

## Notes

Ignored and untracked files do not affect `git_dirty`.
