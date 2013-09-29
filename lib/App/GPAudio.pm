use strictures 1;

package App::GPAudio;
use Object::Glib;
use Gnome2;
use App::GPAudio::Model::Library::Columns qw( library_column );
use App::GPAudio::Model::Playlist::Columns qw( playlist_column );

use namespace::clean;

extends 'GMVC';

our $VERSION = '0.000001'; # 0.0.1
$VERSION = eval $VERSION;

sub _build_config_functions {
    my ($self) = @_;
    my $theme = Gnome2::IconTheme->new;
    return {
        library_column => \&library_column,
        playlist_column => \&playlist_column,
        get => sub { $_[0]->{ $_[1] } },
        stock_icon => sub {
            my ($id, $size) = @_;
            return Gtk2::Image->new_from_stock($id, $size);
        },
        theme_icon => sub {
            my ($id, $size) = @_;
            my ($file) = $theme->lookup_icon($id, $size);
            return Gtk2::Image->new_from_file($file);
        },
    };
}

register;

=head1 NAME

App::GPAudio - Description goes here

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

 Robert Sedlacek <rs@474.at>

=head1 CONTRIBUTORS

None yet - maybe this software is perfect! (ahahahahahahahahaha)

=head1 COPYRIGHT

Copyright (c) 2013 the App::GPAudio L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.
