use strictures 1;

package App::GPAudio::Controller::Files;
use Object::Glib;
use Path::Tiny;
use App::GPAudio::Model::Library::Columns qw( :all );
use App::GPAudio::Util qw( readable_expanded_length );
use curry::weak;

use namespace::clean;

extends 'GMVC::Controller';

property rescan_bar => (
    type => 'Object',
    class => 'Gtk2::InfoBar',
    required => 1,
    handles => {
        _show_rescan_bar => 'show_all',
        _hide_rescan_bar => 'hide',
    },
);

property rescan_label => (
    type => 'Object',
    class => 'Gtk2::Label',
    required => 1,
    handles => {
        _set_rescan_label => 'set_label',
    },
);

property library_model => (
    type => 'Object',
    class => 'App::GPAudio::Model::Library',
    required => 1,
    handles => {
        _scan_paths => 'scan',
        _cancel_scan => 'cancel_scan',
        _when_scan_starts => ['signal_connect', 'scan_started'],
        _when_scan_ends => ['signal_connect', 'scan_ended'],
        _summarize => 'summarize',
        _get_file_object => 'get_file_object',
    },
);

property library_filter => (
    type => 'Object',
    class => 'Gtk2::TreeModelFilter',
    required => 1,
    handles => {
        _set_filter_func => 'set_visible_func',
        _refilter => 'refilter',
    },
);

property sources_model => (
    type => 'Object',
    class => 'App::GPAudio::Model::Sources',
    required => 1,
    handles => {
        _get_source_paths => 'get_paths',
    },
);

property search_text => (
    is => 'rpwp',
    init_arg => undef,
);

property summary_label => (
    type => 'Object',
    class => 'Gtk2::Label',
    required => 1,
    handles => {
        _set_summary_label => 'set_label',
    },
);

property library_view => (
    type => 'Object',
    class => 'Gtk2::TreeView',
    required => 1,
    handles => {
        _get_view_model => 'get_model',
        _get_view_selection => 'get_selection',
    },
);

property properties_dialog_builder => (
    type => 'Code',
    required => 1,
    handles => {
        _create_properties_dialog => 'execute',
    },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->_hide_rescan_bar;
    $self->_set_filter_func($self->curry::weak::_filter_files);
    $self->_when_scan_starts($self->curry::weak::on_scan_start);
    $self->_when_scan_ends($self->curry::weak::on_scan_end);
    $self->_set_rescan_label('Scanning...');
    $self->_recalc_summary;
}

sub on_properties {
    my ($self) = @_;
    my $selection = $self->_get_view_selection;
    my $model = $self->_get_view_model;
    my @files = map {
        my $path = $_;
        my $iter = $model->get_iter($path);
        $self->_get_file_object($model->get($iter, LIBRARY_ID));
    } $selection->get_selected_rows;
    my $dialog = $self->_create_properties_dialog(files => \@files);
    $dialog->show_all;
    my $response = $dialog->run;
    $dialog->destroy;
    return undef;
}

sub _recalc_summary {
    my ($self) = @_;
    my ($count, $length) = $self->_summarize;
    $self->_set_summary_label(join ' / ',
        sprintf('%s track%s', $count, $count == 1 ? '' : 's'),
        readable_expanded_length($length),
    );
    return 1;
}

sub _filter_files {
    my ($self, $model, $iter) = @_;
    my $search = $self->_get_search_text;
    return 1
        unless length $search;
    my $text = $model->get($iter, LIBRARY_SEARCH);
    my $show = $text =~ m{\Q$search\E}i;
    return $show;
}

sub _clear_search {
    my ($self, $entry) = @_;
    $entry->get_buffer->set(text => '');
    $self->_set_search_text('');
    $self->_refilter;
    return 1;
}

sub on_clear_search {
    my ($self, $entry) = @_;
    $self->_clear_search($entry);
    return undef;
}

sub on_search_key_press {
    my ($self, $entry, $ev) = @_;
    if (lc(Gtk2::Gdk->keyval_name($ev->keyval)) eq 'escape') {
        $self->_clear_search($entry);
    }
    return undef;
}

sub on_search {
    my ($self, $buffer) = @_;
    my $search = $buffer->get('text');
    $self->_set_search_text($search);
    $self->_refilter;
    return undef;
}

sub on_drag_get {
    my ($self, $view, $context, $drag_select) = @_;
    my $tree_select = $view->get_selection;
    my $model = $view->get_model;
    my @paths = $tree_select->get_selected_rows;
    my $pack = join(':', 'add', map {
        my $iter = $model->get_iter($_);
        $model->get($iter, LIBRARY_ID);
    } @paths);
    #my ($model, $iter) = $tree_select->get_selected;
    $drag_select->set($drag_select->get_target, 8, $pack);
    return $drag_select;
}

sub on_rescan {
    my ($self) = @_;
    my @paths = $self->_get_source_paths;
    my @path_iters = map { path($_)->iterator({ recurse => 1 }) } @paths;
    my $iterator = sub {
        return undef
            unless @path_iters;
        my $next = $path_iters[0]->();
        until (defined $next) {
            shift @path_iters;
            return undef
                unless @path_iters;
            $next = $path_iters[0]->();
        }
        if (defined $next and not $next->is_dir) {
            $self->_set_rescan_label(
                sprintf('Scanning %s...', $next->parent),
            );
        }
        return $next;
    };
    $self->_scan_paths($iterator);
    return undef;
}

sub on_scan_end {
    my ($self) = @_;
    $self->_hide_rescan_bar;
    $self->_set_rescan_label('Scanning...');
    $self->_recalc_summary;
    return undef;
}

sub on_scan_start {
    my ($self) = @_;
    $self->_show_rescan_bar;
    return undef;
}

sub on_cancel_rescan {
    my ($self) = @_;
    $self->_cancel_scan;
    return undef;
}

register;
