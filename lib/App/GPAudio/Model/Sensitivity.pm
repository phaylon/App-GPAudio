use strictures 1;

package App::GPAudio::Model::Sensitivity;
use Object::Glib;

use namespace::clean;

my @_names = qw(
    source_sensitivity
);

for my $name (@_names) {
    property $name => (
        type => 'Object',
        class => 'App::GPAudio::Model::Bin',
        required => 1,
        handles => {
            "_get_$name" => 'get_value',
            "_set_$name" => 'set_value',
        },
    );
}

property source_selected => (
    is => 'rw',
    on_set => '_update_source_sensitivity',
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->_update_source_sensitivity;
}

sub _update_source_sensitivity {
    my ($self) = @_;
    $self->_set_source_sensitivity($self->get_source_selected);
    return 1;
}

register;
