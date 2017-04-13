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
* a line to execute the downloaded script
