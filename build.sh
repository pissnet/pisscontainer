#!/bin/bash
#
# container builder script
#
# Copyright (C) 2021 Raphael Bertoche
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

usage() {
	echo "$0: --opensuse | --alpine | --all [ --build | --run ] [[REPOSITORY] BRANCH]"
}

set -e

i=1
for arg in "$@"; do
	if [ "$arg" == "--build" ]; then
		BUILD=1;
		shift $i;
		i=$(($i-1))
	elif [ "$arg" == "--run" ]; then
		RUN=1;
		shift $i;
		i=$(($i-1))
	elif [ "$arg" == "--all" ]; then
		ALPINE=1;
		OPENSUSE=1;
		shift $i;
		i=$(($i-1))
	elif [ "$arg" == "--alpine" ]; then
		ALPINE=1;
		shift $i;
		i=$(($i-1))
	elif [ "$arg" == "--opensuse" ]; then
		OPENSUSE=1;
		shift $i;
		i=$(($i-1))
	elif [ "$arg" == "--server" ]; then
		SERVER=1;
		shift $i;
		i=$(($i-1))
	fi
	i=$(($i+1))
done

if [ -z "$ALPINE" ] && [ -z "$OPENSUSE" ]; then
	echo "Please choose a distro passing --opensuse, --alpine or --all"
	usage
	exit 1
fi
if [ -n "$ALPINE" ]; then
	IMAGES+=(alpine/build_server)
fi
if [ -n "$OPENSUSE" ]; then
	if [ -z "$SERVER" ]; then
		IMAGES+=(opensuse/tiny_ssh)
		IMAGES+=(opensuse/dev_ssh)
		IMAGES+=(opensuse/dev_ssh_x)
	fi
	IMAGES+=(opensuse/dev_server)
fi

if [ -z "$RUN" ] && [ -z "$BUILD" ]; then
	RUN=1;
	BUILD=1;
fi

if [ "$#" -ge 2 ]; then
	export REPO="$1"
	shift
else
	export REPO=pissnet/pissircd
fi
if [ "$#" -ge 1 ]; then
	export BRANCH="$1"
	shift
else
	export BRANCH=piss60
fi
REPO_=`echo $REPO | tr \/ _`
echo $REPO $BRANCH

if [ -n "$BUILD" ]; then
	# paths used through ADD Containerfile commands
	mkdir -p unrealircd
	mkdir -p data
	mkdir -p conf
	for i in "${IMAGES[@]}"; do
		i_=`echo $i | tr \/ _`
		f="Containerfile_${i_}"
		tag="p/$i:${REPO_}_${BRANCH}"
		echo "Building $tag..."
		if [ "$i" = "opensuse/dev_server" ]; then
			mkdir -p /var/storage/piss/pissircd
			mkdir -p /var/storage/piss/unrealircd
			mkdir -p /var/storage/piss/conf
			mkdir -p /var/storage/piss/data
			mkdir -p /var/storage/piss/logs
			podman build -f "$f" \
				-t "$tag" \
				-v /var/storage/piss/pissircd:/home/pissnet/pissircd:z \
				-v /var/storage/piss/conf:/home/pissnet/unrealircd/conf:z \
				-v /var/storage/piss/data:/home/pissnet/unrealircd/data:z \
				-v /var/storage/piss/logs:/home/pissnet/unrealircd/logs:z \
				-v /var/storage/piss/unrealircd:/home/pissnet/unrealircd:z \
				--build-arg BRANCH="$BRANCH"
			chown -R 101000:101000 /var/storage/piss/
		elif [ "$i" = "alpine/build_server" ]; then
			podman build -f "$f" \
				--build-arg BRANCH="$BRANCH" \
				-t "$tag"
		else
			podman build -f "$f" \
				-t "$tag"
		fi
	done;
else
	# some tag for build
	i="${IMAGES[-1]}"
	i_=`echo $i | tr \/ _`
	tag="p/$i:${REPO_}_${BRANCH}"
fi

if [ -n "$RUN" ]; then
	echo "Running..."
	echo "^P ^Q for detaching"
	podman run -it --name="${i_}_${REPO_}_${BRANCH}" \
			--userns=auto \
			--network podman1 \
			-p[2804:14d:5c57:8011::9155:f411]:22:22 -p[2804:14d:5c57:8011::9155:f411]:6667:6667 \
			-p[2804:14d:5c57:8011::9155:f411]:6697:6697 -p[2804:14d:5c57:8011::9155:f411]:6900:6900 \
			-p0.0.0.0:9155:22 -p0.0.0.0:6667:6667 -p0.0.0.0:6697:6697 -p0.0.0.0:6900:6900 \
			-v /var/storage/piss/pissircd:/home/pissnet/pissircd:z \
			-v /var/storage/piss/conf:/home/pissnet/unrealircd/conf:z \
			-v /var/storage/piss/data:/home/pissnet/unrealircd/data:z \
			-v /var/storage/piss/logs:/home/pissnet/unrealircd/logs:z \
			-v /var/storage/piss/unrealircd:/home/pissnet/unrealircd:z \
			"$tag"
fi
