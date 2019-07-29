This directory is used to build the susedoc/ci:openSUSE-42.3-sbp container.
This container in itself is a bit of a temporary workaround, necessitated by:

* a reluctance to upgrade from the now-unmaintained Leap 42.3 to something newer
  (because on newer versions of Leap, PDF documents get some bad formatting)
* not all necessary repos exist anymore for Leap 42.3, so it is not an option to
  completely rebuild the container currently
* we needed support for SBP stylesheets (package suse-xsl-stylesheets-sbp)
* we needed a compatibility fix for some profiled Novdoc documents (SES 1.0,
  Cloud 1.0..4.0) (https://github.com/openSUSE/daps/commit/49af9040)

Hopefully, all of this ugliness can be removed soon.
