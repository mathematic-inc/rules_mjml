"""Public interface for a Bazel rule for building MJML documents"""

load("//mjml/private:mjml_library.bzl", _mjml_library = "mjml_library")

mjml_library = _mjml_library
