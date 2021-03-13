"""Implementation of the `apple_static_library` rule."""

load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
)
load(
    "@rules_cc//cc:action_names.bzl",
    "CPP_LINK_STATIC_LIBRARY_ACTION_NAME",
)
load(
    "@rules_cc//cc:find_cc_toolchain.bzl",
    "find_cc_toolchain",
)
load(
    ":compiling.bzl",
    "new_objc_provider",
)
load(
    ":linking.bzl",
    "linker_flag_for_sdk_dylib",
    "register_static_library_link_action",
)
load(
    ":utils.bzl",
    "collect_objc_libraries",
    "expand_locations_and_make_variables",
)

def _apple_static_library_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)

    additional_inputs = []
    additional_inputs.extend(ctx.files.cc_inputs)

    # These can't use additional_inputs since expand_locations needs targets,
    # not files.
    linkopts = expand_locations_and_make_variables(
        attr = "linkopts",
        ctx = ctx,
        targets = ctx.attr.cc_inputs,
        values = ctx.attr.linkopts,
    ) + [
        linker_flag_for_sdk_dylib(dylib)
        for dylib in ctx.attr.sdk_dylibs
    ] + [
        "-Wl,-framework,{}".format(framework)
        for framework in ctx.attr.sdk_frameworks
    ] + [
        "-Wl,-weak_framework,{}".format(framework)
        for framework in ctx.attr.weak_sdk_frameworks
    ]

    feature_configuration = cc_common.configure_features(
        cc_toolchain = cc_toolchain,
        ctx = ctx,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    apple_fragment = ctx.fragments.apple
    platform_type_attr = getattr(apple_common.platform_type, ctx.attr.platform_type)
    platform = apple_fragment.multi_arch_platform(platform_type_attr)

    inputs = []
    for cpu, deps in ctx.split_attr.deps.items():
        avoid_deps = []
        if cpu in ctx.split_attr.avoid_deps:
            avoid_deps = ctx.split_attr.avoid_deps[cpu]
        deps_objects = collect_objc_libraries(deps)
        avoid_deps_objects = collect_objc_libraries(avoid_deps)
        objects = [
            x
            for x in deps_objects
            if x not in avoid_deps_objects
        ]

        single_arch_archive = ctx.actions.declare_file(
            ctx.label.name + "-fl.a",
        )
        _, _, target_cpu = cpu.partition("_")

        register_static_library_link_action(
            actions = ctx.actions,
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            objects = objects,
            output = single_arch_archive,
            target_cpu = target_cpu,
        )
        inputs.append(single_arch_archive)

    output = ctx.actions.declare_file(
        ctx.label.name + "_lipo.a",
    )

    archiver_variables = cc_common.create_link_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        is_using_linker = False,
        output_file = output.path,
    )
    env = cc_common.get_environment_variables(
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
        feature_configuration = feature_configuration,
        variables = archiver_variables,
    )

    execution_requirements_list = cc_common.get_execution_requirements(
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
        feature_configuration = feature_configuration,
    )
    execution_requirements = {req: "1" for req in execution_requirements_list}

    args = ctx.actions.args()
    args.add_all(["lipo", "-create"])
    args.add_all(inputs)
    args.add("-o", output)

    ctx.actions.run(
        arguments = [args],
        env = env,
        executable = ctx.executable._xcrunwrapper,
        execution_requirements = execution_requirements,
        inputs = depset(
            direct = inputs,
            transitive = [
                cc_toolchain.all_files,
            ],
        ),
        mnemonic = "ObjcCombiningArchitectures",
        outputs = [output],
        progress_message = "Linking {}".format(output.short_path),
    )

    objc_provider = new_objc_provider(
        deps = ctx.attr.deps,
        link_inputs = additional_inputs,
        linkopts = linkopts,
        module_map = None,
        static_archives = [output],
    )

    apple_static_library_provider = apple_common.AppleStaticLibrary(
        archive = output,
        objc = objc_provider,
    )

    return [
        DefaultInfo(files = depset([output])),
        apple_static_library_provider,
        objc_provider,
    ]

apple_static_library = rule(
    attrs = {
        "avoid_deps": attr.label_list(
            cfg = apple_common.multi_arch_split,
            doc = """\
A list of targets which should not be included (nor their transitive
dependencies included) in the outputs of this rule -- even if they are
otherwise transitively depended on via the `deps` attribute.

This attribute effectively serves to remove portions of the dependency tree
from a static library, and is useful most commonly in scenarios where static
libraries depend on each other.

That is, suppose static libraries X and C are typically distributed to
consumers separately. C is a very-common base library, and X contains
less-common functionality; X depends on C, such that applications seeking to
import library X must also import library C. The target describing X would set
C's target in `avoid_deps`. In this way, X can depend on C without also
containing C. Without this `avoid_deps` usage, an application importing both X
and C would have duplicate symbols for C.
""",
            providers = [
                [CcInfo],
                [SwiftInfo],
                [apple_common.Objc],
            ],
        ),
        "cc_inputs": attr.label_list(
            allow_files = True,
            doc = """\
Additional files that are referenced using `$(location ...)` in attributes that
support location and Make variable expansion.
""",
        ),
        "deps": attr.label_list(
            cfg = apple_common.multi_arch_split,
            doc = """\
The list of targets that are linked together to form the final bundle.
""",
            providers = [
                [CcInfo],
                [SwiftInfo],
                [apple_common.Objc],
            ],
        ),
        "linkopts": attr.string_list(
            doc = """\
Additional linker options that should be passed to the linker for the binary
that depends on this target. These strings are subject to `$(location ...)`
expansion and Make variable expansion.
""",
        ),
        "minimum_os_version": attr.string(
            mandatory = True,
            doc = """
A required string indicating the minimum OS version supported by the target,
represented as a dotted version number (for example, "9.0").
""",
        ),
        "platform_type": attr.string(
            doc = """
The target Apple platform for which to create a binary. This dictates which SDK
is used for compilation/linking and which flag is used to determine the
architectures to target. For example, if `ios` is specified, then the output
binaries/libraries will be created combining all architectures specified by
`--ios_multi_cpus`. Options are:

*   `ios`: architectures gathered from `--ios_multi_cpus`.
*   `macos`: architectures gathered from `--macos_cpus`.
*   `tvos`: architectures gathered from `--tvos_cpus`.
*   `watchos`: architectures gathered from `--watchos_cpus`.
""",
            mandatory = True,
        ),
        "sdk_dylibs": attr.string_list(
            doc = """
Names of SDK `.dylib` libraries to link with (e.g., `libz` or `libarchive`).
`libc++` is included automatically if the binary has any C++ or Objective-C++
sources in its dependency tree. When linking a binary, all libraries named in
that binary's transitive dependency graph are used.
""",
        ),
        "sdk_frameworks": attr.string_list(
            doc = """\
Deprecated; use `linkopts` instead.

Names of SDK frameworks to link with (e.g., `AddressBook`, `QuartzCore`).
`UIKit` and `Foundation` are always included, even if this attribute is
provided and does not list them.
""",
        ),
        "weak_sdk_frameworks": attr.string_list(
            doc = """\
Deprecated; use `linkopts` instead.

Names of SDK frameworks to weakly link with (e.g., `MediaAccessibility`).
Unlike regularly linked SDK frameworks, symbols from weakly linked
frameworks do not cause the binary to fail to load if they are not present in
the version of the framework available at runtime.
""",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        # Remove once https://github.com/bazelbuild/bazel/issues/7260 is flipped
        "_cc_toolchain": attr.label(
            default = "@bazel_tools//tools/cpp:current_cc_toolchain",
        ),
        # This is not actually needed because we only use it to execute lipo;
        # we're just using it to keep the command the same with the native
        # `apple_static_library` rule for now.
        "_xcrunwrapper": attr.label(
            cfg = "host",
            executable = True,
            default = "@bazel_tools//tools/objc:xcrunwrapper",
        ),
    },
    cfg = transition_support.apple_rule_transition,
    doc = """\
This rule produces single- or multi-architecture ("fat") Objective-C
statically-linked libraries, typically used in creating static Apple Frameworks
for distribution and re-use in multiple extensions or applications.

The `lipo` tool is used to combine files of multiple architectures; a build
flag controls which architectures are targeted. The build flag examined depends
on the `platform_type` attribute for this rule (and is described in its
documentation).
""",
    fragments = ["apple", "cpp", "objc"],
    implementation = _apple_static_library_impl,
    outputs = {
        # Provided for compatibility with built-in `apple_static_library` only.
        "lipobin": "%{name}_lipo.a",
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)
