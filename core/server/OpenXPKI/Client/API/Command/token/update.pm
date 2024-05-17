package OpenXPKI::Client::API::Command::token::update;
use OpenXPKI -plugin;

with 'OpenXPKI::Client::API::Command::token';
set_namespace_to_parent;
__PACKAGE__->needs_realm;
with 'OpenXPKI::Client::API::Command::Protected';

use OpenXPKI::Serialization::Simple;

=head1 NAME

OpenXPKI::Client::API::Command::token::add

=head1 SYNOPSIS

Add a new generation of a crytographic token.

=cut

sub hint_type ($self, $input_params) {
    my $groups = $self->rawapi->run_command('list_token_groups');
    return [ keys %{$groups->params} ];
}

command "update" => {
    alias => { isa => 'Str', 'label' => 'Alias', hint => 'hint_type', required => 1, trigger => \&check_alias  },
    key => { isa => 'FileContents', label => 'Key file (new)' },
    key_update => { isa => 'FileContents', label => 'Key file (update)' },
    notbefore => { isa => 'Epoch', label => 'Validity override (notbefore)' },
    notafter => { isa => 'Epoch', label => 'Validity override (notafter)' },
} => sub ($self, $param) {

    my $alias = $param->alias;
    my $cmd_param = {
        alias => $alias,
    };
    foreach my $key (qw( notbefore notafter )) {
        my $predicate = "has_$key";
        $cmd_param->{$key} = $param->$key if $param->$predicate;
    }

    my $res;
    if ((scalar keys %$param) > 1) {
        $res = $self->rawapi->run_protected_command('update_alias', $cmd_param );
        $self->log->debug("Alias '$alias' was updated");
    } else {
        $res = $self->rawapi->run_command('show_alias', $cmd_param );
        die "Alias '$alias' not found" unless $res;
    }

    # update the key - the handle_key method will die if the alias is not a token
    if ($param->key) {
        my $token = $self->handle_key($alias, $param->key);
        $self->log->debug("Key for '$alias' was added");
        $res->params->{key_name} = $token->param('key_name');
    # set force for update mode (overwrites exising key)
    } elsif ($param->key_update) {
        my $token = $self->handle_key($alias, $param->key_update, 1);
        $self->log->debug("Key for '$alias' was updated");
        $res->params->{key_name} = $token->param('key_name');
    }

    return $res;
};

__PACKAGE__->meta->make_immutable;
