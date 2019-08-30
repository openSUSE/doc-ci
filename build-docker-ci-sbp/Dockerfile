FROM susedoc/ci:openSUSE-42.3
MAINTAINER SUSE Documentation Team <doc-team@suse.com>

COPY suse-xsl-stylesheets-2.0.14-0.noarch.rpm \
     suse-xsl-stylesheets-sbp-2.0.14-0.noarch.rpm \
     catalog-d.xml \
       /root/

RUN rpm -i --force /root/suse-xsl-stylesheets-2.0.14-0.noarch.rpm && \
    rpm -i --force /root/suse-xsl-stylesheets-sbp-2.0.14-0.noarch.rpm && \
    cp /root/catalog-d.xml /etc/xml/catalog-d.xml && \
    rm /root/catalog-d.xml
