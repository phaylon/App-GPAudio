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
$_types[PLAYLIST_FILE_ID] = 'Glib::String';
$_types[PLAYLIST_TITLE] = 'Glib::String';
$_types[PLAYLIST_ARTIST] = 'Glib::String';
$_types[PLAYLIST_ALBUM] = 'Glib::String';
$_types[PLAYLIST_PATH] = 'Glib::String';
$_types[PLAYLIST_TRACK] = 'Glib::String';
$_types[PLAYLIST_YEAR] = 'Glib::String';
$_types[PLAYLIST_LENGTH] = 'Glib::String';
$_types[PLAYLIST_LENGTH_READABLE] = 'Glib::String';
$_types[PLAYLIST_FONT_WEIGHT] = 'Glib::Int';
$_types[PLAYLIST_FAILED] = 'Glib::String';
$_types[PLAYLIST_SEARCH] = 'Glib::String';

property id => (
    is => 'ro',
    required => 1,
);

property title => (
    is => 'rw',
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
            });
    },
    handles => {
        _item_rs => 'search',
        _create_item => 'create',
    },
);

sub new_empty {
    my ($class) = @_;
    return Gtk2::ListStore->new(@_types);
}

sub reload {
    my ($self) = @_;
    $self->clear;
    $self->_init_items;
    return 1;
}

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->set_column_types(@_types);
    $self->set_sort_column_id(PLAYLIST_POSITION, 'ascending');
    $self->_init_items;
}

sub get_file_object {
    my ($self, $id) = @_;
    my $item = $self->_item_rs->find($id);
    return $item->file;
}

sub summarize {
    my ($self) = @_;
    my $row = $self->_item_rs({}, {
        join => ['file'],
        select => [
            { count => 'me.id' },
            { sum => 'file.length' },
        ],
        as => ['count_all', 'length_all'],
    })->first;
    my $count = $row->get_column('count_all') || 0;
    my $length = $row->get_column('length_all') || 0;
    return $count, $length;
}

sub get_random {
    my ($self) = @_;
    my $count = $self->iter_n_children;
    return undef
        unless $count;
    my $idx = rand($count - 1);
    my $iter = $self->iter_nth_child(undef, $idx);
    return $self->get($iter, PLAYLIST_ID);
}

sub get_next {
    my ($self, $id) = @_;
    my $next;
    my $seen;
    $self->foreach(sub {
        my ($self, $path, $iter) = @_;
        if ($seen) {
            $next = $self->get($iter, PLAYLIST_ID);
            return 1;
        }
        if ($self->get($iter, PLAYLIST_ID) eq $id) {
            $seen = 1;
        }
        return undef;
    });
    unless (defined $next) {
        $next = $self->get_first;
    }
    return $next;
}

sub get_first {
    my ($self) = @_;
    my $iter = $self->get_iter_first;
    return undef
        unless $iter;
    return $self->get($iter, PLAYLIST_ID);
}

sub get_by_id {
    my ($self, $id, $col) = @_;
    my $found;
    $self->foreach(sub {
        my ($self, $path, $iter) = @_;
        if ($self->get($iter, PLAYLIST_ID) eq $id) {
            $found = $self->get($iter, $col);
            return 1;
        }
        return undef;
    });
    return $found;
}

sub mark_as_playing {
    my ($self, $item_id) = @_;
    $self->foreach(sub {
        my ($self, $path, $iter) = @_;
        $self->set($iter, PLAYLIST_FONT_WEIGHT, 400)
            if $self->get($iter, PLAYLIST_FONT_WEIGHT) == 800;
        $self->set($iter, PLAYLIST_FONT_WEIGHT, 800)
            if defined($item_id)
            and $self->get($iter, PLAYLIST_ID) eq $item_id;
        return undef;
    });
    return 1;
}

sub resolve_file_ids {
    my ($self, @list_ids) = @_;
    return map { $_->library_id } $self
        ->_item_rs
        ->search({ 'me.id' => { -in => \@list_ids } })
        ->all;
}

sub _find_last_position {
    my ($self) = @_;
    my $item = $self->_item_rs->search({}, {
        order_by => { -desc => 'position' },
        limit => 1,
    })->first;
    return $item ? ($item->position + 1) : 0;
}

sub mark_failed {
    my ($self, $id, $flag) = @_;
    $self->foreach(sub {
        my ($self, $path, $iter) = @_;
        if ($self->get($iter, PLAYLIST_ID) eq $id) {
            $self->set($iter, PLAYLIST_FAILED, $flag ? 'red' : undef);
            return 1;
        }
        return undef;
    });
    return 1;
}

sub remove_files {
    my ($self, @ids) = @_;
    $self->_item_rs->search({ 'me.id' => { -in => \@ids } })->delete;
    my $items = $self->_item_rs;
    my $idx = 0;
    my %new_pos;
    while (my $item = $items->next) {
        my $new_idx = $idx++;
        $item->update({ position => $new_idx });
        $new_pos{ $item->id } = $new_idx;
    }
    my $count = $self->iter_n_children;
    for my $idx (reverse(0 .. ($count - 1))) {
        my $iter = $self->iter_nth_child(undef, $idx);
        my $id = $self->get($iter, PLAYLIST_ID);
        unless (exists $new_pos{ $id }) {
            $self->remove($iter);
        }
    }
    $self->foreach(sub {
        my ($self, $path, $iter) = @_;
        my $id = $self->get($iter, PLAYLIST_ID);
        $self->set($iter, PLAYLIST_POSITION, $new_pos{ $id });
        return undef;
    });
    return 1;
}

sub add_files {
    my ($self, $pos, @ids) = @_;
    $pos //= $self->_find_last_position;
    my $library = $self->_get_library_rs;
    my $after = $self->_item_rs->search(
        { position => { '>=', $pos } },
        { order_by => { -desc => 'position' } },
    );
    my %move;
    while (my $item = $after->next) {
        my $new_pos = $move{ $item->id } = $item->position + @ids;
        $item->update({ position => $new_pos });
    }
    my $count = $self->iter_n_children;
    for my $idx (reverse(0 .. ($count - 1))) {
        my $iter = $self->iter_nth_child(undef, $idx);
        my $id = $self->get($iter, PLAYLIST_ID);
        my $new_pos = $move{ $id };
        if (defined $new_pos) {
            $self->set($iter, PLAYLIST_POSITION, $new_pos);
        }
    }
    for my $idx (0 .. $#ids) {
        my $id = $ids[ $idx ];
        my $file = $library->find($id);
        my $new_pos = $pos + $idx;
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
        PLAYLIST_FILE_ID, $file->id,
        PLAYLIST_FONT_WEIGHT, 400,
    );
    $self->_post_calc($iter);
    return $iter;
}

sub _post_calc {
    my ($self, $iter) = @_;
    my ($title, $length, $path, $artist, $album)
        = $self->get($iter, map {
            playlist_column($_);
        } qw( title length path artist album ));
    $self->set($iter,
        PLAYLIST_LENGTH_READABLE, readable_length($length),
    );
    $self->set($iter, PLAYLIST_TITLE, path($path)->basename)
        unless length $title;
    return 1;
}

register;
