Continuous Documentation for SUSE Documentation
***********************************************

.. image:: https://travis-ci.org/openSUSE/doc-ci.svg?branch=develop
    :target: https://travis-ci.org/openSUSE/doc-ci
    :alt: Travis CI

This repository is meant to be as a placeholder for all doc relevant
SUSE repositories (usually SUSE/doc-*) maintained by the doc team.

Currently, it contains a shell script to run tests against XML files.


Design
======

To improve maintainability of the ``.travis.yml`` files in all doc
repos and all branches, this file should contain:

* a :program:`wget` call to this Git repo to download a script which
  does all the heavy lifting
* a line to execute the downloaded script in a docker container with
  openSUSE 42.3
* If DC-*-all files exist, they will be validated. Otherwise, all
  DC-* files will be validated.


Enable Travis for Doc Repositories
==================================

If you want doc repos to be checked with Travis, do the following:

1. Open https://travis-ci.org/profile/SUSE and search for your repository.
   If you cannot find it, click the "Sync account" button on the upper right
   corner.

2. Enable the doc repo in Travis.

3. In your doc repo, create a feature branch (for example, ``feature/travis``):

       $ git flow feature start travis

4. Copy the ``travis/template/.travis.yml`` file from this repo into your
   root directory for your local doc repo.

5. Publish the feature branch with:

       $ git flow feature publish

6. Wait and see for the results. If there any problems, contact @tomschr or @svenseeberg.

7. Merge your branch into develop.
