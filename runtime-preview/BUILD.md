# ScarlettMac Runtime Preview

ScarlettMac Runtime Preview builds an x86-64 Windows executable for Apple Silicon Macs running Wine and Rosetta. The default VIctory-macOS recipe includes a cap for recycled CPU snapshot buffers and an opt-in fix for direct pixel-center barycentrics, the weights a pixel shader uses to interpolate across a triangle. The ScarlettMac XCL build has its own source and license.

## Build and test

Use an Apple Silicon Mac with Xcode Command Line Tools, Git, Rustup, and the [llvm-mingw 20261117 UCRT macOS universal toolchain](https://github.com/mstorsjo/llvm-mingw/releases/tag/20261117). Extract the toolchain to a directory of your choice. The source build uses these tools and public source repositories.

```sh
rustup toolchain install 1.98.1 --profile minimal --component rustfmt --component clippy
rustup target add --toolchain 1.98.1 x86_64-pc-windows-gnullvm x86_64-pc-windows-msvc
LLVM_MINGW_ROOT=/path/to/llvm-mingw ./build.sh "$HOME/scarlettmac-preview-src"
```

The build places the x86-64 `libunwind.dll` from your llvm-mingw installation beside the executable it links.

For source review, run `./build.sh --prepare NEW_SOURCE_DIR` to fetch the immutable commit in [UPSTREAM](UPSTREAM) and apply the [ordered patches](patches/series). Both modes take a new directory. Run the snapshot tests on macOS using the patched checkout.

```sh
cd "$HOME/scarlettmac-preview-src"
cargo test --locked -j 2 -p victory-gpu --lib snapshot_pool
```

## November 26 source checkpoint

The optional checkpoint uses a newer [VIctory-macOS revision](checkpoint/UPSTREAM) and its own [patch list](checkpoint/patches/series). It adds local GameInput diagnostics and updates mesh pipeline handling under Wine. Use the same toolchain and choose a new output directory for each command.

```sh
./build.sh --checkpoint --prepare "$HOME/scarlettmac-checkpoint-review"
LLVM_MINGW_ROOT=/path/to/llvm-mingw ./build.sh --checkpoint "$HOME/scarlettmac-checkpoint-src"
```

Run `config` as shown below with the checkpoint's `target/x86_64-pc-windows-gnullvm/diag/victory.exe`. The checkpoint uses the same launcher and adds ScarlettMac to the window statistics and CLI help.

| Optional setting | Effect in the checkpoint |
| --- | --- |
| `VICTORY_CONFIRM_FILE` | A Wine-visible path to a local file. After the offline account picker appears, writing `Enter` to this file sends one short confirmation within the title. The write must be less than 600 ms old when polled. |
| `VICTORY_KEYS_TRIGGER` | A Wine-visible marker path. When the file first appears, it starts the `VICTORY_KEYS` timeline. With the trigger set, `VICTORY_KEYS=0.5-1.5:W,2-3:J` holds those keys during the named intervals in seconds. Start with the marker absent and create it only at the scene being tested. |
| `VICTORY_TRACE_RETURNED_STICKS=1` | Logs the title's stick readings when an axis crosses a reporting threshold, with the present serial. |
| `VICTORY_LINK_MESH_OUTPUTS=0` | Disables the mesh output linking that is enabled by default under Wine. |

Under Wine, the checkpoint skips mesh pipelines that still exceed Metal's 32 KiB output limit. Submission diagnostics identify the pipelines on a native GPU wait that exceeds eight seconds. A queue's held work now runs before its next memory wait is tested, so a wait no longer passes or holds on a value that earlier work in the same queue overwrites. Without this, the Series S intro could stall in `Prestream` and end at the title's `+0x23cf683` or `+0x2215c35` check. Guarded development tests on an M3 Max rendered parts of the Series S opening with severe visual artifacts. The local tests used additional launcher settings, and repeatable player and camera control remain unverified.

## Wine startup

Supply Rosetta and a compatible Wine installation with Apple D3DMetal. For setup details, see [VIctory-macOS](https://github.com/pragyaangaur/VIctory-macOS/blob/23ff1f7540952533b283d996a4f3f6710a6f6e85/README.md) and Apple's [Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/).

```sh
preview="$HOME/scarlettmac-preview-src/target/x86_64-pc-windows-gnullvm/diag/victory.exe"
WINE=/path/to/wine WINEPREFIX=/path/to/wine-prefix ./run.sh "$preview" config
```

For an installed CrossOver bottle, point `WINE` at CrossOver's Wine executable and set `SCARLETTMAC_CROSSOVER_BOTTLE` to the name of an existing bottle with D3DMetal. Set `CX_BOTTLE_PATH` to the folder containing the bottle if it uses a custom location. The launcher stages the executable and its llvm-mingw DLL on the bottle's C: drive for the duration of the command. The `config` command checks startup and configuration before a title is supplied.

With a supported title supplied separately, pass `run --execute` followed by its Wine-visible executable path. In the default recipe, set `VICTORY_SNAPSHOT_POOL_MIB=256` to try retaining up to 256 MiB of free snapshot buffers. Zero disables retention. When unset or invalid, the upstream 2,048 MiB limit applies. Buffers currently needed for a submission can exceed the configured retention limit.

In the default recipe, set `VICTORY_DIRECT_BARYCENTRICS=1` to enable the pixel shader fix on a D3D12 device that supports barycentrics. The runtime uses a separate shader cache for this option.

The opening captures used a local development configuration with additional patches. Gameplay verification for this preview remains pending.
