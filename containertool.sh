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
	if [ -z $DONT_PRINT_USAGE ]; then
		echo "$0: --opensuse | --alpine | --all [ --build | --run ] [ --verbose ] [ --only-server ] [ --mount-home ]"
		echo "[ --mount-ircd ] [ --name IMAGENAME ] [ --run-args RUNARGS ] [ --pid-file PIDFILEPATH ]"
		echo "[[REPOSITORY] BRANCH]"
	else
		export DO_PRINT_USAGE=1
	fi
}

set -e

options=$(getopt -o + -l "help,verbose,build,run,all,alpine,opensuse,only-server,mount-home,mount-ircd,name:,run-args:,pid-file:" -- "$@")

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
	ALL=1
	ALPINE=1;
	OPENSUSE=1;
	;;
--alpine)
	ALPINE=1;
	;;
--opensuse)
	OPENSUSE=1;
	;;
--only-server)
	ONLY_SERVER=1;
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

if [ -n "$ALL" -a -n "$NAME" ]; then
	echo "error: using --name and --all at the same time is not currently supported"
	usage
	exit 1
fi

if [ -n "$ALL" -a -n "$PID_FILE" ]; then
	echo "error: using --pid-file and --all at the same time is not currently supported"
	usage
	exit 1
fi

if [ -n "$ALPINE" ]; then
	if [ -z "$ONLY_SERVER" ]; then
		IMAGES+=(alpine/tiny_ssh)
	fi
	IMAGES+=(alpine/build_server)
	RUN_IMAGES+=(alpine/build_server)
fi
if [ -n "$OPENSUSE" ]; then
	if [ -z "$ONLY_SERVER" ]; then
		IMAGES+=(opensuse/tiny_ssh)
		IMAGES+=(opensuse/dev_ssh)
		IMAGES+=(opensuse/dev_ssh_x)
	fi
	IMAGES+=(opensuse/dev_server)
	RUN_IMAGES+=(opensuse/dev_server)
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
if [ -n "$BUILD" ]; then
	echo REPO:$REPO\; BRANCH:$BRANCH
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
fi

if [ -n "$RUN" ]; then
	for i in "${RUN_IMAGES[@]}"; do
		i_=`echo $i | tr \/ _`
		tag="p/$i:${REPO_}_${BRANCH}"
		# prevents NAME from being used two times
		if [ "${#RUN_IMAGES[@]}" -ne 1 -o \
		     -z "$NAME" ]; then
			NAME="${i_}_${REPO_}_${BRANCH}"
		fi
		echo "Running $NAME..."

		echo podman run -dt --name="$NAME" \
				--network podman1 \
				$VOLUMES \
				$RUN_ARGS \
				"$tag"
		podman run -dt --name="$NAME" \
				--network podman1 \
				$VOLUMES \
				$RUN_ARGS \
				"$tag"
		echo "podman run exits with success."
		sleep 1
		if podman ps | grep -q "$NAME"; then
			echo "$NAME is running."
		else
			echo "$NAME is not running anymore or failed to start."
		fi
	done

	# only makes sense for a single image for now
	if [ "${#RUN_IMAGES[@]}" -eq 1 -a \
	     -n "$PID_FILE" ]; then
		sed -ie "s|^.*PIDFile.*|PIDFile=`podman generate systemd $NAME | grep PIDFile`|" $PID_FILE
		systemctl daemon-reload
	fi
fi
