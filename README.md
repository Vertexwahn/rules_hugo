# `rules_hugo`

This repository vendors `stackb/rules_hugo` at commit
`294a8ec626a394011d35397108c930be631ab9fa`, with Bzlmod support and Bazel 9
compatibility changes.

[![Build Status](https://api.cirrus-ci.com/github/stackb/rules_hugo.svg)](https://cirrus-ci.com/github/stackb/rules_hugo)


<table><tr>
<td><img src="https://raw.githubusercontent.com/bazelbuild/bazel-blog/master/images/bazel-icon.svg" height="120"/></td>
<td><img src="https://raw.githubusercontent.com/gohugoio/hugoDocs/master/static/img/hugo-logo.png" height="120"/></td>
</tr><tr>
<td>Rules</td>
<td>Hugo</td>
</tr></table>

[Bazel](https://bazel.build) rules for building static websites with [Hugo](https://gohugo.io).

## Repository Rules

|               Name   |  Description |
| -------------------: | :----------- |
| [hugo_repository](#hugo_repository) | Load hugo dependency for this repo. |
| [github_hugo_theme](#github_hugo_theme) | Load a hugo theme from github. |

## Build Rules

|               Name   |  Description |
| -------------------: | :----------- |
| [hugo_site](#hugo_site) | Declare a hugo site. |
| [hugo_theme](#hugo_theme) | Declare a hugo theme. |

## Usage

### Using Bzlmod

Add the module and the Hugo binary repository to your `MODULE.bazel`:

```python
bazel_dep(name = "rules_hugo", version = "0.1.0")

hugo = use_extension("@rules_hugo//hugo:extensions.bzl", "hugo")
hugo.download(
    extended = True,
    sha256 = "c41672a0725d307758a132bc94a962e59760eb33f9ba08c991b81f9881d6fa7d",
    sha256_darwin = "d48dfd5adab308f941e83e48c5ba925747cf383395972278942cf526ad27cf38",
    sha256_windows = "396b4c8326dc2dd61c2618f825042781c5ea43e1ac1375a2204a9fde4e98b84c",
    version = "0.169.0",
)
use_repo(hugo, "hugo")
```

Then load the rules from `@rules_hugo//hugo:rules.bzl` as shown below.

### Add rules_hugo to your WORKSPACE and add a theme from github

```python
# Update these to latest
RULES_HUGO_COMMIT = "..."
RULES_HUGO_SHA256 = "..."

http_archive(
    name = "build_stack_rules_hugo",
    url = "https://github.com/stackb/rules_hugo/archive/%s.zip" % RULES_HUGO_COMMIT,
    sha256 = RULES_HUGO_SHA256,
    strip_prefix = "rules_hugo-%s" % RULES_HUGO_COMMIT
)

load("@build_stack_rules_hugo//hugo:rules.bzl", "hugo_repository", "github_hugo_theme")

#
# Load hugo binary itself
#
# Optionally, load a specific version of Hugo, with the 'version' argument
hugo_repository(
    name = "hugo",
)

#
# This makes a filegroup target "@com_github_yihui_hugo_xmin//:files"
# available to your build files
#
github_hugo_theme(
    name = "com_github_yihui_hugo_xmin",
    owner = "yihui",
    repo = "hugo-xmin",
    commit = "c14ca049d0dd60386264ea68c91d8495809cc4c6",
)

#
# This creates a filegroup target from a released archive from GitHub
# this is useful when a theme uses compiled / aggregated sources NOT found
# in a source root.
#
http_archive(
    name = "com_github_thegeeklab_hugo_geekdoc",
    url = "https://github.com/thegeeklab/hugo-geekdoc/releases/download/v0.34.2/hugo-geekdoc.tar.gz",
    sha256 = "7fdd57f7d4450325a778629021c0fff5531dc8475de6c4ec70ab07e9484d400e",
    build_file_content="""
filegroup(
    name = "files",
    srcs = glob(["**"]),
    visibility = ["//visibility:public"]
)
    """
)
```

### Declare a hugo_site with a GitHub repository theme in your BUILD file

```python
load("@build_stack_rules_hugo//hugo:rules.bzl", "hugo_site", "hugo_theme", "hugo_serve")

# Declare a theme 'xmin'.  In this case the `name` and
# `theme_name` are identical, so the `theme_name` could be omitted in this case.
hugo_theme(
    name = "xmin",
    theme_name = "xmin",
    srcs = [
        "@com_github_yihui_hugo_xmin//:files",
    ],
)

# Declare a site. Config file is required.
my_site_name = "basic"

hugo_site(
    name = my_site_name,
    config = "config.toml",
    content = [
        "_index.md",
        "about.md",
    ],
    quiet = False,
    theme = ":xmin",
)

# Run local development server
hugo_serve(
    name = "local_%s" % my_site_name,
    dep = [":%s" % my_site_name],
)

# Tar it up
pkg_tar(
    name = "%s_tar" % my_site_name,
    srcs = [":%s" % my_site_name],
)
```

### Declare a hugo_site with a GitHub released archive theme in your BUILD file
```python
load("@build_stack_rules_hugo//hugo:rules.bzl", "hugo_site", "hugo_theme", "hugo_serve")

hugo_theme(
    name = "hugo_theme_geekdoc",
    theme_name = "hugo-geekdoc",
    srcs = [
        "@com_github_thegeeklab_hugo_geekdoc//:files",
    ],
)

# Note, here we are using the config_dir attribute to support multi-lingual configurations.
hugo_site(
    name = "site_complex",
    config_dir = glob(["config/**"]),
    content = glob(["content/**"]),
    data = glob(["data/**"]),
    quiet = False,
    theme = ":hugo_theme_geekdoc",
)

# Run local development server
hugo_serve(
    name = "serve",
    dep = [":site_complex"],
)
```

### Previewing the site

Execute the following command:

```shell
bazel run //site_complex:serve
```

Then open your browser: [here](http://localhost:1313)

For live updates while editing workspace files, point `hugo_serve` at the
site's workspace-relative source directory. This runs Hugo against the real
files instead of a staged build output:

```python
hugo_serve(
    name = "serve",
    source_dir = "path/to/site",
)
```

`bazel run //path/to/site:serve` then watches changes and rebuilds the preview.
The existing `dep` mode remains available for serving a staged site.

On Windows, `hugo_serve` generates a batch file instead of a Bash script, so
`bazel run` can start it directly. It works with and without `--enable_runfiles`.


### Build the site

The `hugo_site` target emits the output in the `bazel-bin` directory.

```sh
$ bazel build :basic
[...]
Target //:basic up-to-date:
  bazel-bin/basic
[...]
```
```sh
$ tree bazel-bin/basic
bazel-bin/basic
├── 404.html
├── about
│   └── index.html
[...]
```

The `pkg_tar` target emits a `%{name}_tar.tar` file containing all the Hugo output files.

```sh
$ bazel build :basic_tar
[...]
Target //:basic up-to-date:
  bazel-bin/basic_tar.tar
```

## Releasing

Pushing a version tag such as `0.1.0` runs the release workflow, builds the
test targets, creates a GitHub Release, and then opens a draft pull request to
the [Bazel Central Registry](https://github.com/bazelbuild/bazel-central-registry).
The BCR presubmit configuration is in `.bcr/presubmit.yml`.

Configure the `BCR_PUBLISH_TOKEN` Actions secret with a classic GitHub personal
access token that has `repo` and `workflow` permissions. The publish workflow uses
the `Vertexwahn/bazel-central-registry` fork and can be rerun manually from Actions
with the release tag if BCR publishing needs to be retried.

The source of truth for these rules is
[`Vertexwahn/Piper`](https://github.com/Vertexwahn/Piper), directory
`devertexwahn/bazel/rules/rules_hugo`. This repository is a read-only mirror
created with Copybara; changes must be made in Piper and synced with
`copy.bara.sky`.

## End

See source code for details about additional rule attributes / parameters.
