"""Implementation of the `objc_import` rule."""

load(
    "@rules_cc//cc:find_cc_toolchain.bzl",
    "find_cc_toolchain",
)
load(
    ":compiling.bzl",
    "new_objc_provider",
)
load(
    ":filetypes.bzl",
    "HEADERS_FILE_TYPES",
)
load(
    ":linking.bzl",
    "linker_flag_for_sdk_dylib",
)
load(
    ":utils.bzl",
    "expand_locations_and_make_variables",
)

def _objc_import_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)

    # These can't use ctx.files.cc_inputs since expand_locations needs targets,
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

    compilation_context = cc_common.create_compilation_context(
        headers = depset(ctx.files.hdrs),
        includes = depset(ctx.attr.includes),
    )

    this_cc_info = CcInfo(compilation_context = compilation_context)
    cc_infos = [this_cc_info]

    for archive in ctx.files.archives:
        library_to_link = cc_common.create_library_to_link(
            actions = ctx.actions,
            alwayslink = ctx.attr.alwayslink,
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            static_library = archive,
        )
        linker_input = cc_common.create_linker_input(
            additional_inputs = depset(ctx.files.cc_inputs),
            libraries = depset([library_to_link]),
            owner = ctx.label,
            user_link_flags = depset(linkopts),
        )
        linking_context = cc_common.create_linking_context(
            linker_inputs = depset([linker_input]),
        )
        cc_info = CcInfo(linking_context = linking_context)
        cc_infos.append(cc_info)

    cc_info = cc_common.merge_cc_infos(cc_infos = cc_infos)

    objc_provider = new_objc_provider(
        deps = [],
        link_inputs = ctx.files.archives + ctx.files.cc_inputs,
        linkopts = linkopts,
        module_map = None,
        static_archives = ctx.files.archives,
    )

    return [
        cc_info,
        objc_provider,
    ]

objc_import = rule(
    attrs = {
        "alwayslink": attr.bool(
            default = False,
            doc = """\
If `True`, any bundle or binary that depends (directly or indirectly) on this
library will link in all the object files for the files listed in srcs and
non_arc_srcs, even if some contain no symbols referenced by the binary. This is
useful if your code isn't explicitly called by code in the binary, e.g., if
your code registers to receive some callback provided by some service.
""",
        ),
        "archives": attr.label_list(
            allow_files = [".a"],
            doc = """\
The list of `.a` files provided to Objective-C targets that depend on this
target.
""",
        ),
        "cc_inputs": attr.label_list(
            allow_files = True,
            doc = """\
Additional files that are referenced using `$(location ...)` in attributes that
support location and Make variables expansion.
""",
        ),
        "hdrs": attr.label_list(
            allow_files = True,
            doc = """\
The list of C, C++, Objective-C, and Objective-C++ header files published by
this library to be included by sources in dependent rules.

These headers describe the public interface for the library and will be made
available for inclusion by sources in this rule or in dependent rules. Headers
not meant to be included by a client of this library should be listed in the
srcs attribute instead.

These will be compiled separately from the source if modules are enabled.
""",
        ),
        "includes": attr.string_list(
            doc = """\
List of #include/#import search paths to add to this target and all depending
targets. This is to support third party and open-sourced libraries that do not
specify the entire workspace path in their #import/#include statements.

The paths are interpreted relative to the package directory, and the bin roots
(e.g. `bazel-out/pkg/includedir`) are included in addition to the actual client
root.
""",
        ),
        "linkopts": attr.string_list(
            doc = """\
Additional linker options that should be passed to the linker for the binary
that depends on this target. These strings are subject to `$(location ...)`
expansion and Make variables expansion.
""",
        ),
        "sdk_dylibs": attr.string_list(
            doc = """
Names of SDK `.dylib` libraries to link with (e.g., `libz` or `libarchive`).
""",
        ),
        "sdk_frameworks": attr.string_list(
            doc = """\
Deprecated; use `linkopts` instead.

Names of SDK frameworks to link with.
""",
        ),
        "textual_hdrs": attr.label_list(
            allow_files = HEADERS_FILE_TYPES,  # Unimplemented
            doc = """\
The list of C, C++, Objective-C, and Objective-C++ files that are included as
headers by source files in this rule or by users of this library. Unlike
`hdrs`, these will not be compiled separately from the sources.
""",
        ),
        "weak_sdk_frameworks": attr.string_list(
            doc = """\
Deprecated; use `linkopts` instead.

Names of SDK frameworks to weakly link with.
""",
        ),
        # Remove once https://github.com/bazelbuild/bazel/issues/7260 is flipped
        "_cc_toolchain": attr.label(
            default = "@bazel_tools//tools/cpp:current_cc_toolchain",
        ),
    },
    fragments = ["apple", "cpp", "objc"],
    implementation = _objc_import_impl,
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)
