package PGDX::LIMS::Manager::Factory;

use Moose;

use PGDX::Config::Manager;
use PGDX::ClarityLIMS::Manager;

use constant TRUE  => 1;
use constant FALSE => 0;

use constant DEFAULT_TYPE => 'clarity';

## Singleton support
my $instance;

has 'type' => (
    is      => 'rw',
    isa     => 'Str',
    writer  => 'setType',
    reader  => 'getType',
    default => DEFAULT_TYPE
    );

sub getInstance {

    if (!defined($instance)){

        $instance = new PGDX::LIMS::Manager::Factory(@_);

        if (!defined($instance)){

            confess "Could not instantiate PGDX::LIMS::Manager::Factory";
        }
    }

    return $instance;
}

sub BUILD {

    my $self = shift;

    $self->_initLogger(@_);

    $self->_initConfigManager(@_);

    $self->{_logger}->info("Instantiated " . __PACKAGE__);
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

sub _getType {

    my $self = shift;
    my (%args) = @_;

    my $type = $self->getType();

    if (!defined($type)){

        if (( exists $args{type}) && ( defined $args{type})){
            $type = $args{type};
        }
        elsif (( exists $self->{type}) && ( defined $self->{type})){
            $type = $self->{type};
        }
        else {
            $self->{_logger}->logconfess("type was not defined");
        }

        $self->setType($type);
    }

    return $type;
}

sub create {

    my $self = shift;
    my ($type) = @_;

    if (!defined($type)){
        $type = $self->{_config_manager}->getLIMSVendor();
        if (!defined($type)){
            $type = DEFAULT_TYPE;
            $self->{_logger}->info("LIMS type was not specified in the configuration file and therefore was set to default '$type'");
        }
    }


    if (lc($type) eq 'clarity'){

        my $manager = PGDX::ClarityLIMS::Manager::getInstance();
        if (!defined($manager)){
            $self->{_logger}->logconfess("Could not instantiate PGDX::ClarityLIMS::Manager");
        }

        return $manager;
    }
    else {
        $self->{_logger}->logconfess("type '$type' is not supported");
    }
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

 PGDX::LIMS::Manager::Factory

 A module factory for creating LIMS Manager instances.

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use PGDX::LIMS::Manager::Factory;
 my $factory = PGDX::LIMS::Manager::Factory::getIntance();
 my $manager = $factory->create($type);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut