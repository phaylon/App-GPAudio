use strictures 1;

package App::GPAudio::Schema::Result::PlaylistItem;
use DBIx::Class::Candy;

use namespace::clean;

table 'playlist_items';

primary_column id => {
    data_type => 'int',
    is_auto_increment => 1,
};

column position => { data_type => 'int' };
column library_id => { data_type => 'int' };
column playlist_id => { data_type => 'int' };

belongs_to playlist => (
    'App::GPAudio::Schema::Result::Playlist',
    'playlist_id',
);

belongs_to file => (
    'App::GPAudio::Schema::Result::Library',
    'library_id',
);

1;
