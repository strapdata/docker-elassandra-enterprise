# docker-elassandra-enterprise

![Elassandra Logo](elassandra-logo.png)

Build **elassandra-enterprise** docker image. 

**Elassandra Enterprise** is a commercial plugin providing additional features for [Elassandra](https://github.com/strapdata/elassandra), elasticsearch monitoring, security and the ability to execute elasticsearch query from your favorite CQL driver. Check-out the [elassandra enterprise documentation](http://doc.elassandra.io/en/latest/enterprise.html) for detailed instructions.

Commercial support is available from [Strapdata](https://www.strapdata.com).

## Build

	ENTERPRISE_PLUGIN_URL=https://packages.strapdata.com/strapdata-plugin-6.latest.zip \
	BASE_IMAGE=strapdata/elassandra:6.2.3.x \
	./build.sh