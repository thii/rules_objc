load(
    "@build_bazel_rules_swift//swift/internal:utils.bzl",
    "owner_relative_path",
)
load("@bazel_skylib//lib:paths.bzl", "paths")

def _intermediate_frontend_file_path(target_name, src):
    """Returns the path to the directory for intermediate compile outputs.

    This is a helper function and is not exported in the `derived_files` module.

    Args:
        target_name: The name of hte target being built.
        src: A `File` representing the source file whose intermediate frontend
            artifacts path should be returned.

    Returns:
        The path to the directory where intermediate artifacts for the given
        target and source file should be stored.
    """
    objs_dir = "{}_objs".format(target_name)

    owner_rel_path = owner_relative_path(src).replace(" ", "__SPACE__")
    safe_name = paths.basename(owner_rel_path)

    return paths.join(objs_dir, paths.dirname(owner_rel_path)), safe_name

def _intermediate_file(actions, extension, target_name, src):
    dirname, basename = _intermediate_frontend_file_path(target_name, src)
    return actions.declare_file(
        paths.join(dirname, "{}{}".format(basename, extension)),
    )

def intermediate_dependency_file(**kwargs):
    """Declares a file for an intermediate dependency file during compilation.

    Args:
        actions: The context's actions object.
        target_name: The name of the target being built.
        src: A `File` representing the source file being compiled.

    Returns:
        The declared `File`.
    """
    return _intermediate_file(
        extension = ".d",
        **kwargs
    )

def intermediate_object_file(**kwargs):
    """Declares a file for an intermediate object file during compilation.

    Args:
        actions: The context's actions object.
        target_name: The name of the target being built.
        src: A `File` representing the source file being compiled.

    Returns:
        The declared `File`.
    """
    return _intermediate_file(
        extension = ".o",
        **kwargs
    )
