# vim:set ft=dockerfile: 
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

LABEL maintainer="support@strapdata.com"
LABEL description="Elassandra Enterprise docker image"

ARG STRAPACK_VERSION
ENV STRAPACK_VERSION ${STRAPACK_VERSION}

ARG STRAPACK_COMMIT
ENV STRAPACK_COMMIT ${STRAPACK_COMMIT}

ENV PROTOCOL https

# Install JCE
RUN apt-get update && apt-get install -y --no-install-recommends unzip && rm -rf /var/lib/apt/lists/* && \
    curl -jksSLH "Cookie: oraclelicense=accept-securebackup-cookie" -o /tmp/unlimited_jce_policy.zip "http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip" && \
    unzip -jo -d /etc/java-8-openjdk/security /tmp/unlimited_jce_policy.zip 

# Add keystores and elasticsearch.yml
COPY --chown=cassandra:cassandra keystore.jks $CASSANDRA_CONF/.keystore
COPY --chown=cassandra:cassandra truststore.jks $CASSANDRA_CONF/.truststore
COPY --chown=cassandra:cassandra cacert.pem $CASSANDRA_CONF/cacert.pem
COPY --chown=cassandra:cassandra elasticsearch.yml $CASSANDRA_CONF/elasticsearch.yml

# Add plugin
COPY --chown=cassandra:cassandra tmp-build/strapdata-enterprise-${STRAPACK_VERSION}.zip /tmp/
RUN cd /usr/share/cassandra \
  && unzip -o /tmp/strapdata-enterprise-${STRAPACK_VERSION}.zip \
  && cd /usr/share/cassandra/strapdata-enterprise-${STRAPACK_VERSION} \
  && ./install.sh \
  && rm -v /tmp/strapdata-enterprise-${STRAPACK_VERSION}.zip

# Enable SSL encryption and authentication
RUN echo 'JVM_OPTS="$JVM_OPTS -Dcassandra.custom_query_handler_class=org.elassandra.index.ElasticQueryHandler"' >> $CASSANDRA_CONF/cassandra-env.sh \
  && yq --yaml-output  '.server_encryption_options.internode_encryption="none"' $CASSANDRA_CONF/cassandra.yaml | \
     yq --yaml-output  '.server_encryption_options.protocol="TLSv1.2"' | \
     yq --yaml-output  ".server_encryption_options.keystore=\"$CASSANDRA_CONF/.keystore\"" | \
     yq --yaml-output  ".server_encryption_options.truststore=\"$CASSANDRA_CONF/.truststore\"" | \
     yq --yaml-output  '.client_encryption_options.enabled=true' | \
     yq --yaml-output  '.client_encryption_options.optional=true' | \
     yq --yaml-output  '.client_encryption_options.protocol="TLSv1.2"' | \
     yq --yaml-output  ".client_encryption_options.keystore=\"$CASSANDRA_CONF/.keystore\"" | \
     yq --yaml-output  ".client_encryption_options.truststore=\"$CASSANDRA_CONF/.truststore\"" | \
     yq --yaml-output  '.authenticator="PasswordAuthenticator"'  | \
     yq --yaml-output  '.authorizer="CassandraAuthorizer"' > $CASSANDRA_CONF/cassandra-ssl.yaml \
  && mv $CASSANDRA_CONF/cassandra-ssl.yaml $CASSANDRA_CONF/cassandra.yaml \
# workaround for cassandra docker-entrypoint.sh
  && echo "# broadcast_rpc_address: 1.2.3.4" >> $CASSANDRA_CONF/cassandra.yaml \
  && { echo "cacert = $CASSANDRA_CONF/cacert.pem"; } > /root/.curlrc \
  && mkdir -p /root/.cassandra && { \
        echo "[connection]"; \
        echo "factory = cqlshlib.ssl.ssl_transport_factory"; \
        echo "[ssl]"; \
        echo "certfile = $CASSANDRA_CONF/cacert.pem"; \
        echo "validate = true"; } > /root/.cassandra/cqlshrc