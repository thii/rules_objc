load("@bazel_skylib//rules:build_test.bzl", "build_test")

build_test(
    name = "examples_build_test",
    targets = [
        "//examples/ios/HelloWorld",
        "//examples/ios/PrenotCalculator",
        "//examples/ios/Squarer:SquarerTests",
        "//examples/macos/CommandLine",
        "//examples/macos/HelloToday",
        "//examples/macos/HelloWorld",
        "//examples/tvos/HelloWorld",
        "//examples/watchos/HelloWorld",
        "//test/targets_under_test/ios:apple_static_library_with_avoid_deps",
        "//test/targets_under_test/ios:lib_without_srcs",
    ],
)
