# Contributing to Spolo

Thanks for helping. Bug reports, translations and small, focused pull requests are all welcome.

## Building

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
scripts/build.sh        # build/Spolo.app, signed to run locally
scripts/preflight.sh    # builds both release configurations and checks them
scripts/test-merge.sh   # end-to-end merge tests with generated media (needs ffmpeg)
```

Edit `project.yml`, not the `.xcodeproj`.

## Pull requests

- Keep one change per pull request, and describe how you tested it.
- `scripts/preflight.sh` and `scripts/test-merge.sh` must pass.
- Spolo stays offline: no network access, analytics or third-party code.
- New user-facing text goes into `Resources/zh-Hans.lproj/Localizable.strings` and `Resources/zh-Hant.lproj/Localizable.strings`, and into `en-GB.lproj` when British English differs.

By contributing you agree that your work is licensed under the [Apache License 2.0](LICENSE).
