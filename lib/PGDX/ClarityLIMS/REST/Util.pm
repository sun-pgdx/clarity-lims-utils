package PGDX::ClarityLIMS::REST::Util;

use Moose;

extends 'PGDX::LIMS::REST::Util';

use constant TRUE  => 1;

use constant FALSE => 0;


my $this;

## Singleton support
my $instance;


sub getInstance {

    if (!defined($instance)){

        $instance = new PGDX::ClarityLIMS::REST::Util(@_);

        if (!defined($instance)){

            confess "Could not instantiate PGDX::ClarityLIMS::REST::Util";
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


sub getContentBySample {

    my $self = shift;
    my ($sample) = @_;

    if (!defined($sample)){
        $self->{_logger}->logconfess("sample was not defined");
    }

    my $url = '/samples/' . $sample;

    $self->{_logger}->info("Will attempt to retrieve data from LIMS via GET request to url '$url'");

    my $responseContent = $self->_get_response_content($url);

    return $responseContent;
}

sub getProjectName {

    my $self = shift;
    my ($project_uri) = @_;

    if (!defined($project_uri)){
        $self->{_logger}->logconfess("project_uri was not defined");
    }


    if ($project_uri =~ m|api/v2/|){#projects/(S+)|){

        ## This is ugly code.  
        ## Regex was not working so moved to this strategy.
        ## Improve this soon.
        my @parts = split(/api\/v2/, $project_uri);

        my $url = $parts[1];
        
        my $content = $self->_get_response_content($url);
        
        if (!defined($content)){
            $self->{_logger}->logconfess("content was not defined for url '$url' project URI '$project_uri'");
        }

        my $project_name = $self->_get_project_name_from_content($content);

        return $project_name;
    }
    else {
        $self->{_logger}->logconfess("Unexpected project URI '$project_uri'");
    }
}

sub _get_project_name_from_content {

    my $self = shift;
    my ($content) = @_;

    $this = $self;

    my $twig = new XML::Twig( 
        twig_handlers =>  { 
           'name'   => \&_project_name_callback,
        }
    );
   
    if (!defined($twig)){
        $self->{_logger}->logconfess("Could not instantiate XML::Twig for response content '$content'");
    }

    $twig->parse($content);


    return $self->{_project_name};
}

sub _project_name_callback {

    my $self = $this;
    my ($twig, $project_name) = @_;

    if (!defined($project_name)){
        $self->{_logger}->logconfess("project_name was not defined");
    }
      
    $self->{_project_name} = $project_name->text;
}


sub getContentBySampleName {

    my $self = shift;
    my ($sample_id) = @_;

    if (!defined($sample_id)){
        $self->{_logger}->logconfess("sample_id was not defined");
    }

    my $headers = $self->getHeaders();
    if (!defined($headers)){
        $self->{_logger}->logconfess("headers was not defined");
    }

    ## First we need to retrieve the sample XML
    # my $url = $self->getRESTAPIURL() . '/samples?name=' . $sample_id;
    my $url = '/samples?name=' . $sample_id;

    $self->{_logger}->info("Will attempt to retrieve data from url '$url'");

    ## The sample XML content will have a <sample> with a uri attribute.
    ## It is the uri attribute value that needs to be used to retrieve
    ## the final content.
    my $limsid_url = $self->_get_limsid_url_from_content($url, $headers);

    # my $content = $self->{_rest_client}->GET($limsid_url, $headers);
    # if (!defined($content)){
    #     $self->{_logger}->logconfess("content was not defined for request '$limsid_url'");
    # }

    ## Need to trim the full URL
    my $rest_api_url = $self->getRESTAPIURL();
    if (!defined($rest_api_url)){
        $self->{_logger}->logconfess("rest_api_url was not defined");
    }

    if ($limsid_url =~ m/$rest_api_url/){
        $limsid_url =~ s/$rest_api_url//;
        $self->{_logger}->info("Trimmed the REST API URL from the sample URL and derived '$limsid_url'");
    }

    my $content = $self->_get_response_content($limsid_url);

    return $content;
}

sub _get_limsid_url_from_content {

    my $self = shift;
    my ($sample_url, $headers) = @_;

    my $responseContent = $self->_get_response_content($sample_url, $headers);

    $this = $self;

    my $twig = new XML::Twig( 
        twig_handlers =>  { 
           'sample'   => \&_sample_callback,
        }
    );
   
    if (!defined($twig)){
        $self->{_logger}->logconfess("Could not instantiate XML::Twig for response content '$responseContent' (URL '$sample_url')");
    }

    $twig->parse($responseContent);

    $self->{_logger}->info("Retrieved uri '$self->{_limsid_url}' from sample URL '$sample_url'");

    return $self->{_limsid_url};
}

sub _sample_callback {

    my $self = $this;
    my ($twig, $sample) = @_;

    if (!defined($sample)){
        $self->{_logger}->logconfess("sample was not defined");
    }
      
    if (exists $sample->{'att'}->{'uri'}){
        my $uri = $sample->{'att'}->{'uri'};
        if (!defined($uri)){
            $self->{_logger}->logconfess("uri was not defined for <sample> : " . Dumper $sample);
        }

        $self->{_limsid_url} = $uri
    }
    else {
        $self->{_logger}->logconfess("uri does not exist for <sample> : ". Dumper $sample);
    }
}

sub getPreservationBySampleId {

    my $self = shift;
    my ($sample_id) = @_;
    
    if (!defined($sample_id)){
        $self->{_logger}->logconfess("sample_id was not defined");
    }

    my $content = $self->getContentBySampleName($sample_id);

    my $file = $self->_write_content_to_file($content);

    my $parser = new PGDX::LIMS::File::XML::Parser(infile => $file);

    if (!defined($parser)){
        $self->{_logger}->logconfess("Could not instantiate PGDX::LIMS::File::XML::Parser");
    }
    
    my $source = $parser->getPreservation();

    if (!defined($source)){
        $self->{_logger}->logconfess("Could not derive preservation from content '$content' for sample_id '$sample_id'");
    }

    return $source;
}


no Moose;
__PACKAGE__->meta->make_immutable;

__END__


=head1 NAME

 PGDX::ClarityLIMS::REST::Util
 

=head1 VERSION

 1.0

=head1 SYNOPSIS

 use PGDX::ClarityLIMS::REST::Util;
 my $util = PGDX::ClarityLIMS::REST::Util::getInstance();
 $util->getUDFBySampleId($sample_id);

=head1 AUTHOR

 Jaideep Sundaram

 Copyright Jaideep Sundaram

=head1 METHODS

=over 4

=cut