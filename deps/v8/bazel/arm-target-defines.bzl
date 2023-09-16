# Embed data in your object files. Try to avoid doing this in most situations,
# as it increases binary size, and instead use it when it really makes sense.

load(":bazel/defs.bzl", "v8_target_platform_transition")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

def _generate_arm_target_defines_impl(ctx):
    hFilename = ctx.label.name + ".h"
    hFile = ctx.actions.declare_file(hFilename)

    hLines = ["#pragma once"]

    toolchain = find_cpp_toolchain(ctx)

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    built_in_includes = depset([inc for inc in toolchain.built_in_include_directories if not inc.endswith("/Frameworks")])
    built_in_frameworks = depset([inc for inc in toolchain.built_in_include_directories if inc.endswith("/Frameworks")])

    cpp_compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = toolchain,
        user_compile_flags = ctx.fragments.cpp.copts,
        system_include_directories = built_in_includes,
        framework_include_directories = built_in_frameworks,
    )

    action_name = "c-compile"

    cpp_options = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = action_name,
        variables = cpp_compile_variables,
    )

    args = [
        cc_common.get_tool_for_action(feature_configuration = feature_configuration, action_name = action_name),
    ]
    args += cpp_options
    args.append("-E -dM - < /dev/null | grep __ARM | sed '1s/^/#pragma once\\n\\n/' > {out}".format(out = hFile.path))

    env = cc_common.get_environment_variables(feature_configuration = feature_configuration, action_name = action_name, variables = cpp_compile_variables)

    ctx.actions.run_shell(
        inputs = [],
        tools = toolchain.all_files,
        outputs = [hFile],
        command = " ".join(args),
        mnemonic = "GenerateArmDefinesHeader",
        progress_message = "Generating " + hFilename,
        env = env,
    )
    return [
        DefaultInfo(
            files = depset([hFile]),
        ),
    ]

def _arm_target_defines_impl(ctx):
    hFilename = ctx.label.name + ".h"
    hFile = ctx.actions.declare_file(hFilename)

    if ctx.attr.src:
        ctx.actions.run_shell(
            inputs = [ctx.file.src],
            outputs = [hFile],
            command = "cp {src} {dst}".format(src = ctx.file.src.path, dst = hFile.path),
            mnemonic = "CopyTargetArmDefines",
            progress_message = "Generating " + hFilename,
        )
    else:
        ctx.actions.write(hFile, "#pragma once\n// Not an ARM target cpu.\n")

    return [
        DefaultInfo(
            files = depset([hFile]),
        ),
    ]

_generate_arm_target_defines = rule(
    implementation = _generate_arm_target_defines_impl,
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
    fragments = ["cpp"],
    attrs = {
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    cfg = v8_target_platform_transition,
)

_arm_target_defines = rule(
    implementation = _arm_target_defines_impl,
    attrs = {
        "src": attr.label(default = None, allow_single_file = True),
    },
)

def arm_target_defines(name, **kwargs):
    target_name = "{}-for-target"
    _generate_arm_target_defines(name = target_name)
    _arm_target_defines(name = name, src = ":{}".format(target_name), **kwargs)
