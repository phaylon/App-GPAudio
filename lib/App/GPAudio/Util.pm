use strictures 1;

package App::GPAudio::Util;

use namespace::clean;
use Exporter 'import';

our @EXPORT_OK = qw(
    readable_length
    readable_expanded_length
);

sub readable_length {
    my ($full_seconds) = @_;
    my $seconds = $full_seconds % 60;
    my $minutes = ($full_seconds - $seconds) / 60;
    return sprintf '%d:%02d', $minutes, $seconds;
}

my $_hsecs = 60*60;

sub readable_expanded_length {
    my ($full_seconds) = @_;
    my $seconds = $full_seconds % 60;
    $full_seconds -= $seconds;
    my $m_secs = $full_seconds % $_hsecs;
    my $minutes = $m_secs / 60;
    $full_seconds -= $m_secs;
    my $hours = $full_seconds / $_hsecs;
    return join(':',
        $hours ? $hours : (),
        $minutes,
        sprintf('%02d', $seconds),
    );
}

1;
