"""Implementation of the `objc_library` rule."""

load(
    "@build_bazel_rules_swift//swift/internal:compiling.bzl",
    "derive_module_name"
)
load(
    "@build_bazel_rules_swift//swift/internal:module_maps.bzl",
    "write_module_map"
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
    "linker_flag_for_sdk_dylib",
    "register_static_library_link_action",
)
load(
    ":utils.bzl",
    "expand_locations_and_make_variables",
)

def _objc_library_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)

    module_map_file = ctx.file.module_map
    if not module_map_file and (
        ctx.files.hdrs or ctx.files.textual_hdrs
    ):
        # The native rule declares this as 'ctx.label.name +
        # ".modulemaps/module.modulemap' which can be problematic, since the
        # $(RULEDIR) can be in include paths which causes the module map to
        # be implicitly searchable
        module_map_file = ctx.actions.declare_file(
            ctx.label.name + ".objc.modulemap",
        )
        write_module_map(
            actions = ctx.actions,
            exported_module_ids = ["*"],
            module_map_file = module_map_file,
            module_name = derive_module_name(ctx.label),
            public_headers = ctx.files.hdrs,
            public_textual_headers = ctx.files.textual_hdrs,
        )

    compilation_context = cc_common.create_compilation_context(
        defines = depset(ctx.attr.defines),
        headers = depset(ctx.files.hdrs),
        includes = depset(ctx.attr.includes),
        quote_includes = depset([".", ctx.bin_dir.path]),
    )

    if ctx.files.srcs or ctx.files.non_arc_srcs:
        output_file = ctx.actions.declare_file("lib" + ctx.label.name + ".a")
        outputs = [output_file]
    else:
        outputs = []

    providers = []

    if outputs:
        # Location expansion needs targets, not files.
        all_inputs = ctx.attr.deps + ctx.attr.hdrs + ctx.attr.non_arc_srcs + \
            ctx.attr.srcs + ctx.attr.textual_hdrs
        copts = expand_locations_and_make_variables(
            attr = "copts",
            ctx = ctx,
            targets = all_inputs,
            values = ctx.attr.copts,
        )
        linkopts = [
            linker_flag_for_sdk_dylib(dylib)
            for dylib in ctx.attr.sdk_dylibs
        ] + [
            "-Wl,-framework,{}".format(framework)
            for framework in ctx.attr.sdk_frameworks
        ] + [
            "-Wl,-weak_framework,{}".format(framework)
            for framework in ctx.attr.weak_sdk_frameworks
        ]

        apple_fragment = ctx.fragments.apple
        cpu = apple_fragment.single_arch_cpu

        extra_features = []
        extra_features.extend(default_features())
        extra_features.extend(
            features_for_compilation_mode(ctx.var["COMPILATION_MODE"]),
        )

        object_files = []

        compilation_extra_inputs = []
        compilation_extra_inputs.extend(ctx.files.hdrs)
        for file in ctx.files.srcs:
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
            libraries = depset([library_to_link]),
            owner = ctx.label,
            user_link_flags = depset(linkopts),
        )
        linking_context = cc_common.create_linking_context(
            linker_inputs = depset([linker_input]),
        )

        direct_cc_info = CcInfo(
            compilation_context = compilation_context,
            linking_context = linking_context,
        )
        cc_info = cc_common.merge_cc_infos(
            direct_cc_infos = [direct_cc_info],
            cc_infos = [
                dep[CcInfo]
                for dep in ctx.attr.deps
                if CcInfo in dep
            ],
        )

        for src in ctx.files.srcs:
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
            deps = ctx.attr.deps,
            link_inputs = [],
            linkopts = linkopts,
            module_map = module_map_file,
            sdk_dylibs = ctx.attr.sdk_dylibs,
            sdk_frameworks = ctx.attr.sdk_frameworks,
            static_archives = compact([library_to_link.static_library]),
        )
        providers.append(objc_provider)
    else:
        direct_cc_info = CcInfo(
            compilation_context = compilation_context,
        )
        cc_info = cc_common.merge_cc_infos(
            direct_cc_infos = [direct_cc_info],
            cc_infos = [
                dep[CcInfo]
                for dep in ctx.attr.deps
                if CcInfo in dep
            ],
        )

    if module_map_file:
        outputs.append(module_map_file)

    providers.extend([
        cc_info,
        DefaultInfo(
            files = depset(outputs),
            runfiles = ctx.runfiles(
                collect_data = True,
                collect_default = True,
                files = ctx.files.data + ctx.files.runtime_deps,
            ),
        ),
    ])

    return providers

objc_library = rule(
    implementation = _objc_library_impl,
    attrs = {
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
            allow_files = True,
        ),
        "includes": attr.string_list(
            doc = """\
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
Names of SDK frameworks to weakly link with.
""",
        ),
        # Remove once https://github.com/bazelbuild/bazel/issues/7260 is flipped
        "_cc_toolchain": attr.label(
            default = "@bazel_tools//tools/cpp:current_cc_toolchain",
        ),
    },
    fragments = ["apple", "objc", "cpp"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)
