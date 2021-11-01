#!/bin/bash

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
		-O pissircd.zip
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
# 		-t opensuse/tumbleweed/pissnet-slim:"$BRANCH" \
# 		--label REV="$SHORTREV"

echo "Running..."
podman run -it --name="$repo_$branch" --user=pissnet \
		-p6667:6667 -p6697:6697 -p6900:6900 \
		-p [::]:6900:6900 -p [::]:6667:6667 -p [::]:6697:6697 \
		--label REV="$SHORTREV" \
		pissnet-full:"$BRANCH"


