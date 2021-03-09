"""Implementation of the `objc_library` rule."""

load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
)
load(
    "@build_bazel_rules_swift//swift/internal:utils.bzl",
    "compact",
)
load("@bazel_skylib//lib:paths.bzl", "paths")
load(
    "@rules_cc//cc:find_cc_toolchain.bzl",
    "find_cc_toolchain",
)
load(
    ":compiling.bzl",
    "compile",
    "new_objc_provider",
)
load(
    ":features.bzl",
    "default_features",
    "features_for_compilation_mode",
)
load(
    ":filetypes.bzl",
    "HEADERS_FILE_TYPES",
    "OBJC_FILE_TYPES",
)
load(
    ":linking.bzl",
    "register_static_library_link_action",
)
load(
    ":utils.bzl",
    "expand_locations_and_make_variables",
)

def _objc_library_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    additional_inputs = []
    additional_inputs.extend(ctx.files.cc_inputs)

    # These can't use additional_inputs since expand_locations needs targets,
    # not files.
    copts = expand_locations_and_make_variables(
        attr = "copts",
        ctx = ctx,
        targets = ctx.attr.cc_inputs,
        values = ctx.attr.copts,
    )
    linkopts = expand_locations_and_make_variables(
        attr = "linkopts",
        ctx = ctx,
        targets = ctx.attr.cc_inputs,
        values = ctx.attr.linkopts,
    ) + [
        "-l{}".format(library)
        for library in ctx.attr.sdk_dylibs
    ] + [
        "-Wl,-framework,{}".format(framework)
        for framework in ctx.attr.sdk_frameworks
    ] + [
        "-Wl,-weak_framework,{}".format(framework)
        for framework in ctx.attr.weak_sdk_frameworks
    ]

    output_file = ctx.actions.declare_file("lib" + ctx.label.name + ".a")

    apple_fragment = ctx.fragments.apple
    cpu = apple_fragment.single_arch_cpu

    extra_features = []
    extra_features.extend(default_features())
    extra_features.extend(
        features_for_compilation_mode(ctx.var["COMPILATION_MODE"]),
    )

    object_files = []

    hdrs = ctx.files.hdrs
    srcs = ctx.files.srcs

    compilation_extra_inputs = []
    compilation_extra_inputs.extend(additional_inputs + hdrs)
    for file in srcs:
        _, extension = paths.split_extension(file.path)
        if extension in HEADERS_FILE_TYPES:
            compilation_extra_inputs.append(file)
    if ctx.attr.pch:
        compilation_extra_inputs.append(ctx.file.pch)

    feature_configuration = cc_common.configure_features(
        cc_toolchain = cc_toolchain,
        ctx = ctx,
        requested_features = ctx.features + extra_features,
        unsupported_features = ctx.disabled_features,
    )

    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        static_library = output_file,
    )
    linker_input = cc_common.create_linker_input(
        additional_inputs = depset(additional_inputs),
        libraries = depset([library_to_link]),
        owner = ctx.label,
        user_link_flags = depset(linkopts),
    )
    compilation_context = cc_common.create_compilation_context(
        defines = depset(ctx.attr.defines),
        headers = depset(hdrs),
        includes = depset(ctx.attr.includes),
    )
    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([linker_input]),
    )

    cc_info = CcInfo(
        compilation_context = compilation_context,
        linking_context = linking_context,
    )
    cc_info = cc_common.merge_cc_infos(
        cc_infos = [cc_info] + [
            dep[CcInfo]
            for dep in ctx.attr.deps
        ],
    )

    for src in srcs:
        _, extension = paths.split_extension(src.path)
        if extension in HEADERS_FILE_TYPES:
            continue
        object_file = compile(
            additional_inputs = compilation_extra_inputs,
            cc_info = cc_info,
            cc_toolchain = cc_toolchain,
            copts = copts,
            cpu = cpu,
            ctx = ctx,
            enable_modules = ctx.attr.enable_modules,
            feature_configuration = feature_configuration,
            is_arc_src = True,
            pch = ctx.file.pch,
            src = src,
        )
        object_files.append(object_file)

    for src in ctx.files.non_arc_srcs:
        _, extension = paths.split_extension(src.path)
        if extension in HEADERS_FILE_TYPES:
            continue
        object_file = compile(
            additional_inputs = compilation_extra_inputs,
            cc_info = cc_info,
            cc_toolchain = cc_toolchain,
            copts = copts,
            cpu = cpu,
            ctx = ctx,
            enable_modules = ctx.attr.enable_modules,
            feature_configuration = feature_configuration,
            is_arc_src = False,
            pch = ctx.file.pch,
            src = src,
        )
        object_files.append(object_file)

    register_static_library_link_action(
        actions = ctx.actions,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        objects = object_files,
        output = output_file,
        target_cpu = cpu,
    )

    objc_provider = new_objc_provider(
        deps = ctx.attr.deps + ctx.attr.private_deps,
        headers = ctx.files.hdrs,
        link_inputs = [output_file] + additional_inputs,
        linkopts = linkopts,
        module_map = ctx.file.module_map,
        static_archives = compact([library_to_link.static_library]),
    )

    return [
        DefaultInfo(
            files = depset([output_file]),
            runfiles = ctx.runfiles(
                collect_data = True,
                collect_default = True,
                files = ctx.files.data + ctx.files.runtime_deps,
            ),
        ),
        cc_info,
        objc_provider,
    ]

objc_library = rule(
    implementation = _objc_library_impl,
    attrs = {
        "cc_inputs": attr.label_list(
            allow_files = True,
            doc = """\
Additional files that are referenced using `$(location ...)` in attributes that
support location and Make variables expansion.
""",
        ),
        "copts": attr.string_list(
            doc = """\
Additional compiler options that should be passed to the C compiler. These
strings are subject to location and Make variables expansion.
""",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = """\
The list of files needed by this target at runtime.
Files and targets named in the `data` attribute will appear in the `*.runfiles`
area of this target, if it has one. This may include data files needed by a
binary or library, or other programs needed by it.
""",
        ),
        "deps": attr.label_list(
            doc = """\
The list of targets that are linked together to form the final bundle.
""",
            providers = [
                [CcInfo],
                [SwiftInfo],
                [apple_common.Objc],
            ],
        ),
        "defines": attr.string_list(
            doc = """\
Extra -D flags to pass to the compiler. They should be in the form KEY=VALUE or
simply KEY and are passed not only to the compiler for this target (as copts
are) but also to all objc_ dependers of this target. Subject to "Make variable"
substitution and Bourne shell tokenization.
""",
        ),
        "enable_modules": attr.bool(
            default = False,
            doc = """\
Enables Clang module support (via `-fmodules`).
""",
        ),
        "hdrs": attr.label_list(
            allow_files = HEADERS_FILE_TYPES,
        ),
        "includes": attr.string_list(
            doc = """\
""",
        ),
        "linkopts": attr.string_list(
            doc = """\
Additional linker options that should be passed to the linker for the binary
that depends on this target. These strings are subject to `$(location ...)`
expansion and Make variables expansion.
""",
        ),
        "module_map": attr.label(
            allow_single_file = True,
        ),
        "non_arc_srcs": attr.label_list(
            allow_files = OBJC_FILE_TYPES,
        ),
        "pch": attr.label(
            allow_single_file = True,
        ),
        "private_deps": attr.label_list(
            providers = [
                [CcInfo],
                [SwiftInfo],
                [apple_common.Objc],
            ],
        ),
        "runtime_deps": attr.label_list(
            allow_files = True,
            doc = """\
Deprecated; use `data` instead.

The list of files needed by this target at runtime.
""",
        ),
        "sdk_dylibs": attr.string_list(
        ),
        "sdk_frameworks": attr.string_list(
            doc = """\
Deprecated; use `linkopts` instead.

Names of SDK frameworks to link with.
""",
        ),
        "srcs": attr.label_list(
            allow_files = OBJC_FILE_TYPES,
        ),
        "textual_hdrs": attr.label_list(
            allow_files = HEADERS_FILE_TYPES,  # Unimplemented
        ),
        "weak_sdk_frameworks": attr.string_list(
            doc = """\
Deprecated; use `linkopts` instead.

Names of SDK frameworks to weakly link with.
""",
        ),
        # Remove once https://github.com/bazelbuild/bazel/issues/7260 is flipped
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
    fragments = ["apple", "objc", "cpp"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)
