FROM registry.opensuse.org/documentation/containers/15.6/opensuse-daps-toolchain-mini:latest

COPY validate.sh /validate.sh
ENTRYPOINT ["/validate.sh"]
