# Elassandra Enterprise docker image

[![Build Status](https://travis-ci.org/strapdata/docker-elassandra.svg?branch=master)](https://travis-ci.org/strapdata/docker-elassandra)

This Elassandra Enterprise image is available on [docker hub](https://hub.docker.com/r/strapdata/elassandra-enterprise/)

[Elassandra](https://github.com/strapdata/elassandra) is a fork of [Elasticsearch](https://github.com/elastic/elasticsearch) modified to run on top of [Apache Cassandra](http://cassandra.apache.org/) in a scalable and resilient peer-to-peer architecture. Elasticsearch code is embedded in Cassanda nodes providing advanced search features on Cassandra tables and Cassandra serve as an Elasticsearch data and configuration store.

**Elassandra Enterprise** is a commercial plugin providing additional features for [Elassandra](https://github.com/strapdata/elassandra), elasticsearch monitoring, security and the ability to execute elasticsearch query from your favorite CQL driver. Check-out the [elassandra enterprise documentation](http://doc.elassandra.io/en/latest/enterprise.html) for detailed instructions.

Commercial support is available from [Strapdata](https://www.strapdata.com).

## Basic usage

```bash
docker pull strapdata/elassandra-enterprise
```

#### Start a single-node cluster

```bash
docker run --name my-elassandra strapdata/elassandra-enterprise
```

#### Connect with cqlsh

```bash
docker exec -it my-elassandra cqlsh
```

or :

```bash
docker run -it --link my-elassandra --rm strapdata/elassandra cqlsh my-elassandra
```


#### Connect to Elasticsearch API with curl

```bash
docker exec -it my-elassandra curl --user cassandra:cassandra https://localhost:9200
```

or :

```bash
docker run -it --link my-elassandra --rm strapdata/elassandra curl --user cassandra:cassandra https://my-elassandra:9200 -k
```

#### Connect to Cassandra nodetool

```bash
docker exec -it my-elassandra nodetool status
```

#### Exposed ports

* 7000: Intra-node communication
* 7001: TLS intra-node communication
* 7199: JMX
* 9042: CQL
* 9142: encrypted CQL
* 9160: thrift service
* 9200: ElasticSearch HTTP
* 9300: ElasticSearch transport

#### Volumes

* /var/lib/cassandra

## Advanced Usage

This image is a fork of the [Cassandra  "Official Image"](https://github.com/docker-library/cassandra) modified to run Elassandra.

We added some more features to the images, described below.

### Enterprise Specific

TODO

### Logging

Elassandra logging is configured with the file [logback.xml](./logback.xml).
It is parametrized with environment variables and thus allows to manage debug levels from your docker env section. 

```
LOGBACK_org_apache_cassandra
LOGBACK_org_apache_cassandra_service_CassandraDaemon
LOGBACK_org_elassandra_shard
LOGBACK_org_elassandra_indices
LOGBACK_org_elassandra_index
LOGBACK_org_elassandra_discovery
LOGBACK_org_elassandra_cluster_service
LOGBACK_org_elasticsearch
```

### Kubernetes

A **ready_probe.sh** script can be used for readiness probe as follow:

```yaml
  readinessProbe:
      exec:
        command: [ "/bin/bash", "-c", "/ready-probe.sh" ]
      initialDelaySeconds: 15
      timeoutSeconds: 5
```

### Configuration

All the environment variables that work for configuring the official Cassandra image continue to work here (e.g `CASSANDRA_RPC_ADDRESS`, `CASSANDRA_LISTEN_ADDRESS`...).

But for convenience, we provide an extended mechanism for configuring almost everything in **cassandra.yaml** and **elasticsearch.yml**, directly from the docker env section.

For instance, to configure cassandra `num_tokens` and elasticsearch `http.port` we do like this :

```bash
docker run \
  -e CASSANDRA__num_tokens=16 \
  -e ELASTICSEARCH__http__port=9201 \
  strapdata/elassandra
```

Notice that `__` are replaced by `.` in the generated yaml files.

It does not work to configure yaml arrays, such as cassandra seeds...

### Run cassandra only

To disable Elasticsearch, set the `CASSANDRA_DAEMON` to `org.apache.cassandra.service.CassandraDaemon`, default is `org.apache.cassandra.service.ElassandraDaemon`.

```bash
docker run \
  -e CASSANDRA_DAEMON=org.apache.cassandra.service.CassandraDaemon \
  strapdata/elassandra
```

### Init script

Every `.sh` files found in `/docker-entrypoint-init.sh` will be sourced before to start elassandra.

```bash
docker run -v $(pwd)/script.sh:/docker-entrypoint-init.d/script.sh strapdata/elassandra
```

## Use the build tool

Lot of parameters available, see the source [build.sh](./build.sh).

### Basic

```bash
PLUGIN_DIR=../path/to/strapack \
BASE_IMAGE=strapdata/elasandra:tag \
DOCKER_PUBLISH=true \
 ./build.sh
```

or :

```bash
PLUGIN_LOCATION=http://path/to/strapdata-enterprise-6.2.3.4.zip \
PLUGIN_COMMIT=hash-of-the-commit \
BASE_IMAGE=strapdata/elasandra:6.2.3.7 \
DOCKER_PUBLISH=true \
 ./build.sh
```

### Change the elassandra base image

The parameter `BASE_IMAGE` must be set to an elassandra open-source image.

It must contain a valid version tag different than latest, like `6.2.3.7` or `5.5.0.24-rc1`.

This tag is used to tag the enterprise image.

### From a local strapack repository
```bash
PLUGIN_DIR=../path/to/strapack-repo ./build.sh
```

Where repo `PLUGIN_DIR` point to a strapack repository with zip package assembled.

### From local deb package
```bash
PLUGIN_LOCATION=../path/to/strapdata-enterprise-6.2.3.4.zip ./build.sh
```

### From an url
```bash
PACKAGE_LOCATION=https://some-host.com/path/to/strapdata-enterprise-6.2.3.4.zip ./build.sh
```

### Set the commit sha1

Use the env var `PLUGIN_COMMIT`. It is inserted in the image as an env var, and it's used as a tag.

The commit hash tag has the form : `E_{ELASSANDRA_COMMIT}-S_{PLUGIN_COMMIT}`.

The elassandra commit is inferred from the base image, while the plugin commit is inferred only if `PLUGIN_DIR` is set.

### Set the registry

Use the env var `DOCKER_REGISTRY`, for instance `DOCKER_REGISTRY=gcr.io`

## Run the tests

run all:

`./run.sh strapdata/elassandra-enterprise:tag`

or with debug output:

`DEBUG=true ./run.sh strapdata/elassandra-enterprise:tag`

only run elassandra-basics tests:

`./run.sh -t elassandra-basics strapdata/elassandra-enterprise:tag`

only run elassandra-config tests:

`./run.sh -t elassandra-config strapdata/elassandra-enterprise:tag`
