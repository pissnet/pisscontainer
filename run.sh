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
	echo "$0: --opensuse | --alpine | --all [ --verbose ] [ --mount-home ]"
	echo "[ --mount-ircd ] [ --name IMAGENAME ] [ --run-args RUNARGS ] [ --pid-file PIDFILEPATH ]"
}

export DONT_PRINT_USAGE=1

SRC_DIR="`dirname -- "${BASH_SOURCE[0]}"`"

"$SRC_DIR/containertool.sh" --run $@
RET=$?

if [ -n $DO_PRINT_USAGE -ne ]; then
	usage
fi
exit $RET
