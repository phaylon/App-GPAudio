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
    handles => {
        _mark_as_playing => 'mark_as_playing',
    },
);

sub on_activate {
    my ($self, $list_view, $path) = @_;
    my $model = $list_view->get_model;
    my $iter = $model->get_iter($path);
    my $id = $model->get($iter, PLAYLIST_ID);
    $self->_set_playing_playlist($self->_get_active_playlist);
    $self->_play_item($id);
    return undef;
}

sub _play_item {
    my ($self, $id) = @_;
    $self->_mark_as_playing($id);
    return 1;
}

register;
