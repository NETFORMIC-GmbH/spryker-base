<?php

use Spryker\Shared\Application\ApplicationConstants as AC;
use Spryker\Shared\Setup\SetupConstants;
use Spryker\Shared\Storage\StorageConstants;
use Spryker\Shared\Session\SessionConstants;
use Spryker\Shared\Propel\PropelConstants;
use Spryker\Shared\Log\LogConstants;

// Get config values from ENV. This enables the infrastructure guys to let the application
// run in different environments without complicated file templating.
// ENV vars are changeable by their deployment tools and or infrastructure services like
//   * confd
//   * ansible
//   * docker
//   * ...

/**
 * getenv() with default
 * Calls getenv(...) but also supports a default value, if the
 * given key does not exist.
 * If no default value is set AND the key could not be found,
 * inform user and abort script execution. This should enforce,
 * that required fields are set via ENV!
**/
function getenvDefault($envKey, $default=null) {
  $envValue = getenv($envKey);
  
  // print error if an required ENV var is not set
  if($envValue === false && $default === null) {
    echo "[ERROR] missing ENV var: ".$envKey." Abort here!\n";
    exit(1);
  }
  
  return ($envValue === false) ? $default : $envValue;
}


/**
 * getenv() with default and converting to boolean
 * This function enables the use of boolean-similar constructs within
 * the given ENV var. That means, that you can specify a "1" (as string or number)
 * to get a True (bool) back. And a "false" (as string) to get a
 * False (bool). The same is for "0" (bool false)
 * and "true" (bool true, case insensitive).
**/
function getenvBoolean($envKey, $default=false) {
  $envValue = getenvDefault($envKey, $default);
  return filter_var($envValue, FILTER_VALIDATE_BOOLEAN);
}


$redis_database_counter = 0;

$config_local = [
  LogConstants::LOG_FILE_PATH               => '/data/logs/application.log',
  
  AC::ELASTICA_PARAMETER__HOST              => getenvDefault('ES_HOST', 'elasticsearch'),
  AC::ELASTICA_PARAMETER__TRANSPORT         => getenvDefault('ES_PROTOCOL', 'http'),
  AC::ELASTICA_PARAMETER__PORT              => getenvDefault('ES_PORT', '9200'),
  AC::ELASTICA_PARAMETER__AUTH_HEADER       => '',
  AC::ELASTICA_PARAMETER__INDEX_NAME        => 'de_search',
  AC::ELASTICA_PARAMETER__DOCUMENT_TYPE     => 'page',
  AC::YVES_SSL_ENABLED                      => getenvBoolean('YVES_SSL_ENABLED', false),
  AC::YVES_COMPLETE_SSL_ENABLED             => getenvBoolean('YVES_COMPLETE_SSL_ENABLED', false),
  AC::ZED_SSL_ENABLED                       => getenvBoolean('ZED_SSL_ENABLED', false),
  
  ZedRequestConstants::ZED_API_SSL_ENABLED  => getenvBoolean('ZED_API_SSL_ENABLED', false),
  
  // REDIS databases
  StorageConstants::STORAGE_REDIS_DATABASE      => $redis_database_counter++,
  StorageConstants::STORAGE_REDIS_PROTOCOL      => getenvDefault('REDIS_STORAGE_PROTOCOL', 'tcp'),
  StorageConstants::STORAGE_REDIS_HOST          => getenvDefault('REDIS_STORAGE_HOST', 'redis'),
  StorageConstants::STORAGE_REDIS_PORT          => getenvDefault('REDIS_STORAGE_PORT', '6379'),
  StorageConstants::STORAGE_REDIS_PASSWORD      => getenvDefault('REDIS_STORAGE_PASSWORD', ''),

  SessionConstants::YVES_SESSION_REDIS_DATABASE => $redis_database_counter++,
  SessionConstants::YVES_SESSION_REDIS_PROTOCOL => getenvDefault('REDIS_SESSION_PROTOCOL', 'tcp'),
  SessionConstants::YVES_SESSION_REDIS_HOST     => getenvDefault('REDIS_SESSION_HOST', 'redis'),
  SessionConstants::YVES_SESSION_REDIS_PORT     => getenvDefault('REDIS_SESSION_PORT', '6379'),
  SessionConstants::YVES_SESSION_REDIS_PASSWORD => getenvDefault('REDIS_SESSION_PASSWORD', ''),

  SessionConstants::ZED_SESSION_REDIS_DATABASE  => $redis_database_counter++,
  SessionConstants::ZED_SESSION_REDIS_PROTOCOL  => getenvDefault('REDIS_SESSION_PROTOCOL', 'tcp'),
  SessionConstants::ZED_SESSION_REDIS_HOST      => getenvDefault('REDIS_SESSION_HOST', 'redis'),
  SessionConstants::ZED_SESSION_REDIS_PORT      => getenvDefault('REDIS_SESSION_PORT', '6379'),
  SessionConstants::ZED_SESSION_REDIS_PASSWORD  => getenvDefault('REDIS_SESSION_PASSWORD', ''),
  
  SessionConstants::YVES_SESSION_SAVE_HANDLER   => SessionConstants::SESSION_HANDLER_REDIS,
  SessionConstants::YVES_SESSION_TIME_TO_LIVE   => SessionConstants::SESSION_LIFETIME_1_HOUR,
  SessionConstants::YVES_SESSION_FILE_PATH      => session_save_path(),
  SessionConstants::YVES_SESSION_PERSISTENT_CONNECTION => $config[StorageConstants::STORAGE_PERSISTENT_CONNECTION],

# FIXME [bug01] jenkins console commands of spryker/setup do not relies
# completely of calls to a remote jenkins call
  SetupConstants::JENKINS_DIRECTORY => '/tmp/jenkins/jobs',
  SetupConstants::JENKINS_BASE_URL  => 'http://'.getenvDefault('JENKINS_HOST', 'jenkins').':'.getenvDefault('JENKINS_PORT', '8080').'/',

  # Use commands to remote databases instead of local sudo commands. database
  # specific client tools like psql for postgres are required nevertheless.
  PropelConstants::USE_SUDO_TO_MANAGE_DATABASE => false,
  PropelConstants::ZED_DB_ENGINE   => $config[PropelConstants::ZED_DB_ENGINE_PGSQL],
  PropelConstants::ZED_DB_USERNAME => getenvDefault('ZED_DB_USERNAME'),
  PropelConstants::ZED_DB_PASSWORD => getenvDefault('ZED_DB_PASSWORD'),
  PropelConstants::ZED_DB_DATABASE => getenvDefault('ZED_DB_DATABASE', 'spryker'),
  PropelConstants::ZED_DB_HOST     => getenvDefault('ZED_DB_HOST', 'database'),
  PropelConstants::ZED_DB_PORT     => getenvDefault('ZED_DB_PORT', '5432'),
];
foreach($config_local as $k => $v)
  $config[$k] = $v;

/**
 * detect the current, valid domain, used for Yves.
 * This is a separate function, as it's a more complex szenario.
 * To support local-dev, we need to detect the used domain
 * dynamicaly.
**/
function getYvesDomain() {
  $domain = getenv('PUBLIC_YVES_DOMAIN');
  if($domain) {
    return $domain;
  }
  
  if(isset($_SERVER['HTTP_HOST'])) {
    return (parse_url($_SERVER['HTTP_HOST'], PHP_URL_PORT) === null)
       ? $_SERVER['HTTP_HOST'] // parse_url fails to return PHP_URL_HOST if there is no port set!
       : parse_url($_SERVER['HTTP_HOST'], PHP_URL_HOST); // drop port specifications
  }
  
  return ''; // return nothing, if ENV and SERVER key isn't set
}

/**
 * Hostname(s) for Yves - Shop frontend
 * In production you probably use a CDN for static content
 * But BE AWARE: session domain has to match the sites domain!
 */
$config[AC::HOST_YVES]
//    = $config[ProductManagementConstants::HOST_YVES]
//    = $config[PayoneConstants::HOST_YVES]
//    = $config[PayolutionConstants::HOST_YVES]
//    = $config[NewsletterConstants::HOST_YVES]
//    = $config[CustomerConstants::HOST_YVES]
    = $config[AC::HOST_STATIC_ASSETS]
    = $config[AC::HOST_STATIC_MEDIA]
    = $config[AC::HOST_SSL_YVES]
    = $config[AC::HOST_SSL_STATIC_ASSETS]
    = $config[AC::HOST_SSL_STATIC_MEDIA]
    = $config[SessionConstants::YVES_SESSION_COOKIE_NAME]
    = $config[SessionConstants::YVES_SESSION_COOKIE_DOMAIN]
    = getYvesDomain();

/**
 * Hostname(s) for Zed - Shop frontend
 * In production you probably use HTTPS for Zed
 */
$config[AC::HOST_ZED_GUI]
    = $config[AC::HOST_ZED_API]
    = $config[AC::HOST_SSL_ZED_GUI]
    = $config[AC::HOST_SSL_ZED_API]
    = getenvDefault('ZED_HOST', 'zed');
