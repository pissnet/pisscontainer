#!/bin/bash -e

export BRANCH=piss60

# if git --version 1>/dev/null 2>&1 ; then
# 	if [ ! -d pissircd ]; then
# 		if [ -z "$BRANCH" ]; then
# 			git clone --depth 1 --single-branch https://github.com/pissnet/pissircd/
# 		else
# 			git clone --depth 1 --single-branch -b "$BRANCH" https://github.com/pissnet/pissircd/
# 		fi
# 	else
# 		pushd pissircd
# 		git pull --no-rebase --depth 1
# 		popd
# 	fi
# else
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
 	#mkdir -p pissircd
 	#rm -rf pissircd/*
 	#tar -xvf default.tar.gz -C pissircd
# fi


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

echo "Running..."
podman run -it --name=pissnet --user=pissnet \
		-p6667:6667 -p6697:6697 -p6900:6900 \
		-p [::]:6900:6900 -p [::]:6667:6667 -p [::]:6697:6697 \
		--label REV="$SHORTREV" \
		pissnet-full:"$BRANCH"


# podman build -f Containerfile_slim_server \
# 	-t opensuse/tumbleweed/pissnet-full:6.0.0-1 -t opensuse/tumbleweed/pissnet-full:latest
