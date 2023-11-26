#!/bin/bash -e

ADDON=tvheadend
GITREPO=https://github.com/tvheadend/tvheadend.git


if [ "$1" = "force" ]; then
	rm -f commit.msg
fi

#---
# Make sure we have the latest revision
#---
if [ ! -d ./${ADDON}.clean ]; then
	git clone ${GITREPO} ${ADDON}.clean
else
	cd ${ADDON}.clean
	git pull
	cd - > /dev/null
fi

#---
# Source last state
#---
if [ -f commit.msg ]; then
	. commit.msg
else
	RNXSHA=
	BUILDNO=0
fi

#---
# Check whether there's something to do
#---
cd ${ADDON}.clean
COMMIT=`git rev-parse --short HEAD`

if [ "${RNXSHA}" = "${COMMIT}" ]; then
	echo "Nothing to do!"
	exit 0
fi

#---
# We've got work to do
#---

# Create clean export
rm -rf ../${ADDON}
mkdir -p ../${ADDON}
ADDON_VER=`git describe --dirty --match "v*"`
git archive master | tar -x -C ../${ADDON}
# tar c . | tar -x -C ../${ADDON}
cd - >/dev/null

# Strip Git Hash form version
ADDON_VER=${ADDON_VER#v}
ADDON_VER=${ADDON_VER%-*}
# if [ -f workspace/${ADDON_VER}.buildno ]; then
# 	. workspace/${ADDON_VER}.buildno
# else
# 	BUILDNO=0
# fi

# Create .orig archive
tar czf ${ADDON}_${ADDON_VER}.orig.tar.gz ${ADDON}

# Create initial commit.msg on fresh run
if [ -z "${RNXSHA}" ]; then
	echo "BUILDNO=${BUILDNO}" > commit.msg
	echo "BUILDVER=${ADDON_VER}" >> commit.msg
	echo "RNXSHA=${COMMIT}" >> commit.msg
fi

#---
# NTGRize the thing
#---
cd readynas
tar c . | tar -x -C ../${ADDON}
cd - >/dev/null

# -- and build it
cd ${ADDON}
dh_quilt_patch
VERSION=`support/version`
support/changelog debian/changelog "" "${VERSION}"
dpkg-buildpackage -S
./Autobuild.sh
cd - >/dev/null

