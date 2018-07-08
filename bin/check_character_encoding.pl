#!/usr/bin/env perl
use strict;
use Carp;
use Term::ANSIColor;
use File::Basename;
use File::Path;
use Getopt::Long qw(:config no_ignore_case no_auto_abbrev);
use FindBin;

use lib "$FindBin::Bin/../lib";

use PGDX::Logger;
use PGDX::Config::Manager;
use PGDX::LIMS::Manager::Factory;

## Do not buffer output stream
$|=1;

use constant TRUE => 1;

use constant FALSE => 0;

use constant DEFAULT_CONFIG_FILE => "$FindBin::Bin/../conf/lims.ini";

use constant DEFAULT_VERBOSE => FALSE;

use constant DEFAULT_LOG_LEVEL => 4;

use constant DEFAULT_OUTDIR => '/tmp/' . File::Basename::basename($0) . '/' . time();


## Command-line arguments
my (
    $sample_id_list,
    $sample_id_file,
    $sample_id, 
    $fields_file,
    $fields_list,
    $outdir,
    $log_level, 
    $help, 
    $logfile, 
    $man, 
    $verbose,
    $config_file,
    );

my $results = GetOptions (
    'log-level|d=s'                  => \$log_level, 
    'logfile=s'                      => \$logfile,
    'fields_file=s'                  => \$fields_file,
    'fields_list=s'                  => \$fields_list,
    'help|h'                         => \$help,
    'man|m'                          => \$man,
    'sample_id=s'                    => \$sample_id,
    'sample_id_list=s'               => \$sample_id_list,
    'sample_id_file=s'               => \$sample_id_file,
    'outdir=s'                       => \$outdir,
    'config_file=s'                  => \$config_file,
    );

&checkCommandLineArguments();

my $logger = new PGDX::Logger(
    logfile   => $logfile, 
    log_level => $log_level
    );

if (!defined($logger)){
    die "Could not instantiate PGDX::Logger";
}

my $config_manager = PGDX::Config::Manager::getInstance(config_file => $config_file);
if (!defined($config_manager)){
    $logger->logconfess("Could not instantiate PGDX::Config::Manager");
}

my $factory = PGDX::LIMS::Manager::Factory::getInstance();
if (!defined($factory)){
    $logger->logconfess("Could not instantiate PGDX::LIMS::Manager::Factory");
}

my $manager = $factory->create();
if (!defined($manager)){
    $logger->logconfess("manager was not defined");
}

$manager->setOutdir($outdir);


##----------------------------------------
##
## Pass on the fields variables
##
##----------------------------------------

if (defined($fields_file)){
    $manager->setFieldsFile($fields_file);
}

if (defined($fields_list)){
    $manager->setFieldsList($fields_list);
}

##----------------------------------------
##
## Pass on the sample_id variables
##
##----------------------------------------
if (defined($sample_id)){
    $manager->setSampleId($sample_id);
}

if (defined($sample_id_file)){
    $manager->setSampleIdFile($sample_id_file);
}

if (defined($sample_id_list)){
    $manager->setSampleIdList($sample_id_list);
}

$manager->runCharacterEncodingChecks();

print File::Spec->rel2abs($0) . " execution completed\n";
print "The log file is '$logfile'\n";
exit(0);


##------------------------------------------------------
##
##  END OF MAIN -- SUBROUTINES FOLLOW
##
##------------------------------------------------------

sub checkCommandLineArguments {
   
    if ($man){
    	&pod2usage({-exitval => 1, -verbose => 2, -output => \*STDOUT});
    }
    
    if ($help){
    	&pod2usage({-exitval => 1, -verbose => 1, -output => \*STDOUT});
    }

    if (!defined($config_file)){

        $config_file = DEFAULT_CONFIG_FILE;
            
        printYellow("--config_file was not specified and therefore was set to default '$config_file'");
    }

    if (!defined($verbose)){

        $verbose = DEFAULT_VERBOSE;

        printYellow("--verbose was not specified and therefore was set to default '$verbose'");
    }


    if (!defined($log_level)){

        $log_level = DEFAULT_LOG_LEVEL;

        printYellow("--log_level was not specified and therefore was set to default '$log_level'");
    }

    if (!defined($outdir)){

        $outdir = DEFAULT_OUTDIR;

        printYellow("--outdir was not specified and therefore was set to default '$outdir'");
    }

    $outdir = File::Spec->rel2abs($outdir);

    if (!-e $outdir){

        mkpath ($outdir) || die "Could not create output directory '$outdir' : $!";

        printYellow("Created output directory '$outdir'");
    }
    
    if (!defined($logfile)){

    	$logfile = $outdir . '/' . File::Basename::basename($0) . '.log';

    	printYellow("--logfile was not specified and therefore was set to '$logfile'");
    }

    $logfile = File::Spec->rel2abs($logfile);

    my $fatalCtr=0;

    if ((!defined($sample_id)) && (!defined($sample_id_list)) && (!defined($sample_id_file))){

        printBoldRed("You must specify either --sample_id, --sample_id_list or --sample_id_file");

        $fatalCtr++;
    }

    if ($fatalCtr> 0 ){

    	die "Required command-line arguments were not specified\n";
    }
}

sub printBoldRed {

    my ($msg) = @_;
    print color 'bold red';
    print $msg . "\n";
    print color 'reset';
}

sub printYellow {

    my ($msg) = @_;
    print color 'yellow';
    print $msg . "\n";
    print color 'reset';
}

sub printGreen {

    my ($msg) = @_;
    print color 'green';
    print $msg . "\n";
    print color 'reset';
}