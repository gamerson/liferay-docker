#!/bin/bash

source ./_common.sh

function build_docker_image {
	local docker_image_name=${2}
	local release_version=${3}

	DOCKER_IMAGE_TAGS=()

	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}${docker_image_name}:${release_version}-${TIMESTAMP}")
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}${docker_image_name}:${release_version}")

	LIFERAY_DOCKER_IMAGE_PLATFORMS=linux/amd64,linux/arm64

	if [[ " ${@} " =~ " --push " ]]
	then
		check_docker_buildx

		docker buildx build \
			--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
			--build-arg LABEL_NAME="${docker_image_name}-${release_version}" \
			--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
			--build-arg LABEL_VCS_URL=$(git config --get remote.origin.url) \
			--build-arg LABEL_VERSION="${release_version}" \
			--builder "liferay-buildkit" \
			--platform "${LIFERAY_DOCKER_IMAGE_PLATFORMS}" \
			--push \
			$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
			"${TEMP_DIR}" || exit 1
	else
		remove_temp_dockerfile_target_platform

		docker build \
			--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
			--build-arg LABEL_NAME="${docker_image_name}-${release_version}" \
			--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
			--build-arg LABEL_VCS_URL=$(git config --get remote.origin.url) \
			--build-arg LABEL_VERSION="${release_version}" \
			$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
			"${TEMP_DIR}" || exit 1
	fi
}

function check_usage {
	if [ ! -n "${3}" ]
	then
		echo "Usage: ${0} path-to-bundle image-name version --no-warm-up --no-test-image --push"
		echo ""
		echo "Example: ${0} ../bundles/master portal-snapshot demo-cbe09fb0 --no-warm-up --no-test-image"

		exit 1
	fi

	check_utils curl docker java rsync
}

function main {
	check_usage "${@}"

	make_temp_directory templates/bundle

	prepare_temp_directory "${@}"

	prepare_tomcat "${@}"

	build_docker_image "${@}"

	test_docker_image "${@}"

	clean_up_temp_directory
}

function prepare_temp_directory {
	excludes=(
		"--exclude" "*.zip"
		"--exclude" "data/elasticsearch6"
		"--exclude" "data/elasticsearch7"
		"--exclude" "deploy"
		"--exclude" "logs/*"
		"--exclude" "osgi/state"
		"--exclude" "osgi/test"
		"--exclude" "portal-ext.properties"
		"--exclude" "portal-setup-wizard.properties"
		"--exclude" "tmp"
	)

	if [[ ! " ${@} " =~ " --no-warm-up " ]]
	then
		excludes+=(
			"--exclude" "osgi/modules"
			"--exclude" "osgi/portal"
			"--exclude" "osgi/war"
		)
	fi

	rsync -aq \
		"${excludes[@]}" \
		"${1}" "${TEMP_DIR}/liferay"
}

main "${@}"