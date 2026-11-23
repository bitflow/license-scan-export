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
start_utc=$(date -u +%Y%m%dT%H%M%SZ) # for file names to tell runs apart (ISO 8601 basic format, sorts chronologically), same as in scan.sh
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
info="$dst/bitflow-license-scan-info.txt" # meta data about the export for reproducibility

# read-only git command in directory $1; safe.directory: repos may be owned by another user, e.g. copied into a Docker container
function g() {
  local d=$1; shift
  git -c safe.directory='*' -C "$d" "$@"
}

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
copy "npm-shrinkwrap.json" # npm: lock file that is published with a package
copy "pnpm-lock.yaml" # pnpm
copy "pnpm-workspace.yaml" # pnpm: catalogs (versions referenced by package.json as "catalog:")
copy "yarn.lock" # yarn
copy "deno.json" # deno: imports
copy "deno.jsonc"
copy "deno.lock"
copy "bun.lock" # bun: text lock file (default since bun 1.2)
copy "bun.lockb" # bun: old binary lock file

# Python
# https://dev.to/adamghill/python-package-manager-comparison-1g98
copy "requirements*.txt" # pip: contains arguments for `pip install`, incl. variants like requirements-dev.txt
copy "requirements/*.txt" # pip: e.g. requirements/base.txt
copy "constraints*.txt" # pip: version constraints (pip install -c)
copy "setup.py" # needed to know about setup of internal packages
copy "setup.cfg" # setuptools: install_requires is often here instead of in setup.py
copy "pyproject.toml" # poetry, pdm, hatch, rye, uv
copy "poetry.lock" # poetry
copy "uv.lock" # uv
copy "pdm.lock" # pdm
copy "pylock.toml" # standard lock file (PEP 751)
copy "pylock.*.toml"
copy "Pipfile" # pipenv
copy "Pipfile.lock"
copy "environment.yml" # conda
copy "environment.yaml"
copy "pixi.toml" # pixi (conda packages)
copy "pixi.lock"
copy "*.whl" # checked in binary packages (wheels)
copy ".venv" # virtual environments

# Ruby
copy "Gemfile" # bundler
copy "Gemfile.lock"
copy "gems.rb" # bundler: alternative names for Gemfile and Gemfile.lock
copy "gems.locked"
copy "*.gemspec" vendor # definition of internal gems; skip installed gems (vendor/bundle)
copy "*.gem" vendor # checked in binary packages

# Java (and other JVM languages: Kotlin, Scala, Groovy)
# Maven
copy "pom.xml"
# Ant
copy "build.xml"
copy "ivy.xml" # Ivy: dependency management for Ant
# Gradle
# https://docs.gradle.org/current/userguide/dependency_management.html
copy "*.gradle" .gradle # Groovy DSL: build.gradle, settings.gradle (subprojects), applied scripts like dependencies.gradle; skip the .gradle cache dir (its name also matches!)
copy "*.gradle.kts" .gradle # Kotlin DSL: build.gradle.kts, settings.gradle.kts
copy "gradle.properties" # versions are often defined as properties here
copy "*.versions.toml" # version catalogs, default: gradle/libs.versions.toml
copy "*gradle.lockfile" # dependency locking: gradle.lockfile, buildscript-gradle.lockfile, settings-gradle.lockfile (exact versions incl. transitive deps)
copy "verification-metadata.xml" # dependency verification: all resolved artifacts with checksums
copy "gradle-wrapper.properties" # Gradle version
# checked in binary dependencies; skip build output (Maven: target, Gradle: build) and the Gradle cache
copy "*.jar" target build .gradle # Java archive
copy "*.war" target build .gradle # web application archive
copy "*.ear" target build .gradle # enterprise application archive
copy "*.aar" target build .gradle # Android archive

# Scala
copy "*.sbt" target # sbt: build.sbt, project/plugins.sbt; skip build output

# Clojure
copy "project.clj" # Leiningen
copy "deps.edn" # Clojure CLI

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
copy "go.sum" # checksums of all module versions used, incl. transitive deps
copy "go.work" # workspace: modules developed together
copy "go.work.sum"
copy "vendor/modules.txt" # vendored modules (`go mod vendor`) with versions
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
copy "composer.json" vendor # skip installed packages (covered by composer.lock)
copy "composer.lock"

# Perl
copy "cpanfile" # Carton/cpanm
copy "cpanfile.snapshot" # Carton: lock file
copy "Makefile.PL" # ExtUtils::MakeMaker: PREREQ_PM
copy "Build.PL" # Module::Build: requires
copy "dist.ini" # Dist::Zilla
copy "META.json" # CPAN distribution metadata incl. prereqs
copy "META.yml"

# Swift / Objective-C
copy "Package.swift" .build # Swift Package Manager; skip build output (contains checkouts of dependencies)
copy "Package.resolved" .build # SwiftPM lock file (also inside *.xcodeproj / *.xcworkspace)
copy "Podfile" Pods # CocoaPods; skip installed pods
copy "Podfile.lock" Pods
copy "Cartfile" Carthage # Carthage; skip checkouts
copy "Cartfile.resolved" Carthage

# Dart / Flutter
copy "pubspec.yaml" .dart_tool build
copy "pubspec.lock" .dart_tool build

# Elixir / Erlang
copy "mix.exs" deps _build # Mix; skip fetched dependencies and build output
copy "mix.lock" deps _build
copy "rebar.config" _build # rebar3 (Erlang)
copy "rebar.lock" _build

# Haskell
copy "*.cabal" dist-newstyle .stack-work # Cabal package; skip build output
copy "cabal.project" dist-newstyle .stack-work
copy "cabal.project.freeze" dist-newstyle .stack-work # Cabal lock file
copy "stack.yaml" .stack-work # Stack
copy "stack.yaml.lock" .stack-work

# R
copy "DESCRIPTION" renv # package metadata incl. Imports/Depends; skip installed packages
copy "renv.lock" renv # renv lock file

# Julia
copy "Project.toml" # also used by other tools, but small
copy "Manifest*.toml" # lock file, also versioned like Manifest-v1.11.toml
copy "JuliaProject.toml"
copy "JuliaManifest.toml"

# Bazel
copy "MODULE.bazel" # Bzlmod: bazel_dep
copy "MODULE.bazel.lock"
copy "WORKSPACE" # legacy: http_archive, git_repository
copy "WORKSPACE.bazel"

# Nix
copy "flake.nix"
copy "flake.lock"

# Containers: base images and installed packages (e.g. apt-get install) are dependencies of what is shipped
copy "Dockerfile"
copy "*.Dockerfile"
copy "Dockerfile.*"
copy "Containerfile"
copy "docker-compose*.y*ml" # Docker Compose: images
copy "compose.y*ml"
copy "compose.*.y*ml"

# Git submodules: other repositories included in this one (any language)
# .gitmodules only contains name, path and URL of each submodule; the pinned commit is stored in git's tree,
# so we also save the output of `git submodule status` (commit hash and path, no code) as gitmodules-status.txt.
# Manifests of checked out submodules are already copied above.
copy ".gitmodules"
if command -v git >/dev/null; then
  n=0
  while IFS= read -r -d '' f; do
    d=$(dirname "$f")
    status="$dst/$d/gitmodules-status.txt"
    if g "$d" submodule status > "$status" 2>/dev/null; then
      n=$((n+1))
    else
      rm -f "$status" # not a git checkout, e.g. exported without .git
    fi
  done < <(files ".gitmodules")
  echo "Saved $n git submodule status"
fi

# Meta data: when was the export done and on which branch/commit of each git repo (incl. submodules),
# so that the scan can be reproduced and the results can be matched to a version of the code.
{
  echo "BitFlow license scan export"
  echo "date: $start_utc"
  echo "export.sh: $(g "$script_dir" describe --always --dirty 2>/dev/null || echo "unknown (not in a git repo)")"
  if command -v git >/dev/null; then
    while IFS= read -r -d '' f; do # .git is a directory, or a file for submodules and worktrees
      d=$(dirname "$f")
      commit=$(g "$d" rev-parse HEAD 2>/dev/null) || continue # not a valid repo or no commits yet
      echo
      echo "repo: $d"
      echo "branch: $(g "$d" rev-parse --abbrev-ref HEAD)" # HEAD if detached (e.g. CI, submodule)
      echo "commit: $commit"
      echo "commit date: $(g "$d" log -1 --format=%cI)"
      echo "describe: $(g "$d" describe --tags --always --dirty)" # nearest tag, -dirty if there are uncommitted changes
      # counts only: if not 0, the exported files may differ from the commit
      echo "modified files: $(g "$d" status --porcelain --untracked-files=no | wc -l | tr -d ' ')"
      echo "untracked files: $(g "$d" status --porcelain --untracked-files=all | grep -c '^??' || true)" # not ignored by .gitignore
      # remotes without credentials that may be part of the URL (https://user:token@host/...)
      g "$d" remote -v | awk '$3 == "(fetch)" {print "remote " $1 ": " $2}' | sed -E 's#://[^/@]+@#://#'
    done < <(files ".git")
  else
    echo "git not found: no info about git repos"
  fi
} > "$info"
echo
cat "$info"

echo
tree $dst

echo
zip="bitflow-license-scan-$start_utc.zip"
echo "Generating $zip"
rm -f $zip
(cd $dst && zip -rq "$OLDPWD/$zip" .) # zip from inside $dst to not include the temp dir path in the archive
rm -rf $dst
