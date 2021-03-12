# Leap 15.1 is the last system to support the Python 2 pdfcompare tool
FROM registry.opensuse.org/opensuse/leap:15.1
MAINTAINER SUSE Documentation Team <doc-team@suse.com>

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN zypper ar -p 10 https://download.opensuse.org/repositories/Documentation:/Tools/openSUSE_Leap_15.1/Documentation:Tools.repo && \
  zypper --gpg-auto-import-keys ref -f && \
  zypper -n install -y pdfcompare && \
  zypper clean --all
