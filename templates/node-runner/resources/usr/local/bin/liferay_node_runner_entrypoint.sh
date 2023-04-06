#!/bin/sh

if [ -e /opt/node/caroot/rootCA.pem ]
then
	export NODE_EXTRA_CA_CERTS=/opt/liferay/caroot/rootCA.pem
fi

if [ -e /usr/local/bin/liferay_node_runner_set_up.sh ]
then
	./usr/local/bin/liferay_node_runner_set_up.sh
fi

$LIFERAY_NODE_RUNNER_INSTALL

$LIFERAY_NODE_RUNNER_START

if [ -e /usr/local/bin/liferay_node_runner_tear_down.sh ]
then
	./usr/local/bin/liferay_node_runner_tear_down.sh
fi