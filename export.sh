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

# directories that are always skipped (unless they are what we are looking for, see copy ".venv"):
# .git: no dependency files, node_modules: installed packages (covered by the lock files), .venv: copied as a whole below
skip_always=(.git node_modules .venv)

# print all files matching $1 null-separated
# $1 is matched against the file name, or against the end of the path if it contains a /, e.g. "requirements/*.txt"
# optional further args are names of directories to skip, e.g. build output: files "*.dll" bin obj
function files() {
  local pattern=$1; shift
  local prune=() d
  for d in "${skip_always[@]}" "$@"; do
    [ "$d" = "$pattern" ] && continue
    prune+=(-type d -name "$d" -prune -o)
  done
  if [[ $pattern == */* ]]; then
    find -L . "${prune[@]}" -ipath "*/$pattern" -print0
  else
    find -L . "${prune[@]}" -iname "$pattern" -print0
  fi
}

# copy all files matching $1 to $dst, preserving the folder structure; arguments as for `files`
# (portable replacement for GNU-only `cp --parents`, also works for paths with spaces)
function copy() {
  local f n=0
  while IFS= read -r -d '' f; do
    mkdir -p "$dst/$(dirname "$f")"
    cp -RLp "$f" "$dst/$f"
    n=$((n+1))
  done < <(files "$@")
  if [ $n -eq 0 ]; then
    echo "No $1"
  else
    echo "Copy $n $1"
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

# .NET (common to C#, F#, Visual Basic, C++/CLI)
# NuGet
copy "packages.config" # old format for .NET Framework projects (instead of <PackageReference> in project files)
copy "packages.lock.json" # NuGet lock file (RestorePackagesWithLockFile): exact versions incl. transitive deps
copy "nuget.config" # package sources, e.g. for local/internal NuGet packages
copy "*.nupkg" # local NuGet package
copy "*.nuspec" # definition of internal NuGet packages (like setup.py for Python)
# MSBuild: files imported by project files, may contain <PackageReference> or <PackageVersion>
copy "*.props" # incl. Directory.Packages.props (Central Package Management: project files then have <PackageReference> without Version!) and Directory.Build.props (implicitly imported by all projects below it)
copy "*.targets" # incl. Directory.Build.targets
copy "global.json" # .NET SDK version and MSBuild project SDKs (msbuild-sdks, which are NuGet packages)
copy "dotnet-tools.json" # local .NET tools (usually in .config/), e.g. dotnet-ef
copy "*.sln" # solution: which projects belong together
copy "*.slnx" # solution (new XML format)
# Paket: alternative package manager (common for F#), replaces <PackageReference>
copy "paket.dependencies"
copy "paket.lock"
# checked in binary references, e.g. <Reference Include="Foo"><HintPath>lib\Foo.dll</HintPath></Reference>
copy "*.dll" bin obj packages # skip build output and restored packages (covered by *.nupkg)

# C#
#  XML project files with e.g. <PackageReference Include="Newtonsoft.Json" Version="13.0.1" />
copy "*.csproj"

# F#
copy "*.fsproj"

# Visual Basic
copy "*.vbproj"

# C/C++
copy "*.vcxproj" # MSBuild project, NuGet packages via packages.config (see .NET)
copy "vcpkg.json" # vcpkg manifest
copy "vcpkg-configuration.json" # vcpkg registries and baseline
copy "conanfile.txt" # Conan
copy "conanfile.py"
copy "conan.lock"
copy "CMakeLists.txt" build # CMake: find_package, FetchContent, CPM.cmake; skip build output
copy "meson.build" build # Meson: dependency()
copy "subprojects/*.wrap" # Meson: wrap files with source URLs and versions of subprojects

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
(cd $dst && zip -rq "$OLDPWD/$zip" .) # zip from inside $dst to not include the temp dir path in the archive
rm -rf $dst
