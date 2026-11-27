# Contributing to ScarlettMac

Help us test Xbox Series X|S compatibility on Apple Silicon. Reproducible bug reports, Mac test results, documentation fixes, and focused patches are welcome. The synthetic Xbox test title runs with no retail game files.

## Start here

| Contribution | What to share |
| --- | --- |
| Run the synthetic test title on an Apple Silicon Mac | Your Mac chip, macOS and CrossOver versions, and the names of checks that failed. |
| Improve the setup guide | The command that failed, what fixed it, and the versions you used. |
| Reproduce a rendering, input, or audio problem | A small synthetic fixture or a repeatable sequence, with the expected and observed behavior. |

Check the [open issues](https://github.com/paveledits/ScarlettMac/issues) for existing reports and the [compatibility notes](docs/compatibility.md) for known limitations.

## Prepare the source

```sh
git clone https://github.com/paveledits/ScarlettMac.git
cd ScarlettMac
scripts/build.sh --prepare
zsh -n scripts/build.sh
zsh -n scripts/run.sh
```

`--prepare` fetches the pinned XCL Mac revision and applies ScarlettMac's patch in `.build/xcl-mac`. It requires Git and network access. The shell syntax check can run from the checkout without fetching XCL.

## Run the synthetic test

Follow the [build and run setup](README.md#build-and-run) for Rust, LLVM-MinGW, DXC and a dedicated CrossOver bottle with D3DMetal enabled. Then run the two commands from the repository root.

```sh
scripts/build.sh --test-title
scripts/run.sh --test-title
```

The launcher creates fresh test data for each run. The test exits with the number of failed checks. Record the test names, CrossOver and D3DMetal versions, and the relevant output so someone else can compare the result. [Synthetic test results](docs/compatibility.md#xbox-system-checks)

If a forced stop leaves the bottle busy or leaves G: pointing at a previous run, confirm the bottle has stopped in CrossOver first. Use a fresh dedicated bottle with `SCARLETT_BOTTLE_DIR`, or inspect the old bottle's `dosdevices/g:` link and remove it only if it points at the previous ScarlettMac run. Remove the empty `.scarlett-lab-run` directory only after confirming that no launcher is using the bottle.

## Report a result

Use the [issue form](https://github.com/paveledits/ScarlettMac/issues/new/choose). For a game result, state the runtime used, the exact build and the furthest stage you observed. A rendered cinematic shows the game reached 3D. Gameplay requires a visible response to player input.

Include the smallest useful log excerpt with the first relevant error and the lines around it. Remove account details, local paths and machine identifiers. Keep game files, keys and executables out of reports.

## Send a pull request

Work on a branch in your fork. Keep changes focused and include the commands and hardware you used to verify them.

- Launcher changes belong in [scripts](scripts/).
- XCL changes belong in [mac-compat.patch](patches/mac-compat.patch) or a follow-on patch, against the pinned source prepared in `.build/xcl-mac`. Keep the generated checkout and build outputs out of the pull request.
- Link the upstream issue or commit for imported changes and preserve their attribution. [Source provenance](SOURCE-NOTICES.md)
