# https://docs.github.com/en/actions/creating-actions/dockerfile-support-for-github-actions
FROM registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain:latest
LABEL version="0.1" \
      author="Tom Schraitle/Stefan Knorr" \
      maintainer="SUSE doc team <doc-team@suse.com>"

COPY validate.sh /validate.sh

# Code file to execute when the docker container starts up:
ENTRYPOINT ["/validate.sh"]
