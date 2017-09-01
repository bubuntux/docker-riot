#!/bin/bash
set -e

docker_versions=`curl -sSL 'https://registry.hub.docker.com/v2/repositories/bubuntux/riot-web/tags?page_size=1024' | jq '."results"[]["name"]' | tr -d '"' | sort --version-sort`
riot_versions=`git ls-remote --tags --refs https://github.com/vector-im/riot-web | awk '{print $2}' | sed 's|^refs/tags/||' | sort --version-sort`

process_versions () {
	for riot_version in $@; do
		if [[ $docker_versions == *$riot_version* ]]; then
			echo "Version ${riot_version} already in docker."
	  		continue
		fi

		echo "Downloading riot-web ${riot_version} app..."
		curl -sSL https://github.com/vector-im/riot-web/releases/download/${riot_version}/riot-${riot_version}.tar.gz     -o riot-web.tar.gz
		curl -sSL https://github.com/vector-im/riot-web/releases/download/${riot_version}/riot-${riot_version}.tar.gz.asc -o riot-web.tar.gz.asc
		
		echo "Verifying files..."
		gpg --no-default-keyring --default-key riot.asc --verify riot-web.tar.gz.asc riot-web.tar.gz
		if [ $? -eq 0 ]; then
    		echo "All good."
		else
    		echo "Problem with signature."
    		continue
		fi

		echo "Preparing the app..."
		tar -xzf riot-web.tar.gz
		rm riot-web.tar.gz*
		mv riot-${riot_version} riot-web/
		cp riot-web/config.sample.json riot-web/config.json

		echo "Building docker image..."
		docker build -qt bubuntux/riot-web:$riot_version .
		echo "Pushing docker image..."
		docker push bubuntux/riot-web:$riot_version

		latest_version=$riot_version

		echo "Cleanig up..."
		rm -fr riot-web
		echo ""
	done
}

docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}

process_versions `echo $riot_versions | tr ' ' '\n' | grep -e "rc" | tail -n 5` # release candidates
latest_version='' # do not set an rc version as latest
process_versions `echo $riot_versions | tr ' ' '\n' | grep -ve "rc" | tail -n 5` # stables

if [ ! -z "$latest_version" ]; then
	docker tag bubuntux/riot-web:$latest_version bubuntux/riot-web:latest
	docker push bubuntux/riot-web:latest
fi