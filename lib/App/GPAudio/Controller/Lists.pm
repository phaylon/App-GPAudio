use strictures 1;

package App::GPAudio::Controller::Lists;
use Object::Glib;
use App::GPAudio::Model::Playlist::Columns qw( :all );

use namespace::clean;

extends 'GMVC::Controller';

property playlist_manager => (
    type => 'Object',
    class => 'App::GPAudio::Model::PlaylistManager',
    required => 1,
    handles => {
        _add_list => 'add_playlist',
        _remove_list => 'remove_playlist',
        _get_list => 'get_playlist',
    },
);

property add_dialog_builder => (
    type => 'Code',
    required => 1,
    handles => {
        _create_add_dialog => 'execute',
    },
);

property playlist_selection => (
    type => 'Object',
    class => 'Gtk2::ComboBox',
    required => 1,
    handles => {
        _set_selected_playlist => 'set_active_iter',
    },
);

property active_playlist => (
    type => 'Object',
    class => 'App::GPAudio::Model::Bin',
    required => 1,
    handles => {
        _set_active_playlist => 'set_value',
        _get_active_playlist => 'get_value',
    },
);

sub on_drag_received {
    my ($self, $view, $ctx, $x, $y, $drag_select, $etime) = @_;
    my $data = $drag_select->get_data;
    #warn "DATA $data";
    my @ids = split m{:}, $data;
    my $list = $self->_get_active_playlist;
    my ($path, $position) = $view->get_dest_row_at_pos($x, $y);
    if (defined $position) {
        my $model = $view->get_model;
        my $iter = $model->get_iter($path);
        my $pos = $model->get($iter, PLAYLIST_POSITION);
        #warn "POS $position AT $pos";
        $pos++
            if $position eq 'after'
            or $position eq 'into-or-after';
        $list->add_files($pos, @ids);
    }
    else {
        $list->add_files(undef, @ids);
    }
    $ctx->finish(1, 0, $etime);
    return undef;
}

sub on_select {
    my ($self, $combo) = @_;
    my $iter = $combo->get_active_iter;
    my $list = $self->_get_list($iter);
    $self->_set_active_playlist($list);
    return undef;
}

sub on_add {
    my ($self) = @_;
    my $view = $self->_create_add_dialog;
    my $dialog = $view->get_root;
    my $entry = $view->get_widget('entry');
    $dialog->show_all;
    $entry->grab_focus;
    my $response = $dialog->run;
    my $title = $entry->get('text');
    if ($response eq 'ok') {
        my $iter = $self->_add_list($title);
        $self->_set_selected_playlist($iter);
    }
    $dialog->destroy;
    return undef;
}

register;
