FROM susedoc/ci:latest

COPY validate.sh /validate.sh
ENTRYPOINT ["/validate.sh"]
