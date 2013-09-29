use strictures 1;

package App::GPAudio::Controller::Play;
use Object::Glib;
use App::GPAudio::Model::Playlist::Columns qw( :all );

use namespace::clean;

extends 'GMVC::Controller';

property active_playlist => (
    type => 'Object',
    class => 'App::GPAudio::Model::Bin',
    required => 1,
    handles => {
        _get_active_playlist => 'get_value',
    },
);

property playing_playlist => (
    type => 'Object',
    is => 'rpwp',
    init_arg => undef,
    predicate => 1,
    handles => {
        _mark_as_playing => 'mark_as_playing',
        _get_playlist_value => 'get_by_id',
        _find_random_item => 'get_random',
        _find_next_item => 'get_next',
    },
);

property playing_item => (
    type => 'Object',
    class => 'App::GPAudio::Model::Bin',
    required => 1,
    handles => {
        _get_playing_item => 'get_value',
        _set_playing_item => 'set_value',
    },
);

property player => (
    type => 'Object',
    class => 'App::GPAudio::Model::Player',
    required => 1,
    handles => {
        _play_file => 'play',
        _stop_player => 'stop',
        _pause_player => 'pause',
        _player_is_paused => 'is_paused',
        _unpause_player => 'unpause',
        _when_eos => ['signal_connect', 'eos'],
    },
);

property shuffle_toggle => (
    type => 'Object',
    class => 'Gtk2::ToggleButton',
    required => 1,
    handles => {
        _is_shuffled => 'get_active',
    },
);

property playlist_view => (
    type => 'Object',
    class => 'Gtk2::TreeView',
    required => 1,
    handles => {
        _get_view_model => 'get_model',
        _scroll_to_path => 'scroll_to_cell',
    },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->_when_eos(sub {
        my ($player, $self) = @_;
        $self->_play_next;
        return undef;
    }, $self);
    Glib::Timeout->add(250, sub {
        $self->_update_position;
        return 1;
    });
}

sub _update_position {
    my ($self) = @_;
    return 1;
}

after _stop_player => sub {
    my ($self) = @_;
    if ($self->_has_playing_playlist) {
        $self->_mark_as_playing(undef);
        $self->_set_playing_item(undef);
    }
};

sub _scroll_to {
    my ($self, $id) = @_;
    my $model = $self->_get_view_model;
    $model->foreach(sub {
        my ($model, $path, $iter, $self) = @_;
        if ($model->get($iter, PLAYLIST_ID) eq $id) {
            $self->_scroll_to_path($path);
            return 1;
        }
        return undef;
    }, $self);
    return 1;
}

sub _play_item_in_list {
    my ($self, $list, $id) = @_;
    $self->_set_playing_playlist($list);
    $self->_play_item($id);
    return 1;
}

sub _play_item {
    my ($self, $id) = @_;
    $self->_mark_as_playing($id);
    my $path = $self->_get_playlist_value($id, PLAYLIST_PATH);
    $self->_play_file($path);
    $self->_set_playing_item($id);
    return 1;
}

sub _play_next {
    my ($self) = @_;
    my $next;
    if ($self->_is_shuffled) {
        $next = $self->_find_random_item;
    }
    else {
        $next = $self->_find_next_item($self->_get_playing_item);
    }
    $self->_play_item($next);
    $self->_scroll_to($next);
    return 1;
}

sub on_next {
    my ($self) = @_;
    $self->_play_next;
    return undef;
}

sub on_activate {
    my ($self, $list_view, $path) = @_;
    my $model = $list_view->get_model;
    my $iter = $model->get_iter($path);
    my $id = $model->get($iter, PLAYLIST_ID);
    $self->_play_item_in_list($self->_get_active_playlist, $id);
    return undef;
}

sub on_play {
    my ($self) = @_;
    if ($self->_player_is_paused) {
        $self->_unpause_player;
    }
    else {
        my $list = $self->_get_active_playlist;
        my $first = $list->get_first;
        $self->_play_item_in_list($list, $first);
    }
    return undef;
}

sub on_pause {
    my ($self) = @_;
    $self->_pause_player;
    return undef;
}

sub on_stop {
    my ($self) = @_;
    $self->_stop_player;
    return undef;
}

sub shutdown {
    my ($self) = @_;
    $self->_stop_player;
}

register;
