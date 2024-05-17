package OpenXPKI::Client::API::Command::token::list;
use OpenXPKI -plugin;

with 'OpenXPKI::Client::API::Command::token';
set_namespace_to_parent;
__PACKAGE__->needs_realm;

=head1 NAME

OpenXPKI::Client::API::Command::token::status

=head1 SYNOPSIS

Show information about the active crypto tokens in a realm.

=cut

command "list" => {
    type => { isa => 'Str', 'label' => 'Token type (e.g. certsign)', hint => 'hint_type' },
} => sub ($self, $param) {

    my $groups = $self->rawapi->run_command('list_token_groups');
    my $res = { token_types => $groups->params, token_groups => {} };

    my @names = values %{$groups->params};
    if ($param->type) {
        @names = ( $groups->param($param->type) );
    }

    foreach my $group (@names) {
        my $entries = $self->rawapi->run_command('list_active_aliases', { group => $group });
        my $grp = {
            count => (scalar @{$entries->result}),
            active => $entries->result->[0]->{alias},
            token => [],
        };
        foreach my $entry (@{$entries->result}) {
            my $token = $self->rawapi->run_command('get_token_info', { alias => $entry->{alias} });
            delete $token->params->{key_cert};
            push @{$grp->{token}}, $token->params;
        }
        $res->{token_groups}->{$group} = $grp;
    }
    return $res;
};

__PACKAGE__->meta->make_immutable;
