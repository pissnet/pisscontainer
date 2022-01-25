#!/bin/sh

if [ ! -d pissircd ]; then
	git clone --single-branch --depth 1 $REPO -b $BRANCH
else
	cd pissircd
	git pull
fi
