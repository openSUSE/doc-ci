FROM registry.opensuse.org/opensuse/leap:15.2
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
# * Documentation:Tools:Auto -- for unstable versions of DAPS (prio 4 = higher than D:T, so we get DAPS from this project)

COPY rm-packages rm-files /root/
RUN zypper ar -p 10 obs://Documentation:Tools doc_tools && \
  zypper ar -p 8 obs://M17N:fonts m17n_fonts && \
  zypper ar -p 6 obs://devel:languages:python dev_lang_python && \
  zypper ar -p 4 obs://Documentation:Tools:Auto doc_tools_auto && \
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
