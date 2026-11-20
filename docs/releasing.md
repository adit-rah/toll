# Releasing

A TestFlight build is a `vX.Y.Z` tag on `main`. Xcode Cloud builds the tag; `ios/ci_scripts/ci_post_clone.sh` makes the tag the app's version, and the build number comes from Xcode Cloud.

## It happens by itself
When a merge to `main` changes the app (`ios/**`), the `ios` workflow builds and tests it. If that passes, the `release` workflow creates the next tag and a GitHub prerelease with generated notes, and Xcode Cloud picks the tag up. Nobody chooses a number.

- **The number:** `ios/scripts/next-version.sh` adds one to the patch of the newest `vX.Y.Z` tag. Run it to see what the next release will be.
- **A minor release** (0.2.x → 0.3.0): raise `MARKETING_VERSION` in `ios/Config/Base.xcconfig` to `0.3.0` in the pull request. The next release is then `v0.3.0`, and patches count from there.
- **Drift is caught:** every `ios` run checks that `Base.xcconfig` is not behind the newest tag (`next-version.sh --check`), and fails if it is.
- **Not twice:** a commit that already has a tag is not released again. When several merges land close together, only the newest commit on `main` is released.
- **Docs-only merges** don't run `ios`, so they make no build.

## By hand
To release `main` without a change to the app (for example, to rebuild after an Xcode Cloud failure): GitHub → Actions → **release** → Run workflow. It is skipped if `main`'s newest commit is already tagged.

Don't create `v*` tags yourself: the next automatic release counts from whatever tag is newest.
