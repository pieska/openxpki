package OpenXPKI::Client::UI::Response::Section::Form;

use Moose;

with 'OpenXPKI::Client::UI::Response::SectionRole';


has 'action' => (
    is => 'rw',
    isa => 'Str',
);

has 'reset' => (
    is => 'rw',
    isa => 'Str',
);

has 'submit_label' => (
    is => 'rw',
    isa => 'Str',
    documentation => 'content/',
);

has 'reset_label' => (
    is => 'rw',
    isa => 'Str',
    documentation => 'content/',
);

has '_fields' => (
    is => 'rw',
    isa => 'ArrayRef[HashRef]',
    traits => [ 'Array' ],
    handles => {
        _add_field => 'push',
    },
    default => sub { [] },
    documentation => 'content/fields',
);

sub BUILD {
    my $self = shift;
    $self->type('form');
}

sub is_set { shift->has_any_value }

sub add_field {
    my $self = shift;
    $self->_add_field({ @_ });
    return $self; # allows method chaining
}

__PACKAGE__->meta->make_immutable;
