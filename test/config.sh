#!/usr/bin/env bash

elassandra_tests='
	  elassandra-basics
	  elassandra-config
	'

imageTests+=(
	[elassandra-enterprise]=$elassandra_tests

	[elassandra-enterprise-rc]=$elassandra_tests
)