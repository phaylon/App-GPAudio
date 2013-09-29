use strictures 1;

package App::GPAudio::Model::PlayerState;
use Object::Glib;

use namespace::clean;

extends 'App::GPAudio::Model::Bin';

property player => (
    type => 'Object',
    class => 'App::GPAudio::Model::Player',
    required => 1,
    handles => {
        _get_current_state => 'get_state',
        _when_state_changes => ['signal_connect', 'notify::state'],
    },
);

property state => (
    is => 'ro',
    required => 1,
);

property invert => (
    is => 'ro',
    required => 1,
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->_update_value;
    $self->_when_state_changes(sub {
        my ($player, undef, $self) = @_;
        $self->_update_value;
        return undef;
    }, $self);
}

sub _update_value {
    my ($self) = @_;
    my $state = $self->get_state;
    my @all = ref($state) ? @$state : $state;
    my $current = $self->_get_current_state;
    my $on = grep { $current eq $_ } @all;
    $on = $on ? 0 : 1
        if $self->get_invert;
    $self->set_value($on);
    return 1;
}

register;
