#!/bin/bash

# Set memlock limit to unlimited (before set -e)
ulimit -l unlimited 2&>/dev/null

set -e

[ "$DEBUG" ] && set -x

# first arg is `-f` or `--some-option`
# or there are no args
if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
	set -- cassandra -f "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'cassandra' -a "$(id -u)" = '0' ]; then
	find /var/lib/cassandra /var/log/cassandra "$CASSANDRA_CONFIG" \
		\! -user cassandra -exec chown cassandra '{}' +
	exec gosu cassandra "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'cassandra' ]; then
  export JVM_OPTS

  # Add JMX prometheus exporter
  if [ -n "${CASSANDRA_JMX_PROMETHEUS_EXPORTER_PORT}" ]; then
     JVM_OPTS="$JVM_OPTS -javaagent:/usr/share/cassandra/agents/jmx_prometheus_javaagent.jar=${CASSANDRA_JMX_PROMETHEUS_EXPORTER_PORT}:${CASSANDRA_JMX_PROMETHEUS_EXPORTER_CONF:-/etc/cassandra/jmx_prometheus_exporter.yml}"
  fi

  echo "JVM_OPTS=$JVM_OPTS"
fi

# kick off the upstream command
exec /docker-entrypoint.sh "$@"
