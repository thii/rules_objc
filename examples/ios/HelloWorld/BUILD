load("//objc:objc.bzl", "objc_library")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")
load(
    "@build_bazel_rules_apple//apple:versioning.bzl",
    "apple_bundle_version",
)

licenses(["notice"])

objc_library(
    name = "Sources",
    srcs = [
        "Sources/AppDelegate.h",
        "Sources/AppDelegate.m",
        "Sources/main.m",
    ],
)

apple_bundle_version(
    name = "HelloWorldVersion",
    build_version = "1.0",
)

ios_application(
    name = "HelloWorld",
    bundle_id = "com.example.hello-world",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [":Info.plist"],
    minimum_os_version = "8.0",
    version = ":HelloWorldVersion",
    deps = [":Sources"],
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [":HelloWorld"],
)
