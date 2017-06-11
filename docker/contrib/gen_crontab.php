<?php

$workdir = getenv('WORKDIR');
$jobsfile = $workdir.'/config/Zed/cronjobs/jobs.php';
$crontabs = '/etc/crontabs';
$header = '# this file is autogenerated by parsing '.$jobsfile."\n\n";
$crontab = [];

# TODO: add newrelic app support
# $PHP_BIN -d newrelic.appname='Cron(${environment})'

if( file_exists($jobsfile) === false ) {
  echo "skipping as there is no $jobsfile";
  exit(0);
}

// will include $jobs[num][assoc]
require_once($jobsfile);

function matches_requirements(&$job) {
  $required_fields=['name', 'command', 'schedule', 'enable', 'run_on_non_production', 'stores'];
  foreach($required_fields as $f) {
    if(isset($job[$f]) === false) {
      return false;
    }
  }
  return true;
}

function get_job_user(&$job) {
  return (isset($job['role']) && $job['role'] == 'user') ? 'www-data' : 'root';
}


foreach($jobs as $job) {
  if(matches_requirements($job) === false) {
    echo '[WARNING] dropping JOB as it does not match our requirements, got data: '.var_export($job, true);
    continue;
  }


  $tmp_job_description = ['#', $job['name']];
  $tmp_job_definition  = [];


  if($job['enable'] != true) {
    $tmp_job_description[] = 'DISABLED';
    $tmp_job_definition[] = '#';
  }
  $tmp_job_definition[] = $job['schedule'];
  $tmp_job_definition[] = 'cd '.$workdir.' && ';
  $tmp_job_definition[] = $job['command'];

  $user = get_job_user($job);
  $crontab[$user][] = implode(' ', $tmp_job_description);
  $crontab[$user][] = implode(' ', $tmp_job_definition);
}

# this will overwrite existing crontab files, which is by intent to make the progress idempotent
foreach($crontab as $user => $data) {
  file_put_contents($crontabs.'/'.$user, $header.implode("\n", $data)."\n");
}