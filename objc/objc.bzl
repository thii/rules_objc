load(
    "//objc/internal:objc_import.bzl",
    _objc_import = "objc_import",
)
load(
    "//objc/internal:objc_library.bzl",
    _objc_library = "objc_library",
)

objc_import = _objc_import
objc_library = _objc_library
