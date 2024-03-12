"""Defines a Bazel rule for building MJML documents"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:shell.bzl", "shell")

MjmlInfo = provider("Provider for MJML", fields = ["files"])

COMMON_ATTRS = {
    "srcs": attr.label_list(
        doc = "List of labels of Mailjet Markup source files or CSS files to be provided to the compiler.",
        mandatory = True,
        allow_files = [".mjml", ".css"],
    ),
    "deps": attr.label_list(
        doc = "List of labels of other Mailjet Markup libraries to be provided to the compiler.",
        providers = [MjmlInfo],
    ),
}

def _mjml_library_impl(ctx):
    deps = [] + ctx.files.srcs
    for dep in ctx.attr.deps:
        deps += dep[MjmlInfo].files

    return [
        MjmlInfo(files = deps),
        DefaultInfo(files = depset(ctx.files.srcs)),
    ]

mjml_library = rule(
    implementation = _mjml_library_impl,
    attrs = COMMON_ATTRS,
    provides = [MjmlInfo],
)

def _mjml_binary_impl(ctx):
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

    inputs = _mjml_library_impl(ctx)[0].files

    main = ctx.file.main
    if main:
        found = False
        for file in ctx.files.srcs:
            if file.path == main.path:
                found = True
                break
        if not found:
            fail("'main' attribute must be a .mjml file in 'srcs'")
    else:
        basename = ctx.label.name + ".mjml"
        for src in ctx.files.srcs:
            if src.basename == basename and src.owner.package == ctx.label.package:
                main = src
                break

        if main == None:
            fail("'main' attribute was not specified and {} could not be found".format(basename))

    out = ctx.actions.declare_file(paths.replace_extension(main.basename, ".html"))

    args = ctx.actions.args()
    args.add(main)
    args.add("-o", out)

    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
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

mjml_binary = rule(
    implementation = _mjml_binary_impl,
    attrs = {
        "main": attr.label(
            doc = "The main MJML file to compile. If unspecified, the name of the rule + '.mjml' is used.",
            allow_single_file = [".mjml"],
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
    } | COMMON_ATTRS,
)
