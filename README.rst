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
      * ``Dockerfile`` - The main setup file for the openSUSE Docker container
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
