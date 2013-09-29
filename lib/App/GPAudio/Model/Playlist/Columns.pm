use strictures 1;

package App::GPAudio::Model::Playlist::Columns;
use Sub::Install qw( install_sub );

use namespace::clean;
use Exporter 'import';

my @_columns = qw(
    position
    id
    file_id
    title
    album
    artist
    track
    year
    path
    length
    length_readable
    font_weight
);

my $_idx = 0;
my %_column_idx = (map { ($_, $_idx++) } @_columns);
my $_to_const = sub { sprintf 'PLAYLIST_%s', uc shift };
my @_const = map { $_->$_to_const } @_columns;

our %EXPORT_TAGS = (
    constants => [@_const],
    all => ['playlist_column', @_const],
);

our @EXPORT_OK = ('playlist_column', @_const);

for my $idx (0 .. $#_columns) {
    my $col = $_columns[ $idx ];
    install_sub {
        into => __PACKAGE__,
        as => $col->$_to_const,
        code => sub () { $idx },
    };
}

sub playlist_column { $_column_idx{ $_[0] } }

1;
