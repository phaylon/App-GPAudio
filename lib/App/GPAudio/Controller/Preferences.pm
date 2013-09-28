use strictures 1;

package App::GPAudio::Controller::Preferences;
use Object::Glib;

use namespace::clean;

extends 'GMVC::Controller';

property window_builder => (
    type => 'Code',
    required => 1,
    handles => {
        _create_window => 'execute',
    },
);

property source_chooser_builder => (
    type => 'Code',
    required => 1,
    handles => {
        _create_source_chooser => 'execute',
    },
);

property current_window => (
    is => 'rpwp',
    clearer => 1,
    init_arg => undef,
);

property sources_model => (
    type => 'Object',
    class => 'App::GPAudio::Model::Sources',
    required => 1,
    handles => {
        _add_source => 'add_source',
        _remove_source => 'remove_source',
    },
);

property selected_source => (
    is => 'rpwp',
    clearer => 1,
    init_arg => undef,
);

property sensitivity_model => (
    type => 'Object',
    class => 'App::GPAudio::Model::Sensitivity',
    required => 1,
    handles => {
        _set_source_selected => 'set_source_selected',
    },
);

after _set_selected_source => sub {
    my ($self) = @_;
    $self->_set_source_selected(1);
};

after _clear_selected_source => sub {
    my ($self) = @_;
    $self->_set_source_selected(0);
};

sub on_show {
    my ($self) = @_;
    my $window = $self->_create_window;
    $window->show_all;
    $self->_set_current_window($window);
    my $response = $window->run;
    $self->_clear_current_window;
    $window->destroy;
    return undef;
}

sub on_source_remove {
    my ($self) = @_;
    my $selected = $self->_get_selected_source;
    $self->_remove_source($selected);
    return undef;
}

sub on_source_add {
    my ($self) = @_;
    my $dialog = $self->_create_source_chooser(
        parent_window => $self->_get_current_window,
    );
    $dialog->show_all;
    my $response = $dialog->run;
    my $path = $dialog->get_filename;
    $self->_add_source($path)
        if $response eq 'ok';
    $dialog->destroy;
    return undef;
}

sub on_source_select {
    my ($self, $selection) = @_;
    if ($selection->count_selected_rows) {
        my ($model, $iter) = $selection->get_selected;
        my $path = $model->get($iter, 0);
        $self->_set_selected_source($path);
    }
    else {
        $self->_clear_selected_source;
    }
    return undef;
}

register;
