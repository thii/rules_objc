load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "build_bazel_rules_apple",
    patch_args = ["-p1"],
    patches = ["//third_party:rules_apple.patch"],
    sha256 = "d46c999340c46dea461bd4ab3e2ad8ec0b5b9960b62bf8a6a69a995ffa64edde",
    strip_prefix = "rules_apple-29d2caf5bc1a81c952126fa2efe82a0242bb3697",
    url = "https://github.com/bazelbuild/rules_apple/archive/29d2caf5bc1a81c952126fa2efe82a0242bb3697.tar.gz",
)

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)

apple_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()

swift_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:extras.bzl",
    "swift_rules_extra_dependencies",
)

swift_rules_extra_dependencies()

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()
