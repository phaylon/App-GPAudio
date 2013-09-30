use strictures 1;

package App::GPAudio::Controller::WithStatus;
use Object::Glib::Role;

use namespace::clean;

property status_bar => (
    type => 'Object',
    class => 'Gtk2::Statusbar',
    required => 1,
    handles => {
        _push_status => 'push',
        _remove_status => 'remove',
        get_status_context_id => 'get_context_id',
    },
);

property display_context => (
    is => 'rpo',
    lazy => 1,
    builder => sub {
        my ($self) = @_;
        return $self->get_status_context_id('display context');
    },
);

sub display_status {
    my ($self, $seconds, $message) = @_;
    my $ctx = $self->_get_display_context;
    my $id = $self->_push_status($ctx, $message);
    Glib::Timeout->add_seconds($seconds, sub {
        $self->_remove_status($ctx, $id);
        return undef;
    });
    return 1;
}

1;
