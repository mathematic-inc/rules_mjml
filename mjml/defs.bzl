"""Public interface for a Bazel rule for building MJML documents"""

load("//mjml/private:mjml.bzl", _mjml_binary = "mjml_binary", _mjml_library = "mjml_library")

mjml_library = _mjml_library
mjml_binary = _mjml_binary
