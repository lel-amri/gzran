#!/bin/sh
set -eu

# Define the upstream repo URL
upstream_remote_url="https://go.googlesource.com/go"

# Define the local working repository path
workrepo="$(mktemp -d)"

# Create the local working repository
git init --bare "$workrepo"

# Add upstream as a remote to the local working repository
git -C "$workrepo" remote add origin "$upstream_remote_url"

# List upstream repo branches
upstream_branches="$(git -C "$workrepo" ls-remote --branches origin | tail -n +2 | cut -f 2 | grep '^refs/heads/release-branch.go[0-9]*\(\.[0-9]*\)\{0,1\}$' | sed 's~^refs/heads/\(.*\)$~\1~')"

# List upstream repo tags
upstream_tags="$(git -C "$workrepo" ls-remote --tags origin | tail -n +2 | cut -f 2 | grep '^refs/tags/go[0-9]*\(\.[0-9]*\)\{1,2\}$' | sed 's~^refs/tags/\(.*\)$~\1~')"

# Fetch upstream branches and tags to local working repository
{ printf '%s\n' "$upstream_branches" | sed 's~^\(.*\)$~+refs/heads/\1:refs/heads/\1~' ; printf '%s\n' "$upstream_tags" | sed 's~^\(.*\)$~+refs/tags/\1:refs/tags/\1~' ; } | xargs git -C "$workrepo" fetch -fn origin

# Filter the local working repository
git -C "$workrepo" filter-repo --path-regex 'src/(pkg/|lib/)?compress/(flate|gzip)' --path-regex 'src/(pkg/|lib/)?compress/testdata/e\.txt' --path-match src/testdata/Isaac\.Newton-Opticks.txt --force

# Fetch upstream branches and tags to local working repository
{ printf '%s\n' "$upstream_branches" | sed 's~^\(.*\)$~+refs/heads/\1:refs/heads/upstream/\1~' ; printf '%s\n' "$upstream_tags" | sed 's~^\(.*\)$~+refs/tags/\1:refs/tags/upstream/\1~' ; } | xargs git fetch -fn "$workrepo"

# Remove the local working repository
rm -rf "$workrepo"
