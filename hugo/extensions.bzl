# SPDX-License-Identifier: Apache-2.0
"""Module extension that sets up the Hugo binary repository."""

load("//hugo:internal/hugo_repository.bzl", "hugo_repository")

_download = tag_class(
    attrs = {
        "name": attr.string(default = "hugo"),
        "version": attr.string(mandatory = True),
        "sha256": attr.string(),
        "sha256_windows": attr.string(),
        "sha256_darwin": attr.string(),
        "extended": attr.bool(default = False),
        "os_arch": attr.string(),
    },
)

def _hugo_impl(module_ctx):
    seen = {}
    for module in module_ctx.modules:
        for tag in module.tags.download:
            if tag.name in seen:
                continue
            seen[tag.name] = True
            hugo_repository(
                name = tag.name,
                version = tag.version,
                sha256 = tag.sha256,
                sha256_windows = tag.sha256_windows,
                sha256_darwin = tag.sha256_darwin,
                extended = tag.extended,
                os_arch = tag.os_arch,
            )

hugo = module_extension(
    implementation = _hugo_impl,
    tag_classes = {"download": _download},
)
