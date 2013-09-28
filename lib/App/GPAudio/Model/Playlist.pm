use strictures 1;

package App::GPAudio::Model::Playlist;
use Object::Glib;
use App::GPAudio::Model::Playlist::Columns qw( :all );
use App::GPAudio::Util qw( readable_length );
use Path::Tiny;

use namespace::clean;

extends ['Gtk2', 'ListStore'];

my @_types;
$_types[PLAYLIST_POSITION] = 'Glib::Int';
$_types[PLAYLIST_ID] = 'Glib::String';
$_types[PLAYLIST_TITLE] = 'Glib::String';
$_types[PLAYLIST_ARTIST] = 'Glib::String';
$_types[PLAYLIST_ALBUM] = 'Glib::String';
$_types[PLAYLIST_PATH] = 'Glib::String';
$_types[PLAYLIST_TRACK] = 'Glib::String';
$_types[PLAYLIST_YEAR] = 'Glib::String';
$_types[PLAYLIST_LENGTH] = 'Glib::String';
$_types[PLAYLIST_LENGTH_READABLE] = 'Glib::String';

property id => (
    is => 'ro',
    required => 1,
);

property schema => (
    type => 'Object',
    class => 'DBIx::Class::Schema',
    required => 1,
    handles => {
        _get_playlist_item_rs => ['resultset', 'PlaylistItem'],
        _get_library_rs => ['resultset', 'Library'],
    },
);

property item_resultset => (
    type => 'Object',
    class => 'DBIx::Class::ResultSet',
    init_arg => undef,
    lazy => 1,
    builder => sub {
        my ($self) = @_;
        return scalar $self
            ->_get_playlist_item_rs
            ->search({ playlist_id => $self->get_id }, {
                order_by => { -asc => 'position' },
                join => 'file',
                prefetch => ['file'],
            });
    },
    handles => {
        _item_rs => 'search',
        _create_item => 'create',
    },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->set_column_types(@_types);
    $self->set_sort_column_id(PLAYLIST_POSITION, 'ascending');
    $self->_init_items;
}

sub _find_last_position {
    my ($self) = @_;
    my $item = $self->_item_rs->search({}, {
        order_by => { -desc => 'position' },
        limit => 1,
    })->first;
    return $item ? ($item->position + 1) : 0;
}

sub add_files {
    my ($self, $pos, @ids) = @_;
    $pos //= $self->_find_last_position;
    my $library = $self->_get_library_rs;
    my $after = $self->_item_rs->search({ position => { '>=', $pos } });
    my %move;
    while (my $item = $after->next) {
        my $new_pos = $move{ $item->id } = $item->position + @ids;
        $item->update({ position => $new_pos });
    }
    $self->foreach(sub {
        my ($self, $path, $iter) = @_;
        my $new_pos = $move{ $self->get($iter, PLAYLIST_ID) };
        if (defined $new_pos) {
            $self->set($iter, PLAYLIST_POSITION, $new_pos);
        }
    });
    for my $idx (0 .. $#ids) {
        my $id = $ids[ $idx ];
        my $file = $library->find($id);
        my $item = $self->_create_item({
            library_id => $id,
            position => $pos + $idx,
        });
        $item->discard_changes;
        $self->_add_entry($item);
    }
    return 1;
}

sub _init_items {
    my ($self) = @_;
    my $rs = $self->_item_rs;
    while (my $row = $rs->next) {
        $self->_add_entry($row);
    }
    return 1;
}

sub _add_entry {
    my ($self, $item) = @_;
    my $file = $item->file;
    my $data = { $file->get_inflated_columns };
    my $iter = $self->insert_with_values(0,
        (map {
            my $col = playlist_column($_);
            defined($col)
                ? ($col, $data->{ $_ })
                : ();
        } keys %$data),
        PLAYLIST_POSITION, $item->position,
        PLAYLIST_ID, $item->id,
    );
    $self->_post_calc($iter);
    return $iter;
}

sub _post_calc {
    my ($self, $iter) = @_;
    my ($title, $length, $path)
        = $self->get($iter, map {
            playlist_column($_);
        } qw( title length path ));
    $self->set($iter,
        PLAYLIST_LENGTH_READABLE, readable_length($length),
    );
    $self->set($iter, PLAYLIST_TITLE, path($path)->basename)
        unless length $title;
    return 1;
}

register;
