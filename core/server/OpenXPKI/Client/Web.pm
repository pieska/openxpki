package OpenXPKI::Client::Web;
use Mojo::Base 'Mojolicious', -signatures;

# CPAN modules
use Mojo::Util qw( url_unescape );
use Mojo::Log;
use Type::Params qw( signature_for );

# Project modules
use OpenXPKI::Client;
use OpenXPKI::Client::Config;
use OpenXPKI::Log4perl::MojoLogger;

# Feature::Compat::Try should be done last to safely disable warnings
use Feature::Compat::Try;


my $socketfile = $ENV{OPENXPKI_CLIENT_SOCKETFILE} || '/var/openxpki/openxpki.socket';

sub declare_routes ($self, $r) {
    # Health Check
    $r->get('/healthcheck' => sub { shift->redirect_to('check', command => 'ping') });
    $r->get('/healthcheck/<command>')->to('Healthcheck#index')->name('check');

    # EST urls look like
    #   /.well-known/est/cacerts
    #   /.well-known/est/namedservice/cacerts  # incl. endpoint
    # <endpoint> is optional because a default is given.
    $r->any('/.well-known/est/<endpoint>/<operation>')->to(
        namespace => '',
        controller => 'OpenXPKI::Client::Service::EST',
        action => 'index',
        endpoint => 'default',
    );

    # SCEP urls look like
    #   /scep/server?operation=PKIOperation                 # incl. endpoint/server
    #   /scep/server/pkiclient.exe?operation=PKIOperation   # incl. endpoint/server
    # <*throwaway> is a catchall placeholder which is optional (because a default is given).
    $r->any('/scep/<endpoint>/<*throwaway>')->to(
        namespace => '',
        controller => 'OpenXPKI::Client::Service::SCEP',
        action => 'index',
        throwaway => '',
    );
}

sub startup ($self) {

    $self->log(OpenXPKI::Log4perl->get_logger(''));

    #$self->secrets(['Mojolicious rocks']);

    $self->exception_format('txt') unless 'development' eq $self->mode;

    # Routes
    my $r = $self->routes;
    $r->namespaces(['OpenXPKI::Client::Web']); # Mojolicious defaults is OpenXPKI::Client::Web::Controller::*
    $self->declare_routes($r);

    # Helpers
    $self->helper(oxi_config => $self->can('helper_oxi_config'));
    $self->helper(oxi_client => $self->can('helper_oxi_client'));

    # Mojolicious server start hook
    $self->hook(before_server_start => sub ($server, $app) {
        $self->log->debug(sprintf "Start OpenXPKI HTTP server in '%s' mode: pid = %s", $self->mode, $$);

        my $close_connection = sub {
            $self->log->debug("Stop OpenXPKI HTTP server: pid = $$");
            $app->oxi_client->close_connection if $app->oxi_client(skip_creation => 1);
        };

        if ($server->isa('Mojo::Server::Prefork')) {
            $server->on(finish => $close_connection);
        }

        elsif ($server->isa('Mojo::Server::Daemon')) {
            # this does currently not work
            # (it was proposed by a Mojolicious developer in 2018:
            # https://github.com/mojolicious/mojo/issues/1255#issuecomment-417866464)
            $server->ioloop->on(finish => $close_connection);
        }
    });


    # Change scheme if "X-Forwarded-HTTPS" header is set
    $self->hook(before_dispatch => sub ($c) {
        $self->log->trace(sprintf 'Incoming %s request', uc($c->req->url->base->protocol)); # ->protocol: Normalized version of ->scheme

        $self->log->error("Missing header X-OpenXPKI-Apache-ENVSET - Apache setup seems to be incomplete")
            unless $c->req->headers->header('X-OpenXPKI-Apache-ENVSET');

        # Inject forwarded Apache ENV into Mojo::Request
        my $headers = $c->req->headers->to_hash;
        my $apache_env = {};
        for my $header (sort keys $headers->%*) {
            if (my ($key) = $header =~ /^X-OpenXPKI-Apache-ENV-(.*)/) {
                my $val = url_unescape($headers->{$header});
                $apache_env->{$key} = $val;
                $self->log->trace("Apache ENV variable received via header: $key");
            }
        }
        $c->stash(apache_env => $apache_env);

        # Inject forwarded query parameters into Mojo::Request.
        # NOTE:
        # We need this workaround because Apache cannot forward the
        # QUERY_STRING to the backend server. The "proxy_pass" documentation
        # which is also valid for "RewriteRule ... url [p]" says: "url is a
        # partial URL for the remote server and cannot include a query string."
        # (https://httpd.apache.org/docs/2.4/mod/mod_proxy.html#proxypass)
        if (my $query_escaped = $c->req->headers->header('X-OpenXPKI-Apache-QueryString')) {
            my $query = url_unescape($query_escaped);
            $c->req->url->query($query);
            $self->log->trace("Apache QUERY_STRING received via header: $query");
        }

        if ($self->mode eq 'development') {
            $self->log->trace('Development mode: enforcing HTTPS');
            $c->req->url->base->scheme('https');
        }
    });

    # Move first part and slash from path to base path in production mode
    # $self->hook(before_dispatch => sub ($c) {
    #     push @{$c->req->url->base->path->trailing_slash(1)},
    #         shift @{$c->req->url->path->leading_slash(0)};
    # ) if $self->mode eq 'production';
}

sub helper_oxi_config ($self, $service) {
    state $configs = {}; # cache config object accross requests

    die "No service specified in call to helper 'oxi_config'" unless $service;

    unless ($configs->{$service}) {
        $self->log->debug("Load configuration for service '$service'");
        $configs->{$service} = OpenXPKI::Client::Config->new($service);
    }

    return $configs->{$service};
}

signature_for helper_oxi_client => (
    method => 1,
    named => [
        skip_creation => 'Bool', { default => 0 },
    ],
);
sub helper_oxi_client ($self, $arg) {
    state $client; # cache client accross requests

    if ($client and not $client->is_connected) {
        $client = undef;
    }

    unless ($client or $arg->skip_creation) {
        try {
            $client = OpenXPKI::Client->new({
                SOCKETFILE => $socketfile,
            });
            $client->init_session;
            $self->log->debug("Got new client: " . $client->session_id);
        }
        catch ($err) {
            $client = undef;
            $self->log->error("Unable to bootstrap client: $err");
        }
    }

    return $client;
}

1;
