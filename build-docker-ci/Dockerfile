FROM scratch
MAINTAINER SUSE Containers Team <containers@suse.com>
ADD openSUSE-Leap-42.3.base.x86_64.tar.xz /
RUN zypper ar http://download.opensuse.org/repositories/Documentation:/Tools/openSUSE_Leap_42.3/Documentation:Tools.repo
RUN zypper --gpg-auto-import-keys ref -f
RUN zypper install -y daps git geekodoc novdoc tar
RUN mkdir -p /root/.config/daps
RUN echo 'DOCBOOK5_RNG_URI="https://github.com/openSUSE/geekodoc/raw/master/geekodoc/rng/geekodoc5-flat.rnc"' > /root/.config/daps/dapsrc
RUN zypper clean --all
