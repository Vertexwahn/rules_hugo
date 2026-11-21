load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

HUGO_BUILD_FILE = """
package(default_visibility = ["//visibility:public"])
exports_files(["hugo"])
"""

HUGO_WINDOWS_BUILD_FILE = """
package(default_visibility = ["//visibility:public"])
exports_files(["hugo.exe"])
alias(
    name = "hugo",
    actual = ":hugo.exe",
)
"""

def _hugo_repository_impl(repository_ctx):
    hugo = "hugo"
    if repository_ctx.attr.extended:
        hugo = "hugo_extended"

    os_name = repository_ctx.os.name.lower()
    if "windows" in os_name:
        os_arch = repository_ctx.attr.os_arch or "windows-amd64"
        archive_type = "zip"
        sha256 = repository_ctx.attr.sha256_windows
        build_file = HUGO_WINDOWS_BUILD_FILE
    elif "mac" in os_name or "darwin" in os_name:
        os_arch = repository_ctx.attr.os_arch or "darwin-universal"
        archive_type = "pkg"
        sha256 = repository_ctx.attr.sha256_darwin
        build_file = HUGO_BUILD_FILE
    else:
        os_arch = repository_ctx.attr.os_arch or "Linux-64bit"
        archive_type = "tar.gz"
        sha256 = repository_ctx.attr.sha256
        build_file = HUGO_BUILD_FILE

    if not sha256:
        fail("A SHA-256 checksum must be provided for the current host platform")

    url = "https://github.com/gohugoio/hugo/releases/download/v{version}/{hugo}_{version}_{os_arch}.{archive_type}".format(
        hugo = hugo,
        os_arch = os_arch,
        archive_type = archive_type,
        version = repository_ctx.attr.version,
    )

    if archive_type == "pkg":
        repository_ctx.download(
            url = url,
            output = "hugo.pkg",
            sha256 = sha256,
        )
        expanded_path = repository_ctx.path("hugo-expanded")
        result = repository_ctx.execute([
            "/usr/sbin/pkgutil",
            "--expand-full",
            str(repository_ctx.path("hugo.pkg")),
            str(expanded_path),
        ])
        if result.return_code:
            fail("Failed to expand Hugo macOS package: %s" % result.stderr)

        result = repository_ctx.execute([
            "/usr/bin/find",
            str(expanded_path),
            "-type",
            "f",
            "-name",
            "hugo",
        ])
        if result.return_code:
            fail("Failed to locate Hugo in its macOS package: %s" % result.stderr)
        hugo_path = result.stdout.strip()
        if not hugo_path:
            fail("Hugo executable was not found in the macOS package")
        repository_ctx.symlink(hugo_path, "hugo")
    else:
        repository_ctx.download_and_extract(
            url = url,
            sha256 = sha256,
        )

    repository_ctx.file("BUILD.bazel", build_file)

hugo_repository = repository_rule(
    _hugo_repository_impl,
    attrs = {
        "version": attr.string(
            default = "0.55.5",
            doc = "The hugo version to use",
        ),
        "sha256": attr.string(
            doc = "The SHA-256 checksum of the Linux/macOS archive.",
        ),
        "sha256_windows": attr.string(
            doc = "The SHA-256 checksum of the Windows archive.",
        ),
        "sha256_darwin": attr.string(
            doc = "The SHA-256 checksum of the macOS package.",
        ),
        "os_arch": attr.string(
            doc = "The os arch value. If empty, autodetect it",
        ),
        "extended": attr.bool(
            doc = "Use extended hugo version",
        ),
    },
)
