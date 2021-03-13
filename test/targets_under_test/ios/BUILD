load("//objc:objc.bzl", "apple_static_library", "objc_library")

apple_static_library(
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

objc_library(
    name = "UpperLib",
    srcs = [":UpperLibSource"],
    deps = [":LowerLib"],
)

objc_library(
    name = "LowerLib",
    srcs = [":LowerLibSource"],
    deps = [":LowestLib"],
)

objc_library(
    name = "LowestLib",
    srcs = [":LowestLibSource"],
)

objc_library(
    name = "lib_without_srcs",
    data = ["//test/targets_under_test/resources:dummy_data"],
)
