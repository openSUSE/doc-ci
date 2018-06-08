FROM scratch
MAINTAINER SUSE Documentation Team <doc-team@suse.com>
ADD openSUSE-Leap-42.3-x86_64-1.0.0-Build6.5.tar.xz /
RUN zypper ar https://download.opensuse.org/repositories/Documentation:/Tools/openSUSE_Leap_42.3/Documentation:Tools.repo
RUN zypper ar https://download.opensuse.org/repositories/devel:/languages:/ruby:/extensions/openSUSE_Leap_42.3/devel:languages:ruby:extensions.repo
RUN zypper --gpg-auto-import-keys ref -f
RUN zypper install -y daps-devel suse-doc-style-checker git geekodoc novdoc tar
RUN mkdir -p /root/.config/daps
RUN echo 'DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc"' > /root/.config/daps/dapsrc
RUN zypper clean --all
