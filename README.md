# Starlark Objective-C rules for Bazel ![](https://github.com/thii/rules_objc/workflows/build/badge.svg)

This repository contains an experimental Starlark implementation of Objective-C
rules for Bazel.

## Getting Started

Add the following to your `WORKSPACE` file, replacing `<commit>` and `<sha256>`
accordingly.

```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_objc",
    sha256 = "<sha256>",
    urls = ["https://github.com/thii/rules_objc/archive/<commit>.zip"],
)
```

Then, in your `BUILD` files, import and use the rules:

```starlark
load("@rules_objc//objc:objc.bzl", "objc_library")

objc_library(
    ...
)
```

The rules are expected to be compatible with their native implementation,
with support for the following extra attributes:

 - `cc_inputs`: Additional files to be passed to the compile and linker
   commands.
 - `linkopts`: Additional linker options.
 - `private_deps`: Private (implementation-only) dependencies of the target being compiled.


See the
[documentation](https://docs.bazel.build/versions/master/be/objective-c.html#objc_library)
from the native rules.

## Current status

- Implemented: `objc_import`, `objc_library`.
- Be able to build all Objective-C examples in `rules_apple`.
- Does not interop with Swift, yet.

## Acknowledgments

Special thanks to the following external rules that have heavily inspired the
implementation of these rules.

- [rules_cc](https://github.com/bazelbuild/rules_cc)'s `my_c_compile` and
  `my_c_archive` example rules.
- [rules_swift](https://github.com/bazelbuild/rules_swift)'s `swift_library`
  rule, as well as other helper components that these rules reuse.
- [rules_ios](https://github.com/bazel-ios/rules_ios)'s draft implementation of
  `apple_library_2` rule.
