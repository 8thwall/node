"""Build rules to choose the v8 target os."""

load("@bazel_skylib//lib:selects.bzl", "selects")

V8OsTypeInfo = provider(
    doc = "A singleton provider that specifies the V8 target OS type",
    fields = {
        "value": "The V8 Target OS selected.",
    },
)

def _host_target_os_impl(ctx):
    allowed_values = ["android", "macos", "ios", "linux", "windows", "none"]
    os_type = ctx.build_setting_value
    if os_type in allowed_values:
        return V8OsTypeInfo(value = os_type)
    else:
        fail("Error setting " + str(ctx.label) + ": invalid v8 target os '" +
             os_type + "'. Allowed values are " + str(allowed_values))

v8_target_os = rule(
    implementation = _host_target_os_impl,
    build_setting = config.string(flag = True),
    doc = "OS that V8 will generate code for.",
)

def v8_configure_target_os(name, matching_configs):
    selects.config_setting_group(
        name = "is_" + name,
        match_any = matching_configs,
    )

    # If v8_target_os flag is set to 'name'
    native.config_setting(
        name = "v8_host_target_os_is_" + name,
        flag_values = {
            ":v8_target_os": name,
        },
    )

    # Default target if no v8_host_target_os flag is set.
    selects.config_setting_group(
        name = "v8_target_os_is_" + name,
        match_all = [
            ":v8_host_target_os_is_none",
            ":is_" + name,
        ],
    )

    # Select either the default target or the flag.
    selects.config_setting_group(
        name = "v8_target_" + name,
        match_any = [
            ":v8_host_target_os_is_" + name,
            ":v8_target_os_is_" + name,
        ],
    )
