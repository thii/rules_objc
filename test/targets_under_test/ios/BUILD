load("@rules_cc//cc:defs.bzl", "objc_library")
load(
    "//objc:objc.bzl",
    starlark_apple_static_library = "apple_static_library",
    starlark_objc_library = "objc_library",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

starlark_apple_static_library(
    name = "apple_static_library_with_avoid_deps",
    avoid_deps = [":LowerLib"],
    minimum_os_version = "8.0",
    platform_type = "ios",
    deps = [":UpperLib"],
)

_cmd = "echo 'static int {} __attribute__((unused,used)) = 0;' > $@"

genrule(
    name = "UpperLibSource",
    outs = ["Upper.c"],
    cmd = _cmd.format("Upper"),
)

genrule(
    name = "LowerLibSource",
    outs = ["Lower.c"],
    cmd = _cmd.format("Lower"),
)

genrule(
    name = "LowestLibSource",
    outs = ["Lowest.c"],
    cmd = _cmd.format("Lowest"),
)

starlark_objc_library(
    name = "UpperLib",
    srcs = [":UpperLibSource"],
    deps = [":LowerLib"],
)

starlark_objc_library(
    name = "LowerLib",
    srcs = [":LowerLibSource"],
    deps = [":LowestLib"],
)

starlark_objc_library(
    name = "LowestLib",
    srcs = [":LowestLibSource"],
)

starlark_objc_library(
    name = "lib_without_srcs",
    data = ["//test/targets_under_test/resources:dummy_data"],
)

genrule(
    name = "objc_hdr",
    outs = ["dummy.h"],
    cmd = "touch $@",
)

objc_library(
    name = "objclib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    hdrs = [":objc_hdr"],
)

starlark_objc_library(
    name = "starlark_objclib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    hdrs = [":objc_hdr"],
)

genrule(
    name = "swift_src",
    outs = ["Dummy.swift"],
    cmd = "echo 'import test_targets_under_test_ios_objclib' > $@",
)

swift_library(
    name = "swiftlib",
    srcs = [":swift_src"],
    deps = [":objclib"],
)

genrule(
    name = "swiftlib_depending_on_starlark_objclib_src",
    outs = ["swiftlib_depending_on_starlark_objclib_src.swift"],
    cmd = "echo 'import test_targets_under_test_ios_starlark_objclib' > $@",
)

swift_library(
    name = "swiftlib_depending_on_starlark_objclib",
    srcs = [":swiftlib_depending_on_starlark_objclib_src"],
    deps = [":starlark_objclib"],
)
