# doc-ci/gha-validate

A GitHub Action to validate one or multiple documents with DAPS.

Minimal example job:

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Validating DC file(s) DC-a DC-b
        uses: openSUSE/doc-ci@gha-validate
        with:
          dc-files: "DC-a DC-b"
```


## Inputs

Name | Required? | Type | Default | Explanation
-----|-----------|------|---------|------------
`dc-files` | yes | string | "" | DC files to validate, space-separated (`DC-a DC-b`).
`validate-ids` | no | bool | "true" | Enable check whether all referenced `xml:id`s adhere to the character set `[a-z0-9-]` (`daps validate --validate-ids`).
`validate-images` | no | bool | "true" | Enable check whether all referenced images exist (`daps validate --validate-images`).
`validate-tables` | no | bool | "true" | Enable check whether all tables within the document are valid (`daps/libexec/validate-tables.py`).
`xml-schema` | no | string | "geekodoc1" | XML schema to use for DocBook 5-based documents (`geekodoc1`, `geekodoc2`, `docbook51`, `docbook52`).


## Outputs

Name | Type | Explanation
-----|------|------------
`exit-validate` | int | Overall exit code for all included validates.
