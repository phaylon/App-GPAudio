use strictures 1;

package App::GPAudio::Controller::Selection;
use Object::Glib;

use namespace::clean;

extends 'GMVC::Controller';

property last_click_position => (
    is => 'rpwp',
    init_arg => undef,
    clearer => 1,
    predicate => 1,
);

property ui_manager => (
    type => 'Object',
    class => 'Gtk2::UIManager',
    required => 1,
    handles => {
        _get_ui_widget => 'get_widget',
    },
);

property popup_name => (
    is => 'rpo',
    required => 1,
);

property count_model => (
    type => 'Object',
    class => 'App::GPAudio::Model::Bin',
    required => 1,
    handles => {
        _set_count => 'set_value',
    },
);

sub _show_popup {
    my ($self, $ev) = @_;
    my $popup = $self->_get_ui_widget($self->_get_popup_name);
    $popup->popup((undef) x 4, $ev->button, $ev->time);
    return 1;
}

sub on_allow_select {
    my ($self) = @_;
    return $self->_has_last_click_position ? 0 : 1;
}

sub on_select {
    my ($self, $selection) = @_;
    $self->_set_count($selection->count_selected_rows);
    return undef;
}

sub on_click {
    my ($self, $view, $ev) = @_;
    $self->_clear_last_click_position;
    my $path = $view->get_path_at_pos($ev->x, $ev->y);
    my $selection = $view->get_selection;
    if ($ev->button == 3) {
        if ($path and not $selection->path_is_selected($path)) {
            $selection->unselect_all;
            $selection->select_path($path);
        }
        $self->_show_popup($ev);
        return 1;
    }
    elsif ($ev->button == 1) {
        return undef
            unless defined $path;
        return undef
            unless $path and $selection->path_is_selected($path);
        $self->_set_last_click_position([$ev->x, $ev->y]);
    }
    return undef;
}

sub on_click_end {
    my ($self, $view, $ev) = @_;
    my $path = $view->get_path_at_pos($ev->x, $ev->y);
    my $selection = $view->get_selection;
    if ($ev->button == 1) {
        return undef
            unless defined $path;
        if ($self->_has_last_click_position) {
            my ($x, $y) = @{ $self->_get_last_click_position };
            if ($ev->x eq $x and $ev->y eq $y) {
                $self->_clear_last_click_position;
                $selection->unselect_all;
                $selection->select_path($path);
            }
        }
    }
    $self->_clear_last_click_position;
    return undef;
}

register;
