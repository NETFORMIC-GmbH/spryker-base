#!/bin/bash

if [[ -z "$SETUP" ]]; then
    tput setab 1
    echo "Please do not run this script individually"
    tput sgr0
    exit 0
fi

CURL=`which curl`
NPM=`which npm`
GIT=`which git`
PHP=`which php`

ERROR_BKG=`tput setab 1` # background red
GREEN_BKG=`tput setab 2` # background green
BLUE_BKG=`tput setab 4` # background blue
YELLOW_BKG=`tput setab 3` # background yellow
MAGENTA_BKG=`tput setab 5` # background magenta

INFO_TEXT=`tput setaf 3` # yellow text
WHITE_TEXT=`tput setaf 7` # text white
BLACK_TEXT=`tput setaf 0` # text black
RED_TEXT=`tput setaf 1` # text red
NC=`tput sgr0` # reset

if [[ `echo "$@" | grep '\-v'` ]]; then
    VERBOSITY='-v'
fi

if [[ `echo "$@" | grep '\-vv'` ]]; then
    VERBOSITY='-vv'
fi

if [[ `echo "$@" | grep '\-vvv'` ]]; then
    VERBOSITY='-vvv'
fi

function labelText {
    echo -e "\n${BLUE_BKG}${WHITE_TEXT}-> ${1} ${NC}\n"
}

function errorText {
    echo -e "\n${ERROR_BKG}${WHITE_TEXT}=> ${1} <=${NC}\n"
}

function infoText {
    echo -e "\n${INFO_TEXT}=> ${1} <=${NC}\n"
}

function successText {
    echo -e "\n${GREEN_BKG}${BLACK_TEXT}=> ${1} <=${NC}\n"
}

function warningText {
    echo -e "\n${YELLOW_BKG}${RED_TEXT}=> ${1} <=${NC}\n"
}

function setupText {
    echo -e "\n${MAGENTA_BKG}${WHITE_TEXT}=> ${1} <=${NC}\n"
}

function writeErrorMessage {
    if [[ $? != 0 ]]; then
        errorText "${1}"
        errorText "Command unsuccessful"
        exit 1
    fi
}

function createDevelopmentDatabase {
    # postgres
    sudo createdb ${DATABASE_NAME}

    # mysql
    # mysql -u root -e "CREATE DATABASE DE_development_zed;"
}

function dumpDevelopmentDatabase {
    export PGPASSWORD=$DATABASE_PASSWORD
    export LC_ALL="en_US.UTF-8"

    pg_dump -i -h 127.0.0.1 -U $DATABASE_USER  -F c -b -v -f  $DATABASE_NAME.backup $DATABASE_NAME
}

function restoreDevelopmentDatabase {
    read -r -p "Restore database ${DATABASE_NAME} ? [y/N] " response
    case $response in
        [yY][eE][sS]|[yY])
            export PGPASSWORD=$DATABASE_PASSWORD
            export LC_ALL="en_US.UTF-8"

            sudo pg_ctlcluster 9.4 main restart --force
            sudo dropdb $DATABASE_NAME
            sudo createdb $DATABASE_NAME
            pg_restore -i -h 127.0.0.1 -p 5432 -U $DATABASE_USER -d $DATABASE_NAME -v $DATABASE_NAME.backup
            ;;
        *)
            echo "Nothing done."
            ;;
    esac
}

function installDemoshop {
    labelText "Preparing to install Spryker Platform..."

    updateComposerBinary
    composerInstall

    installZed
    sleep 1
    installYves

    configureCodeception

    successText "Setup successful"
    infoText "\nYves URL: http://www.de.spryker.dev/\nZed URL: http://zed.de.spryker.dev/\n"
}

function installZed {
    setupText "Zed setup"

    resetDataStores

    dropDevelopmentDatabase

    $CONSOLE setup:install $VERBOSITY
    writeErrorMessage "Setup install failed"

    labelText "Importing Demo data"
    $CONSOLE import:demo-data $VERBOSITY
    writeErrorMessage "DemoData import failed"

    labelText "Setting up data stores"
    $CONSOLE collector:search:export $VERBOSITY
    $CONSOLE collector:storage:export $VERBOSITY
    writeErrorMessage "DataStore setup failed"

    labelText "Setting up cronjobs"
    $CONSOLE setup:jenkins:generate $VERBOSITY
    writeErrorMessage "Cronjob setup failed"

    antelopeInstallZed

    labelText "Zed setup successful"
}

function installYves {
    setupText "Yves setup"

    antelopeInstallYves

    labelText "Yves setup successful"
}

function configureCodeception {
    labelText "Configuring test environment"
    vendor/bin/codecept build -q $VERBOSITY
    writeErrorMessage "Test configuration failed"
}

function optimizeRepo {
    labelText "Optimizing repository"
    git gc              # garbage collector
    git prune           # kills loose garbage
    writeErrorMessage "Repository optimization failed"
}

function resetDataStores {
    labelText "Flushing Elasticsearch"
    curl -XDELETE 'http://localhost:10005/de_search/'
    writeErrorMessage "Elasticsearch reset failed"

    labelText "Flushing Redis"
    redis-cli -p 10009 FLUSHALL
    writeErrorMessage "Redis reset failed"
}

function resetDevelopmentState {
    labelText "Preparing to reset data..."
    sleep 1

    resetDataStores

    dropDevelopmentDatabase

    labelText "Generating Transfer Objects"
    $CONSOLE transfer:generate
    writeErrorMessage "Generating Transfer Objects failed"

    labelText "Installing Propel"
    $CONSOLE propel:install $VERBOSITY
    $CONSOLE propel:diff $VERBOSITY
    $CONSOLE propel:migrate $VERBOSITY
    writeErrorMessage "Propel setup failed"

    labelText "Initializing DB"
    $CONSOLE setup:init-db $VERBOSITY
    writeErrorMessage "DB setup failed"
}

function dropDevelopmentDatabase {
    if [ `sudo psql -l | grep ${DATABASE_NAME} | wc -l` -ne 0 ]; then

        PG_CTL_CLUSTER=`which pg_ctlcluster`
        DROP_DB=`which dropdb`

        if [[ -f $PG_CTL_CLUSTER ]] && [[ -f $DROP_DB ]]; then
            labelText "Deleting PostgreSql Database: ${DATABASE_NAME} "
            sudo pg_ctlcluster 9.4 main restart --force && sudo dropdb $DATABASE_NAME 1>/dev/null
            writeErrorMessage "Deleting DB command failed"
        fi
    fi

    # MYSQL=`which mysql`
    # if [[ -f $MYSQL ]]; then
    #    labelText "Drop MySQL database: ${1}"
    #    mysql -u root -e "DROP DATABASE IF EXISTS ${1};"
    # fi
}

function updateComposerBinary {
    labelText "Setting up composer"

    if [[ ! -f "./composer.phar" ]]; then
        labelText "Download composer.phar"
        $CURL -sS https://getcomposer.org/installer | $PHP
    fi

    COMPOSER_TIMESTAMP=$(stat -c %Y "composer.phar")
    CURRENT_TIMESTAMP=$(date +"%s")

    COMPOSER_FILE_AGE=$(($CURRENT_TIMESTAMP-$COMPOSER_TIMESTAMP))
    THIRTY_DAYS_AGE=$((60*60*24*30))

    if [[ $COMPOSER_FILE_AGE > $THIRTY_DAYS_AGE ]]; then
        labelText "Install Composer Dependencies"
        $PHP composer.phar selfupdate
    fi
}

function composerInstall {
    echo $@
    labelText "Installing composer packages"
    $PHP composer.phar install --prefer-dist
}

function dumpAutoload {
    $PHP composer.phar dump-autoload
}

function resetYves {
    if [[ -d "./node_modules" ]]; then
        labelText "Remove node_modules directory"
        rm -rf "./node_modules"
        writeErrorMessage "Could not remove node_modules directory"
    fi

    if [[ -d "./data/DE/logs" ]]; then
        labelText "Clear logs"
        rm -rf "./data/DE/logs"
        mkdir "./data/DE/logs"
        writeErrorMessage "Could not remove logs directory"
    fi

    if [[ -d "./data/DE/cache" ]]; then
        labelText "Clear cache"
        rm -rf "./data/DE/cache"
        writeErrorMessage "Could not remove cache directory"
    fi
}

function checkNodejsVersion {
    if [[ `node -v | grep -E '^v[0-4]'` ]]; then
        labelText "Upgrade Node.js"
        $CURL -sL https://deb.nodesource.com/setup_5.x | sudo -E bash -

        sudo apt-get install -y nodejs

        successText "Node.js updated to version `node -v`"
        successText "NPM updated to version `$NPM -v`"
    fi
}

function installAntelope {
    checkNodejsVersion

    labelText "Install or Update Antelope tool globally"
    sudo $NPM install -g antelope
    writeErrorMessage "Antelope setup failed"
}

function antelopeInstallZed {
    installAntelope

    ANTELOPE_TOOL=`which antelope`

    if [[ -f $ANTELOPE_TOOL ]]; then
        labelText "Installing project dependencies"
        $ANTELOPE_TOOL install

        labelText "Building and optimizing assets for Zed"
        $ANTELOPE_TOOL build zed
        writeErrorMessage "Antelope build failed"
    fi
}

function antelopeInstallYves {
    installAntelope

    ANTELOPE_TOOL=`which antelope`

    if [[ -f $ANTELOPE_TOOL ]]; then
        labelText "Installing project dependencies"
        $ANTELOPE_TOOL install

        labelText "Building and optimizing assets for Yves"
        $ANTELOPE_TOOL build yves
        writeErrorMessage "Antelope build failed"
    fi
}

function displayHeader {
    labelText "Spryker Platform Setup"
    echo "./$(basename $0) [OPTION] [VERBOSITY]"
}

function displayHelp {

    displayHeader

    echo ""
    echo "  -i, --install-demo-shop"
    echo "      Install and setup new instance of Spryker Platform and populate it with Demo data"
    echo " "
    echo "  -yves, --install-yves"
    echo "      (re)Install Yves only"
    echo " "
    echo "  -zed, --install-zed"
    echo "      (re)Install Zed only"
    echo " "
    echo "  -r, --reset"
    echo "      Reset state. Delete Redis, Elasticsearch and Database data"
    echo ""
    echo "  -ddb, --dump-db"
    echo "      Dump database into a file"
    echo ""
    echo "  -rdb, --restore-db"
    echo "      Restore database from a file"
    echo ""
    echo "  -h, --help"
    echo "      Show this help"
    echo ""
    echo "  -c, --clean"
    echo "      Cleanup unnecessary files and optimize the local repository"
    echo ""
    echo "  -v, -vv, -vvv"
    echo "      Set verbosity level"
    echo " "
}
