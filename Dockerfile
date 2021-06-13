FROM registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain-mini:latest

COPY validate.sh /validate.sh
ENTRYPOINT ["/validate.sh"]
