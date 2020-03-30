#!/usr/bin/env bash

# Set up fully the test environment (except for installing required sw packages).
# Has to be useable from Docker as well as from Travis.
#
# Uses env vars: TRAVIS_PHP_VERSION, EZ_PACKAGES, CODE_COVERAGE, EZ_VERSION, EZ_APPDIR, INSTALL_TAGSBUNDLE

# @todo check if all required env vars have a value

set -ev

cd $(dirname ${BASH_SOURCE[0]})/../../..

# For php 5.6, Composer needs humongous amounts of ram - which we don't have on Travis. Enable swap as workaround
if [ "${TRAVIS_PHP_VERSION}" = "5.6" ]; then sudo fallocate -l 10G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile; fi

# Increase php memory limit (need to do this now or we risk composer failing)
if [ "${TRAVIS}" = "true" ]; then
    phpenv config-add WrapperBundle/Tests/environment/zzz_php.ini
else
    sudo cp WrapperBundle/Tests/environment/zzz_php.ini /etc/php/7.3/cli/conf.d
fi

# Disable xdebug for speed (both for executing composer and running tests), but allow us to e-enable it later
export XDEBUG_INI=''
export XDEBUG_INI=`php -i | grep xdebug.ini | grep home/travis | grep -v '=>' | head -1`
export XDEBUG_INI=${XDEBUG_INI/,/}
if [ "$XDEBUG_INI" != "" ]; then mv "$XDEBUG_INI" "$XDEBUG_INI.bak"; fi

# We do not rely on the requirements set in composer.json, but install a different eZ version depending on the test matrix (env vars)

# For the moment, to install eZPlatform, a set of DEV packages have to be allowed; really ugly sed expression to alter composer.json follows
# A different work around for this has been found in setting up an alias for them in the std composer.json require-dev section
#if [ "$EZ_VERSION" = "ezplatform" ]; then sed -i 's/"license": "GPL-2.0",/"license": "GPL-2.0", "minimum-stability": "dev", "prefer-stable": true,/' composer.json; fi

# composer.lock gets in the way when switching between eZ versions
if [ -f composer.lock ]; then rm composer.lock; fi
composer require --dev ${EZ_PACKAGES}

if [ "${TRAVIS}" = "true" ]; then
    # useful for troubleshooting tests failures
    composer show
fi

# Re-enable xdebug for when we need to generate code coverage
if [ "$CODE_COVERAGE" = "1" -a "$XDEBUG_INI" != "" ]; then mv "$XDEBUG_INI.bak" "$XDEBUG_INI"; fi

# Create the database from sql files present in either the legacy stack or kernel
./WrapperBundle/Tests/setup/create-db.sh

# Set up configuration files
./WrapperBundle/Tests/setup/setup-ez-config.sh

# Set up contents as needed by the test
./WrapperBundle/Tests/setup/setup-content.sh ${EZ_VERSION} ${EZ_APP_DIR}

# TODO are these needed at all?
#php vendor/ezsystems/ezpublish-community/ezpublish/console --env=behat assetic:dump
#php vendor/ezsystems/ezpublish-community/ezpublish/console --env=behat cache:clear --no-debug

# TODO for eZPlatform, do we need to set up SOLR as well ?
#if [ "$EZ_VERSION" = "ezplatform" ]; then ./vendor/ezsystems/ezplatform-solr-search-engine:bin/.travis/init_solr.sh; fi
