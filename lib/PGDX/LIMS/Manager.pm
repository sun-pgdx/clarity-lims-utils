package PGDX::LIMS::Manager;

use Moose;
use File::Slurp;

use PGDX::Logger;
use PGDX::Config::Manager;
use PGDX::Validation::CharacterEncodingChecker;

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_FIELDS_TO_CHECK => 'Specimen #, Diagnosis, Primary Tumor Site, Sample Type, Percent Tumor, Patient Name, Protocol, Patient Medical Record, Test Disposition, Tests Ordered, Client Name';

use constant DEFAULT_OUTDIR => '/tmp/' . File::Basename::basename($0) . '/' . time();

## Singleton support
my $instance;

has 'fields_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setFieldsFile',
    reader   => 'getFieldsFile',
    required => FALSE
    );

has 'fields_list' => (
    is       => 'rw',
    isa      => 'ArrayRef',
    writer   => 'setFieldsList',
    reader   => 'getFieldsList',
    required => FALSE
    );

has 'fields_lookup' => (
    is       => 'rw',
    isa      => 'HashRef',
    writer   => 'setFieldsLookup',
    reader   => 'getFieldsLookup',
    required => FALSE
    );

has 'outdir' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setOutdir',
    reader   => 'getOutdir',
    required => FALSE,
    default  => DEFAULT_OUTDIR
    );

has 'sample_id' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setSampleId',
    reader   => 'getSampleId',
    required => FALSE
    );

has 'sample_id_list' => (
    is       => 'rw',
    isa      => 'ArrayRef',
    writer   => 'setSampleIdList',
    reader   => 'getSampleIdList',
    required => FALSE
    );
has 'sample_id_lookup' => (
    is       => 'rw',
    isa      => 'HashRef',
    writer   => 'setSampleIdLookup',
    reader   => 'getSampleIdLookup',
    required => FALSE
    );

has 'sample_id_file' => (
    is       => 'rw',
    isa      => 'Str',
    writer   => 'setSampleIdFile',
    reader   => 'getSampleIdFile',
    required => FALSE
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

        $instance = new PGDX::LIMS::Manager(@_);

        if (!defined($instance)){

            confess "Could not instantiate PGDX::LIMS::Manager";
        }
    }
    return $instance;
}

sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

    $self->_initConfigManager(@_);

    $self->_initRESTUtil(@_);

    $self->_initChecker(@_);

    $self->_init_allowed_null_fields_lookup();

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
        $self->{_logger}->logconfess("Could not instantiate PGDX::Config::File::Manager");
    }

    $self->{_config_manager} = $config_manager;

}

sub _initChecker {

    my $self = shift;

    my $checker = PGDX::Validation::CharacterEncodingChecker::getInstance();
    if (!defined($checker)){
        $self->{_logger}->logconfess("Could not instantiate PGDX::Validation::CharacterEncodinghChecker");
    }

    $self->{_checker} = $checker;
}

sub _init_allowed_null_fields_lookup{

    my $self = shift;

    $self->{_allowed_null_fields_lookup} = {
        'Diagnosis'                 => 'N/A',
        'Primary Tumor Site'        => 'N/A',
        'Percent Tumor'             => 'N/A',
        'Protocol'                  => 'N/A',
        'Patient Name'              => 'N/A',
        'Patient Medical Record'    => 'N/A',
        # 'Project Name'              => 'Some Bogus Project Name', #'Victor JHU Lab',
        # 'Test Disposition'          => 'Tumor/Normal',
        # 'Tests Ordered'             => 'CancerXOME',
        # 'Client Name'               => 'Some Bogus Client'
    };
}

sub _initialize_parameters {

    my $self = shift;

    $self->_load_final_sample_id_list();

    $self->_load_final_fields_to_check_lookup();

}

sub _load_final_sample_id_list {

    my $self = shift;
    
    my $sample_id = $self->getSampleId();

    if (defined($sample_id)){
        push(@{$self->{_final_sample_id_list}}, $sample_id);
    }

    my $sample_id_list = $self->getSampleIdList();
    if (defined($sample_id_list)){

        $self->_load_final_sample_id_list_from_list($sample_id_list);        
    }

    my $sample_id_file = $self->getSampleIdFile();
    if (defined($sample_id_file)){
        $self->_load_final_sample_id_list_from_file($sample_id_file);
    }
}

sub _load_final_sample_id_list_from_list {

    my $self = shift;
    my ($sample_id_list) = @_;

    my $ctr = 0;

    my @ids = split(',', $sample_id_list);
    
    foreach my $id (@ids){

        $ctr++;
        
        push(@{$self->{_final_sample_id_list}}, $id);
    }

    $self->{_logger}->info("Added '$ctr' sample_id values from the sample_id list");
}

sub _load_final_sample_id_list_from_file {

    my $self = shift;
    my ($sample_id_file) = @_;

    $self->_checkInfileStatus($sample_id_file);

    my @list = read_file($sample_id_file);

    chomp @list;

    my $ctr = 0;
            
    foreach my $id (@list){

        $id =~ s/^\s+//;
        $id =~ s/\s+$//;

        $ctr++;
        
        push(@{$self->{_final_sample_id_list}}, $id);
    }

    $self->{_logger}->info("Added '$ctr' sample_id values from the sample_id file '$sample_id_file'");
}


sub _load_final_fields_to_check_lookup {

    my $self = shift;
        
    $self->{_fields_to_check_ctr} = 0;

    my $fields_list = $self->getFieldsList();
    if (defined($fields_list)){
        $self->_load_final_fields_to_check_lookup_from_list($fields_list);
    }

    my $fields_file = $self->getFieldsFile();
    if (defined($fields_file)){
        $self->_load_final_fields_to_check_lookup_from_file($fields_file);
    }

    if ($self->{_fields_to_check_ctr} == 0){
        $self->_load_final_fields_to_check_lookup_from_config();
    }
}

sub _load_final_fields_to_check_lookup_file {

    my $self = shift;
    my ($fields_file) = @_;

    my @fields_of_interest = read_file($fields_file);

    chomp @fields_of_interest;

    my $ctr = 0;

    foreach my $field (@fields_of_interest){
        
        $field =~ s/\s+$//;
        $field =~ s/^\s+//;

        $self->{_final_fields_to_check_lookup}->{$field}++;
        $ctr++;
    }

    if ($ctr > 0){
        $self->{_fields_to_check_ctr} += $ctr;
        $self->{_logger}->info("Added '$ctr' fields to the final fields to check loookup for the fields file '$fields_file'");
    }
    else {
        $self->{_logger}->warn("No fields were added from user-specified fields-file '$fields_file'");   
    }   
}

sub _load_final_fields_to_check_from_list {

    my $self = shift;
    my ($fields_list) = @_;

    my @list = split(',', $fields_list);

    my $ctr = 0;

    foreach my $field (@list){

        $field =~ s/^\s+//;
        $field =~ s/\s+$//;
        
        $self->{_final_fields_to_check_lookup}->{$field}++;
        
        $ctr++;
    }

    if ($ctr > 0){
    
        $self->{_fields_to_check_ctr} += $ctr;
    
        $self->{_logger}->info("Added '$ctr' fields to the final fields to check lookup from the fields list '$fields_list'");
    }
    else {
        $self->{_logger}->warn("No fields were added from user-specified fields-list '$fields_list'");   
    }   
}

sub _load_final_fields_to_check_lookup_from_config {

    my $self = shift;

    my $load_from_config = FALSE;
    
    my $string = $self->{_config_manager}->getFieldsToCheck();

    if ((defined($string)) && ($string ne '')){
    
        $load_from_config = TRUE;
    }
    else {
        $string = DEFAULT_FIELDS_TO_CHECK;
    }

    my $ctr = 0;

    my @list = split(',', $string);

    foreach my $field (@list){

        $field =~ s/^\s+//;
        $field =~ s/\s+$//;

        $self->{_final_fields_to_check_lookup}->{$field}++;
        
        $ctr++;
    }

    if ($ctr > 0){

        $self->{_fields_to_check_ctr} += $ctr;

        if ($load_from_config){
            $self->{_logger}->info("Added '$ctr' default fields to the final fields to check lookup from the configuration file");
        }
        else {
            $self->{_logger}->info("Added '$ctr' default fields to the final fields to check lookup from default");
        }
    }
    else {
        $self->{_logger}->logconfess("Did not load any fields to check in the configuration file nor in default settings");
    }
}


# sub derive_lims_field_list {

#     if (defined($fields_file)){
#         &load_fields_lookup_from_file($fields_file);
#     }

#     if (defined($fields_list)){
#         &load_fields_lookup_from_list();
#     }

#     if (!$fields_loaded) {
#         &load_fields_lookup_from_default();
#     }

#     $logger->info("Here are the fields to be pulled from LIMS: " . join(',', sort keys %{$fields_lookup}));
# }

# sub derive_sample_id_list {

#     if (defined($sample_id_file)){
#         &load_sample_id_lookup_from_file($sample_id_file);
#     }

#     if (defined($sample_id_list)){
#         &load_sample_id_lookup_from_list($sample_id_list);
#     }

#     if (defined($sample_id)){
#         $sample_id_lookup->{$sample_id} = TRUE;
#     }

#     $logger->info("Here are the sample_id values to be processed: " . join(',', sort keys %{$sample_id_lookup}));
# }

# sub load_sample_id_lookup_from_file {

#     my ($sample_id_file) = @_;

#     my @list = read_file($sample_id_file);

#     chomp @list;

#     my $ctr = 0;

#     foreach my $sample_id (@list){
        
#         $sample_id =~ s/\s+$//;
#         $sample_id  =~ s/^\s+//;

#         $sample_id_lookup->{$sample_id}++;
#         $ctr++;
#     }

#     if ($ctr > 0){
#         $sample_id_loaded = TRUE;
#         $logger->info("Added '$ctr' sample_id values to the sample_id_lookup");
#     }
#     else {
#         $logger->warn("No sample_id values  added from user-specified sample_id file '$sample_id_file'");   
#     }   
# }

# sub load_sample_id_lookup_from_list {

#     my @list = split(',', $sample_id_list);

#     my $ctr = 0;

#     foreach my $sample_id (@list){
#         $sample_id_lookup->{$sample_id}++;
#         $ctr++;
#     }

#     if ($ctr > 0){
#         $sample_id_loaded = TRUE;
#         $logger->info("Added '$ctr' sample_id values to the sample_id_lookup");
#     }
#     else {
#         $logger->warn("No sample_id values were added from user-specified sample_id list '$sample_id_list'");   
#     }   
# }

sub getFinalSampleIdList {

    my $self = shift;
    
    return $self->{_final_sample_id_list};
}

sub getFieldsToCheckLookup {

    my $self = shift;

    return $self->{_final_fields_to_check_lookup};
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 PGDX::LIMS::Manager
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use PGDX::LIMS::Manager;
 my $manager = PGDX::LIMS::Manager::getInstance();
 $manager->commitCodeAndPush($comment);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
