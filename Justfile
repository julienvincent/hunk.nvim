[macos]
prepare-nvim channel:
  #!/usr/bin/env bash
  set -eo pipefail

  NVIM_DIR=".build/nvim/{{ channel }}"

  test -d $NVIM_DIR || {
    mkdir -p $NVIM_DIR

    # Older versions of nvim don't have arch specific releases - so we do a simple retry without the arch component.
    curl -L https://github.com/neovim/neovim/releases/download/{{ channel }}/nvim-macos-$(arch).tar.gz --fail > ./.build/nvim-macos.tar.gz || \
    curl -L https://github.com/neovim/neovim/releases/download/{{ channel }}/nvim-macos.tar.gz --fail > ./.build/nvim-macos.tar.gz

    xattr -c ./.build/nvim-macos.tar.gz
    tar xzf ./.build/nvim-macos.tar.gz -C $NVIM_DIR --strip-components=1
    rm ./.build/nvim-macos.tar.gz
  }

[linux]
prepare-nvim channel:
  #!/usr/bin/env bash
  set -eo pipefail

  NVIM_DIR=".build/nvim/{{ channel }}"

  case "$(arch)" in
    aarch64) NVIM_ARCH="arm64" ;;
    *) NVIM_ARCH="$(arch)" ;;
  esac

  test -d $NVIM_DIR || {
    mkdir -p $NVIM_DIR

    curl -L https://github.com/neovim/neovim/releases/download/{{ channel }}/nvim-linux-${NVIM_ARCH}.tar.gz > ./.build/nvim-linux.tar.gz
    tar xzf ./.build/nvim-linux.tar.gz -C $NVIM_DIR --strip-components=1
    rm ./.build/nvim-linux.tar.gz
  }

prepare-dependencies:
  #!/usr/bin/env bash
  set -eo pipefail

  test -d .build/dependencies || {
    mkdir -p ./.build/dependencies
    git clone --depth 1 https://github.com/nvim-lua/plenary.nvim ./.build/dependencies/plenary.nvim
    git clone --depth 1 https://github.com/MunifTanjim/nui.nvim ./.build/dependencies/nui.nvim
  }

prepare channel: (prepare-nvim channel) prepare-dependencies

test channel="stable" file="": (prepare channel)
  #!/usr/bin/env bash
  set -eo pipefail

  NVIM_DIR=".build/nvim/{{ channel }}"

  ./$NVIM_DIR/bin/nvim --version
  ./$NVIM_DIR/bin/nvim \
    --headless \
    --noplugin \
    -u tests/config.lua \
    -c "PlenaryBustedDirectory tests/hunk/{{ file }} { minimal_init='tests/config.lua', sequential=true }"

run channel="stable": (prepare channel)
  #!/usr/bin/env bash
  set -eo pipefail

  TMPDIR="${TMPDIR:-/tmp}"
  NVIM_DIR=".build/nvim/{{ channel }}"

  rm -r $TMPDIR/hunk-nvim-run/ || true
  cp -a dev/fixtures/split/default $TMPDIR/hunk-nvim-run/

  ./$NVIM_DIR/bin/nvim \
    --noplugin \
    -u tests/config.lua \
    -c "DiffEditor $TMPDIR/hunk-nvim-run/left $TMPDIR/hunk-nvim-run/right $TMPDIR/hunk-nvim-run/out"

run-local:
  #!/usr/bin/env bash
  set -eo pipefail

  TMPDIR="${TMPDIR:-/tmp}"

  rm -r $TMPDIR/hunk-nvim-run/ || true
  cp -a dev/fixtures/split/default $TMPDIR/hunk-nvim-run/

  nvim \
    -c "DiffEditor $TMPDIR/hunk-nvim-run/left $TMPDIR/hunk-nvim-run/right $TMPDIR/hunk-nvim-run/out"

run-merge channel="stable" fixture="default": (prepare channel)
  #!/usr/bin/env bash
  set -eo pipefail

  TMPDIR="${TMPDIR:-/tmp}"
  NVIM_DIR=".build/nvim/{{ channel }}"

  rm -r $TMPDIR/hunk-nvim-merge/ || true
  mkdir -p $TMPDIR/hunk-nvim-merge/
  cp dev/fixtures/merge/{{ fixture }}/base.lua $TMPDIR/hunk-nvim-merge/base.lua
  cp dev/fixtures/merge/{{ fixture }}/left.lua $TMPDIR/hunk-nvim-merge/left.lua
  cp dev/fixtures/merge/{{ fixture }}/right.lua $TMPDIR/hunk-nvim-merge/right.lua
  touch $TMPDIR/hunk-nvim-merge/output.lua

  ./$NVIM_DIR/bin/nvim \
    --noplugin \
    -u tests/config.lua \
    -c "MergeEditor $TMPDIR/hunk-nvim-merge/base.lua $TMPDIR/hunk-nvim-merge/left.lua $TMPDIR/hunk-nvim-merge/right.lua $TMPDIR/hunk-nvim-merge/output.lua"

  echo ""
  echo "=== Output ==="
  cat $TMPDIR/hunk-nvim-merge/output.lua

run-merge-local fixture="default":
  #!/usr/bin/env bash
  set -eo pipefail

  TMPDIR="${TMPDIR:-/tmp}"

  rm -r $TMPDIR/hunk-nvim-merge/ || true
  mkdir -p $TMPDIR/hunk-nvim-merge/
  cp dev/fixtures/merge/{{ fixture }}/base.lua $TMPDIR/hunk-nvim-merge/base.lua
  cp dev/fixtures/merge/{{ fixture }}/left.lua $TMPDIR/hunk-nvim-merge/left.lua
  cp dev/fixtures/merge/{{ fixture }}/right.lua $TMPDIR/hunk-nvim-merge/right.lua
  touch $TMPDIR/hunk-nvim-merge/output.lua

  nvim \
    -c "MergeEditor $TMPDIR/hunk-nvim-merge/base.lua $TMPDIR/hunk-nvim-merge/left.lua $TMPDIR/hunk-nvim-merge/right.lua $TMPDIR/hunk-nvim-merge/output.lua"

  echo ""
  echo "=== Output ==="
  cat $TMPDIR/hunk-nvim-merge/output.lua
