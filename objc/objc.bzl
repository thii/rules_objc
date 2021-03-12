load(
    "//objc/internal:apple_static_library.bzl",
    _apple_static_library = "apple_static_library",
)
load(
    "//objc/internal:objc_import.bzl",
    _objc_import = "objc_import",
)
load(
    "//objc/internal:objc_library.bzl",
    _objc_library = "objc_library",
)

apple_static_library = _apple_static_library
objc_import = _objc_import
objc_library = _objc_library
