package PGDX::ClarityLIMS::Manager;

use Moose;
use Data::Dumper;

use PGDX::ClarityLIMS::REST::Util;

extends 'PGDX::LIMS::Manager';

use constant TRUE  => 1;

use constant FALSE => 0;


## Singleton support
my $instance;


sub getInstance {

    if (!defined($instance)){

        $instance = new PGDX::ClarityLIMS::Manager(@_);

        if (!defined($instance)){

            confess "Could not instantiate PGDX::ClarityLIMS::Manager";
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

sub _initRESTUtil {

    my $self = shift;

    my $util = PGDX::ClarityLIMS::REST::Util::getInstance(@_);
    if (!defined($util)){
        $self->{_logger}->logconfess("Could not instantiate PGDX::ClarityLIMS::REST::Util");
    }

    $self->{_rest_util} = $util;
}

sub runCharacterEncodingChecks {

    my $self = shift;
    
    $self->_initialize_parameters();

    my $sample_id_list = $self->getFinalSampleIdList();
    if (!defined($sample_id_list)){
        $self->{_logger}->logconfess("sample_id_list was not defined");
    }

    my $fields_to_check_lookup = $self->getFieldsToCheckLookup();
    if (!defined($fields_to_check_lookup)){
        $self->{_logger}->logconfess("fields_to_check_lookup was not defined");
    }

    foreach my $sample_id (@{$sample_id_list}){
        
        $self->{_logger}->info("Processing sample_id '$sample_id'");

        my $retrieved_fields_lookup = $self->getFieldsBySampleId($sample_id);

        foreach my $field_to_check (sort keys %{$fields_to_check_lookup}){
            
            $self->{_logger}->info("Checking field '$field_to_check' for sample_id '$sample_id'");
            
            if (! exists $retrieved_fields_lookup->{$field_to_check}){
            
                $self->{_logger}->warn("field '$field_to_check' was not available for sample_id '$sample_id'");
            }
            else {
                
                my $val = $retrieved_fields_lookup->{$field_to_check};
                
                if ($self->{_checker}->hasNonPrintableChars($val)){
            
                    push(@{$self->{_non_printable_char_lookup}->{$sample_id}}, [$field_to_check, $val]);
            
                    $self->{_non_printable_char_ctr}++;
                }

                if ($self->{_checker}->hasNonAsciiChars($val)){
            
                    push(@{$self->{_non_ascii_char_lookup}->{$sample_id}}, [$field_to_check, $val]);
            
                    $self->{_non_ascii_char_ctr}++;
                }
            }
        }
    }
}

sub getFieldsBySampleId {

    my $self = shift;
    my ($sample_id) = @_;

    if (! exists $self->{_retrieved_fields_lookup}->{$sample_id}){
    
        my $retrieved_fields_lookup = $self->{_rest_util}->getSampleUDFLookup($sample_id);
    
        if (!defined($retrieved_fields_lookup)){
            $self->{_logger}->logconfess("retrieved_fields_lookup was not defined");
        }

        $self->{_retrieved_fields_lookup}->{$sample_id} = $retrieved_fields_lookup;
    }

    return $self->{_retrieved_fields_lookup};
}



no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 PGDX::ClarityLIMS::Manager
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use PGDX::ClarityLIMS::Manager;
 my $manager = PGDX::ClarityLIMS::Manager::getInstance();
 $manager->runCharacterEncodingChecks();

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut