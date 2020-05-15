FROM opensuse/leap:15.1
MAINTAINER SUSE Documentation Team <doc-team@suse.com>

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8


# Do as much as we can in a single step, to avoid adding layers that make the
# image larger than necessary:
# * Add necessary repos
# * Install
# * Remove packages unnecessary for running DAPS (few)
# * Remove files unnecessary for running DAPS (many)

# Additional repos:
# * Documentation:Tools -- up-to-date versions of DAPS and all[!] stylesheets
# * M17N:fonts -- Work Sans font (in the future)
# * devel:languages:python -- we need LXML 4.2.0 or later, https://github.com/openSUSE/daps/issues/539#issuecomment-585926182

COPY rm-packages rm-files /root/
RUN zypper ar https://download.opensuse.org/repositories/Documentation:/Tools/openSUSE_Leap_15.1/Documentation:Tools.repo && \
  zypper ar https://download.opensuse.org/repositories/M17N:/fonts/openSUSE_Leap_15.1/M17N:fonts.repo && \
  zypper ar https://download.opensuse.org/repositories/devel:/languages:/python/openSUSE_Leap_15.1/devel:languages:python.repo && \
  zypper --gpg-auto-import-keys ref -f && \
  zypper -n install -y daps ruby2.5-rubygem-asciidoctor suse-doc-style-checker git geekodoc novdoc tar w3m libreoffice-draw curl hpe-xsl-stylesheets suse-xsl-stylesheets-sbp && \
  zypper clean --all && \
  for package in $(cat /root/rm-packages); do \
    [[ $(rpm -qi "$package" 1>/dev/null) ]] || rpm -e --nodeps "$package"; \
  done && \
  rm -rf $(cat /root/rm-files) && \
  rm /root/rm-packages /root/rm-files

RUN mkdir -p /root/.config/daps && \
    echo 'DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc"' > /root/.config/daps/dapsrc


# We need a NovDoc profiling fix until we get DAPS 3.0.1 in the container,
# https://github.com/openSUSE/daps/commit/49af9040

COPY daps-extra-catalog.xml /etc/xml/catalog.d/
RUN update-xml-catalog
