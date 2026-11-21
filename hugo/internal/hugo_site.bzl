load("//hugo:internal/hugo_theme.bzl", "HugoThemeInfo")

def relative_path(src, dirname):
    """Given a src File and a directory it's under, return the relative path.

    Args:
        src: File(path/to/site/content/docs/example1.md)
        dirname: string("content")

    Returns:
        string
    """

    # Find the last path segment that matches the given dirname, and return that
    # substring.
    if src.short_path.startswith("/"):
        i = src.short_path.rfind("/%s/" % dirname)
        if i == -1:
            fail("failed to get relative path: couldn't find %s in %s" % (dirname, src.short_path))
        return src.short_path[i + 1:]

    i = src.short_path.rfind("%s/" % dirname)
    if i == -1:
        fail("failed to get relative path: couldn't find %s in %s" % (dirname, src.short_path))
    return src.short_path[i:]

def copy_to_dir(ctx, srcs, dirname):
    outs = []
    for i in srcs:
        if i.is_source:
            o = ctx.actions.declare_file(relative_path(i, dirname))
            ctx.actions.run_shell(
                inputs = [i],
                outputs = [o],
                command = 'cp -r -L "$1" "$2"',
                arguments = [i.path, o.path],
            )
            outs.append(o)
        else:
            outs.append(i)
    return outs

def _hugo_site_impl(ctx):
    hugo = ctx.executable.hugo
    hugo_inputs = []
    hugo_outputdir = ctx.actions.declare_directory(ctx.label.name)
    hugo_outputs = [hugo_outputdir]
    hugo_args = []

    if ctx.file.config == None and (ctx.files.config_dir == None or len(ctx.files.config_dir) == 0):
        fail("You must provide either a config file or a config_dir")

    # Copy the config file into place
    config_dir = ctx.files.config_dir

    if config_dir == None or len(config_dir) == 0:
        config_file = ctx.actions.declare_file(ctx.file.config.basename)

        ctx.actions.run_shell(
            inputs = [ctx.file.config],
            outputs = [config_file],
            command = 'cp -L "$1" "$2"',
            arguments = [ctx.file.config.path, config_file.path],
        )

        hugo_inputs.append(config_file)

        hugo_args += [
            "--source",
            config_file.dirname,
        ]
    else:
        placeholder_file = ctx.actions.declare_file(".placeholder")
        ctx.actions.write(placeholder_file, "paceholder", is_executable = False)
        hugo_inputs.append(placeholder_file)

        #  placeholder_file.dirname + "/config/_default/config.yaml",
        hugo_args += [
            "--source",
            placeholder_file.dirname,
        ]

    # Copy all the files over
    for name, srcs in {
        "archetypes": ctx.files.archetypes,
        "assets": ctx.files.assets,
        "content": ctx.files.content,
        "data": ctx.files.data,
        "i18n": ctx.files.i18n,
        "images": ctx.files.images,
        "layouts": ctx.files.layouts,
        "static": ctx.files.static,
        "config": ctx.files.config_dir,
    }.items():
        hugo_inputs += copy_to_dir(ctx, srcs, name)

    # Copy the themes
    themes = []
    if ctx.attr.theme:
        theme = ctx.attr.theme[HugoThemeInfo]
        themes.append(theme)
        hugo_args += ["--theme", theme.name]
    for theme_target in ctx.attr.themes:
        themes.append(theme_target[HugoThemeInfo])

    for theme in themes:
        for i in theme.files.to_list():
            path_list = i.short_path.split("/")
            if i.short_path.startswith("../"):
                o_filename = "/".join(["themes", theme.name] + path_list[2:])
            elif i.short_path[len(theme.path):].startswith("/themes"):  # check if themes is the first dir after theme path
                indx = path_list.index("themes")
                o_filename = "/".join(["themes", theme.name] + path_list[indx + 2:])
            else:
                o_filename = "/".join(["themes", theme.name, i.short_path[len(theme.path):]])
            o = ctx.actions.declare_file(o_filename)
            ctx.actions.run_shell(
                inputs = [i],
                outputs = [o],
                command = 'cp -r -L "$1" "$2"',
                arguments = [i.path, o.path],
            )
            hugo_inputs.append(o)

    # Prepare hugo command
    hugo_args += [
        "--destination",
        ctx.label.name,
    ]

    if ctx.attr.quiet:
        hugo_args.append("--quiet")
    if ctx.attr.verbose:
        hugo_args += ["--logLevel", "debug"]
    if ctx.attr.base_url:
        hugo_args += ["--baseURL", ctx.attr.base_url]
    if ctx.attr.build_drafts:
        hugo_args += ["--buildDrafts"]

    ctx.actions.run(
        mnemonic = "GoHugo",
        progress_message = "Generating hugo site",
        executable = hugo,
        arguments = hugo_args,
        inputs = hugo_inputs,
        outputs = hugo_outputs,
        tools = [hugo],
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    files = depset([hugo_outputdir])
    runfiles = ctx.runfiles(files = [hugo_outputdir] + hugo_inputs)

    return [DefaultInfo(
        files = files,
        runfiles = runfiles,
    )]

hugo_site = rule(
    attrs = {
        # Hugo config file
        "config": attr.label(
            allow_single_file = [
                ".toml",
                ".yaml",
                ".yml",
                ".json",
            ],
        ),
        # For use of config directories
        "config_dir": attr.label_list(
            allow_files = True,
        ),
        # Files to be included in the content/ subdir
        "content": attr.label_list(
            allow_files = True,
            mandatory = True,
        ),
        # Files to be included in the archetypes/ subdir
        "archetypes": attr.label_list(
            allow_files = True,
        ),
        # Files to be included in the static/ subdir
        "static": attr.label_list(
            allow_files = True,
        ),
        # Files to be included in the images/ subdir
        "images": attr.label_list(
            allow_files = True,
        ),
        # Files to be included in the layouts/ subdir
        "layouts": attr.label_list(
            allow_files = True,
        ),
        # Files to be included in the assets/ subdir
        "assets": attr.label_list(
            allow_files = True,
        ),
        # Files to be included in the data/ subdir
        "data": attr.label_list(
            allow_files = True,
        ),
        # Files to be included in the i18n/ subdir
        "i18n": attr.label_list(
            allow_files = True,
        ),
        # The hugo executable
        "hugo": attr.label(
            default = "@hugo//:hugo",
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
        # Optionally set the base_url as a hugo argument
        "base_url": attr.string(),
        "theme": attr.label(
            providers = [HugoThemeInfo],
        ),
        # Additional themes used by Hugo's config theme list.
        "themes": attr.label_list(
            providers = [HugoThemeInfo],
        ),
        # Emit quietly
        "quiet": attr.bool(
            default = True,
        ),
        # Emit verbose
        "verbose": attr.bool(
            default = False,
        ),
        # Build content marked as draft
        "build_drafts": attr.bool(
            default = False,
        ),
    },
    implementation = _hugo_site_impl,
)

_SERVE_SCRIPT_PREFIX = """#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

trap exit_gracefully SIGINT
function exit_gracefully() {
    exit 0;
}

"""
_SERVE_SCRIPT_TEMPLATE = """{source_check}{hugo_bin} serve -s {source_dir} {args}"""

# Windows cannot execute the bash script, so a batch file is generated instead.
# Hugo is looked up in the runfiles tree and, when runfiles are disabled (the
# Windows default), in the runfiles manifest.
_WINDOWS_SERVE_SCRIPT_TEMPLATE = """@echo off
setlocal
{source_check}set "HUGO=%~f0.runfiles\\{hugo_runfiles_path}"
if not exist "%HUGO%" if exist "%~f0.runfiles_manifest" (
  for /f "usebackq tokens=1,*" %%a in ("%~f0.runfiles_manifest") do (
    if "%%a"=="{hugo_rlocation_path}" set "HUGO=%%b"
  )
)
set "HUGO=%HUGO:/=\\%"
if not exist "%HUGO%" (
  echo Could not find {hugo_rlocation_path} in the runfiles 1>&2
  exit /b 1
)
"%HUGO%" serve -s {source_dir} {args}
"""

_WINDOWS_SOURCE_CHECK = """if not defined BUILD_WORKSPACE_DIRECTORY (
  echo Run this target with bazel run 1>&2
  exit /b 1
)
"""

def _rlocation_path(ctx, file):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]
    return ctx.workspace_name + "/" + file.short_path

def _windows_serve_script(ctx, hugo, hugo_args):
    if ctx.attr.source_dir:
        source_check = _WINDOWS_SOURCE_CHECK
        source_dir = '"%BUILD_WORKSPACE_DIRECTORY%/{}"'.format(ctx.attr.source_dir)
    else:
        source_check = ""

        # The trailing "." avoids a backslash escaping the closing quote.
        source_dir = '"%~dp0."'
    hugo_rlocation_path = _rlocation_path(ctx, hugo)
    script_content = _WINDOWS_SERVE_SCRIPT_TEMPLATE.format(
        source_check = source_check,
        hugo_runfiles_path = hugo_rlocation_path.replace("/", "\\"),
        hugo_rlocation_path = hugo_rlocation_path,
        source_dir = source_dir,
        args = " ".join(hugo_args),
    )

    # Normalize first: a CRLF checkout of this file leaves "\r" in the template.
    return script_content.replace("\r\n", "\n").replace("\n", "\r\n")

def _hugo_serve_impl(ctx):
    """Runs Hugo against workspace sources for live development updates."""
    if not ctx.attr.source_dir and not ctx.attr.dep:
        fail("hugo_serve requires either source_dir or dep")

    hugo = ctx.executable.hugo
    hugo_args = []

    if ctx.attr.quiet:
        hugo_args.append("--quiet")
    if ctx.attr.verbose:
        hugo_args += ["--logLevel", "debug"]
    if ctx.attr.disable_fast_render:
        hugo_args.append("--disableFastRender")

    executable_path = "./" + ctx.attr.hugo.files_to_run.executable.short_path

    runfiles = ctx.runfiles()
    runfiles = runfiles.merge(ctx.runfiles(files = [ctx.attr.hugo.files_to_run.executable]))

    for dep in ctx.attr.dep:
        runfiles = runfiles.merge(dep.default_runfiles).merge(dep.data_runfiles).merge(ctx.runfiles(files = dep.files.to_list()))

    is_windows = ctx.target_platform_has_constraint(
        ctx.attr._windows_constraint[platform_common.ConstraintValueInfo],
    )
    if is_windows:
        script = ctx.actions.declare_file("{}-serve.bat".format(ctx.label.name))
        script_content = _windows_serve_script(ctx, hugo, hugo_args)
    else:
        script = ctx.actions.declare_file("{}-serve".format(ctx.label.name))
        if ctx.attr.source_dir:
            source_check = 'if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then echo "Run this target with bazel run" >&2; exit 1; fi\n'
            source_dir = '"$BUILD_WORKSPACE_DIRECTORY/{}/"'.format(ctx.attr.source_dir)
        else:
            source_check = ""
            source_dir = '"$DIR"'
        script_content = _SERVE_SCRIPT_PREFIX + _SERVE_SCRIPT_TEMPLATE.format(
            hugo_bin = executable_path,
            source_check = source_check,
            source_dir = source_dir,
            args = " ".join(hugo_args),
        )
    ctx.actions.write(output = script, content = script_content, is_executable = True)

    return [DefaultInfo(executable = script, runfiles = runfiles)]

hugo_serve = rule(
    attrs = {
        # The hugo executable
        "hugo": attr.label(
            default = "@hugo//:hugo",
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
        "dep": attr.label_list(
            default = [],
        ),
        # Workspace-relative site directory to serve directly. Enables Hugo
        # to watch and rebuild as source files change.
        "source_dir": attr.string(),
        # Disable fast render
        "disable_fast_render": attr.bool(
            default = False,
        ),
        # Emit quietly
        "quiet": attr.bool(
            default = True,
        ),
        # Emit verbose
        "verbose": attr.bool(
            default = False,
        ),
        "_windows_constraint": attr.label(
            default = "@platforms//os:windows",
        ),
    },
    implementation = _hugo_serve_impl,
    executable = True,
)
