Continuous Documentation for SUSE Documentation
***********************************************

.. image:: https://travis-ci.org/openSUSE/doc-ci.svg?branch=develop
    :target: https://travis-ci.org/openSUSE/doc-ci
    :alt: Travis CI

This repository contains tooling to quickly set up Travis CI on SUSE
and openSUSE documentation repositories.

Currently, setting up this repository means that the following checks
will be run automatically:

* XML validation with DAPS (using GeekoDoc for DocBook 5 content)
* Check for missing images

Additionally, you can use Travis CI to push live builds to susedoc.github.io.
For details, see https://github.com/openSUSE/doc-ci#travis-draft-builds


Enabling Travis for Doc Repositories
====================================

If you want doc repos to be checked with Travis, do the following:

1. On the Travis Web UI:

   a. Open https://travis-ci.org/profile/SUSE and search for your repository.
      If you cannot find it, click the "Sync account" button on the upper right
      corner.

   b. Enable the doc repo in Travis.

2. On the GitHub Web UI:

   a. Open your repo's "Settings" page.

   b. Under "Integrations & services", choose "Add service" > "Travis CI"
  
   c. Click "Add service"

3. In your documentation repo:

   a. In your doc repo, create a feature branch (for example, ``feature/travis``):

      .. code::

        $ git checkout -b feature/travis

   b. Copy the following files from this repo into your doc repo:
      * ``travis/template/.travis.yml`` - The main setup file for Travis
      * ``travis/template/Dockerfile`` - The main setup file for the openSUSE Docker container
      * ``.dockerignore`` - Files in your repo that should be ignored by Docker

   c. [Optional] By default, Travis will run over DC files matching the pattern
      ``DC-*-all``. If none exist, it will use the pattern ``DC-*`` instead. To
      set up any other set of DC files to check, add a file named ``.travis-check-docs``
      to your repo. In this file, list the names of all DC files to check, separated by
      newlines (``\n``)

   c. Push the feature branch with:

      .. code::

          $ git push --set-upstream origin feature/travis

   d. Wait and see for the results. If you encounter an issue, contact
      `@tomschr <https://github.com/tomschr/>`_ or `@svenseeberg <https://github.com/svenseeberg/>`_.

   e. Merge your branch into ``develop``.


Travis Draft Builds
===================

Concept
-------
We want to publish HTML builds of our public repositories on https://susedoc.github.io.
To build the documentation, we are using Travis CI which is already triggered
for each commit. Our default Travis CI script receives an environment variable from
the .travis.yml file with all branches that should be published. If the commit, that
Travis is currently validating, belongs to one of those branches, a build will
be triggered. Travis then needs to push the builds to the target repositories in
the SUSEdoc organization. For that, each target repository has a SSH public key
with write access that is used by Travis. The SSH private key is stored in
the corresponding source repository in an encrypted file. Travis uses an internal
private key to decrypt this SSH private key.

Configuring Travis CI
---------------------

To create draft builds of branches in a repository, first deploy Travis
CI as described in the previous section. Then follow this procedure:

1. Install the Travis CLI. This can also be done on a machine with SSH
   access.

2. Create a new SSH key pair that can be used for deploying to GitHub
   pages and copy the encrypted private key to the documentation source
   code repository.

   a. Create a new directory and in it key pair in the current working directory.
      Do not set a password for the key file.

      .. code::

         > ssh-keygen -t rsa -b 4096 -C "doc-team@suse.com" -f id_rsa

   b. Create a secret that will be used to encrypt the SSH private key:

      .. code::

         > echo $(openssl rand -base64 64 | tr -d '\n') > secret

      Store the SSH key and also the secret in the internal doc-dotfiles
      repository.

   c. Encrypt the private key with the secret and copy the encrypted file
      to the documentation source repository.

      .. code::

         > openssl aes-256-cbc -pass "file:./secret" -in ./id_rsa -out ./ssh_key.enc -a
         > cp ssh_key.enc /PATH/TO/XML/REPO/ssh_key.enc
         > cat secret

      Copy and paste the string from the secret file, you will need it for
      the next step.

   d. We now crate an environment variable named
      ENCRYPTED_PRIVKEY_SECRET that stores the secret and then we
      encrypt this full string to be included in the .travis.yml

      .. code::

         > travis.ruby2.1 encrypt -r SUSE/doc-repo ENCRYPTED_PRIVKEY_SECRET=INSERT_SECRET_STRING

      Take the result and in the .travis.yml replace the string
      ADD_ENCRYPTED_SECRET with the result. Do not copy the quotes from
      the result.

      Some details why we are doing this: Travis CI needs to decrypt
      the SSH private key file on every run. You can set environment
      variables in the Web UI of Travis CI for each repository. For
      additional security, we will again encrypt the secret that Travis
      needs to decrypt the SSH key. This is necessary because
      environment variables can leak over unwanted paths.

      To achieve this encryption, Travis CI has a private and public
      key for each repository. Travis CI keeps the private key and
      allows encrypting arbitrary data with the public key over it's
      API.

3. Create a repository in the SUSEdoc organization and add the SSH public
   key as a deployment key.

4. Create a file named .travis-build-docs in the root directory of your
   repository and add all DC files that should be build. Use one line
   per DC file.

5. Add links to the builds to the index.html of the
   SUSEdoc/susedoc.github.io repository.

Docker Image susedoc/ci
=======================

Building Docker Image for hub.docker.com
----------------------------------------

1. Get openSUSE Leap base image from https://github.com/openSUSE/docker-containers-build/tree/openSUSE-Leap-42.3/x86_64

2. Get Dockerfile from doc-ci repo: https://github.com/openSUSE/doc-ci/raw/develop/build-docker-ci/Dockerfile

3. Place both files into one folder and run

   .. code::

      > docker build ./

4. Tag the image and upload it

   .. code::

      > docker tag IMAGE_ID susedoc/ci:openSUSE-42.3
      > docker push susedoc/ci:openSUSE-42.3
