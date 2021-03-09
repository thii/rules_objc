load("//objc:objc.bzl", "objc_library")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load(
    "@build_bazel_rules_apple//apple:macos.bzl",
    "macos_command_line_application",
)
load(
    "@build_bazel_rules_apple//apple:versioning.bzl",
    "apple_bundle_version",
)

licenses(["notice"])

objc_library(
    name = "Sources",
    srcs = ["Sources/main.m"],
)

apple_bundle_version(
    name = "CommandLineVersion",
    build_version = "1.0",
)

macos_command_line_application(
    name = "CommandLine",
    bundle_id = "com.example.command-line",
    infoplists = [":Info.plist"],
    minimum_os_version = "10.11",
    version = ":CommandLineVersion",
    deps = [":Sources"],
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [":CommandLine"],
)
