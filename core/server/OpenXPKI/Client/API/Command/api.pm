package OpenXPKI::Client::API::Command::api;
use OpenXPKI -role;

=head1 NAME

OpenXPKI::CLI::Command::api

=head1 SYNOPSIS

Run commands of the OpenXPKI API

=head1 USAGE

Feed me!

=cut

sub hint_command ($self, $input_params){
    my $actions = $self->rawapi->run_enquiry('command');
    $self->log->trace(Dumper $actions->result) if $self->log->is_trace;
    return $actions->result || [];
}

sub help_command ($self, $command) {
    return $self->rawapi->run_enquiry('command', { command => $command })->params;
}

1;
