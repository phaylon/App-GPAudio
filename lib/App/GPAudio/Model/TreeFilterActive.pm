use strictures 1;

package App::GPAudio::Model::TreeFilterActive;
use Object::Glib;

use namespace::clean;

extends ['Gtk2', 'TreeModelFilter'];

property active_model => (
    type => 'Object',
    class => 'App::GPAudio::Model::Bin',
    required => 1,
    handles => {
        _when_active_model_changes => ['signal_connect', 'notify::value'],
    },
);

property empty_model => (
    is => 'rpo',
    required => 1,
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    my $empty = $self->_get_empty_model;
    $self->_when_active_model_changes(sub {
        my ($active, undef, $self) = @_;
        $self->set('child_model', $active->get_value || $empty);
        $self->refilter;
        return undef;
    }, $self);
}

register;
