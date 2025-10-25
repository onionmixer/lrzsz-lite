#!/usr/bin/env bash
set -euo pipefail

# build-lrzsz-no-pty.sh
# Usage:
#   ./build-lrzsz-no-pty.sh --url <tarball_url> --prefix /opt/lrzsz-no-pty
#   or
#   ./build-lrzsz-no-pty.sh --src /path/to/lrzsz-source --prefix /opt/lrzsz-no-pty

show_help() {
  cat <<'EOF'
build-lrzsz-no-pty.sh
Create a patched lrzsz build with PTY isatty() checks removed.

Options:
  --url <tarball_url>   Download lrzsz source tarball and use it
  --src <source_dir>    Use existing local source directory
  --prefix <dir>        Installation prefix (default: /usr/local/lrzsz-no-pty)
  --jobs <n>            make -jN (default: number of CPUs)
  --keep                Keep extracted source after build
  --help                Show this help
EOF
}

# defaults
PREFIX="/usr/local/lrzsz-no-pty"
JOBS=$(nproc 2>/dev/null || echo 1)
KEEP=0
SRC_DIR=""
TARBALL_URL=""

# parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) TARBALL_URL="$2"; shift 2;;
    --src) SRC_DIR="$2"; shift 2;;
    --prefix) PREFIX="$2"; shift 2;;
    --jobs) JOBS="$2"; shift 2;;
    --keep) KEEP=1; shift;;
    --help) show_help; exit 0;;
    *) echo "Unknown arg: $1"; show_help; exit 1;;
  esac
done

if [[ -z "$TARBALL_URL" && -z "$SRC_DIR" ]]; then
  echo "Error: either --url or --src must be provided."
  show_help
  exit 1
fi

WORKDIR=$(mktemp -d /tmp/lrzsz-build.XXXX)
echo "Working directory: $WORKDIR"
cleanup() {
  if [[ $KEEP -eq 0 ]]; then
    rm -rf "$WORKDIR"
  else
    echo "Keeping workdir: $WORKDIR"
  fi
}
trap cleanup EXIT

cd "$WORKDIR"

# Download or copy source
if [[ -n "$TARBALL_URL" ]]; then
  echo "Downloading $TARBALL_URL ..."
  curl -L -o lrzsz.tar.gz "$TARBALL_URL"
  tar xzf lrzsz.tar.gz
  # try to find extracted dir (disable pipefail to avoid SIGPIPE from head)
  EXDIR=$(set +o pipefail; tar tzf lrzsz.tar.gz | head -n1 | cut -f1 -d"/")
  if [[ -d "$EXDIR" ]]; then
    cd "$EXDIR"
  else
    # fallback: find first dir
    cd "$(find . -maxdepth 2 -type d -name 'lrz*' | head -n1 || echo .)"
  fi
else
  # use local source
  if [[ ! -d "$SRC_DIR" ]]; then
    echo "Source dir not found: $SRC_DIR"
    exit 1
  fi
  echo "Copying source from $SRC_DIR ..."
  cp -a "$SRC_DIR" .
  BASENAME=$(basename "$SRC_DIR")
  cd "$BASENAME"
fi

echo "Source directory: $(pwd)"

# backup original files optionally
git init -q || true
git add -A >/dev/null 2>&1 || true
git commit -q -m "baseline" >/dev/null 2>&1 || true

# Apply patch to allow lrzsz to work without TTY (pipes and redirections)
echo "Applying no-TTY patch to rbsb.c..."

# Find rbsb.c file
RBSB_FILE=$(find . -name "rbsb.c" -type f | head -n1)

if [[ -z "$RBSB_FILE" ]]; then
  echo "Warning: rbsb.c not found. Proceeding without patch..."
else
  echo "Found rbsb.c at: $RBSB_FILE"

  # Create backup
  cp -a "$RBSB_FILE" "$RBSB_FILE.orig"

  # Apply patch: Add isatty() check at the beginning of io_mode function
  # This allows lrzsz to work with pipes and non-TTY file descriptors
  awk '
    /^io_mode\(int fd, int n\)/ { in_func=1; print; next }
    in_func && /^{/ {
      print
      print "\tstatic int did0 = FALSE;"
      print ""
      print "\t/* If fd is not a tty, skip terminal configuration */"
      print "\t/* This allows lrzsz to work with pipes and redirections */"
      print "\tif (!isatty(fd) && n != 0) {"
      print "\t\t/* For non-tty, just return OK without terminal setup */"
      print "\t\treturn OK;"
      print "\t}"
      in_func=0
      skip_did0=1
      next
    }
    skip_did0 && /static int did0 = FALSE;/ { skip_did0=0; next }
    { print }
  ' "$RBSB_FILE" > "$RBSB_FILE.patched" && mv "$RBSB_FILE.patched" "$RBSB_FILE"

  # Show git diff for review
  if command -v git >/dev/null 2>&1; then
    echo "Patch summary (git diff):"
    git add -A
    git --no-pager diff --staged || true
  fi
fi

# Try autoreconf / configure / make
echo "Attempting to build..."
# Some lrzsz versions use plain Makefile, others use autoconf
if [[ -f configure.ac || -f configure.in ]]; then
  echo "Running autoreconf -i ..."
  autoreconf -i || true
fi

# configure
if [[ -f ./configure ]]; then
  ./configure --prefix="$PREFIX"
else
  # some distributions provide plain Makefile; try default build
  echo "No configure script found; attempting make directly"
fi

make -j "$JOBS"
echo "Build finished. Installing into $PREFIX (may need sudo)..."
mkdir -p "$PREFIX/bin"
if [[ $EUID -ne 0 && "$PREFIX" =~ ^/usr ]]; then
  echo "Non-root attempt to install into system prefix; using sudo"
  sudo make install || { echo "sudo make install failed"; exit 1; }
else
  make install DESTDIR="" || true
fi

echo "Installation complete. Binaries installed under $PREFIX/bin (if make install supported prefix)."
echo "If real install did not occur, you can copy the built binaries from this tree's src/ or ."

echo "You can test with:"
echo "  $PREFIX/bin/sz --version"
echo "  $PREFIX/bin/rz --version"

echo "Done."

