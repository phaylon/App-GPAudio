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

property remove_dialog_builder => (
    type => 'Code',
    required => 1,
    handles => {
        _create_remove_dialog => 'execute',
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
        _clear_selected_playlist => ['set', 'active', -1],
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

property schema => (
    type => 'Object',
    class => 'DBIx::Class::Schema',
    required => 1,
    handles => {
        _txn => 'txn_do',
    },
);

sub on_drag_get {
    my ($self, $view, $context, $drag_select) = @_;
    my $tree_select = $view->get_selection;
    my $model = $view->get_model;
    my @paths = $tree_select->get_selected_rows;
    my $pack = join(':', 'reorder',
        (map {
            my $iter = $model->get_iter($_);
            $model->get($iter, PLAYLIST_ID);
        } @paths),
    );
    #my ($model, $iter) = $tree_select->get_selected;
    $drag_select->set($drag_select->get_target, 8, $pack);
    return $drag_select;
}

sub on_drag_received {
    my ($self, $view, $ctx, $x, $y, $drag_select, $etime) = @_;
    my $data = $drag_select->get_data;
    #warn "DATA $data";
    my ($func, @list_ids) = split m{:}, $data;
    my $list = $self->_get_active_playlist;
    my @ids = ($func eq 'reorder')
        ? $list->resolve_file_ids(@list_ids)
        : @list_ids;
    my ($path, $position) = $view->get_dest_row_at_pos($x, $y);
    $self->_txn(sub {
        if (defined $position) {
            my $model = $view->get_model;
            my $iter = $model->get_iter($path);
            my $pos = $model->get($iter, PLAYLIST_POSITION);
            $pos++
                if $position eq 'after'
                or $position eq 'into-or-after';
            $list->add_files($pos, @ids);
        }
        else {
            $list->add_files(undef, @ids);
        }
        if ($func eq 'reorder') {
            $list->remove_files(@list_ids);
        }
    });
    $ctx->finish(1, 0, $etime);
    return undef;
}

sub on_select {
    my ($self, $combo) = @_;
    my $iter = $combo->get_active_iter;
    if ($iter) {
        my $list = $self->_get_list($iter);
        $self->_set_active_playlist($list);
    }
    else {
        $self->_set_active_playlist(undef);
    }
    return undef;
}

sub on_remove {
    my ($self) = @_;
    my $list = $self->_get_active_playlist;
    my $dialog = $self->_create_remove_dialog(name => $list->get_title);
    $dialog->show_all;
    my $response = $dialog->run;
    if ($response eq 'yes') {
        $self->_clear_selected_playlist;
        $self->_remove_list($list->get_id);
    }
    $dialog->destroy;
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
