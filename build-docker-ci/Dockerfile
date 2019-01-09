FROM scratch
MAINTAINER SUSE Documentation Team <doc-team@suse.com>

ADD openSUSE-Leap-42.3-x86_64-1.0.0-Build6.5.tar.xz /

COPY hpe-xsl-stylesheets-1.0.2.1-1.3.noarch.rpm rm-packages rm-files /root/

# Do as much as we can in a single step, to avoid adding layers that make the
# image larger than necessary

RUN zypper ar https://download.opensuse.org/repositories/Documentation:/Tools/openSUSE_Leap_42.3/Documentation:Tools.repo && \
  zypper ar https://download.opensuse.org/repositories/devel:/languages:/ruby:/extensions/openSUSE_Leap_42.3/devel:languages:ruby:extensions.repo && \
  zypper --gpg-auto-import-keys ref -f && \
  zypper -n install -y daps ruby2.1-rubygem-asciidoctor suse-doc-style-checker git geekodoc novdoc tar w3m libreoffice-draw && \
  zypper install -y /root/hpe-xsl-stylesheets-1.0.2.1-1.3.noarch.rpm && \
  zypper clean --all && \
  rpm -e --nodeps $(cat /root/rm-packages) && \
  rm -rf $(cat /root/rm-files) && \
  rm /root/hpe-xsl-stylesheets-1.0.2.1-1.3.noarch.rpm /root/rm-packages /root/rm-files && \
  mkdir -p /root/.config/daps && \
  echo 'DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc"' > /root/.config/daps/dapsrc
