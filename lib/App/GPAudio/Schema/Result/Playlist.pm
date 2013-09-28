use strictures 1;

package App::GPAudio::Schema::Result::Playlist;
use DBIx::Class::Candy;

use namespace::clean;

table 'playlists';

primary_column id => {
    data_type => 'int',
    is_auto_increment => 1,
};

column title => { data_type => 'text' };

has_many items => (
    'App::GPAudio::Schema::Result::PlaylistItem',
    'playlist_id',
);

1;
