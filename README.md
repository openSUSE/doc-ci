# doc-ci/gha-build

A GitHub Action to build one or multiple documents as HTML or single-HTML with DAPS.

Minimal example job:

```yaml
jobs:
  build-html:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Building DC file(s) DC-a DC-b
        id: build-dc
        uses: openSUSE/doc-ci@gha-build
        with:
          dc-files: "DC-a DC-b"
```


## Inputs

Name | Required? | Type | Default | Explanation
-----|-----------|------|---------|------------
`dc-files` | yes | string | "" | DC files to build from, space-separated (`DC-a DC-b`).
`format-html` | no | bool | "true" | Whether to build HTML documents. (Expect unhandled errors when all formats are set 'false' simultaneously!)
`format-single-html` | no | bool | "true" | Whether to build single-HTML documents. (Expect unhandled errors when all formats are set 'false' simultaneously!)


## Outputs

Name | Type | Explanation
-----|------|------------
`exit-build` | int | Overall exit code for all included builds.
`artifact-name` | string | Naming suggestion for artifact upload (`build-` + SHA-1 sum of input `dc-files` string).
`artifact-dir` | string | Local path to generated output documents.
