"""Implementation of compilation logic for Objective-C."""

load(
    "@build_bazel_rules_swift//swift/internal:utils.bzl",
    "collect_cc_libraries",
    "get_providers",
)
load(
    "@rules_cc//cc:action_names.bzl",
    "OBJC_COMPILE_ACTION_NAME",
)
load(
    ":intermediates.bzl",
    "intermediate_dependency_file",
    "intermediate_object_file",
)

def compile(
        additional_inputs,
        cc_info,
        cc_toolchain,
        copts,
        cpu,
        ctx,
        enable_modules,
        feature_configuration,
        is_arc_src,
        pch,
        src):
    object_file = intermediate_object_file(
        actions = ctx.actions,
        target_name = ctx.label.name,
        src = src,
    )
    dependency_file = intermediate_dependency_file(
        actions = ctx.actions,
        src = src,
        target_name = ctx.label.name,
    )

    c_compiler_path = cc_common.get_tool_for_action(
        action_name = OBJC_COMPILE_ACTION_NAME,
        feature_configuration = feature_configuration,
    )
    c_compile_variables = cc_common.create_compile_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        output_file = object_file.path,
        source_file = src.path,
        user_compile_flags = ctx.fragments.cpp.copts + ctx.fragments.cpp.conlyopts + copts,
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        action_name = OBJC_COMPILE_ACTION_NAME,
        feature_configuration = feature_configuration,
        variables = c_compile_variables,
    )
    env = cc_common.get_environment_variables(
        action_name = OBJC_COMPILE_ACTION_NAME,
        feature_configuration = feature_configuration,
        variables = c_compile_variables,
    )

    execution_requirements_list = cc_common.get_execution_requirements(
        action_name = OBJC_COMPILE_ACTION_NAME,
        feature_configuration = feature_configuration,
    )
    execution_requirements = {req: "1" for req in execution_requirements_list}

    args = ctx.actions.args()
    args.add("-arch", cpu)
    args.add("-iquote", ".")
    args.add("-iquote", ctx.bin_dir.path)
    args.add("-MD")
    args.add("-MF", dependency_file)
    args.add_all(cc_info.compilation_context.defines, format_each = "-D%s")
    args.add_all(cc_info.compilation_context.includes, format_each = "-I%s")

    if enable_modules:
        args.add("-fmodules")

    if is_arc_src:
        args.add("-fobjc-arc")

    if pch:
        args.add("-include", pch)

    args.add_all(command_line)

    ctx.actions.run(
        arguments = [args],
        env = env,
        executable = c_compiler_path,
        execution_requirements = execution_requirements,
        inputs = depset(
            items = [src] + additional_inputs,
            transitive = [
                cc_toolchain.all_files,
                cc_info.compilation_context.headers,
            ],
        ),
        mnemonic = "ObjcCompile",
        outputs = [
            dependency_file,
            object_file,
        ],
        progress_message = "Compiling {}".format(src.short_path),
    )

    return object_file

def new_objc_provider(
        deps,
        headers,
        link_inputs,
        linkopts,
        module_map,
        static_archives):
    """Creates an `apple_common.Objc` provider for an Objective-C target.

    Args:
        deps: The dependencies of the target being built, whose `Objc` providers
            will be passed to the new one in order to propagate the correct
            transitive fields.
        link_inputs: Additional linker input files that should be propagated to
            dependents.
        linkopts: Linker options that should be propagated to dependents.
        module_map: The provided module map, if any.
        static_archives: A list (typically of one element) of the static
            archives (`.a` files) containing the target's compiled code.

    Returns:
        An `apple_common.Objc` provider that should be returned by the calling
        rule.
    """
    objc_providers = get_providers(deps, apple_common.Objc)
    objc_provider_args = {
        "link_inputs": depset(direct = link_inputs),
        "providers": objc_providers,
        "uses_swift": True,
    }

    # The link action registered by `apple_binary` only looks at `Objc`
    # providers, not `CcInfo`, for libraries to link. Until that rule is
    # migrated over, we need to collect libraries from `CcInfo` (which will
    # include Swift and C++) and put them into the new `Objc` provider.
    transitive_cc_libs = []
    for cc_info in get_providers(deps, CcInfo):
        static_libs = collect_cc_libraries(
            cc_info = cc_info,
            include_static = True,
        )
        transitive_cc_libs.append(depset(static_libs, order = "topological"))
    objc_provider_args["library"] = depset(
        static_archives,
        transitive = transitive_cc_libs,
        order = "topological",
    )

    objc_provider_args["header"] = depset(headers)
    if linkopts:
        objc_provider_args["linkopt"] = depset(
            direct = linkopts,
            order = "topological",
        )

    force_loaded_libraries = [
        archive
        for archive in static_archives
        if archive.basename.endswith(".lo")
    ]
    if force_loaded_libraries:
        objc_provider_args["force_load_library"] = depset(
            direct = force_loaded_libraries,
        )

    transitive_objc_provider_args = {"providers": objc_providers}
    if module_map:
        transitive_objc_provider_args["module_map"] = depset(
            direct = [module_map],
        )

    transitive_objc = apple_common.new_objc_provider(
        **transitive_objc_provider_args
    )
    objc_provider_args["module_map"] = transitive_objc.module_map

    return apple_common.new_objc_provider(**objc_provider_args)
