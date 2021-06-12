FROM registry.opensuse.org/opensuse/leap:15.3
LABEL version="0.1" \
      author="Stefan Knorr" \
      maintainer="SUSE doc team <doc-team@suse.com>"

# Fix tput errors, "tput: No value for $TERM and no -T specified"
ENV TERM xterm-256color

RUN \
  zypper -n install --no-recommends -y openssh git; \
  zypper clean --all

COPY publish.sh /publish.sh
ENTRYPOINT ["/publish.sh"]
