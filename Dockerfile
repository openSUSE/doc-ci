FROM registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain:latest

COPY build.sh /build.sh
ENTRYPOINT ["/build.sh"]
