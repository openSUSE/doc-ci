# FIXME: We should really use a smaller base container here!
FROM registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain:latest

COPY docserv-dchash /docserv-dchash
COPY select-dcs.sh /select-dcs.sh
ENTRYPOINT ["/select-dcs.sh"]
