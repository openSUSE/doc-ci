FROM registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain:latest

COPY validate.sh /validate.sh
ENTRYPOINT ["/validate.sh"]
