# doc-ci: GitHub Actions example workflow and actions for DAPS documentation

This repository collects CI tooling for the SUSE documentation team.
Newer tooling is all made for GitHub Actions.
Older tooling for Travis CI is still around.


## Branches

### Current branches

Name | Type | Description
-----|------|------------
`gha-workflow-example` | example workflow file | An example workflow file to validate, build, and publish documentation with DAPS. (You are here.)
`gha-select-dcs` | action | An action that allows checking basic DC file properties and making lists of which DC files to validate and build from.
`gha-validate` | action | An action that validates DC files with DAPS.
`gha-build` | action | An action that builds HTML and single-HTML from DC files with DAPS.
`gha-publish` | action | An action that publish artifacts into a Git repository.

### Old branches

Name | Description
-----|------------
`develop` | Old Travis CI script and container build description (deprecated)
`master` | Slightly newer Travis CI script and container build description (deprecated)


## Container images used currently

All containers used by current versions of our tooling come from https://build.opensuse.org/project/show/Documentation:Containers.
They can be downloaded from https://registry.opensuse.org.

* `opensuse-daps-toolchain`: Main (large) toolchain container used for `gha-build`.
* `opensuse-daps-toolchain-mini`: Smaller toolchain container used for `gha-select-dcs` and `gha-validate`.
* `opensuse-git-ssh`: Very basic Git/SSH container used for `gha-publish`.

All of the above containers are currently based on openSUSE Leap 15.2.
