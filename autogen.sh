#! /bin/bash

#-------------------------------------------------------------------------
#
# autogen.sh
#             Foreign-data wrapper for remote MongoDB servers
#
# Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
# Portions Copyright (c) 2004-2021, EnterpriseDB Corporation.
#
# IDENTIFICATION
#             autogen.sh
#
#-------------------------------------------------------------------------


MONGOC_VERSION=1.19.0
JSONC_VERSION=0.15-20200726

if [ "$#" -ne 1 ]; then
    echo "Usage: autogen.sh --[with-legacy | with-master]"
    exit
fi

CMAKE_COMMAND='cmake3'
if ! [ -x "$(command -v cmake3)" ]; then
    CMAKE_COMMAND='cmake'
fi

###
# Pull the latest version of Monggo C Driver's master branch
#
function checkout_mongo_driver
{
	rm -rf mongo-c-driver &&
	wget https://github.com/mongodb/mongo-c-driver/releases/download/$MONGOC_VERSION/mongo-c-driver-$MONGOC_VERSION.tar.gz &&
	tar -zxf mongo-c-driver-$MONGOC_VERSION.tar.gz &&
	mv mongo-c-driver-$MONGOC_VERSION mongo-c-driver &&
	rm -rf mongo-c-driver-$MONGOC_VERSION.tar.gz
}

###
# Pull the legacy branch from the Mongo C Driver's
#
function checkout_legacy_branch
{
	rm -rf mongo-c-driver &&
	wget https://github.com/mongodb/mongo-c-driver/archive/v0.8.tar.gz &&
	tar -zxf v0.8.tar.gz &&
	mv  mongo-c-driver-0.8 mongo-c-driver &&
	rm -rf v0.8.tar.gz
}
##
# Pull the json-c library
#
function checkout_json_lib
{
	echo $PWD &&
	rm -rf json-c &&
	wget https://github.com/json-c/json-c/archive/json-c-$JSONC_VERSION.tar.gz &&
	tar -zxf json-c-$JSONC_VERSION.tar.gz &&
	mv json-c-json-c-$JSONC_VERSION json-c &&
	rm -rf json-c-$JSONC_VERSION.tar.gz &&
	echo $PWD
}


##
# Compile and install json-c library
#
function install_json_lib
{
	cd json-c &&
	$CMAKE_COMMAND $JSONC_CFLAGS . &&
	make install &&
	cd ..
}

###
# Configure and install the Mongo C Driver and libbson
#
function install_mongoc_driver
{
	cd mongo-c-driver &&
	$CMAKE_COMMAND -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF -DENABLE_SSL=AUTO . &&
	make install &&
	cd ..
}

###
# Cleanup the system
#
function cleanup
{
	rm -f config.h
	touch config.h
}

###
# Create a config file and append #define META_DRIVER which will be
# used in case of Meta Driver (master branch) option.
#
function create_config
{
	echo "#ifdef __CONFIG__" >> config.h &&
	echo "#define META_DRIVER" >> config.h &&
	echo "#endif" >> config.h
}

cleanup

if [ "--with-legacy" = $1 ]; then
	checkout_json_lib &&
	checkout_legacy_branch &&
	install_json_lib &&
	cp Makefile.legacy Makefile

	ret=$?
	if [ "$ret" -ne 0 ]; then
		echo "Failed"
		exit $ret
	else
		echo "Done"
		exit 0
	fi
elif [ "--with-master" == $1 ]; then
	checkout_mongo_driver &&
	checkout_json_lib &&
	install_mongoc_driver &&
	install_json_lib &&
	create_config &&
	export PKG_CONFIG_PATH=mongo-c-driver/src/libmongoc/src:mongo-c-driver/src/libbson/src &&
	cp Makefile.meta Makefile

	ret=$?
	if [ "$ret" -ne 0 ]; then
		echo "Failed"
		exit $ret
	else
		echo "Done"
		exit 0
	fi
else
	echo "Usage: autogen.sh --[with-legacy | with-master]"
fi
