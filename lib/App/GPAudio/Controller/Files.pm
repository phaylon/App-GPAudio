use strictures 1;

package App::GPAudio::Controller::Files;
use Object::Glib;
use Path::Tiny;
use App::GPAudio::Model::Library::Columns qw( :all );
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
        _when_scan_starts => ['signal_connect', 'scan_started'],
        _when_scan_ends => ['signal_connect', 'scan_ended'],
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

property last_click_position => (
    is => 'rpwp',
    init_arg => undef,
    clearer => 1,
    predicate => 1,
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->_hide_rescan_bar;
    $self->_when_scan_starts($self->curry::weak::on_scan_start);
    $self->_when_scan_ends($self->curry::weak::on_scan_end);
    $self->_set_rescan_label('Scanning...');
}

sub on_drag_get {
    my ($self, $view, $context, $drag_select) = @_;
    my $tree_select = $view->get_selection;
    my $model = $view->get_model;
    my @paths = $tree_select->get_selected_rows;
    my $pack = join(':', map {
        my $iter = $model->get_iter($_);
        $model->get($iter, LIBRARY_ID);
    } @paths);
    #my ($model, $iter) = $tree_select->get_selected;
    $drag_select->set($drag_select->get_target, 8, $pack);
    return $drag_select;
}

sub on_allow_select {
    my ($self) = @_;
    return $self->_has_last_click_position ? 0 : 1;
}

sub on_click {
    my ($self, $view, $ev) = @_;
    $self->_clear_last_click_position;
    my $path = $view->get_path_at_pos($ev->x, $ev->y);
    my $selection = $view->get_selection;
    if ($ev->button == 3) {
        unless ($selection->path_is_selected($path)) {
            $selection->unselect_all;
            $selection->select_path($path);
        }
        warn "POPUP";
        return 1;
    }
    elsif ($ev->button == 1) {
        return undef
            unless defined $path;
        return undef
            unless $selection->path_is_selected($path);
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
                my $path = $view->get_path_at_pos($x, $y);
                $selection->unselect_all;
                $selection->select_path($path);
            }
            $self->_clear_last_click_position;
        }
    }
    return undef;
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
    return undef;
}

sub on_scan_start {
    my ($self) = @_;
    $self->_show_rescan_bar;
    return undef;
}

sub on_cancel_rescan {
    my ($self) = @_;
    return undef;
}

register;
