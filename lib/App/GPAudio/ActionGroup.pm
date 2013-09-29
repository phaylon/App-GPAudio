use strictures 1;

package App::GPAudio::ActionGroup;
use Object::Glib;

use namespace::clean;

extends ['Gtk2', 'ActionGroup'];

property sensitivity_model => (
    is => 'rpo',
    type => 'Object',
    class => 'App::GPAudio::Model::Bin',
    handles => {
        _when_sensitivity_changes => ['signal_connect', 'notify::value'],
        _get_sensitivity_value => 'get_value',
    },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    if (defined $self->_get_sensitivity_model) {
        $self->_when_sensitivity_changes(sub {
            my ($active, undef, $self) = @_;
            $self->set_sensitive($active->get_value ? 1 : 0);
            return undef;
        }, $self);
        $self->set_sensitive($self->_get_sensitivity_value ? 1 : 0);
    }
}

register;
