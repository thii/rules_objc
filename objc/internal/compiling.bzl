"""Implementation of compilation logic for Objective-C."""

load(
    "@build_bazel_rules_swift//swift/internal:utils.bzl",
    "collect_cc_libraries",
    "get_providers",
)
load(
    "@bazel_tools//tools/build_defs/cc:action_names.bzl",
    "CPP_COMPILE_ACTION_NAME",
    "C_COMPILE_ACTION_NAME",
    "OBJCPP_COMPILE_ACTION_NAME",
    "OBJC_COMPILE_ACTION_NAME",
)
load(
    ":intermediates.bzl",
    "intermediate_dependency_file",
    "intermediate_object_file",
)

def _compile_action_name_for_file(src):
    extension = src.extension
    if extension in ["c"]:
        return C_COMPILE_ACTION_NAME
    elif extension in ["cc", "cpp", "cxx", "C"]:
        return CPP_COMPILE_ACTION_NAME
    elif extension in ["mm"]:
        return OBJCPP_COMPILE_ACTION_NAME
    else:
        return OBJC_COMPILE_ACTION_NAME

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

    compile_action_name = _compile_action_name_for_file(src)
    c_compiler_path = cc_common.get_tool_for_action(
        action_name = compile_action_name,
        feature_configuration = feature_configuration,
    )
    c_compile_variables = cc_common.create_compile_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        output_file = object_file.path,
        quote_include_directories = cc_info.compilation_context.quote_includes,
        source_file = src.path,
        user_compile_flags = ctx.fragments.cpp.copts + ctx.fragments.cpp.conlyopts + copts,
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        action_name = compile_action_name,
        feature_configuration = feature_configuration,
        variables = c_compile_variables,
    )
    env = cc_common.get_environment_variables(
        action_name = compile_action_name,
        feature_configuration = feature_configuration,
        variables = c_compile_variables,
    )

    execution_requirements_list = cc_common.get_execution_requirements(
        action_name = compile_action_name,
        feature_configuration = feature_configuration,
    )
    execution_requirements = {req: "1" for req in execution_requirements_list}

    args = ctx.actions.args()
    args.add("-arch", cpu)
    args.add("-MD")
    args.add("-MF", dependency_file)
    args.add_all(
        cc_info.compilation_context.defines,
        format_each = "-D%s",
    )
    args.add_all(
        cc_info.compilation_context.framework_includes,
        format_each = "-F%s",
    )
    args.add_all(
        cc_info.compilation_context.includes,
        format_each = "-I%s",
    )

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
        link_inputs,
        linkopts,
        module_map,
        sdk_dylibs,
        sdk_frameworks,
        static_archives):
    """Creates an `apple_common.Objc` provider for an Objective-C target.

    Args:
        deps: The dependencies of the target being built, whose `Objc` providers
            will be passed to the new one in order to propagate the correct
            transitive fields.
        link_inputs: Additional linker input files that should be propagated to
            dependents.
        linkopts: Linker options that should be propagated to dependents.
        module_map: The module map for this target, if any.
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

    if linkopts:
        objc_provider_args["linkopt"] = depset(
            direct = linkopts,
            order = "topological",
        )

    if sdk_dylibs:
        objc_provider_args["sdk_dylib"] = depset(
            direct = sdk_dylibs,
        )

    if sdk_frameworks:
        objc_provider_args["sdk_framework"] = depset(
            direct = sdk_frameworks,
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

    if module_map:
        objc_provider_args["module_map"] = depset(direct = [module_map])

    return apple_common.new_objc_provider(**objc_provider_args)
