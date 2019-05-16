FROM scratch
MAINTAINER SUSE Documentation Team <doc-team@suse.com>

# from https://github.com/openSUSE/docker-containers-build/blob/openSUSE-Leap-42.3/x86_64/openSUSE-Leap-42.3-x86_64-1.0.0-Build6.5.tar.xz
ADD openSUSE-Leap-42.3-x86_64-1.0.0-Build6.5.tar.xz /

COPY rm-packages rm-files /root/

# Do as much as we can in a single step, to avoid adding layers that make the
# image larger than necessary


RUN zypper ar https://download.opensuse.org/repositories/Documentation:/Tools/openSUSE_Leap_42.3/Documentation:Tools.repo && \
  zypper --gpg-auto-import-keys ref -f && \
  zypper -n install -y git openssl libxml2-tools libxslt-tools xmlstarlet && \
  zypper clean --all && \
  rpm -e --nodeps $(cat /root/rm-packages) && \
  rm -rf $(cat /root/rm-files) && \
  rm /root/rm-packages /root/rm-files
