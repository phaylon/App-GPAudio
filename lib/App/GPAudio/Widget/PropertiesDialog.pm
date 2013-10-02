use strictures 1;

package App::GPAudio::Widget::PropertiesDialog;
use Object::Glib;
use Path::Tiny;
use Audio::Scan;
use curry::weak;

use namespace::clean;

extends ['Gtk2', 'Dialog'];

property files => (
    type => 'Array',
    required => 1,
    handles => {
        _get_file_count => 'count',
        _get_files => 'all',
        _get_file => 'get',
    },
);

for my $store (qw( info_store tags_store )) {
    property $store => (
        is => 'rpo',
        lazy => 1,
        init_arg => undef,
        builder => sub {
            my ($self) = @_;
            return Gtk2::ListStore->new(qw(
                Glib::String
                Glib::String
            ));
        },
    );
}

property current_index => (
    is => 'rpwp',
    init_arg => undef,
);

property content_view => (
    type => 'Object',
    class => 'GMVC::View',
    required => 1,
    handles => {
        _get_root => ['get_widget', 'root'],
        _set_filename => ['widget_set', 'filename', 'label'],
        _set_location => ['widget_set', 'location', 'label'],
        _when_next => ['widget_connect', 'next_file', 'clicked'],
        _when_prev => ['widget_connect', 'prev_file', 'clicked'],
        _set_allow_next => ['widget_set', 'next_file', 'sensitive'],
        _set_allow_prev => ['widget_set', 'prev_file', 'sensitive'],
        _set_info_model => ['widget_set', 'info_list', 'model'],
        _set_tags_model => ['widget_set', 'tags_list', 'model'],
    },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->get_content_area->add($self->_get_root);
    $self->_set_info_model($self->_get_info_store);
    $self->_set_tags_model($self->_get_tags_store);
    $self->_set_current_index(0);
    $self->_populate;
    $self->_when_next($self->curry::weak::_adjust(1));
    $self->_when_prev($self->curry::weak::_adjust(-1));
}

sub _adjust {
    my ($self, $value) = @_;
    $self->_set_current_index($self->_get_current_index + $value);
    $self->_populate;
    return 1;
}

sub _populate {
    my ($self) = @_;
    my $index = $self->_get_current_index;
    my $file = $self->_get_file($index);
    my $path = path($file->path);
    $self->_set_filename($path->basename);
    $self->_set_location($path->parent);
    my $last_index = $self->_get_file_count - 1;
    $self->_set_allow_next($index < $last_index);
    $self->_set_allow_prev($index > 0);
    my $data = Audio::Scan->scan($path);
    $self->_populate_store($self->_get_info_store, $data->{info});
    $self->_populate_store($self->_get_tags_store, $data->{tags});
    return 1;
}

sub _populate_store {
    my ($self, $store, $data) = @_;
    $store->clear;
    for my $key (sort keys %$data) {
        my $value = $data->{ $key };
        my $iter = $store->append;
        $store->set($iter, 0 => $key, 1 => $value);
    }
    return 1;
}

register;
