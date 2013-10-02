use strictures 1;

package App::GPAudio::Model::Notifier;
use Object::Glib;
use Net::DBus::GLib;
use curry::weak;

use namespace::clean;

property dbus_object => (
    type => 'Object',
    init_arg => undef,
    lazy => 1,
    builder => sub {
        my ($self) = @_;
        return Net::DBus::GLib
            ->session
            ->get_service('org.freedesktop.Notifications')
            ->get_object(
                '/org/freedesktop/Notifications',
                'org.freedesktop.Notifications',
            );
    },
    handles => {
        _create => 'Notify',
        _when_closed => ['connect_to_signal', 'NotificationClosed'],
    },
);

property notification_icon => (
    is => 'rpo',
    default => sub { '' },
);

property last_id => (
    is => 'rpwp',
    init_arg => undef,
    clearer => 1,
    default => sub { 0 },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->_when_closed($self->curry::weak::_closed);
}

sub _closed {
    my ($self) = @_;
    $self->_clear_last_id;
}

sub notify {
    my ($self, $summary, $body) = @_;
    my $id = $self->_create(
        'GPAudio',
        $self->_get_last_id,
        $self->_get_notification_icon,
        $summary,
        $body,
        [],
        {},
        5000,
    );
    $self->_set_last_id($id);
    return 1;
}

register;
