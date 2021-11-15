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

if wget --version 1>/dev/null 2>&1; then
	wget "https://codeload.github.com/$REPO/zip/refs/heads/$BRANCH" \
		-O pissircd.zip
elif curl --version 1>/dev/null 2>&1; then
	curl "https://codeload.github.com/$REPO/zip/refs/heads/$BRANCH" \
		-o pissircd.zip
else
	echo "Can't download pissnet. Install _something_!"
	exit -1
fi

REV=`unzip -z pissircd.zip | tail -1`
SHORTREV=`echo "$REV" | dd bs=1 count=6`

rm -rf tmp pissircd
mkdir -p tmp
unzip -qx pissircd.zip -d tmp

mv tmp/* pissircd

mkdir -p unrealircd
mkdir -p data
mkdir -p conf
echo "Building unrealircd..."
podman build -f Containerfile_build_server --build-arg BRANCH="$BRANCH" \
		-v "$PWD/unrealircd:/home/pissnet/unrealircd" \
		-t opensuse/tumbleweed/pissnet-build:"$BRANCH" \
		--label REV="$SHORTREV"

echo "Building full_server..."
podman build -f Containerfile_full_server --build-arg BRANCH="$BRANCH" \
		-t opensuse/tumbleweed/pissnet-full:"$BRANCH" \
		--label REV="$SHORTREV"

# podman build -f Containerfile_slim_server --build-arg BRANCH="$BRANCH" \
#		-t opensuse/tumbleweed/pissnet-slim:"$BRANCH" \
#		--label REV="$SHORTREV"

echo "Running..."
echo "^P ^Q for detaching"
podman run -it --name="$repo_$branch" --user=pissnet \
		-p6667:6667 -p6697:6697 -p6900:6900 \
		--label REV="$SHORTREV" \
		pissnet-full:"$BRANCH"


