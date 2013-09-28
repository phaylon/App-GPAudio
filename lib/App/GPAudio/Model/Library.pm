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

my @_types;
$_types[LIBRARY_ID] = 'Glib::String';
$_types[LIBRARY_ADDED] = 'Glib::String';
$_types[LIBRARY_TITLE] = 'Glib::String';
$_types[LIBRARY_ARTIST] = 'Glib::String';
$_types[LIBRARY_ALBUM] = 'Glib::String';
$_types[LIBRARY_PATH] = 'Glib::String';
$_types[LIBRARY_TRACK] = 'Glib::String';
$_types[LIBRARY_YEAR] = 'Glib::String';
$_types[LIBRARY_LENGTH] = 'Glib::String';
$_types[LIBRARY_LENGTH_READABLE] = 'Glib::String';

$_types[LIBRARY_SORT_LENGTH] = 'Glib::String';
$_types[LIBRARY_SORT_TITLE] = 'Glib::String';
$_types[LIBRARY_SORT_ARTIST] = 'Glib::String';
$_types[LIBRARY_SORT_ALBUM] = 'Glib::String';

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->set_column_types(@_types);
    $self->_init_from_storage;
}

sub scan {
    my ($self, $iterator) = @_;
    $self->signal_emit('scan_started');
    Glib::Idle->add($self->curry::weak::_scan_next($iterator));
    return 1;
}

sub _scan_next {
    my ($self, $iterator) = @_;
    my $next = $iterator->();
    if (defined $next) {
        unless ($next->is_dir) {
            try {
                if (my $iter = $self->_get_file_cache($next)) {
                    $self->_update_file($iter);
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
    $self->signal_emit('scan_ended');
    return undef;
}

sub _update_file {
    my ($self, $iter) = @_;
    return 1;
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
    utf8::decode($file);
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
        album => $tags->{TALB},
        artist => $tags->{TPE1} // $tags->{TPE2} // $tags->{TPE4},
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

sub _post_calc {
    my ($self, $iter) = @_;
    my ($id, $title, $artist, $album, $length, $track, $path)
        = $self->get($iter, map {
            library_column($_);
        } qw( id title artist album length track path ));
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
