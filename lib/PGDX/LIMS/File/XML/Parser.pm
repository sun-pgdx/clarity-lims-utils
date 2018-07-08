package PGDX::LIMS::File::XML::Parser;

use Moose;
use Data::Dumper;
use PGDX::Logger;
use XML::Twig;

use constant TRUE  => 1;
use constant FALSE => 0;

use constant DEFAULT_TEST_MODE => TRUE;

use constant DEFAULT_VERBOSE => TRUE;

has 'verbose' => (
    is       => 'rw',
    isa      => 'Bool',
    writer   => 'setVerbose',
    reader   => 'getVerbose',
    required => FALSE,
    default  => DEFAULT_VERBOSE
    );

has 'infile' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setInfile',
    reader   => 'getInfile',
    required => FALSE
    );

has 'project_uri' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setProjectURI',
    reader   => 'getProjectURI',
    required => FALSE
    );

my $this;

sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

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

sub parseFile {

    my $self = shift;
    $self->_parse_file(@_);
}

sub _parse_file {

    my $self = shift;
    my ($infile) = @_;

    if (!defined($infile)){

        $infile = $self->getInfile();

        if (!defined($infile)){
            $self->{_logger}->logconfess("infile was not defined");
        }
    }

    $self->_checkInfileStatus($infile);

    $this = $self;

    my $twig = new XML::Twig( 
       twig_handlers =>  { 
        'project' => \&_project_callback,
        'smp:sample'   => \&_smp_sample_callback,        
       });
   
    if (!defined($twig)){
        $self->{_logger}->logconfess("Could not instantiate XML::Twig for file '$infile'");
    }

    $twig->parsefile( $infile );

    $self->{_logger}->info("Finished parsing XML file '$infile'");
}


sub _project_callback {

    my $self = $this;
    my ($twig, $project) = @_;

    if (!defined($project)){
        $self->{_logger}->logconfess("project was not defined");
    }
      
    if (exists $project->{'att'}->{'uri'}){
        $self->{_logger}->info("Found project URI '$project->{att}->{uri}'");
        $self->setProjectURI($project->{'att'}->{'uri'});
    }
    else {
        $self->{_logger}->logconfess("uri was not defined for the project");
    }
}

sub _smp_sample_callback {

    my $self = $this;
    my ($twig, $sample) = @_;

    if (!defined($sample)){
        $self->{_logger}->logconfess("sample was not defined");
    }
      
    if (! $sample->has_child('udf:field')){
        $self->{_logger}->logconfess("smp:sample does not have child udf:field " . Dumper $sample);
    }

    my $udf = $sample->first_child('udf:field');

    $self->_process_udf_field($udf);

    while ($udf = $udf->next_sibling()){

        $self->_process_udf_field($udf);
    }
}

sub _process_udf_field {

    my $self = shift;
    my ($udf) = @_;

    my $field_name = $udf->{'att'}->{'name'};
    if (!defined($field_name)){
        $self->{_logger}->logconfess("name was not defined for <udf:field> : " . Dumper $udf);
    }

    my $val = $udf->text();
    if (!defined($val)){
        $val = '';
        $self->{_logger}->warn("val was not defined and therefore was set to '$val'");
    }

    $self->{_field_to_value_lookup}->{$field_name} = $val;
}


sub hasField {

    my $self = shift;
    my ($field) = @_;

    if (!defined($field)){
        $self->{_logger}->logconfess("field was not defined");
    }

    if (exists $self->{_field_to_value_lookup}->{$field}){
        return TRUE;
    }

    return FALSE;
}

sub getValue {

    my $self = shift;
    my ($field) = @_;

    if (!defined($field)){
        $self->{_logger}->logconfess("field was not defined");
    }

    if (exists $self->{_field_to_value_lookup}->{$field}){
        return $self->{_field_to_value_lookup}->{$field};
    }

    return undef;
}

sub _checkInfileStatus {

    my $self = shift;
    my ($infile) = @_;

    if (!defined($infile)){
        $self->{_logger}->logconfess("infile was not defined");
    }

    my $errorCtr = 0 ;

    if (!-e $infile){
        $self->{_logger}->fatal("input file '$infile' does not exist");
        $errorCtr++;
    }
    else {
        if (!-f $infile){
            $self->{_logger}->fatal("'$infile' is not a regular file");
            $errorCtr++;
        }
        
        if (!-r $infile){
            $self->{_logger}->fatal("input file '$infile' does not have read permissions");
            $errorCtr++;
        }
        
        if (!-s $infile){
            $self->{_logger}->fatal("input file '$infile' does not have any content");
            $errorCtr++;
        }
    }

    if ($errorCtr > 0){
        $self->{_logger}->logconfess("Encountered issues with input file '$infile'");
    }
}

sub getPreservation {

    my $self = shift;
    
    $self->_parse_file();
    
    if (exists $self->{_field_to_value_lookup}->{'Preservation'}){
        return $self->{_field_to_value_lookup}->{'Preservation'};
    }

    $self->{_logger}->warn("Preservation does not exist in the field to value lookup");

    return undef;
}

sub getSampleUDFLookup {

    my $self = shift;
        
    if (! exists $self->{_field_to_value_lookup}){

        $self->_parse_file();
    }

    return $self->{_field_to_value_lookup};
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

 PGDX::LIMS::File::XML::Parser
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use PGDX::LIMS::File::XML::Parser;
 my $manager = PGDX::LIMS::File::XML::Parser::getInstance();
 $manager->runBenchmarkTests($infile);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut