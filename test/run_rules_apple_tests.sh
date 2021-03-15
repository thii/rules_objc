#!/bin/bash

set -euo pipefail

bazelisk test -- @build_bazel_rules_apple//test/starlark_tests/...
