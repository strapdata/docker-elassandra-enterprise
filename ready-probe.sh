#!/bin/bash
#
# Check for elassandra availability.
# Override .curlrc for SSL client auth
#set -x
timeout=${READINESS_PROBE_TIMEOUT:-30}

# curl -LI http://www.example.org -o /dev/null -w '%{http_code}\n' -s
if [[ $(nodetool status | grep $POD_IP) == *"UN"* ]]; then
  if [[ "${CASSANDRA_DAEMON:-"org.apache.cassandra.service.CassandraDaemon"} == "org.apache.cassandra.service.CassandraDaemon" ]]; then
     exit 0;
  else 
     rc = $(curl -sLI -w '%{http_code}\n' -o /dev/null --max-time $timeout "${PROTOCOL:-http}://localhost:9200/")
     if [[ $DEBUG ]]; then
        echo "Elasticsearch rc="+rc;
     fi
     case "$rc" in
     "200")
     "401")
	exit 0;;
     esac
     if [[ $DEBUG ]]; then
        echo "Elasticsearch not UP";
     fi
     exit 2;
  fi
else
  if [[ $DEBUG ]]; then
     echo "Cassandra not UP";
  fi
  exit 1;
fi
