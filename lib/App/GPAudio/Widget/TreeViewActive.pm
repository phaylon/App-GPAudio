use strictures 1;

package App::GPAudio::Widget::TreeViewActive;
use Object::Glib;

use namespace::clean;

extends ['Gtk2', 'TreeView'];

property active_model => (
    type => 'Object',
    class => 'App::GPAudio::Model::Bin',
    required => 1,
    handles => {
        _when_active_model_changes => ['signal_connect', 'notify::value'],
    },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->_when_active_model_changes(sub {
        my ($active, undef, $self) = @_;
        if (my $model = $active->get_value) {
            $self->set_model($model);
        }
        else {
            $self->set_model(undef);
        }
        return undef;
    }, $self);
}

register;
