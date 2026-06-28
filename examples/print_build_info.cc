#include "example/build_info.hh"

#include <iostream>

int main() {
  auto const& info = example::build_info();
  std::cout << "git_branch:        " << info.git_branch << '\n'
            << "git_tag:           " << info.git_tag << '\n'
            << "git_describe:      " << info.git_describe << '\n'
            << "git_commit:        " << info.git_commit << '\n'
            << "git_short_commit:  " << info.git_short_commit << '\n'
            << "git_dirty:         " << std::boolalpha << info.git_dirty << '\n';
}
