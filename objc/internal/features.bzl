"""Helper functions for working with Bazel features."""

def features_for_compilation_mode(compilation_mode):
    return [compilation_mode]

def default_features():
    return [
        "apply_default_compiler_flags",
        "apply_default_warnings",
    ]
