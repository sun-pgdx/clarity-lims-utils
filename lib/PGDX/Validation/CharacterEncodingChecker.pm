package PGDX::Validation::CharacterEncodingChecker;

use Moose;
use Term::ANSIColor;

use PGDX::Logger;
use PGDX::Config::Manager;

use constant TRUE  => 1;

use constant FALSE => 0;

use constant DEFAULT_TEST_MODE => TRUE;


## Singleton support
my $instance;


sub getInstance {

    if (!defined($instance)){

        $instance = new PGDX::Validation::CharacterEncodingChecker(@_);

        if (!defined($instance)){

            confess "Could not instantiate PGDX::Validation::CharacterEncodingChecker";
        }
    }
    return $instance;
}

sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

    $self->_initConfigManager(@_);

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

sub hasNonPrintableChar {

    my $self = shift;
    my ($val) = @_;

    if (!defined($val)){
        $self->{_logger}->logconfess("val was not defined");
    }

    if ($val =~ /[^[:print:]]/){
        $self->{_logger}->warn("val '$val' contains a non-printable character");
        return TRUE;
    }

    return FALSE;
}

sub hasNonAsciiChar {

    my $self = shift;
    my ($val) = @_;

    if (!defined($val)){
        $self->{_logger}->logconfess("val was not defined");
    }

    if ($val =~ /[^[:ascii:]]/){
        $self->{_logger}->warn("val '$val' contains a non-ascii character");
        return TRUE;
    }

    return FALSE;
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 PGDX::Validation::CharacterEncodingChecker
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use PGDX::Validation::CharacterEncodingChecker;
 my $validator = PGDX::Validation::CharacterEncodingChecker::getInstance();
 if ($validator->hasNonPrintableChar($val)){
    print("val '$val' has a non-printable character in it!");
 }

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
