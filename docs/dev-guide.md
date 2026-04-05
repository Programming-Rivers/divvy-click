# DivvyClick Development Guide

## Formatting the swift code

```bash
$ bazel run //tools/format:format
```

## Linting the build files

```bash
$ bazel run -- @buildifier_prebuilt//:buildifier -- -lint=fix $(find $PWD -name 'BUILD.bazel')
```

## Distribution

To package the application into a `.dmg` file for distribution (e.g., for GitHub Releases):

```bash
$ bazel run //:package_dmg
```

This will build the application and create a `DivvyClick.dmg` in the `bazel-bin/` directory. The DMG includes a shortcut to the `/Applications` folder for easy installation.

