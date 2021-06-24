FROM registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain:latest

COPY docserv-dchash /docserv-dchash
COPY select-dcs.sh /select-dcs.sh
ENTRYPOINT ["/select-dcs.sh"]
