# Source notices

The preview patches, build script, and launcher are distributed under GPL-3.0-or-later. Each recipe reconstructs its complete corresponding source and keeps the upstream notices. See [LICENSE](LICENSE).

| Recipe | Pinned VIctory-macOS source and patches | Reconstruct source |
| --- | --- | --- |
| Default | [23ff1f7](https://github.com/pragyaangaur/VIctory-macOS/commit/23ff1f7540952533b283d996a4f3f6710a6f6e85), [patch series](patches/series) | `./build.sh --prepare NEW_SOURCE_DIR` |
| November 26 checkpoint | [c84e42a](https://github.com/pragyaangaur/VIctory-macOS/commit/c84e42a3070eebd9d627b84538c92a5ddbff9273), [patch series](checkpoint/patches/series) | `./build.sh --checkpoint --prepare NEW_SOURCE_DIR` |

Both recipes carry the ScarlettMac display-name changes. The checkpoint also carries local picker and GameInput changes. Its mesh output limits and submission wait diagnostics are adapted from derz92’s upstream changes. The queue wait ordering fix comes from Kolkka. [Mesh limits PR #282](https://github.com/pragyaangaur/VIctory-macOS/pull/282) · [Submission diagnostics PR #283](https://github.com/pragyaangaur/VIctory-macOS/pull/283) · [Queue wait order PR #434](https://github.com/pragyaangaur/VIctory-macOS/pull/434)

VIctory-macOS builds on [Marvisak's VIctory](https://github.com/Marvisak/VIctory). Its repository ships a BCPack format table under its [asset policy](https://github.com/pragyaangaur/VIctory-macOS/blob/23ff1f7540952533b283d996a4f3f6710a6f6e85/docs/asset-policy.md). The table is supplied by the pinned upstream checkout. Its Microsoft silicon-rans attribution is recorded separately in [LICENSE-silicon-rans](LICENSE-silicon-rans).

Wine, Apple's D3DMetal, the compiler toolchain, and any game files are supplied separately by their users.
