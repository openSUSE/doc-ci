# doc-ci/gha-select-dcs

A GitHub Action that performs two somewhat different jobs, to be used as the first action in a validate/build workflow:

* Check whether the `MAIN` files referenced in DC files actually exist ('mode=soundness').
* Check which DC files should be validated/built and create a list of those that can be handed to subsequent jobs ('use-case=list-validate' and 'use-case=list-build').
  * `list-validate` determines a minimal set of documents that need to be validated within a directory automatically based on `MAIN` and `PROF...` settings of DC files.
  * `list-build` determines which documents to build based on an online configuration file at https://github.com/susedoc/susedoc.github.io.

Based upon the theory that container downloads and setup are time-consuming, it should be possible to save time by _not_ creating the maximum number of validate/build jobs.
Thus, this GitHub Action limits generated validate/build jobs in its `list-` modes to 8 runners each.
To disable this behavior and use a separate runner for each document validate/build run, use the parameter `merge-runs=false`.

Minimal example job using all three modes and exposing relevant outputs:

```yaml
jobs:
  select-dc-files:
    runs-on: ubuntu-latest
    outputs:
      validate-list: ${{ steps.select-dc-validate.outputs.dc-list }}
      build-list: ${{ steps.select-dc-build.outputs.dc-list }}
      allow-build: ${{ steps.select-dc-build.outputs.allow-build }}
      relevant-branches: ${{ steps.select-dc-build.outputs.relevant-branches }}
    steps:
      - uses: actions/checkout@v2
      - name: Checking basic soundness of DC files
        uses: openSUSE/doc-ci@gha-select-dcs
        with:
          mode: soundness

      - name: Selecting DC files to validate
        id: select-dc-validate
        uses: openSUSE/doc-ci@gha-select-dcs
        with:
          mode: list-validate

      - name: Selecting DC files to build
        id: select-dc-build
        uses: openSUSE/doc-ci@gha-select-dcs
        with:
          mode: list-build
```


## Inputs

Name | Required? | Type | Default | Explanation
-----|-----------|------|---------|------------
`mode` | yes | string | "" | Whether to check DC file soundness ('soundness'), select DC files for validation ('list-validate'), or select DC files for building ('list-build').
`merge-runs` | no | string | "true" | Only with 'use-case=list-*': If there are more than 8 build/validate runs, run multiple runs in same runner to avoid incurring a container image download each time.
`input-dirs` | no | string | "." | Which input dirs to select DC files from. (Currently noop.)


## Outputs

Name | Type | Explanation
-----|------|------------
`dc-list` | string | 'use-case=list-validate'/'use-case=list-build' only: A list of DC files as a JSON.
`allow-build` | 'true'/'false' | 'use-case=list-build' only: Builds are only allowed if susedoc.github.io configuration is correct.
`relevant-branches` | string | 'use-case=list-build' only: Branches from the source repo that are still relevant and must not be cleaned up during publishing.
