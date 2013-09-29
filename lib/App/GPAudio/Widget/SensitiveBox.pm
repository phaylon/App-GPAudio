use strictures 1;

package App::GPAudio::Widget::SensitiveBox;
use Object::Glib;

use namespace::clean;

extends ['Gtk2', 'VBox'];

property sensitive_property => (
    is => 'ro',
    builder => sub { 'sensitive' },
);

property model => (
    type => 'Object',
    class => 'App::GPAudio::Model::Bin',
    required => 1,
    handles => {
        _on_sensitivity_change => ['signal_connect', 'notify::value'],
        _get_sensitivity => 'get_value',
    },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->set_spacing(0);
    my $sens_prop = $self->get_sensitive_property;
    $self->_on_sensitivity_change(sub {
        my ($model, undef, $self) = @_;
        $self->set($sens_prop, $model->get_value ? 1 : 0);
        return undef;
    }, $self);
    $self->set($sens_prop, $self->_get_sensitivity ? 1 : 0);
    $self->signal_connect_after('show', sub {
        my ($self) = @_;
        $self->set($sens_prop, $self->_get_sensitivity ? 1 : 0);
        return undef;
    });
}

register;
