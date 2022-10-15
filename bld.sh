#!/bin/bash

# ADJUST THESE FOR YOUR ENV
BUNDLES_ROOT="${HOME}/projects/bundles"
LIFERAY_PORTAL_SRC="${HOME}/projects/portal-master"
LIFERAY_DOCKER_SRC="${HOME}/projects/liferay-docker"
DOCKER_ORG="rotty3000"
TOMCAT_DIR=$(ls -td ${BUNDLES_ROOT}/tomcat-* | head -1)

# A common invocation: ./bld.sh --dxp --pre-warm-up

### Rest shouldn't need to change

set -e

args=("$@")
args+=(--no-test-image)

if [[ $# == 0 ]] || [[ " ${@} " =~ " -h " ]] || [[ " ${@} " =~ " --help " ]]
then
	cat <<EOF
Simplify build DXP docker image

USAGE: bld.sh [OPTIONS]

OPTIONS:
    -h|--help         this message
    --docker    build the docker image
    --dxp       build DXP
    --lpkg      invoke LPKG packaging
    --no-warm-up      don't warm up tomcat (faster build, slower startup)
    --pre-warm-up     warm up tomcat before invoking build_local_image.sh (also
                      sets --no-warm-up)
    --push            build and push multi-arch to docker hub (using buildx)
    --(no-)test-image do or don't run a test of the image after building it
    --reset-db        reset the hybersonic database to original (not needed if
                      --dxp is used)
    --reset-state     reset the $\{liferay.home}/osgi/state directory (a.k.a.
                      delete it)

EOF
	exit 0
fi

cp -f \
	${LIFERAY_PORTAL_SRC}/tools/servers/tomcat/bin/setenv.sh \
	${TOMCAT_DIR}/bin/setenv.sh

if [[ " ${@} " =~ " --test-image " ]]
then
	args=("${args[@]/--no-test-image}")
fi

if [[ " ${@} " =~ " --reset-db " ]]
then
	echo "=== Resetting the DB"

	rm -rf \
		${BUNDLES_ROOT}/data/hypersonic/* \
		${BUNDLES_ROOT}/portal-setup-wizard.properties

	cp ${LIFERAY_PORTAL_SRC}/sql/lportal.script \
		${LIFERAY_PORTAL_SRC}/sql/lportal.properties \
		${BUNDLES_ROOT}/data/hypersonic/
fi

if [[ " ${@} " =~ " --reset-state " ]]
then
	echo "=== Resetting osgi/state"

	rm -rf \
		${BUNDLES_ROOT}/osgi/state/*
fi

if [[ " ${@} " =~ " --dxp " ]]
then
	echo "=== Building DXP"

	time (
		cd $LIFERAY_PORTAL_SRC

		ant all
		ant install-portal-snapshots
		(cd modules && blade gw eclipse --parallel)
	)
fi

if [[ " ${@} " =~ " --lpkg " ]]
then
	echo "=== Building LPKGs"

	(
		cd $LIFERAY_PORTAL_SRC

		ant -f modules/build.xml build-app-lpkg-all -Dliferay.home=${BUNDLES_ROOT}
	)
fi

if [[ " ${@} " =~ " --pre-warm-up " ]]
then
	echo "=== Pre-warming Tomcat"

	args+=("--no-warm-up")
	(
		cd $BUNDLES_ROOT

		grep --line-buffered -q "org.apache.catalina.startup.Catalina.start Server startup" \
			<("${TOMCAT_DIR}/bin/catalina.sh" run 2>&1 | tee /dev/tty)

		echo "Warmup Complete"

		pid=$(lsof -Fp -i 4tcp:8080 -sTCP:LISTEN | head -n 1 | sed 's/p//')

		kill -0 "${pid}" 2>/dev/null && kill -9 "${pid}" 2>/dev/null
	)
fi

if [[ " ${@} " =~ " --docker " ]]
then
	echo "=== Building docker image"

	(
		cd ${LIFERAY_DOCKER_SRC}

		./build_local_image.sh \
			${BUNDLES_ROOT}/ \
			${DOCKER_ORG}/dxp 7.4.13.LOCALDEV-SNAPSHOT \
			"${args[@]}"
	)
fi
