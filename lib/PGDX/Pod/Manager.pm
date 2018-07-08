package PGDX::Pod::Manager;

use Moose;
use FindBin;

use PGDX::Logger;
use PGDX::Config::File::INI::Manager;

use constant TRUE  => 1;

use constant FALSE => 0;


## Singleton support
my $instance;


sub getInstance {

    if (!defined($instance)){

        $instance = new PGDX::Pod::Manager(@_);

        if (!defined($instance)){

            confess "Could not instantiate PGDX::Pod::Manager";
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
    
    my $config_manager = PGDX::Config::File::INI::Manager::getInstance();
    if (!defined($config_manager)){
        $self->{_logger}->logconfess("Could not instantiate PGDX::Config::File::INI::Manager");
    }

    $self->{_config_manager} = $config_manager;
}

sub _load_qualified_pod_list {

    my $self = shift;

    my $pods_path = $self->{_config_manager}->getPodsPath();
    if (!defined($pods_path)){
        $self->{_logger}->logconfess("pods_path was not defined");
    }

    opendir(my $dh, $pods_path) || $self->{_logger}->logconfess("Can't open '$pods_path' : $!");

    my $ctr = 0;

    while (my $file = readdir $dh) {

        if ($file =~ m/data\d+\-pgdx\-pod\d+$/){

            my $fullpath = $pods_path . '/' . $file;

            $fullpath =~ s|/+|/|g;

            $self->{_logger}->info("Found data pod path '$fullpath'");

            push(@{$self->{_qualified_pod_list}}, $fullpath);

            $ctr++;
        }
    }

    closedir $dh;

    $self->{_logger}->info("Found '$ctr' qualified pod directories under '$pods_path'");
}

sub getPathByPipelineName {

    my $self = shift;
    my ($pipeline_name) = @_;   

    $self->{_logger}->info("Searching data pods for directory for pipeline '$pipeline_name'");

    my $found = FALSE;

    if (! exists $self->{_pipeline_name_to_dir_lookup}->{$pipeline_name}){


        if (! exists $self->{_qualified_pod_list}){

            $self->_load_qualified_pod_list();


            foreach my $dir (reverse sort @{$self->{_qualified_pod_list}}){
                
                my $sample_dir = $dir . '/Samples/';

                $sample_dir =~ s|/+|/|g;

                $self->{_logger}->info("Searching for pipeline directory under data pod '$sample_dir'");

                opendir(my $dh, $sample_dir) || $self->{_logger}->logconfess("Can't open '$sample_dir' : $!");
                
                while (my $file = readdir $dh) {

                    if ($file eq $pipeline_name){

                        my $fullpath = $sample_dir . $file;

                        $self->{_pipeline_name_to_dir_lookup}->{$pipeline_name} = $fullpath; 

                        closedir $dh;

                        $found = TRUE;

                        return $self->{_pipeline_name_to_dir_lookup}->{$pipeline_name};                        
                        
                        ## end the madness
                    }
                }

                closedir $dh;
            }
        }

        if (!$found){
            $self->{_logger}->logconfess("Could not find the full pipeline directory!  Checked here: ". join(',', @{$self->{_qualified_pod_list}}));
        }
    }

    return $self->{_pipeline_name_to_dir_lookup}->{$pipeline_name};
}



no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 PGDX::Pod::Manager
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use PGDX::Pod::Manager;
 my $manager = PGDX::Pod::Manager::getInstance();
 $manager->generateTriggerFile($sample_id);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut
