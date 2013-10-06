use strictures 1;

package App::GPAudio::Model::Library;
use Object::Glib;
use App::GPAudio::Model::Library::Columns qw( :all );
use App::GPAudio::Util qw( readable_length );
use Audio::Scan;
use Try::Tiny;
use curry::weak;
use utf8;

use namespace::clean;

extends ['Gtk2', 'ListStore'];

signal scan_started => (arity => 0);
signal scan_ended => (arity => 0);

property schema => (
    type => 'Object',
    class => 'DBIx::Class::Schema',
    required => 1,
    handles => {
        _get_files_rs => ['resultset', 'Library'],
        _get_items_rs => ['resultset', 'PlaylistItem'],
        _txn => 'txn_do',
    },
);

property cache => (
    type => 'Hash',
    init_arg => undef,
    handles => {
        _set_file_cache => 'set',
        _get_file_cache => 'get',
        _has_file => 'exists',
    },
);

property cancel_scan => (
    is => 'rpwp',
    init_arg => undef,
);

my @_types;
$_types[LIBRARY_ID] = 'Glib::Int';
$_types[LIBRARY_ADDED] = 'Glib::String';
$_types[LIBRARY_ADDED_READABLE] = 'Glib::String';
$_types[LIBRARY_TITLE] = 'Glib::String';
$_types[LIBRARY_ARTIST] = 'Glib::String';
$_types[LIBRARY_ALBUM] = 'Glib::String';
$_types[LIBRARY_PATH] = 'Glib::String';
$_types[LIBRARY_TRACK] = 'Glib::String';
$_types[LIBRARY_YEAR] = 'Glib::String';
$_types[LIBRARY_LENGTH] = 'Glib::String';
$_types[LIBRARY_LENGTH_READABLE] = 'Glib::String';
$_types[LIBRARY_SEARCH] = 'Glib::String';

$_types[LIBRARY_SORT_LENGTH] = 'Glib::String';
$_types[LIBRARY_SORT_TITLE] = 'Glib::String';
$_types[LIBRARY_SORT_ARTIST] = 'Glib::String';
$_types[LIBRARY_SORT_ALBUM] = 'Glib::String';

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->set_column_types(@_types);
    $self->_init_from_storage;
}

sub get_file_object {
    my ($self, $id) = @_;
    return $self->_get_files_rs->find($id);
}

sub cancel_scan {
    my ($self) = @_;
    $self->_set_cancel_scan(1);
    return 1;
}

sub summarize {
    my ($self) = @_;
    my $row = $self->_get_files_rs->search({}, {
        select => [
            { count => 'me.id' },
            { sum => 'me.length' },
        ],
        as => ['count_all', 'length_all'],
    })->first;
    my $count = $row->get_column('count_all') || 0;
    my $length = $row->get_column('length_all') || 0;
    return $count, $length;
}

sub scan {
    my ($self, $iterator) = @_;
    $self->_set_cancel_scan(0);
    $self->signal_emit('scan_started');
    Glib::Idle->add($self->curry::weak::_scan_next($iterator));
    return 1;
}

sub _scan_next {
    my ($self, $iterator) = @_;
    unless ($self->_get_cancel_scan) {
        my $next = $iterator->();
        if (defined $next) {
            unless ($next->is_dir) {
                try {
                    if ($self->_file_stored($next)) {
                        $self->_update_file($next);
                    }
                    else {
                        $self->_add_new_file($next);
                    }
                }
                catch {
                    warn "Unable to process $next:\n\t$_\n";
                };
            }
            return 1;
        }
    }
    $self->signal_emit('scan_ended');
    return undef;
}

sub _file_stored {
    my ($self, $path) = @_;
    return $self->_get_files_rs->search({ path => $path })->count;
}

sub _extract_file_type {
    my ($self, $path) = @_;
    $path =~ m{\.([^\.]+)$}
        or die "File '$path' has no extension\n";
    my $ext = $1;
    my $type = lc(Audio::Scan->type_for($ext));
    return $type;
}

sub _open_file {
    my ($self, $path) = @_;
    my $file = $path->stringify;
    #utf8::decode($file);
    open my $fh, '<', $file
        or die "Unable to read from $file: $!\n";
    return $fh;
}

my $_sanitize = sub {
    my ($data) = @_;
    my $track = $data->{track};
    return {
        %$data,
        (length($track) and $track =~ m{^\d+$})
            ? ()
            : (track => undef),
    };
};

sub _extract_data {
    my ($self, $path) = @_;
    my $type = $self->_extract_file_type($path);
    local $ENV{AUDIO_SCAN_NO_ARTWORK} = 1;
    my $fh = $self->_open_file($path);
    my $data = Audio::Scan->scan_fh($type, $fh);
    my $tags = $data->{tags} || {};
    my $info = $data->{info} || {};
    my $method = "_extract_${type}_data";
    return $self->$method($path, $info, $tags)->$_sanitize;
}

sub _extract_mp3_data {
    my ($self, $path, $info, $tags) = @_;
    my $data = {
        title => $tags->{TIT2} // $path->basename,
        album => $tags->{TALB} // '',
        artist => $tags->{TPE1} // $tags->{TPE2} // $tags->{TPE4} // '',
        year => $tags->{TDRC} // $tags->{TYER},
        track => $tags->{TRCK},
        length => int($info->{song_length_ms} / 1000),
    };
    defined($data->{$_}) and utf8::decode($data->{$_})
        for qw( title album artist );
    return $data;
}

my $_concat = sub {
    return join '///', map {
        (defined($_) && length($_))
            ? "1$_"
            : '2'
    } @_;
};

my $_date = sub {
    my ($time) = @_;
    my ($day, $month, $year) = (localtime $time)[3, 4, 5];
    $year += 1900;
    $month += 1;
    return join '.', $day, $month, $year;
};

sub _post_calc {
    my ($self, $iter) = @_;
    my ($id, $title, $artist, $album, $length, $track, $path, $added)
        = $self->get($iter, map {
            library_column($_);
        } qw( id title artist album length track path added ));
    $self->set($iter,
        LIBRARY_SORT_TITLE,
            $_concat->($title, $artist, $id),
        LIBRARY_SORT_ARTIST,
            $_concat->($artist, $album, $track, $title, $id),
        LIBRARY_SORT_ALBUM,
            $_concat->($album, $artist, $track, $title, $id),
        LIBRARY_SORT_LENGTH,
            $_concat->(sprintf('%08d', $length), $track, $id),
        LIBRARY_LENGTH_READABLE,
            readable_length($length),
        LIBRARY_ADDED_READABLE,
            $added->$_date,
        LIBRARY_SEARCH,
            join(' ', map { defined($_) ? $_ : () }
                length($title) ? (
                    $title,
                    $artist,
                    $album,
                ) : ($path),
            ),
    );
    $self->set($iter, LIBRARY_TITLE, path($path)->basename)
        unless length $title;
    return 1;
}

my $_to_columns = sub {
    my ($data) = @_;
    return map {
        my $col = library_column($_);
        defined($col) ? ($col, $data->{$_}) : ();
    } keys %$data;
};

sub remove_file {
    my ($self, $id) = @_;
    $self->_txn(sub {
        $self->_get_files_rs->find($id)->delete;
        $self->_get_items_rs->search({ library_id => $id })->delete;
    });
    $self->foreach(sub {
        my ($self, $path, $iter) = @_;
        if ($self->get($iter, LIBRARY_ID) eq $id) {
            $self->remove($iter);
            return 1;
        }
        return undef;
    });
    return 1;
}

sub _add_new_file {
    my ($self, $path) = @_;
    return 1
        unless Audio::Scan->is_supported("$path");
    my $data = $self->_extract_data($path);
    my $added = time;
    my $item = $self->_get_files_rs->create({
        %$data,
        path => $path,
        added => $added,
    });
    my $iter = $self->insert_with_values(0,
        $data->$_to_columns,
        LIBRARY_ID, $item->id,
        LIBRARY_ADDED, $added,
        LIBRARY_PATH, $path,
    );
    $self->_set_file_cache($path, $iter);
    $self->_post_calc($iter);
    return 1;
}

sub _update_file {
    my ($self, $path) = @_;
    my $data = $self->_extract_data($path);
    my $item = $self->_get_files_rs->search({ path => $path })->first;
    $item->update({ %$data });
    $self->foreach(sub {
        my ($self, undef, $iter) = @_;
        if ($self->get($iter, LIBRARY_PATH) eq $path) {
            $self->set($iter, $data->$_to_columns);
            $self->_post_calc($iter);
            return 1;
        }
        return undef;
    });
    return 1;
}

sub _init_from_storage {
    my ($self) = @_;
    my $rs = $self->_get_files_rs->search({});
    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    while (my $row = $rs->next) {
        my $iter = $self->insert_with_values(0,
            $row->$_to_columns,
        );
        $self->_set_file_cache($row->{path}, $iter);
        $self->_post_calc($iter);
    }
}

register;
