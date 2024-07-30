FROM registry.opensuse.org/documentation/containers/15.6/opensuse-daps-toolchain:latest

COPY build.sh /build.sh
ENTRYPOINT ["/build.sh"]
