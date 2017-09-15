package OpenXPKI::Server::API2::Command;
=head1 Name

OpenXPKI::Server::API2::Command

=cut

# CPAN modules
use Moose;
use Moose::Exporter;

# Project modules
use OpenXPKI::Server::API2::CommandMetaClass;

#
# Exports (imported when calling "use OpenXPKI::Server::API2::Command;")
#
Moose::Exporter->setup_import_methods(
    with_meta => [ "param", "api" ],
    also => "Moose",
);

# Moose::Exporter will call init_meta() when the IMPORT function is called.
# $args{for_class} contains the metaclass of the class that imports us.
sub init_meta {
    shift; # our class name
    my %args = @_;

    Moose->init_meta(%args);
    my $importing_class_meta = $args{for_class}->meta;

    # We modify the class that imports us:
    # 1. plant a new parent class into
    $importing_class_meta->superclasses("OpenXPKI::Server::API2::CommandBase");
    # 2. change the classes' metaclass to be able to use the api_param_classes() HashRef
    OpenXPKI::Server::API2::CommandMetaClass->meta->rebless_instance($importing_class_meta);

    return $importing_class_meta;
}

sub param {
    my ($meta, $name, %spec) = @_;

    if ($spec{matching}) {
        # FIXME Implement
        delete $spec{matching};
    }

    $meta->add_attribute($name,
        is => 'ro',
        %spec,
    );
}

sub api {
    my ($meta, $method_name, $params, $code_ref) = @_;

    $meta->add_method($method_name => $code_ref);

    my $param_metaclass = Moose::Meta::Class->create(
        join("::", $meta->name, "${method_name}_ParamObject"),
#        superclasses => ,
#        roles => ,
#        cache => 1,
    );

    for my $param_name (sort keys %{ $params }) {
        # the parameter specs like "isa => ..., required => ..."
        my $param_spec = $params->{$param_name};
        if ($param_spec->{matching}) {
            # FIXME Implement
            delete $param_spec->{matching};
        }
        # add a Moose attribute to the parameter container class
        $param_metaclass->add_attribute($param_name,
            is => 'ro',
            %{ $param_spec },
        );
    }

    $meta->api_param_classes->{$method_name} = $param_metaclass;
}

1;
