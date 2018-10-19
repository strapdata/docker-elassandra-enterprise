#!/bin/bash
#
# Check for elassandra availability.
#
# MONITOR_SSL_CLIENT_CERT could be your client-auth certificate and keystore (filename of a mounted k8s secret)
# MONITOR_SSL_CLIENT_CERT_TYPE should be your client-auth certificate file type, p12 by default
#
if [[ $DEBUG ]]; then
  set -x
fi

_ip_address() {
	# scrape the first non-localhost IP address of the container
	# in Swarm Mode, we often get two IPs -- the container IP, and the (shared) VIP, and the container IP should always be first
	ip address | awk '
		$1 == "inet" && $NF != "lo" {
			gsub(/\/.+$/, "", $2)
			print $2
			exit
		}
	'
}

POD_IP=${POD_IP:-$(_ip_address)}

if [[ $(nodetool status | grep ${POD_IP}) == *"UN"* ]]; then
  if [[ "${CASSANDRA_DAEMON:-org.apache.cassandra.service.CassandraDaemon}" == "org.apache.cassandra.service.CassandraDaemon" ]]; then
     exit 0;
  else 
     rc=$(curl -sLI -k -w '%{http_code}\n' ${MONITOR_SSL_CLIENT_CERT:+"--cert"} ${MONITOR_SSL_CLIENT_CERT} ${MONITOR_SSL_CLIENT_CERT:+"--cert-type"} ${MONITOR_SSL_CLIENT_CERT:+"${MONITOR_SSL_CLIENT_CERT_TYPE:-p12}"} -o /dev/null --max-time ${READINESS_PROBE_TIMEOUT:-30} "${PROTOCOL:-http}://${POD_IP}:9200/")
     if [[ $DEBUG ]]; then
        echo "Elasticsearch check rc=${rc}";
     fi
     case "$rc" in
     "200") exit 0;;
     "401") exit 0;;
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
