use strictures 1;

package App::GPAudio::Controller::Main;
use Object::Glib;

use namespace::clean;

extends 'GMVC::Controller';

property window => (
    type => 'Object',
    class => 'Gtk2::Window',
    required => 1,
    handles => {
        _show_window => 'show_all',
    },
);

property library_pane => (
    type => 'Object',
    class => 'Gtk2::Widget',
    required => 1,
    handles => {
        _show_library => 'show',
        _hide_library => 'hide',
    },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->_show_window;
}

sub on_toggle_library_visible {
    my ($self, $action) = @_;
    if ($action->get('active')) {
        $self->_show_library;
    }
    else {
        $self->_hide_library;
    }
    return undef;
}

sub on_quit {
    my ($self) = @_;
    $self->quit;
    return undef;
}

register;
