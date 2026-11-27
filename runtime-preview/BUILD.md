# ScarlettMac Runtime Preview

ScarlettMac Runtime Preview builds an x86-64 Windows executable for Apple Silicon Macs running Wine and Rosetta. All three recipes identify the runtime as ScarlettMac in the window title and CLI help. The default VIctory-macOS recipe includes a cap for recycled CPU snapshot buffers and an opt-in fix for direct pixel-center barycentrics, the weights a pixel shader uses to interpolate across a triangle. The ScarlettMac XCL build has its own source and license.

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

The optional checkpoint uses a newer [VIctory-macOS revision](checkpoint/UPSTREAM) and its own [patch list](checkpoint/patches/series). It adds local GameInput diagnostics, updates mesh pipeline handling under Wine, copies only the title pages that were written, and translates the console's 64-lane wave reductions, first-lane and cross-half lane reads for the Mac's 32-lane GPU (`VICTORY_WAVE64_REDUCE=1`), which improved lighting coverage in the contributor’s M3 Pro tests. Use the same toolchain and choose a new output directory for each command.

```sh
./build.sh --checkpoint --prepare "$HOME/scarlettmac-checkpoint-review"
LLVM_MINGW_ROOT=/path/to/llvm-mingw ./build.sh --checkpoint "$HOME/scarlettmac-checkpoint-src"
```

Run `config` as shown below with the checkpoint's `target/x86_64-pc-windows-gnullvm/diag/victory.exe`. The checkpoint uses the same launcher.

| Optional setting | Effect in the checkpoint |
| --- | --- |
| `VICTORY_CONFIRM_FILE` | A Wine-visible path to a local file. After the offline account picker appears, writing `Enter` to this file sends one short confirmation within the title. The write must be less than 600 ms old when polled. |
| `VICTORY_KEYS_TRIGGER` | A Wine-visible marker path. When the file first appears, it starts the `VICTORY_KEYS` timeline. With the trigger set, `VICTORY_KEYS=0.5-1.5:W,2-3:J` holds those keys during the named intervals in seconds. Start with the marker absent and create it only at the scene being tested. |
| `VICTORY_TRACE_RETURNED_STICKS=1` | Logs the title's stick readings when an axis crosses a reporting threshold, with the present serial. |
| `VICTORY_LINK_MESH_OUTPUTS=0` | Disables the mesh output linking that is enabled by default under Wine. |
| `VICTORY_WAVE64_REDUCE=1` | Enables experimental translation of supported 64-lane wave operations on 32-lane GPUs. |

Under Wine, the checkpoint skips mesh pipelines that still exceed Metal's 32 KiB output limit. Submission diagnostics identify the pipelines on a native GPU wait that exceeds eight seconds. A queue's held work now runs before its next memory wait is tested, so a wait no longer passes or holds on a value that earlier work in the same queue overwrites. Without this, the Series S intro could stall in `Prestream` and end at the title's `+0x23cf683` or `+0x2215c35` check. Guarded development tests on an M3 Max rendered parts of the Series S opening with severe visual artifacts. The local tests used additional launcher settings, and repeatable player and camera control remain unverified.

## November 27 performance recipe

The optional performance recipe pins a [VIctory-macOS fork](perf/UPSTREAM) and applies its [patch series](perf/patches/series). In the contributor's Series S intro tests on a 24 GB M5 Pro, the game world ran at about 4 fps, up from about 1 fps. The median frame took 225 to 255 ms, and the slowest 5% took 0.3 to 0.4 s.

| World frames in the first 120 s | Runs |
| --- | --- |
| Same source before the November 27 changes | about 140 to 160 |
| This recipe, release build | 474, 509, 508, 508, 528 |

What changed:

- Fewer DirectStorage reader threads (6, not one per core). Wine serializes the memory-map calls these threads make, so 18 readers mostly waited on each other. This roughly doubled the frame rate.
- The memory guard now runs under D3DMetal, which reports separate video memory on a unified-memory Mac. Large textures load their top mip at half size (`VICTORY_TEXTURE_DROP_MIPS=0` restores full detail). Swap growth over 4 minutes fell from 3 to 5 GB to under 0.4 GB.
- Write faults that Wine reports with extra protection bits, or on pages reserved first and committed later, are healed instead of crashing.
- A compute shader that reads a buffer's size from its descriptor is now translated instead of dropped.

On an M3 Max with 48 GB, a release build with the precompiled clamp rendered a lit character and yard in the Series S intro. The test used 720p game output, desktop FSR, and a local CrossOver 26.3-derived Wine with D3DMetal 4.0 beta 3. Runtime FPS samples ranged from about 1 to 3. The guard ended the run at 480.2 seconds. Player and camera response remain unverified.

Set `DEPS` to an x86-64 prefix containing FreeType and GnuTLS. Prepare the source and build its patched Wine. [Pinned Wine setup guide](https://github.com/halfwave50/VIctory-macOS-halfwave/blob/8616bd67939a0a659dc50b02b52a291c73a73859/docs/macos.md#crossover-wine-with-d3dmetal-24-november-2026)

```sh
./build.sh --perf --prepare "$HOME/scarlettmac-perf-src"
cd "$HOME/scarlettmac-perf-src"
DEPS=/path/to/x86-64-dependencies tools/macos/build-crossover-wine.sh
```

Install the D3DMetal redistributable from Apple's game evaluation environment into the built Wine's `target/wine-cx/lib` as described in the guide. Use the Series S profile to match the contributor's test.

```sh
tools/macos/play-main-mac.sh "/path/to/the/game/executable" --console series-s
```

`play-main-mac.sh` builds a release executable and sets the contributor's performance switches. A setting you export first wins. `LLVM_MINGW_ROOT=/path/to/llvm-mingw SCARLETTMAC_BUILD_PROFILE=release ./build.sh --perf NEW_SOURCE_DIR` builds only the executable. Without `SCARLETTMAC_BUILD_PROFILE` it builds the slower diagnostics profile.

Known issues: after 4 to 5 minutes, swap grows again by about 2 GB and some minutes drop to 1 fps. The opening credits show a flat green panel where a video should play. `VICTORY_COPY_FAST` and `VICTORY_ALIAS_BUFFERS` are off by default because both still crash.

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
