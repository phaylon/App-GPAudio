use strictures 1;

package App::GPAudio::Model::Library::Columns;
use Sub::Install qw( install_sub );

use namespace::clean;
use Exporter 'import';

my @_columns = qw(
    id
    added
    title
    album
    artist
    track
    year
    path
    length
    sort_title
    sort_album
    sort_artist
    sort_length
    length_readable
);

my $_idx = 0;
my %_column_idx = (map { ($_, $_idx++) } @_columns);
my $_to_const = sub { sprintf 'LIBRARY_%s', uc shift };
my @_const = map { $_->$_to_const } @_columns;

our %EXPORT_TAGS = (
    constants => [@_const],
    all => ['library_column', @_const],
);

our @EXPORT_OK = ('library_column', @_const);

for my $idx (0 .. $#_columns) {
    my $col = $_columns[ $idx ];
    install_sub {
        into => __PACKAGE__,
        as => $col->$_to_const,
        code => sub () { $idx },
    };
}

sub library_column { $_column_idx{ $_[0] } }

1;
