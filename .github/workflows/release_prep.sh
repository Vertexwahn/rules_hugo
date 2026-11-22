#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Copied from https://github.com/bazel-contrib/rules-template (at hash 2154387cb9c634b68139f6e280dba10fc08e9f75)
# Available under Apache-2.0 license
# Copyright belongs to contributors of rules-template (see https://github.com/bazel-contrib/rules-template/graphs/contributors)
# Some modification where applied with are also available under Apache-2.0 license

# Set by GH actions, see
# https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
TAG=${GITHUB_REF_NAME}
# The prefix is chosen to match what GitHub generates for source archives
PREFIX="rules_hugo-${TAG}"
ARCHIVE="rules_hugo-$TAG.tar.gz"
git archive --format=tar --prefix=${PREFIX}/ ${TAG} | gzip > $ARCHIVE
SHA=$(shasum -a 256 $ARCHIVE | awk '{print $1}')

cat << EOF
## Using Bzlmod
Add to your \`MODULE.bazel\` file:
\`\`\`starlark
bazel_dep(name = "rules_hugo", version = "${TAG}")

hugo = use_extension("@rules_hugo//hugo:extensions.bzl", "hugo")
hugo.download(
    extended = True,
    sha256 = "c41672a0725d307758a132bc94a962e59760eb33f9ba08c991b81f9881d6fa7d",
    sha256_darwin = "d48dfd5adab308f941e83e48c5ba925747cf383395972278942cf526ad27cf38",
    sha256_windows = "396b4c8326dc2dd61c2618f825042781c5ea43e1ac1375a2204a9fde4e98b84c",
    version = "0.169.0",
)
use_repo(hugo, "hugo")
EOF

echo "\`\`\`"
