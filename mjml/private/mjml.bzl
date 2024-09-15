"""Defines a Bazel rule for building MJML documents"""

load("@aspect_bazel_lib//lib:copy_to_bin.bzl", "COPY_FILE_TO_BIN_TOOLCHAINS", "copy_files_to_bin_actions")
load("@bazel_skylib//lib:paths.bzl", "paths")

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
    files = [] + copy_files_to_bin_actions(ctx = ctx, files = ctx.files.srcs)
    for dep in ctx.attr.deps:
        files += dep[MjmlInfo].files

    return [
        MjmlInfo(files = files),
        DefaultInfo(files = depset(ctx.files.srcs)),
    ]

mjml_library = rule(
    implementation = _mjml_library_impl,
    attrs = COMMON_ATTRS,
    provides = [MjmlInfo],
    toolchains = COPY_FILE_TO_BIN_TOOLCHAINS,
)

def _mjml_binary_impl(ctx):
    c_mode = ctx.var["COMPILATION_MODE"] == "opt" and "production" or "development"

    opts = ctx.actions.args()
    opts.add("-l", "strict")
    if c_mode == "production":
        opts.add("--config.minify", True)
        opts.add("--config.beautify", False)
        opts.add("--config.keepComments", False)
        opts.add("--config.minifyOptions", ctx.attr.minify_options)
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
        main_short_path = "/".join([ctx.label.package, basename]) if ctx.label.package else basename
        for src in ctx.files.srcs:
            if src.short_path == main_short_path:
                main = src
                break

        if main == None:
            fail("'main' attribute was not specified and {} could not be found".format(basename))

    out = ctx.actions.declare_file(paths.replace_extension(main.basename, ".html"), sibling = main)

    args = ctx.actions.args()
    args.add(main.short_path)
    args.add("-o", out.short_path)

    ctx.actions.run(
        outputs = [out],
        inputs = inputs,
        mnemonic = "MjmlLibrary",
        executable = ctx.executable._mjml,
        arguments = [args, opts],
        env = {
            "BAZEL_BINDIR": ctx.bin_dir.path,
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
            default = """{"collapseWhitespace":true,"minifyCSS":false,"removeEmptyAttributes":true}""",
        ),
        "_mjml": attr.label(
            cfg = "exec",
            default = "//mjml/toolchain:mjml",
            doc = "The mjml executable to use",
            executable = True,
        ),
    } | COMMON_ATTRS,
    toolchains = COPY_FILE_TO_BIN_TOOLCHAINS,
)
