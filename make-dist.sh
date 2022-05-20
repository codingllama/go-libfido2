#!/bin/bash
set -eu

main() {
  local target=''
  local os_hardware=''
  os_hardware="$(uname -s)-$(uname -m)"
  case "$os_hardware" in
    Darwin-x86_64)
      target='dist/darwin-amd64'
      ;;
    *)
      echo "$0 not implemented for $os_hardware" >&2
      exit 1
      ;;
  esac
  # Sanity check.
  if [[ -z "$target" ]]; then
    echo "$0: target cannot be empty" >&2
    exit 1
  fi

  if [[ "$(uname -s)-$(uname -m)" != "Darwin-x86_64" ]]; then
    echo "$0 must be executed on macOS amd64 machines" >&2
    exit 1
  fi

  cd "$(dirname "$0")"

  local tmp=''
  tmp="$(mktemp -d)"
  #shellcheck disable=SC2064  # Early expasion on purpose.
  trap "rm -fr '$tmp'" EXIT

  # /usr/local/opt is the path for Homebrew openssl.
  export PKG_CONFIG_PATH="$tmp/lib/pkgconfig:/usr/local/opt/openssl@1.1/lib/pkgconfig"

  # Clean any leftovers from previous builds.
  for d in third_party/*; do
    pushd "$d"
    [[ -f Makefile ]] && make clean
    git clean -df
    popd
  done

  echo 'Building libcbor' >&2
  pushd "third_party/libcbor"
  cmake \
    -DCBOR_CUSTOM_ALLOC=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$tmp" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DWITH_EXAMPLES=OFF .
  make
  make install
  popd # third_party/libcbor

  echo 'Building libcbor' >&2
  pushd "third_party/libfido2"
  cmake \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_MANPAGES=OFF \
    -DBUILD_TOOLS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$tmp"
  make
  make install
  popd # third_party/libfido2

  rm -fr "$target"
  mkdir -p "$target/lib"
  cp -r "$tmp/include" "$target/"
  cp -r "$tmp/lib"/*.a "$target/lib/"

  cat >"$target/README" <<EOF
libfido2: $(cd third_party/libfido2; git rev-parse HEAD)
libcbor: $(cd third_party/libcbor; git rev-parse HEAD)
EOF
}

main "$@"
