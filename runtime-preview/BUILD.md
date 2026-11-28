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

Under Wine, the checkpoint skips mesh pipelines that still exceed Metal's 32 KiB output limit. Submission diagnostics identify the pipelines on a native GPU wait that exceeds eight seconds. A queue's held work now runs before its next memory wait is tested, so a wait no longer passes or holds on a value that earlier work in the same queue overwrites. Without this, the Series S intro could stall in `Prestream` and end at the title's `+0x23cf683` or `+0x2215c35` check. Guarded development tests on an M3 Max rendered parts of the Series S opening with severe visual artifacts. Those checkpoint trials preceded the later performance recipe's controls verification.

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

An earlier M3 Max trial rendered a lit character and yard in the Series S intro at about 1 to 3 fps before the guard ended it at 480.2 seconds. The later controls trial reached the prison room and verified both walking and camera input.

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

The performance recipe includes pixel DPP8 translation when every read stays in its destination quad and a cheaper hash for address-keyed maps. The contributor measured about 7 ms less submitting-thread work per frame on a 24 GB M5 Pro.

Set `SCARLETTMAC_LIGHTING` when invoking `play-main-mac.sh` to choose a lighting preset. Exported `VICTORY_*` settings take precedence.

| Preset | Effect |
| --- | --- |
| `estimate` (default) | Uses the existing indirect-light estimator. |
| `fallback` | Uses the alternative indirect light from PR #15, with the renderer's existing level and sky settings. |
| `exact` | Requests the title's BVH builder and native lighting from PR #20. It sets `VICTORY_WAVE64_REDUCE=1`, `VICTORY_BUILDER_EXACT=1` and `VICTORY_AMBIENT=0`. The builder opens only if all its programs translate exactly. |

On the contributor's M5 Pro, exact lighting restored more of the opening and reduced dropped draws, with 424 and 464 world frames in the first 120 seconds compared with 519 using fallback light. On our M3 Max, all 53 programs passed the builder gate and more of the café scene appeared. Some dialogue frames stayed black, the prison room was darker, and performance varied with the scene. [PR #15](https://github.com/paveledits/ScarlettMac/pull/15) · [PR #20](https://github.com/paveledits/ScarlettMac/pull/20)

| Setting | Purpose |
| --- | --- |
| `VICTORY_KEYS_FILE` | Reads appended keyboard commands from an existing file at a Wine-visible path. A line can tap a key, hold it or schedule a delayed hold. `release` cancels queued holds. |
| `VICTORY_SPANS_QUICK=1` | Avoids taking the descriptor census lock when the slot being cleared is already empty. |
| `VICTORY_DETILE_ROWS=1` | Uses two workers to detile eligible large 2D uploads by row bands, retaining the serial path for other layouts. |
| `VICTORY_FRAME_WAITS=1` | Reports time spent on title pacing, queue and fence waits, and presentation. |
| `VICTORY_SHADER_OPT=2` | Folds defined integer constant arithmetic and comparisons before emitting DXIL. |
| `VICTORY_HALVES_F64_COUNT=1` | With `VICTORY_HALVES_EXCHANGE=1`, counts exact `1.0` terms across synchronized wave halves. |

Create the input file before launch. Append `W 3` on its own line to hold W for three seconds, or `J 2 4` to hold J for two seconds after a four-second delay. Each command is relative to the time the runtime reads the line. Shader folding and cross-half counting use separate shader and pipeline cache identities.

### November 27 Prologue controls trial

Run 7317 used the performance recipe release at renderer revision `59a1fe8`, the precompiled 64-thread argument clamp, privately built CrossOver 26.3 Wine, and D3DMetal 4.0 beta 3. Series S and desktop FidelityFX from the 2.4.0 SDK produced 853 × 480 rendering at 1280 × 720 output. The local launcher copied an existing Prologue save with Large subtitles and began with a fresh cache. [Observed controls and frame measurements](../docs/compatibility.md#november-27-in-world-controls)

To repeat the controls check, use a copy of your Prologue profile and a separate cache directory. Export `VICTORY_DATA_DIR` and `VICTORY_CACHE_DIR` with their Wine-visible paths. The example assumes an exported `WINEPREFIX`, a separately installed desktop FidelityFX DLL in `C:\amd-fsr-sdk-2.4.0`, and the prepared performance source from above. Confirm that the runtime logs `argument clamp: using precompiled 64-thread shader` and the render and output sizes above.

```sh
input_file="$WINEPREFIX/drive_c/scarlettmac-input.txt"
touch "$input_file"
VICTORY_OUTPUT=1280x720 VICTORY_PRESENT_PLANE=0 VICTORY_PRESENT_COMPOSITE=1 \
  VICTORY_FIDELITYFX_DIR='C:\amd-fsr-sdk-2.4.0' \
  VICTORY_SNAPSHOT_POOL_MIB=512 VICTORY_COALESCE_TRACKED_REFRESH=1 \
  VICTORY_SPANS_QUICK=1 VICTORY_DETILE_ROWS=1 VICTORY_FRAME_WAITS=1 \
  VICTORY_SHADER_OPT=2 VICTORY_HALVES_F64_COUNT=1 \
  VICTORY_KEYS_FILE='C:\scarlettmac-input.txt' \
  tools/macos/play-main-mac.sh "/path/to/the/game/executable" --console series-s
```

From another terminal, use the same path for `input_file`. Once the lit prison room appears, append the first sequence. Watch the camera turn in both directions and stay steady during the release intervals.

```sh
printf '%s\n' release 'J 8 6' 'L 8 22' 'W 8 38' >> "$input_file"
```

After the movement tutorial appears and the first sequence finishes, append the second sequence and watch for the cellmate prompt.

```sh
printf '%s\n' release 'S 8 5' 'D 8 21' 'W 8 37' >> "$input_file"
```

### Contributor measurements on a 128 GB M5 Max

NotAOwner tested release builds of the earlier November 27 performance recipe on a 128 GB M5 Max, with macOS 27.2.1, patched CrossOver Wine 26.3.0 and D3DMetal 4.0 beta 3. The offline runs lasted seven minutes each from launch and used warm shader and pipeline caches. The table shows medians from five-second reports with at least 1,000 draws per frame. [Contributor test details](https://github.com/paveledits/ScarlettMac/pull/14)

| Settings over `play-main-mac.sh` | Median FPS | Median frame time | Median dropped draws per frame |
| --- | ---: | ---: | ---: |
| `--console series-s` | 3.9 | 257 ms | 200 |
| `--console series-s`, `VICTORY_AMBIENT=1.0` | 4.1 | 245 ms | 263 |
| `--console series-x` | 3.2 | 308 ms | 341 |
| `--console series-x`, `VICTORY_OUTPUT=1920x1080` | 3.6 | 280 ms | 339 |

`VICTORY_AMBIENT=1.0` uses fixed indirect light in place of the estimate. The contributor reported better visibility for faces and rooms in indoor and backlit shots with this setting. [Lighting and frame-rate observations](https://github.com/paveledits/ScarlettMac/pull/14)

The contributor's opening remained black after the background pipeline queue reached zero. Their diagnostic trace reported 2,679 pipeline library loads and four pipeline builds. The frame reports still counted 1,000 to 2,800 dropped draws per frame during the black opening, then about 265 in the world. The drop reasons remained unresolved. The M3 Max controls trial above also showed a black opening while pipeline work was still pending. The cause of the black image remains open. [Contributor pipeline diagnostic](https://github.com/paveledits/ScarlettMac/pull/14)

## Wine startup

Supply Rosetta and a compatible Wine installation with Apple D3DMetal. For setup details, see [VIctory-macOS](https://github.com/pragyaangaur/VIctory-macOS/blob/23ff1f7540952533b283d996a4f3f6710a6f6e85/README.md) and Apple's [Game Porting Toolkit](https://developer.apple.com/games/game-porting-toolkit/).

```sh
preview="$HOME/scarlettmac-preview-src/target/x86_64-pc-windows-gnullvm/diag/victory.exe"
WINE=/path/to/wine WINEPREFIX=/path/to/wine-prefix ./run.sh "$preview" config
```

For an installed CrossOver bottle, point `WINE` at CrossOver's Wine executable and set `SCARLETTMAC_CROSSOVER_BOTTLE` to the name of an existing bottle with D3DMetal. Set `CX_BOTTLE_PATH` to the folder containing the bottle if it uses a custom location. The launcher stages the executable and its llvm-mingw DLL on the bottle's C: drive for the duration of the command. The `config` command checks startup and configuration before a title is supplied.

If the picture is clipped because the frame is larger than its window on a scaled Retina display, try enabling Retina mode in the affected plain Wine prefix. A contributor verified this workaround on an M5 Max with the November 26 checkpoint and D3DMetal 4.0 beta 3 at a scaled 3008 × 1692 desktop.

```sh
WINEPREFIX="/path/to/wine-prefix" "/path/to/wine" reg add 'HKCU\Software\Wine\Mac Driver' /v RetinaMode /t REG_SZ /d y /f
```

In CrossOver, try **High Resolution Mode** in the affected bottle's settings. High-resolution mode changes the DPI reported to the application, and some applications can render incorrectly with it enabled. Leave it off if the picture already fits. [CrossOver Mac advanced settings](https://support.codeweavers.com/en_US/advanced-settings-in-crossover-mac-26)

With a supported title supplied separately, pass `run --execute` followed by its Wine-visible executable path. In the default recipe, set `VICTORY_SNAPSHOT_POOL_MIB=256` to try retaining up to 256 MiB of free snapshot buffers. Zero disables retention. When unset or invalid, the upstream 2,048 MiB limit applies. Buffers currently needed for a submission can exceed the configured retention limit.

In the default recipe, set `VICTORY_DIRECT_BARYCENTRICS=1` to enable the pixel shader fix on a D3D12 device that supports barycentrics. The runtime uses a separate shader cache for this option.

The earlier opening captures used local development configurations. In-world control was verified in the later Prologue room trial above. First-mission completion remains unverified.
