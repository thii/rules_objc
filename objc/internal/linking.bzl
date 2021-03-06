"""Implementation of linking logic for Objective-C."""

load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load(
    "@rules_cc//cc:action_names.bzl",
    "CPP_LINK_STATIC_LIBRARY_ACTION_NAME",
)

# Verbatim imported from rules_apple, as that is not publicly loadable.
# https://github.com/bazelbuild/rules_apple/blob/5b7b85c0123815993f27200931dec3c69a528605/apple/apple_binary.bzl#L26-L41
def linker_flag_for_sdk_dylib(dylib):
    """Returns a linker flag suitable for linking the given `sdk_dylib` value.

    As does Bazel core, we strip a leading `lib` if it is present in the name
    of the library.

    Args:
        dylib: The name of the library, as specified in the `sdk_dylib`
            attribute.

    Returns:
        A linker flag used to link to the given library.
    """
    if dylib.startswith("lib"):
        dylib = dylib[3:]
    return "-l{}".format(dylib)

def register_static_library_link_action(
        actions,
        cc_toolchain,
        feature_configuration,
        objects,
        output,
        target_cpu):
    archiver_path = cc_common.get_tool_for_action(
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
        feature_configuration = feature_configuration,
    )
    archiver_variables = cc_common.create_link_variables(
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        is_using_linker = False,
        output_file = output.path,
    )
    command_line = cc_common.get_memory_inefficient_command_line(
        action_name = CPP_LINK_STATIC_LIBRARY_ACTION_NAME,
        feature_configuration = feature_configuration,
        variables = archiver_variables,
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

    args = actions.args()
    args.set_param_file_format("multiline")
    args.use_param_file(param_file_arg = "@%s", use_always = True)

    args.add_all([
        "-arch_only",
        target_cpu,
        "-syslibroot",
        apple_support.path_placeholders.sdkroot(),
    ])
    args.add_all(command_line)

    filelist_args = actions.args()
    args.add("-filelist")
    filelist_args.set_param_file_format("multiline")
    filelist_args.use_param_file(param_file_arg = "%s", use_always = True)
    filelist_args.add_all(objects)

    actions.run(
        arguments = [args, filelist_args],
        env = env,
        executable = archiver_path,
        execution_requirements = execution_requirements,
        inputs = depset(
            direct = objects,
            transitive = [
                cc_toolchain.all_files,
            ],
        ),
        mnemonic = "ObjcLink",
        outputs = [output],
        progress_message = "Linking {}".format(output.short_path),
    )
