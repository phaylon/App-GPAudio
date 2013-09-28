use strictures 1;

package App::GPAudio::Model::PlaylistManager;
use Object::Glib;

use aliased 'App::GPAudio::Model::Playlist';

use namespace::clean;

extends ['Gtk2', 'ListStore'];

property schema => (
    type => 'Object',
    is => 'rpo',
    class => 'DBIx::Class::Schema',
    required => 1,
    handles => {
        _get_playlist_rs => ['resultset', 'Playlist'],
    },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->set_column_types(qw(
        Glib::String
        Glib::String
    ));
    $self->set_sort_column_id(1, 'ascending');
    $self->_init_playlists;
}

sub get_playlist {
    my ($self, $iter) = @_;
    my $id = $self->get($iter, 0);
    return Playlist->new(
        id => $id,
        schema => $self->_get_schema,
    );
}

sub add_playlist {
    my ($self, $title) = @_;
    my $item = $self->_get_playlist_rs->create({
        title => $title,
    });
    my $iter = $self->insert_with_values(0,
        0 => $item->id,
        1 => $title,
    );
    return $iter;
}

sub _init_playlists {
    my ($self) = @_;
    my @lists = $self->_get_playlist_rs->all;
    for my $list (@lists) {
        $self->insert_with_values(0,
            0 => $list->id,
            1 => $list->title,
        );
    }
    return 1;
}

register;
