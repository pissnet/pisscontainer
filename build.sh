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

set -e

i=1
for arg in "$@"; do
	if [ "$arg" == "--build" ]; then
		BUILD=1;
		shift $i;
	elif [ "$arg" == "--run" ]; then
		RUN=1;
		shift $i;
	elif [ "$arg" == "--all" ]; then
		RUN=1;
		BUILD=1;
		shift $i;
	fi
	i=$(($i+1))
done

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
echo $REPO $BRANCH

set -v

if [ -n "$BUILD" ]; then
	mkdir -p unrealircd
	mkdir -p data
	mkdir -p conf
	echo "Building unrealircd..."
	podman build -f Containerfile_build_server \
			--build-arg BRANCH="$BRANCH" \
			-t opensuse/tumbleweed/pissnet-build:"$BRANCH" \
	                -v "$PWD/unrealircd:/home/pissnet/unrealircd_volume" \
			--label REV="$SHORTREV"


	# echo "Building full_server..."
	# podman build -f Containerfile_full_server \
	# 		--build-arg BRANCH="$BRANCH" \
	# 		-t opensuse/tumbleweed/pissnet-full:"$BRANCH" \
	# 		--label REV="$SHORTREV"

	echo "Building slim_server..."
	podman build -f Containerfile_slim_server
			--build-arg BRANCH="$BRANCH" \
			-t opensuse/tumbleweed/pissnet-slim:"$BRANCH" \
			--label REV="$SHORTREV"
fi

if [ -n "$RUN" ]; then
	echo "Running..."
	echo "^P ^Q for detaching"
	podman run -it --name="$repo_$branch" --user=pissnet \
			--network cni-podman1 \
			-p6667:6667 -p6697:6697 -p6900:6900 \
			--label REV="$SHORTREV" \
			pissnet-build:"$BRANCH"
	#		-p [::]:6900:6900 -p [::]:6667:6667 -p [::]:6697:6697 \
	# podman run -it --name="$repo_$branch" --user=pissnet \
	# 		--network podman \
	#  		pissnet-build:"$BRANCH"
fi


