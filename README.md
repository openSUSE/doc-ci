# doc-ci: GitHub Actions example workflow and actions for DAPS documentation

This repository collects CI tooling for the SUSE documentation team.
Tooling on this branch and the other `gha-` branches is for GitHub Actions.

This repository makes extensive use of orphan branches, because each branch does completely disparate things.


## Branches


### Current branches

Name | Content | Description
-----|---------|------------
`gha-workflow-example` | example workflow file | An example workflow file to validate, build, and publish documentation with DAPS. (You are here.)
`gha-select-dcs` | action | An action that allows checking basic DC file properties and making lists of which DC files to validate and build from. [Action-specific readme](https://github.com/openSUSE/doc-ci/tree/gha-select-dcs#readme)
`gha-validate` | action | An action that validates DC files with DAPS. [Action-specific readme](https://github.com/openSUSE/doc-ci/tree/gha-validate#readme)
`gha-build` | action | An action that builds HTML and single-HTML from DC files with DAPS. [Action-specific readme](https://github.com/openSUSE/doc-ci/tree/gha-build#readme)
`gha-publish` | action | An action that publish artifacts into a Git repository. [Action-specific readme](https://github.com/openSUSE/doc-ci/tree/gha-publish#readme)


### Old branches

Name | Description
-----|------------
`travis-obsolete` | Travis CI script and container build description (deprecated)


## Container images used currently

All containers used by current versions of our tooling come from https://build.opensuse.org/project/show/Documentation:Containers.
They can be downloaded from https://registry.opensuse.org.

* `opensuse-daps-toolchain`: Main (large) toolchain container used for `gha-build`.
* `opensuse-daps-toolchain-mini`: Smaller toolchain container used for `gha-select-dcs` and `gha-validate`.
* `opensuse-git-ssh`: Very basic Git/SSH container used for `gha-publish`.

All of the above containers are currently based on openSUSE Leap 15.3.


## Enabling GitHub Actions within documentation repositories


### Setting up DAPS validation only

Copy the file `docbook.yml` from this repository into the path `.github/workflows/` of your documentation repository.
Delete the line with `build-html:` and all lines after it.


### Enabling DAPS validation and preview builds

For official SUSE repositories, all actions below that involve the GitHub web interface should be performed as @suse-docs-bot.
This avoids creating automated pushes under your own GitHub account name, which may confuse people.
@suse-docs-bot only needs access to the repo when you upload the key and should be removed from contributor list of the source repo immediately after that.
If you do not have access to the @suse-docs-bot account, ask @fsundermeyer, @tomschr, or @taroth21 to perform the below actions for you.

1.  To allow for builds to be uploaded into a publishing Git repository, create an SSH key pair that can be used as a deploy key.
    We use an internal repository to hold the SSH deploy keys to make sure they are not lost.

    a.  Clone the internal [`doc-ci-secrets`](https://gitlab.nue.suse.com/susedoc/doc-ci-secrets) repository.

    b.  Create a new directory named after your repository in `doc-ci-secrets/ci-ssh-docs-bot` (if you are using the @suse-docs-bot user account; otherwise use the directory `ci-ssh`).

    c.  Generate a key pair in within this directory.
        Do not set a password for the key file.

        ssh-keygen -t rsa -b 4096 -C "doc-team+docbot@suse.com" -f id_rsa

    d.  Commit/push both key files, `id_rsa` and `id_rsa.pub`.

2.  Create a new target repository for publishing within the organization https://github.com/susedoc.
    Ideally, the name of the target repository should match the name of the source repository.

3.  Clone the target repository locally, create a ``gh-pages`` branch in it and create an initial commit:

    ```
    git clone git@github.com:SUSEdoc/doc-repo doc-repo-publish && doc-repo-publish
    git checkout -b gh-pages
    git commit --allow-empty -m"Initial Commit"
    git push origin gh-pages
    ```

4.  Add the `id_rsa.pub` public key as a deploy key for the target repository.
    Open the repository's page on GitHub, then click _Settings_ > _Deploy keys_.
    Click _Add deploy key_, then copy the text content of `id_rsa.pub`.
    Make sure to enable _Allow write access_.

5.  Within the source repository, set up the `id_rsa` private key as a GitHub Actions secret.
    Open the repository's page on GitHub, then click _Settings_ > _Secrets_ > _Actions_.
    Click _New repository secret_, then copy the text content of `id_rsa`.
    Give it a name such as `DEPLOY_KEY_` and the name of the repository.
    (Names of secrets must only include underscores and capital letters.)

6.  Copy the file `docbook.yml` from this repository into the path `.github/workflows/` of your documentation repository.
    Update the value `DEPLOY_KEY: ${{ secrets.DEPLOY_KEY_SLE }}` with the name that you gave your deploy key in the previous step.
    Update the value of `original-org: SUSE` with the name of the home org of your repository (which may very well be `SUSE` too).
