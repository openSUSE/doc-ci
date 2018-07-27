FROM scratch
MAINTAINER SUSE Documentation Team <doc-team@suse.com>

ADD openSUSE-Leap-42.3-x86_64-1.0.0-Build6.5.tar.xz /

COPY hpe-xsl-stylesheets-1.0.2.1-1.3.noarch.rpm /root/hpe-xsl-stylesheets.rpm

# Do as much as we can in a single step, to avoid adding layers that make the
# image larger than necessary

RUN zypper ar https://download.opensuse.org/repositories/Documentation:/Tools/openSUSE_Leap_42.3/Documentation:Tools.repo && \
  zypper ar https://download.opensuse.org/repositories/devel:/languages:/ruby:/extensions/openSUSE_Leap_42.3/devel:languages:ruby:extensions.repo && \
  zypper --gpg-auto-import-keys ref -f && \
  zypper -n install -y daps-devel suse-doc-style-checker git geekodoc novdoc tar && \
  zypper install -y /root/hpe-xsl-stylesheets.rpm && \
  rm /root/hpe-xsl-stylesheets.rpm && \
  zypper clean --all && \
  mkdir -p /root/.config/daps && \
  echo 'DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc"' > /root/.config/daps/dapsrc
