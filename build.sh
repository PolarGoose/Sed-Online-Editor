#!/usr/bin/env bash

set -o xtrace
set -o errexit
set -o nounset
set -o pipefail

readonly currentScriptDir=`dirname "$(realpath -s "${BASH_SOURCE[0]}")"`
readonly buildDir="$currentScriptDir/build"

rm -rf "$buildDir"
mkdir -p "$buildDir"
mkdir -p "$currentScriptDir/docs/gen"

# Download and configure Emscripten
git clone --depth=1 https://github.com/emscripten-core/emsdk.git "$buildDir/emsdk"
"$buildDir/emsdk/emsdk" install latest
"$buildDir/emsdk/emsdk" activate latest
source "$buildDir/emsdk/emsdk_env.sh"

# Download and build sed to generate "docs/gen/sed.js".
git clone --branch v4.9 --single-branch git://git.savannah.gnu.org/sed.git "$buildDir/sed-git-repo"
(
cd "$buildDir/sed-git-repo"
./bootstrap
# extra flags to ./configure are needed because of the bug: https://github.com/emscripten-core/emscripten/issues/12415#issuecomment-1207215248
emconfigure ./configure ac_cv_have_decl_alarm=no gl_cv_func_sleep_works=yes
emmake make sed/sed CFLAGS=" \
  -s INVOKE_RUN=0 \
  -s SINGLE_FILE \
  -s ENVIRONMENT=web \
  -s EXIT_RUNTIME=1 \
  -s EXPORT_ES6=1 \
  -s FORCE_FILESYSTEM=1 \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s EXTRA_EXPORTED_RUNTIME_METHODS=[FS,callMain] \
  -O3 \
  -w"
cp sed/sed "$currentScriptDir/docs/gen/sed.js"
)

# Generate sedVersion.js
readonly shortGitCommitHash=`git -C "$buildDir/sed-git-repo" rev-parse --short HEAD`
readonly nearestTagName=`git -C "$buildDir/sed-git-repo" describe --tags --abbrev=0`
echo "export default '$nearestTagName~$shortGitCommitHash'" > "$currentScriptDir/docs/gen/sedVersion.js"
