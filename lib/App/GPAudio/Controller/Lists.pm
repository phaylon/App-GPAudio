use strictures 1;

package App::GPAudio::Controller::Lists;
use Object::Glib;
use App::GPAudio::Model::Playlist::Columns qw( :all );
use App::GPAudio::Util qw( readable_expanded_length );

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
        _rename_list => 'rename_playlist',
    },
);

property remove_dialog_builder => (
    type => 'Code',
    required => 1,
    handles => {
        _create_remove_dialog => 'execute',
    },
);

property properties_dialog_builder => (
    type => 'Code',
    required => 1,
    handles => {
        _create_properties_dialog => 'execute',
    },
);

property name_dialog_builder => (
    type => 'Code',
    required => 1,
    handles => {
        _create_name_dialog => 'execute',
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
        _has_active_playlist => 'has_value',
    },
);

property playlist_view => (
    type => 'Object',
    class => 'Gtk2::TreeView',
    required => 1,
    handles => {
        _get_view_model => 'get_model',
        _get_view_selection => 'get_selection',
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

property sensitivity_model => (
    type => 'Object',
    class => 'App::GPAudio::Model::Sensitivity',
    required => 1,
    handles => {
        _set_item_count => 'set_item_count',
    },
);

property summary_label => (
    type => 'Object',
    class => 'Gtk2::Label',
    required => 1,
    handles => {
        _set_summary_label => 'set_label',
    },
);

sub _recalc_summary {
    my ($self) = @_;
    if (my $list = $self->_get_active_playlist) {
        my ($count, $length) = $list->summarize;
        $self->_set_summary_label(join ' / ',
            sprintf('%s track%s', $count, $count == 1 ? '' : 's'),
            readable_expanded_length($length),
        );
    }
    else {
        $self->_set_summary_label('');
    }
    return 1;
}

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
    $self->_set_item_count($list->iter_n_children);
    $self->_recalc_summary;
    return undef;
}

sub on_key_press {
    my ($self, $view, $ev) = @_;
    my $key = Gtk2::Gdk->keyval_name($ev->keyval);
    if (lc($key) eq 'delete') {
        my $model = $self->_get_view_model;
        my $list = $self->_get_active_playlist;
        if ($list and $model) {
            my $selection = $self->_get_view_selection;
            my @paths = $selection->get_selected_rows
                or return undef;
            my @ids = map {
                $model->get($model->get_iter($_), PLAYLIST_ID);
            } @paths;
            my ($before) = map { $_ - 1 } $paths[0]->get_indices;
            my ($after) = $paths[0]->get_indices;
            $self->_txn(sub {
                $list->remove_files(@ids);
            });
            INDEX: for my $index ($after, $before) {
                if ($index >= 0 and $index < $model->iter_n_children) {
                    my $path = Gtk2::TreePath->new_from_indices($index);
                    $selection->select_path($path);
                    last INDEX;
                }
            }
            $self->_set_item_count($list->iter_n_children);
            $self->_recalc_summary;
        }
    }
    return undef;
}

sub on_select {
    my ($self, $combo) = @_;
    my $iter = $combo->get_active_iter;
    if ($iter) {
        my $list = $self->_get_list($iter);
        $self->_set_active_playlist($list);
        $self->_set_item_count($list->iter_n_children);
    }
    else {
        $self->_set_active_playlist(undef);
        $self->_set_item_count(0);
    }
    $self->_recalc_summary;
    return undef;
}

sub on_properties {
    my ($self) = @_;
    my $selection = $self->_get_view_selection;
    my $model = $self->_get_view_model;
    my $list = $self->_get_active_playlist;
    my @files = map {
        my $path = $_;
        my $iter = $model->get_iter($path);
        $list->get_file_object($model->get($iter, PLAYLIST_ID));
    } $selection->get_selected_rows;
    my $dialog = $self->_create_properties_dialog(files => \@files);
    $dialog->show_all;
    my $response = $dialog->run;
    $dialog->destroy;
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

sub on_rename {
    my ($self) = @_;
    my $list = $self->_get_active_playlist;
    my $current = $list->get_title;
    my $view = $self->_create_name_dialog(
        dialog_title => qq{Rename '$current' Playlist},
    );
    my $dialog = $view->get_root;
    my $entry = $view->get_widget('entry');
    $dialog->show_all;
    $entry->set(text => $current);
    $entry->grab_focus;
    my $response = $dialog->run;
    my $title = $entry->get('text');
    if ($response eq 'ok' and length $title) {
        $self->_rename_list($list->get_id, $title);
        $list->set_title($title);
    }
    $dialog->destroy;
    return undef;
}

sub on_add {
    my ($self) = @_;
    my $view = $self->_create_name_dialog(
        dialog_title => 'Add Playlist',
    );
    my $dialog = $view->get_root;
    my $entry = $view->get_widget('entry');
    $dialog->show_all;
    $entry->grab_focus;
    my $response = $dialog->run;
    my $title = $entry->get('text');
    if ($response eq 'ok' and length $title) {
        my $iter = $self->_add_list($title);
        $self->_set_selected_playlist($iter);
    }
    $dialog->destroy;
    return undef;
}

register;
