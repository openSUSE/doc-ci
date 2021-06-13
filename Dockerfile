FROM registry.opensuse.org/documentation/containers/containers/opensuse-git-ssh:latest
LABEL version="0.1" \
      author="Stefan Knorr" \
      maintainer="SUSE doc team <doc-team@suse.com>"

COPY publish.sh /publish.sh
ENTRYPOINT ["/publish.sh"]
