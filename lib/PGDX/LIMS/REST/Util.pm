package PGDX::LIMS::REST::Util;

use Moose;
use Cwd;
use Data::Dumper;
use File::Path;
use FindBin;
use File::Slurp;
use Term::ANSIColor;
use JSON::Parse 'json_file_to_perl';
use XML::Twig;
use MIME::Base64;
use REST::Client;

use PGDX::Logger;
use PGDX::Config::Manager;

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_TEST_MODE => TRUE;

use constant DEFAULT_OUTDIR => '/tmp/' . File::Basename::basename($0) . '/' . time();

use constant DEFAULT_INDIR => File::Spec->rel2abs(cwd());

my $this;

## Singleton support
my $instance;

has 'outdir' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setOutdir',
    reader   => 'getOutdir',
    required => FALSE,
    default  => DEFAULT_OUTDIR
    );

has 'auth' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setAuth',
    reader   => 'getAuth',
    required => FALSE,
    );

has 'headers' => (
    is       => 'rw',
    isa      => 'HashRef',
    writer   => 'setHeaders',
    reader   => 'getHeaders',
    required => FALSE,
    );

has 'auth' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setAuth',
    reader   => 'getAuth',
    required => FALSE,
    );

has 'username' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setUsername',
    reader   => 'getUsername',
    required => FALSE
    );

has 'password' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setPassword',
    reader   => 'getPassword',
    required => FALSE
    );

has 'rest_api_url' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setRESTAPIURL',
    reader   => 'getRESTAPIURL',
    required => FALSE
    );

sub getInstance {

    if (!defined($instance)){

        $instance = new PGDX::LIMS::REST::Util(@_);

        if (!defined($instance)){

            confess "Could not instantiate PGDX::LIMS::REST::Util";
        }
    }
    return $instance;
}

sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

    $self->_initConfigManager(@_);

    $self->_initRESTClient(@_);

    $self->{_logger}->info("Instantiated ". __PACKAGE__);
}

sub _initLogger {

    my $self = shift;

    my $logger = Log::Log4perl->get_logger(__PACKAGE__);

    if (!defined($logger)){
        confess "logger was not defined";
    }

    $self->{_logger} = $logger;
}


sub _initConfigManager {

    my $self = shift;
    
    my $config_manager = PGDX::Config::Manager::getInstance();
    if (!defined($config_manager)){
        $self->{_logger}->logconfess("Could not instantiate PGDX::Config::Manager");
    }

    $self->{_config_manager} = $config_manager;

}

sub _get_auth {

    my $self = shift;
    my ($auth) = @_;

    if (!defined($auth)){
        $auth = $self->getAuth();
        if (!defined($auth)){
            $auth = $self->{_config_manager}->getLIMSAuth();
            if (!defined($auth)){
                $self->{_logger}->logconfess("LIMS auth was not defined in the configuration file");
            }

            $self->{_logger}->info("LIMS auth was not defined and therefore was derived from the configuration file");

            $self->setAuth($auth);
        }
    }

    chomp $auth; ## remove trailing newline character

    return $auth;
}


sub _get_url {

    my $self = shift;
    my ($url) = @_;

    if (!defined($url)){
     
        $url = $self->getRESTAPIURL();
     
        if (!defined($url)){
     
            $url = $self->{_config_manager}->getLIMSRESTURL();
     
            if (!defined($url)){
                $self->{_logger}->logconfess("LIMS REST API url was not defined in the configuration file");
            }

            $self->{_logger}->info("LIMS REST API url was not defined and therefore was derived from the configuration file");

            $self->setRESTAPIURL($url);
        }
    }

    return $url;
}

sub _get_username {

    my $self = shift;
    my ($username) = @_;

    if (!defined($username)){

        $username = $self->getUsername();
        
        if (!defined($username)){

            $username = $self->{_config_manager}->getLIMSUsername();
            if (!defined($username)){
                $self->{_logger}->logconfess("LIMS username was not defined in the configuration file");
            }

            $self->{_logger}->info("LIMS username was not defined and therefore was derived from the configuration file");

            $self->setUsername($username);
        }        
    }

    return $username;
}

sub _get_password {

    my $self = shift;
    my ($password) = @_;

    if (!defined($password)){

        $password = $self->getPassword();
        
        if (!defined($password)){

            $password = $self->{_config_manager}->getLIMSPassword();
            if (!defined($password)){
                $self->{_logger}->logconfess("LIMS password was not defined in the configuration file");
            }

            $self->{_logger}->info("LIMS password was not defined and therefore was derived from the configuration file");

            $self->setPassword($password);
        }        
    }

    return $password;
}

sub _initRESTClient {

    my $self = shift;
    my ($auth, $url, $username, $password) = @_;

    $auth = $self->_get_auth($auth);
    
    $url = $self->_get_url($url);
    
    $username = $self->_get_username($username);
    
    $password = $self->_get_password($password);

    my $authorization = encode_base64($username . ':' . $password);
    if (!defined($authorization)){
        $self->{_logger}->logconfess("authorization was not defined for username '$username' password '$password'");
    }

    chomp $authorization;

    $self->{_logger}->info("authorization set to '$authorization' for username '$username' password '$password'");

    my $headers = {
        Accept => 'application/xml',
        Authorization => "Basic $authorization",
    };


    $self->setHeaders($headers);

    my $rest = REST::Client->new({
        host => $url,
    });
    
    if (!defined($rest)){
        $self->{_logger}->logconfess("Could not instantiate REST::Client");
    }
 
    $self->{_rest_client} = $rest;
}

sub _get_response_content {

    my $self = shift;
    my ($url, $headers) = @_;

    if (!defined($url)){
        $self->{_logger}->logconfess("url was not defined");
    }

    if (!defined($headers)){
     
        $headers = $self->getHeaders();
     
        if (!defined($headers)){
            $self->{_logger}->logconfess("headers was not defined");
        }
    }

    my $response;

    eval {
        $response = $self->{_rest_client}->GET($url, $headers);
        if (!defined($response)){
            $self->{_logger}->logconfess("request was not defined for request '$url'");
        }
    };

    if ($?){
        $self->{_logger}->logconfess("Encountered some problem while attempting to GET $url");
    }

    my $responseContent = $response->responseContent();
    if (!defined($responseContent)){
        $self->{_logger}->logconfess("responseContent was not defined for GET request to '$url'");
    }

    $self->{_logger}->info("response content '$responseContent' for GET request to URL '$url'");

    return $responseContent;
}



sub checkIndirectoryStatus {

    my $self = shift;
    my ($indir) = @_;

    if (!defined($indir)){
        $self->{_logger}->logconfess("indir was not defined");
    }

    my $errorCtr = 0 ;

    if (!-e $indir){
        
        $self->{_logger}->warn("input directory '$indir' does not exist");
        
        $errorCtr++;
    }
    else {

        if (!-d $indir){
        
            $self->{_logger}->warn("'$indir' is not a regular directory");
            
            $errorCtr++;
        }

        if (!-r $indir){
            
            $self->{_logger}->warn("input directory '$indir' does not have read permissions");
            
            $errorCtr++;
        }        
    }
     
    if ($errorCtr > 0){
        
        $self->{_logger}->warn("Encountered issues with input directory '$indir'");
        
    }
}

sub _execute_cmd {
    
    my $self = shift;
    
    my ($cmd) = @_;
    if (!defined($cmd)){
        $self->{_logger}->logconfess("cmd was not defined");
    }

    $self->{_logger}->info("About to execute '$cmd'");

    my @results;

    eval {
        @results = qx($cmd);
    };

    if ($?){
        $self->{_logger}->logconfess("Encountered some error while attempting to execute '$cmd' : $! $@");
    }

    chomp @results;

    return \@results;
}    


sub _write_content_to_file {

    my $self = shift;
    my ($content) = @_;

    my $outdir = $self->getOutdir();

    if (!defined($outdir)){

        mkpath($outdir) || $self->{_logger}->logconfess("Could not create output directory '$outdir' : $!");

        $self->{_logger}->info("created outdir '$outdir'");
    }

    my $outfile = $outdir . '/' . File::Basename::basename($0) . '.' . time() . '.xml';

    open (OUTFILE, ">$outfile") || $self->{_logger}->logconfess("Could not open '$outfile' in write mode : $!");
    
    print OUTFILE $content;

    close OUTFILE;
    
    $self->{_logger}->info("Wrote XML content to '$outfile'");
    
    return $outfile;
}

no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 PGDX::LIMS::REST::Util
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use PGDX::LIMS::REST::Util;
 my $manager = PGDX::LIMS::REST::Util::getInstance();
 $manager->commitCodeAndPush($comment);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
