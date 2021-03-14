#!/bin/bash

set -euo pipefail

bazelisk test -- @build_bazel_rules_apple//test/starlark_tests/... \
  -@build_bazel_rules_apple//test/starlark_tests:dtrace_compile_generates_expected_header_contents \
  -@build_bazel_rules_apple//test/starlark_tests:ios_app_clip_linkmap_test \
  -@build_bazel_rules_apple//test/starlark_tests:ios_application_custom_executable_name_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:ios_application_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:ios_application_linkmap_test \
  -@build_bazel_rules_apple//test/starlark_tests:ios_extension_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:ios_extension_linkmap_test \
  -@build_bazel_rules_apple//test/starlark_tests:ios_ui_test_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:ios_unit_test_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:macos_application_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:macos_bundle_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:macos_command_line_application_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:macos_dylib_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:macos_ui_test_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:macos_unit_test_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:tvos_application_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:tvos_application_linkmap_test \
  -@build_bazel_rules_apple//test/starlark_tests:tvos_extension_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:tvos_ui_test_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:tvos_unit_test_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:watchos_extension_dsyms_test \
  -@build_bazel_rules_apple//test/starlark_tests:watchos_extension_linkmap_test
