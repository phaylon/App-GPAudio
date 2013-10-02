use strictures 1;

package App::GPAudio::Model::Player;
use Object::Glib;
use GStreamer-init;
use GStreamer::Interfaces;

use aliased 'App::GPAudio::Model::PlayerState';

use namespace::clean;

signal eos => (arity => 0);
signal error => (arity => 1);
signal duration => (arity => 1);

property state => (
    is => 'rwp',
    init_arg => undef,
    builder => sub { 'null' },
    on_set => '_on_state_change',
);

property playbin => (
    type => 'Object',
    init_arg => undef,
    lazy => 1,
    builder => sub {
        my ($self) = @_;
        return GStreamer::ElementFactory->make(playbin => 'play');
    },
    handles => {
        _set_playbin_state => 'set_state',
        _set_uri => ['set', 'uri'],
        _get_playbin_bus => 'get_bus',
        _query_playbin => 'query',
        _seek_playbin => 'seek',
        set_volume => ['set', 'volume'],
    },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->_get_playbin_bus->add_watch(sub {
        my ($bus, $message, $self) = @_;
        #warn "MSG " . $message->type . "\n";
        if ($message->type & 'eos') {
            $self->stop;
            $self->signal_emit('eos');
        }
        elsif ($message->type & 'error') {
            $self->stop;
            $self->signal_emit('error', $message->error);
        }
        elsif ($message->type & 'duration') {
            $self->signal_emit('duration', $message->duration);
        }
        return 1;
    }, $self);
}

sub _on_state_change {
    my ($self) = @_;
    $self->_set_playbin_state($self->get_state);
    return 1;
}

my %_query_class = (
    position => 'GStreamer::Query::Position',
    duration => 'GStreamer::Query::Duration',
);

sub _query_by_type {
    my ($self, $type) = @_;
    my $query = $_query_class{ $type }->new('time');
    $self->_query_playbin($query);
    my (undef, $value) = $query->$type;
    return $value;
}

sub seek_to {
    my ($self, $position) = @_;
    $self->_seek_playbin(
        1.0,
        'time',
        [qw( skip flush )],
        'set',
        $position,
        'none',
        0,
    );
    return 1;
}

sub query_duration {
    my ($self) = @_;
    return $self->_query_by_type('duration');
}

sub query_position {
    my ($self) = @_;
    return $self->_query_by_type('position');
}

sub is_playing {
    my ($self) = @_;
    return $self->get_state eq 'playing';
}

sub is_paused {
    my ($self) = @_;
    return $self->get_state eq 'paused';
}

sub unpause {
    my ($self) = @_;
    $self->_set_state('playing');
}

sub pause {
    my ($self) = @_;
    $self->_set_state('paused');
    return 1;
}

sub stop {
    my ($self) = @_;
    $self->_set_state('null');
    return 1;
}

sub play {
    my ($self, $path) = @_;
    $self->stop;
    $self->_set_uri("file://$path");
    $self->_set_state('playing');
    return 1;
}

sub get_state_model {
    my ($self, $state, $invert) = @_;
    return PlayerState->new(
        player => $self,
        state => $state,
        invert => $invert,
    );
}

register;
