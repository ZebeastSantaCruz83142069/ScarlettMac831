#!/bin/zsh
set -eu

root=${0:A:h:h}
mode=run
test_title=0
source=xcl-mac
if [[ ${1:-} == --inspect ]]; then
    mode=inspect
    shift
elif [[ $# == 1 && $1 == --test-title ]]; then
    test_title=1
    set -- "$root/.build/test-title/xcl_testtitle.exe" -- --hello
elif [[ ${1:-} == --lanes ]]; then
    source=xcl-mac-lanes
    export XCL_CREATE_LIST_X_CLOSED=1
    export XCL_HOST_COMPUTE=1
    unset XCL_CONSOLE_LISTS
    shift
fi
if [[ $# -eq 0 || ! -f "$1" ]]; then
    print -u2 'Usage: scripts/run.sh [--inspect] /path/to/game.exe [-- guest arguments]'
    print -u2 '       scripts/run.sh --test-title (after scripts/build.sh --test-title)'
    print -u2 '       scripts/run.sh --lanes /path/to/lanes.exe [-- guest arguments]'
    exit 2
fi

game=${1:A}
shift
if [[ $# -gt 0 && ( $mode != run || $1 != -- ) ]]; then
    print -u2 'Use -- before guest arguments in run mode.'
    exit 2
fi
game_root=${game:h}
app=${SCARLETT_CROSSOVER_APP:-/Applications/CrossOver Preview.app}
wine="${app:A}/Contents/SharedSupport/CrossOver/bin/wine"
bottle=${SCARLETT_BOTTLE_DIR:-$HOME/Library/Application Support/CrossOver/Bottles/ScarlettLab}
bottle=${bottle:A}
compiled="$root/.build/$source/target/x86_64-pc-windows-gnullvm/release/xcl.exe"
: "${SCARLETT_LLVM_MINGW:?Set SCARLETT_LLVM_MINGW to the extracted LLVM-MinGW directory}"
: "${SCARLETT_DXC_DIR:?Set SCARLETT_DXC_DIR to the directory with the x64 DXC DLLs}"
unwind="$SCARLETT_LLVM_MINGW/x86_64-w64-mingw32/bin/libunwind.dll"
dependencies=("$compiled" "$unwind" "$SCARLETT_DXC_DIR/dxcompiler.dll" "$SCARLETT_DXC_DIR/dxil.dll")
if [[ ! -x "$wine" || ! -d "$bottle/drive_c" || ! -d "$bottle/dosdevices" ]]; then
    print -u2 'CrossOver or the dedicated Windows 11 bottle is missing.'
    exit 1
fi
for file in "${dependencies[@]}"; do
    if [[ ! -f "$file" ]]; then
        print -u2 "Missing runtime file $file"
        exit 1
    fi
done

lock="$bottle/.scarlett-lab-run"
drive="$bottle/dosdevices/g:"
mapped=0
if ! mkdir "$lock"; then
    print -u2 "The bottle is busy or has a stale lock at $lock"
    exit 1
fi
cleanup() {
    if [[ $mapped == 1 && -L "$drive" && ${drive:A} == "$game_root" ]]; then
        unlink "$drive"
    fi
    rmdir "$lock"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ -L "$drive" || -e "$drive" ]]; then
    if [[ ! -L "$drive" || ${drive:A} != "$game_root" ]]; then
        print -u2 'G: already points to another location in this bottle.'
        exit 1
    fi
else
    ln -s "$game_root" "$drive"
    mapped=1
fi

runtime="$bottle/drive_c/scarlett-lab"
mkdir -p "$runtime"
for file in "${dependencies[@]}"; do
    cp "$file" "$runtime/${file:t}"
done
if [[ -n ${SCARLETT_OPUS_DLL:-} ]]; then
    cp "$SCARLETT_OPUS_DLL" "$runtime/libopus-0.dll"
fi

export CX_BOTTLE_PATH=${bottle:h}
export XCL_DATA_ROOT='C:\scarlett-lab-data'
if [[ $test_title == 1 ]]; then
    fixture_root="$bottle/drive_c/scarlett-lab-data"
    mkdir -p "$fixture_root"
    fixture_state=$(mktemp -d "$fixture_root/test-run.XXXXXXXX")
    XCL_DATA_ROOT+="\\${fixture_state:t}"
fi
export XCL_DXC_DIR='C:\scarlett-lab'
export XCL_NETWORK=0
export XCL_RECT_LIST_GS=${XCL_RECT_LIST_GS:-0}
export XCL_TEXTURE_SKIP_UNCHANGED=${XCL_TEXTURE_SKIP_UNCHANGED:-1}
args=("$mode" "G:\\${game:t}" "$@")
if [[ $mode == inspect ]]; then
    args+=(--json)
fi

cd "$runtime"
/usr/bin/sandbox-exec -D "GAME_ROOT=$game_root" -D "BOTTLE=$bottle" -p '
(version 1)
(allow default)
(deny network-outbound (remote ip))
(deny file-write* (require-all (subpath (param "GAME_ROOT")) (require-not (subpath (param "BOTTLE")))))
' "$wine" --bottle "${bottle:t}" --no-update --no-gui --no-convert --cx-app 'C:\scarlett-lab\xcl.exe' "${args[@]}"
