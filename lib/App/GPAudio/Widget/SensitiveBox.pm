use strictures 1;

package App::GPAudio::Widget::SensitiveBox;
use Object::Glib;

use namespace::clean;

extends ['Gtk2', 'VBox'];

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
    $self->_on_sensitivity_change(sub {
        my ($model, undef, $self) = @_;
        $self->set_sensitive($model->get_value ? 1 : 0);
        return undef;
    }, $self);
    $self->set_sensitive($self->_get_sensitivity ? 1 : 0);
}

register;
