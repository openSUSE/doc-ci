# xml-doc-action

GitHub Action to manage XML files through [DAPS](https://github.com/openSUSE/daps).

A simple example to use this action in your doc repository:

```yaml
on:
  push

jobs:
  validate:
     runs-on: ubuntu-latest

     steps:
       - uses: actions/checkout@v2

       - name: Validate with DAPS
         uses: tomschr/xml-doc-action@main
         with:
            command: daps -v -d DC-test validate
```


## Inputs

Name                | Required? | Type     | Default | Explanation
--------------------|-----------|----------|---------|------------------------
`command`           | yes*      | string   | `daps --version` | The DAPS command to use


## Outputs

Name            | Type | Explanation
----------------|------|-----------------
`dapsexitcode`  | int  | The exit code from the input command