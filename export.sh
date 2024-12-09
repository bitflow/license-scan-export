#!/usr/bin/env bash

# This script will copy all files with dependency definitions or checked in binary dependencies.
# It will not search the source code for copied source files!
# If you are using a language or package manager that is missing here, let us know!

set -euo pipefail # exit on error, error on undef var, error on any fail in pipe (not just last cmd); add -x to print each cmd
trap 'echo "ERROR: $BASH_SOURCE:$LINENO $BASH_COMMAND" >&2' ERR

# dst="bitflow-license-scan"
# rm -rf $dst
# mkdir --parents $dst
dst=$(mktemp -d)
trap 'rm -rf -- "$dst"' EXIT # clean up temp dir on premature exit

function copy() {
  results=$(find -L -iname "$1")
  if [ -z "$results" ]; then
    echo "No $1"
  else
    n=$(echo "$results" | wc -l)
    echo "Copy $n $1"
    cp -L --parents $results $dst
  fi
}

# JS/TS
copy "package.json" # any
copy "package-lock.json" # npm
copy "pnpm-lock.yaml" # pnpm
copy "yarn.lock" # yarn
copy "deno.lock" # deno
copy "bun.lockb" # bun

# Python
# https://dev.to/adamghill/python-package-manager-comparison-1g98
copy "requirements.txt" # pip: contains arguments for `pip install`
copy "setup.py" # needed to know about setup of internal packages
copy "pyproject.toml" # poetry, pdm, hatch, rye. uv
copy "poetry.lock" # poetry
copy ".venv" # virtual environments

# Ruby
copy "Gemfile" # gem
copy "Gemfile.lock"

# Java
copy "pom.xml" # mvn (Maven)
copy "build.xml" # ant
copy "*.jar" # individual jar files

# .NET
#  XML files with e.g. <PackageReference Include="Newtonsoft.Json" Version="13.0.1" />
copy "packages.config" # old format for .NET Framework projects
copy "*.csproj" # C#
copy "*.fsproj" # F#
copy "*.vbproj" # Visual Basic
copy "*.vcxproj" # C++
copy "nuget.config" # for local NuGet packages
copy "*.nupkg" # local NuGet package

# GO
# https://go.dev/wiki/Modules#quick-start
# https://go.dev/ref/mod
# https://go.dev/blog/migrating-to-go-modules see 'other supported formats'
copy "go.mod" # Go module (default)
copy "Godeps.json"
copy "GLOCKFILE"
copy "Gopkg.lock"
copy "dependencies.tsv"
copy "glide.lock"
copy "vendor.conf"
copy "vendor.yml"
copy "vendor.json"

# Rust
copy "Cargo.toml"
copy "Cargo.lock"

# PHP
copy "composer.json"
copy "composer.lock"

# Perl

echo
tree $dst

echo
zip="bitflow-license-scan.zip"
echo "Generating $zip"
rm -f $zip
zip -rq $zip $dst
rm -rf $dst
