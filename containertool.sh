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

options=$(getopt -o + -l "help,verbose,build,run,all,alpine,opensuse,server,mount-home,mount-ircd,name:,run-args:,pid-file:" -- "$@")

eval set -- "$options"

while true
do
case $1 in
--help)
	usage
	exit 0
	;;
--verbose)
	export verbose=1
	set -xv
	;;
--build)
	BUILD=1;
	;;
--run)
	RUN=1;
	;;
--all)
	ALPINE=1;
	OPENSUSE=1;
	;;
--alpine)
	ALPINE=1;
	;;
--opensuse)
	OPENSUSE=1;
	;;
--server)
	SERVER=1;
	;;
--mount-home)
	MOUNT_HOME=1;
	;;
--mount-ircd)
	MOUNT_IRCD=1;
	;;
--name)
	shift
	NAME="$1"
	;;
--run-args)
	shift
	RUN_ARGS="$1"
	;;
--pid-file)
	shift
	PID_FILE="$1"
	;;
--)
	shift
	ARGS="$@"
	break;;
esac
shift
done

if [ -z "$ALPINE" ] && [ -z "$OPENSUSE" ]; then
	echo "Please choose a distro passing --opensuse, --alpine or --all"
	usage
	exit 1
fi
if [ -n "$ALPINE" ]; then
	if [ -z "$SERVER" ]; then
		IMAGES+=(alpine/tiny_ssh)
	fi
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

if [ -n "$MOUNT_HOME" ]; then
	mkdir -p /var/home
	VOLUMES="$VOLUMES -v /var/home:/home:z"
fi
if [ -n "$MOUNT_IRCD" ]; then
	mkdir -p /var/storage/piss/pissircd
	mkdir -p /var/storage/piss/unrealircd
	chown -R 101000:101000 /var/storage/piss
	VOLUMES="$VOLUMES \
	-v /var/storage/piss/pissircd:/home/pissnet/pissircd:z \
	-v /var/storage/piss/unrealircd:/home/pissnet/unrealircd:z \
	-v /var/storage/piss/conf:/home/pissnet/unrealircd/conf:z \
	-v /var/storage/piss/data:/home/pissnet/unrealircd/data:z \
	-v /var/storage/piss/logs:/home/pissnet/unrealircd/logs:z"
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
echo REPO:$REPO\; BRANCH:$BRANCH

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
			podman build -f "$f" \
				-t "$tag" \
				$VOLUMES \
				--build-arg BRANCH="$BRANCH"
		elif [ "$i" = "alpine/build_server" ]; then
			podman build -f "$f" \
				--build-arg BRANCH="$BRANCH" \
				$VOLUMES \
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

if [ -z "$NAME" ]; then
	NAME="${i_}_${REPO_}_${BRANCH}"
fi

if [ -n "$RUN" ]; then
	echo "Running..."
	echo "^P ^Q for detaching"

	echo podman run -dt --name="$NAME" \
			--userns=auto \
			--network podman1 \
			$VOLUMES \
			$RUN_ARGS \
			"$tag"
	podman run -dt --name="$NAME" \
			--userns=auto \
			--network podman1 \
			$VOLUMES \
			$RUN_ARGS \
			"$tag"

	if [ -n "$PID_FILE" ]; then
		sed -ie "s|^.*PIDFile.*|PIDFile=`podman generate systemd $NAME | grep PIDFile`|" $PID_FILE
		systemctl daemon-reload
	fi
fi
