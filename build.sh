#!/bin/bash -e

if [ "$#" -t 1 ]; then
	export BRANCH=piss60
else
	export BRANCH="$1"
fi

if wget --version 1>/dev/null 2>&1; then
	wget "https://codeload.github.com/pissnet/pissircd/zip/refs/heads/$BRANCH" \
		-O pissnet.zip
elif curl --version 1>/dev/null 2>&1; then
	curl "https://codeload.github.com/pissnet/pissircd/zip/refs/heads/$BRANCH" \
		-O pissnet.zip
else
	echo "Can't download pissnet. Install _something_!"
	exit -1
fi
REV=`unzip -z pissnet.zip | tail -1`
SHORTREV=`echo "$REV" | dd bs=1 count=6`


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
podman run -it --name=pissnet --user=pissnet \
		-p6667:6667 -p6697:6697 -p6900:6900 \
		-p [::]:6900:6900 -p [::]:6667:6667 -p [::]:6697:6697 \
		--label REV="$SHORTREV" \
		pissnet-full:"$BRANCH"


