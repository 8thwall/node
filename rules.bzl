load("//deps/v8:bazel/defs.bzl", "v8_target_cpu_transition")

def _node_mksnapshot_impl(ctx):
    out = ctx.actions.declare_file("node_snapshot.cc")
    if ctx.files.srcs:
      src_args = [ "--build-snapshot" ] + [x.path for x in ctx.files.srcs]
    else:
      src_args = []
    ctx.actions.run(
        outputs = [out],
        inputs = ctx.files.srcs,
        arguments = src_args + [ out.path ],
        executable = ctx.executable.tool,
        progress_message = "Running node_mksnapshot",
    )
    return [DefaultInfo(files = depset([out]))]

def _node_configure_impl(ctx):
    out = ctx.actions.declare_file("config.gypi")

    args = []
    if ctx.attr.shared:
        args.append("--shared")
    if ctx.attr.cross_compiling:
        args.append("--cross-compiling")

    args += [
        "--dest-os={}".format(ctx.attr.os),
        "--dest-cpu={}".format(ctx.attr.cpu),
        "--config-gypi-output={}".format(out.path),
    ]

    ctx.actions.run(
        outputs = [out],
        inputs = ctx.files.srcs,
        arguments = args,
        use_default_shell_env = True,
        executable = ctx.executable.configure_tool,
        progress_message = "Running node_configure",
    )

    return [DefaultInfo(files = depset([out]))]

node_mksnapshot = rule(
    implementation = _node_mksnapshot_impl,
    attrs = {
        "srcs": attr.label_list(
            default = [],
            allow_files = True,
        ),
        "tool": attr.label(
            mandatory = True,
            allow_single_file = True,
            executable = True,
            cfg = "exec",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    cfg = v8_target_cpu_transition,
)

node_configure = rule(
    implementation = _node_configure_impl,
    attrs = {
        "cross_compiling": attr.bool(
            mandatory = True,
        ),
        "shared": attr.bool(
            mandatory = True,
        ),
        "cpu": attr.string(
            mandatory = True,
        ),
        "os": attr.string(
            mandatory = True,
        ),
        "srcs": attr.label_list(
            default = [],
            allow_files = True,
        ),
        "configure_tool": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
    },
)
