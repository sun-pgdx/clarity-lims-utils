package PGDX::Util::Request;

## Simple module to send post requests. Can be extended for other request types.

use strict;
use warnings;
use LWP::UserAgent;

## Default timeout in seconds for request
my $default_timeout = 180;

sub send_post {
   my ($class, $url, $data, $success_sub, $failure_sub, $timeout, $apiKey) = @_;

   $timeout = $default_timeout unless( $timeout );
   
   my $req = new HTTP::Request( 'POST' => $url );
   if (!defined($req)){
    die "Could not instantiate HTTP::Request : $!";
   }

   $req->content($data);
   $req->header('Content-Type' => 'application/json');
   $req->header('Authorization' => 'GenieKey ' . $apiKey);

   my $agent = new LWP::UserAgent();
   $agent->timeout( $timeout );
   
   my $response = $agent->request($req);
   my $content = $response->decoded_content();
   my $success = 0;

   ## This means we successfully posted. No assumptions about what happened after we sent the message.
   if( $response->is_success() ) {
       if( $success_sub ) {
           $success_sub->($response);
       } else {
           $success = 1;
       }
   } else {
       if( $failure_sub ) {
           $failure_sub->($response)
       }
   }
   
   return ($success,$content);
}
1;
