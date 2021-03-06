This repository is deprecated. Native Objective-C rules have already been migrated to Starlark in Bazel core.

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
    strip_prefix = "rules_objc-<commit>",
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

The rules are expected to be compatible with their native implementation. See
the
[documentation](https://docs.bazel.build/versions/master/be/objective-c.html)
from the native rules.

## Current status

- Implemented: `apple_static_library`, `objc_import`, and `objc_library`.
- Passes [all `rules_apple`'s analysis tests](test/run_rules_apple_tests.sh).
- Be able to build a non-trivial iOS app.

## Acknowledgments

Special thanks to the following external rules that have heavily inspired the
implementation of these rules (sorted alphabetically).

- [rules_apple](https://github.com/bazelbuild/rules_apple)
- [rules_cc](https://github.com/bazelbuild/rules_cc)
- [rules_ios](https://github.com/bazel-ios/rules_ios)
- [rules_swift](https://github.com/bazelbuild/rules_swift)
