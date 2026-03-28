# DivvyClick Development Guide

## Formatting the swift code

```bash
$ bazel run //tools/format:format
```

## Linting the build files

```bash
$ bazel run -- @buildifier_prebuilt//:buildifier -- -lint=fix $(find $PWD -name 'BUILD.bazel')
```
