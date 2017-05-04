#!/bin/sh

CONSOLE="execute_console_command"

# services activated for this docker container instance will be added to this string
ENABLED_SERVICES=""

source $WORKDIR/docker/common.inc.sh

cd $WORKDIR


case $1 in 
    run_yves)
      ENABLED_SERVICES="yves"
      enable_services
      start_services
      ;;

    run_zed)
      ENABLED_SERVICES="zed"
      enable_services
      start_services
      ;;

    run_yves_and_zed)
      ENABLED_SERVICES="yves zed"
      enable_services
      start_services
      ;;
    
    install_container_services)
      execute_scripts_within_directory "$WORKDIR/docker/install_container_services.d/"
      successText "installing container services FINISHED"
      ;;
    
    build)
      execute_scripts_within_directory "$WORKDIR/docker/build.d/"
      successText "building image tasks FINISHED"
      ;;
    
    init)
      execute_scripts_within_directory "$WORKDIR/docker/init.d/"
      successText "Setup initialization tasks FINISHED"
    ;;
    
    *)
      sh -c "$*"
      ;;
esac
