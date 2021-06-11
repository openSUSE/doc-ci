# https://docs.github.com/en/actions/creating-actions/dockerfile-support-for-github-actions
# FIXME: We should really use a smaller base container here!
FROM registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain:latest
LABEL version="0.1" \
      author="Stefan Knorr" \
      maintainer="SUSE doc team <doc-team@suse.com>"

# Fix tput errors, "tput: No value for $TERM and no -T specified"
ENV TERM xterm-256color

COPY docserv-dchash /docserv-dchash
COPY select-dcs.sh /select-dcs.sh
# Code file to execute when the docker container starts up:
ENTRYPOINT ["/select-dcs.sh"]
