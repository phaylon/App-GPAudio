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
        _maximize_window => 'maximize',
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
    $self->_maximize_window;
}

sub on_toggle_visible {
    my ($self, $widget, $action) = @_;
    if ($action->get('active')) {
        $widget->set(visible => 1);
    }
    else {
        $widget->set(visible => 0);
    }
    return undef;
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
