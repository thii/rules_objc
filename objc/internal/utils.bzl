"""Common utility definitions."""

def collect_objc_libraries(deps):
    """Returns a list of libraries referenced in the given `deps`'s `ObjcProvider`.

    Args:
        deps: The dependencies whose libraries should be returned.

    Returns:
        The list of libraries provided in `deps`'s `ObjcProvider`.
    """
    libraries = []

    for x in deps:
        if apple_common.Objc in x:
            libraries.extend(x[apple_common.Objc].library.to_list())

    return libraries

def expand_locations_and_make_variables(ctx, attr, values, targets = []):
    """Expands the `$(location)` placeholders and Make variables in each of the given values.

    Args:
        ctx: The rule context.
        values: A list of strings, which may contain `$(location)`
            placeholders, and predefined Make variables.
        targets: A list of additional targets (other than the calling rule's
           `deps`) that should be searched for substitutable labels.

    Returns:
        A list of strings with any `$(location)` placeholders and Make
            variables expanded.
    """
    return_values = []
    for value in values:
        expanded_value = ctx.expand_location(
            value,
            targets = targets,
        )
        expanded_value = ctx.expand_make_variables(
            attr,
            expanded_value,
            {},
        )
        return_values.append(expanded_value)

    return return_values
