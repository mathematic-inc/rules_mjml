"""Defines a Bazel rule for building MJML documents"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:shell.bzl", "shell")

def _mjml_library_impl(ctx):
    if len(ctx.files.srcs) != 1:
        fail("Exactly one source file is required")

    c_mode = ctx.var["COMPILATION_MODE"] == "opt" and "production" or "development"

    opts = ctx.actions.args()
    opts.add("-l", "strict")
    if c_mode == "production":
        opts.add("--config.minify", True)
        opts.add("--config.beautify", False)
        opts.add("--config.keepComments", False)
        opts.add("--config.minifyOptions", shell.quote(ctx.attr.minify_options))
    else:
        opts.add("--config.minify", False)
        opts.add("--config.beautify", True)
        opts.add("--config.keepComments", True)

    src = ctx.files.srcs[0]
    out = ctx.actions.declare_file(paths.replace_extension(src.basename, ".html"))

    args = ctx.actions.args()
    args.add(src)
    args.add("-o", out)

    ctx.actions.run(
        outputs = [out],
        inputs = [src],
        mnemonic = "MjmlLibrary",
        executable = ctx.executable._mjml,
        arguments = [args, opts],
        env = {
            # This breaks on Windows. rules_js should be updated to
            # support this path.
            "BAZEL_BINDIR": ".",
        },
    )

    return [DefaultInfo(files = depset([out]))]

mjml_library = rule(
    implementation = _mjml_library_impl,
    attrs = {
        "srcs": attr.label_list(
            doc = "List of labels of Mailjet Markup source files to be provided to the compiler.",
            mandatory = True,
            allow_files = [".mjml"],
        ),
        "minify_options": attr.string(
            doc = "Options for minifying output. See [html-minifier](https://github.com/kangax/html-minifier) for options.",
            default = """
            {
                "collapseWhitespace": true,
                "minifyCSS": false,
                "removeEmptyAttributes": true
            }
            """,
        ),
        "_mjml": attr.label(
            cfg = "exec",
            default = "//mjml/toolchain:mjml",
            doc = "The mjml executable to use",
            executable = True,
        ),
    },
)
