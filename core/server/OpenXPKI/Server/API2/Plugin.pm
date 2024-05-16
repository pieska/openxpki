package OpenXPKI::Server::API2::Plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin - Define an OpenXPKI API plugin

=cut

# CPAN modules
use Moose ();
use Moose::Exporter;

# Project modules
use OpenXPKI::Server::API2::PluginRole;
use OpenXPKI::Server::API2::PluginMetaClassTrait;


=head1 DESCRIPTION

To define a new API plugin:

    package OpenXPKI::Server::API2::Plugin::MyTopic::MyActions;
    use OpenXPKI -plugin;

    set_namespace_to_parent;

    command "aaa" => {
        # parameters
    } => sub {
        # actions
        ...
        $self->api->another_command();
        ...
    };

If no namespace is specified in a plugin class the commands are assigned to
the default namespace of the API.

It does not seem to be possible to set a custom base class for your
plugin, but you can instead easily add another role to it:

    package OpenXPKI::Server::API2::Plugin::MyTopic::MyActions;
    use OpenXPKI -plugin;

    with "OpenXPKI::Server::API2::Plugin::MyTopic::Base";

C<use OpenXPKI -plugin> will modify your package as follows:

=over

=item * adds C<use Moose;>

=item * provides the L</command> keyword to define API commands

=item * applies the Moose role L<OpenXPKI::Server::API2::PluginRole>

=item * applies the Moose metaclass role (aka. "trait")
L<OpenXPKI::Server::API2::PluginMetaClassTrait>

=back

=cut
Moose::Exporter->setup_import_methods(
    with_meta => [ 'command', 'protected_command', 'set_namespace', 'set_namespace_to_parent' ],
    base_class_roles => [ 'OpenXPKI::Server::API2::PluginRole' ],
    class_metaroles => {
        class => [ 'OpenXPKI::Server::API2::PluginMetaClassTrait' ],
    },
);


=head1 KEYWORDS (imported functions)

The following functions are imported into the package that uses
C<OpenXPKI::Server::API2::Plugin>.

=head2 command

Define an API command including input parameter types.

Example:

    command 'givetheparams' => {
        name => { isa => 'Str', matching => qr/^(?!Donald).*/, required => 1 },
        size => { isa => 'Int', matching => sub { $_ > 0 } },
    } => sub {
        my ($self, $po) = @_;

        $po->name("The genious ".$po->name) if $po->has_name;

        if ($po->has_size) {
            $self->some_helper($po->size);
            $po->clear_size; # unset the attribute
        }

        $self->process($po);
    };

Note that this can be written as (except for the dots obviously)

    command(
        'givetheparams',
        {
            name => ...
            size => ...
        },
        sub {
            my ($self, $po) = @_;
            return { ... };
        }
    );

You can access the API via C<$self-E<gt>api> to call another command.

B<Parameters>

=over

=item * C<$command> - name of the API command

=item * C<$params> - I<HashRef> containing the parameter specifications. Keys
are the parameter names and values are I<HashRefs> with options.

Allows the same options as Moose's I<has> keyword (i.e. I<isa>, I<required> etc.)
plus the following ones:

=over

=item * C<matching> - I<Regexp> or I<CodeRef> that matches if
L<TRUE|perldata/"Scalar values"> value is returned.

=back

You can use all Moose types (I<Str>, I<Int> etc) plus OpenXPKI's own types
defined in L<OpenXPKI::Types> (C<OpenXPKI::Server::API2>
automatically imports them).

=item * C<$code_ref> - I<CodeRef> with the command implementation. On invocation
it gets passed two parameters:

=over

=item * C<$self> - the instance of the command class (that called C<api>).

=item * C<$po> - a parameter data object with Moose attributes that follow
the specifications in I<$params> above.

For each attribute two additional methods are available on the C<$po>:
A clearer named C<clear_*> to clear the attribute and a predicate C<has_*> to
test if it's set. See L<Moose::Manual::Attributes/Predicate and clearer methods>
if you don't know what that means.

=back

=back

=cut
sub command {
    my ($meta, $command, $params, $code_ref) = @_;

    _command($meta, $command, $params, $code_ref, 0);
}

=head2 protected_command

Define a protected API command. All parameters are equivalent to L</command>.

Commands are only protected if L<OpenXPKI::Server::API2/enable_protection> is
set to TRUE. In this case they can only be called by passing
C<protected_call =E<gt> 1> to L<OpenXPKI::Server::API2/dispatch>.


=cut
sub protected_command {
    my ($meta, $command, $params, $code_ref) = @_;

    _command($meta, $command, $params, $code_ref, 1);
}

#
sub _command {
    my ($meta, $command, $params, $code_ref, $is_protected) = @_;

    $meta->add_method($command, $code_ref);    # Add a method to calling class
    $meta->add_param_specs($command, $params); # Add a parameter class (OpenXPKI::Server::API2::PluginMetaClassTrait)
    $meta->is_protected($command, $is_protected);    # Set protection flag (OpenXPKI::Server::API2::PluginMetaClassTrait)
}

=head2 set_namespace_to_parent

Set the command namespace to the current classes parent namespace
(default is the API's root namespace).

    package OpenXPKI::Server::API2::Plugin::MyTopic::info;

    set_namespace_to_parent;
    # is the same as:
    set_namespace 'OpenXPKI::Server::API2::Plugin::MyTopic';

=cut
sub set_namespace_to_parent {
    my ($meta) = @_;

    my $caller_package = caller(1);

    my @parts = split '::', $caller_package;
    pop @parts;

    $meta->namespace(join '::', @parts);
}

=head2 set_namespace

Set the command namespace (default is the API's root namespace).

Must be specified as a full Perl package name.

=cut
sub set_namespace :prototype($) {
    my ($meta, $namespace) = @_;

    $meta->namespace($namespace);
}

1;