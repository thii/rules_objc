CPP_FILE_TYPES = [".cc", ".cpp", ".mm", ".cxx", ".C"]

NON_CPP_FILE_TYPES = [".m", ".c"]

ASSEMBLY_FILE_TYPES = [".s", ".S", ".asm"]

OBJECT_FILE_FILE_TYPES = [".o"]

HEADERS_FILE_TYPES = [
    ".h",
    ".hh",
    ".hpp",
    ".ipp",
    ".hxx",
    ".h++",
    ".inc",
    ".inl",
    ".tlh",
    ".tli",
    ".H",
    ".hmap",
]

OBJC_FILE_TYPES = CPP_FILE_TYPES + NON_CPP_FILE_TYPES + ASSEMBLY_FILE_TYPES + \
                  OBJECT_FILE_FILE_TYPES + HEADERS_FILE_TYPES
