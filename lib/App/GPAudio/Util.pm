use strictures 1;

package App::GPAudio::Util;

use namespace::clean;
use Exporter 'import';

our @EXPORT_OK = qw(
    readable_length
);

sub readable_length {
    my ($full_seconds) = @_;
    my $seconds = $full_seconds % 60;
    my $minutes = ($full_seconds - $seconds) / 60;
    return sprintf '%d:%02d', $minutes, $seconds;
}

1;
