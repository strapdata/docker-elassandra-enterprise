# vim:set ft=dockerfile: 
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

LABEL maintainer="support@strapdata.com"
LABEL description="Elassandra Enterprise docker image"

ARG ENTERPRISE_PLUGIN_VERSION
ENV ENTERPRISE_PLUGIN_VERSION ${ENTERPRISE_PLUGIN_VERSION}

ARG ENTERPRISE_PLUGIN_COMMIT
ENV ENTERPRISE_PLUGIN_COMMIT ${ENTERPRISE_PLUGIN_COMMIT}

ENV PROTOCOL https

# Install JCE
RUN apt-get update && apt-get install -y --no-install-recommends unzip && rm -rf /var/lib/apt/lists/* && \
    curl -jksSLH "Cookie: oraclelicense=accept-securebackup-cookie" -o /tmp/unlimited_jce_policy.zip "http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip" && \
    unzip -jo -d /etc/java-8-openjdk/security /tmp/unlimited_jce_policy.zip 

# Add keystores and elasticsearch.yml
COPY --chown=cassandra:cassandra cacert.pem $CASSANDRA_CONF/cacert.pem
COPY --chown=cassandra:cassandra keystore.jks $CASSANDRA_CONF/server-keystore.jks
COPY --chown=cassandra:cassandra truststore.jks $CASSANDRA_CONF/server-truststore.jks
COPY --chown=cassandra:cassandra keystore.jks $CASSANDRA_CONF/client-keystore.jks
COPY --chown=cassandra:cassandra truststore.jks $CASSANDRA_CONF/client-truststore.jks
COPY --chown=cassandra:cassandra elasticsearch.yml $CASSANDRA_CONF/elasticsearch.yml
COPY --chown=cassandra:cassandra cqlshrc /home/cassandra/.cassandra/cqlshrc

# Overwrite the log configuration to include audit appender.
COPY logback.xml /etc/cassandra/

# Add the strapdata enterprise plugin
COPY --chown=cassandra:cassandra tmp-build/strapdata-enterprise-${ENTERPRISE_PLUGIN_VERSION}.zip /tmp/
RUN unzip -o /tmp/strapdata-enterprise-${ENTERPRISE_PLUGIN_VERSION}.zip -d /usr/share/cassandra \
  && cd /usr/share/cassandra/strapdata-enterprise-${ENTERPRISE_PLUGIN_VERSION} \
  && ./install.sh \
  && rm -v /tmp/strapdata-enterprise-${ENTERPRISE_PLUGIN_VERSION}.zip

# Enable cassandra security features
ENV CASSANDRA__server_encryption_options__internode_encryption none
ENV CASSANDRA__server_encryption_options__protocol TLSv1.2
ENV CASSANDRA__server_encryption_options__keystore /etc/cassandra/server-keystore.jks
ENV CASSANDRA__server_encryption_options__truststore /etc/cassandra/server-truststore.jks
ENV CASSANDRA__client_encryption_options__enabled true
ENV CASSANDRA__client_encryption_options__optional true
ENV CASSANDRA__client_encryption_options__protocol TLSv1.2
ENV CASSANDRA__client_encryption_options__keystore /etc/cassandra/client-keystore.jks
ENV CASSANDRA__client_encryption_options__truststore /etc/cassandra/client-truststore.jks
ENV CASSANDRA__authenticator PasswordAuthenticator
ENV CASSANDRA__authorizer CassandraAuthorizer

RUN echo 'JVM_OPTS="$JVM_OPTS -Dcassandra.custom_query_handler_class=org.elassandra.index.EnterpriseElasticQueryHandler"' >> $CASSANDRA_CONF/cassandra-env.sh \
  && { echo "cacert = $CASSANDRA_CONF/cacert.pem"; } > /root/.curlrc \
  && mkdir /root/.cassandra
 
# copy .cqlshrc pointing to /etc/cassandra/cacert.pem
COPY cqlshrc /root/.cassandra/cqlshrc

COPY docker-entrypoint-enterprise.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint-enterprise.sh /docker-entrypoint-enterprise.sh # backwards compat
ENTRYPOINT ["docker-entrypoint-enterprise.sh"]
  
