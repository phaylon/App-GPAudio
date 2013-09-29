use strictures 1;

package App::GPAudio::Model::Player;
use Object::Glib;
use GStreamer-init;
use GStreamer::Interfaces;

use namespace::clean;

property state => (
    is => 'rwp',
    init_arg => undef,
    on_set => '_on_state_change',
);

property playbin => (
    type => 'Object',
    init_arg => undef,
    lazy => 1,
    builder => sub {
        my ($self) = @_;
        return GStreamer::ElementFactory->make(playbin => 'play');
    },
    handles => {
        _set_playbin_state => 'set_state',
    },
);

sub _on_state_change {
    my ($self) = @_;
    $self->_set_playbin_state($self->get_state);
    return 1;
}

register;
