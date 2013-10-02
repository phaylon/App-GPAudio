use strictures 1;

package App::GPAudio::Controller::Settings;
use Object::Glib;

use namespace::clean;

extends 'GMVC::Controller';

property schema => (
    type => 'Object',
    class => 'DBIx::Class::Schema',
    required => 1,
    handles => {
        _txn => 'txn_do',
        _settings_rs => ['resultset', 'Setting'],
    },
);

property settings => (
    type => 'Hash',
    lazy => 1,
    builder => sub {
        my ($self) = @_;
        my $rs = $self->_settings_rs->search;
        my %data;
        while (my $row = $rs->next) {
            $data{ $row->key } = $row->value;
        }
        return \%data,
    },
    handles => {
        (map {
            ("_get_stored_$_" => ['get', $_],
             "_has_stored_$_" => ['exists', $_],
            );
        } qw(
            volume
            pane_position
            shuffle_active
            playlist_id
            show_item_album
            show_item_year
            show_file_album
            show_file_year
            show_file_added
        )),
    },
);

property pane => (
    type => 'Object',
    class => 'Gtk2::Paned',
    required => 1,
    handles => {
        _set_pane_position => ['set', 'position'],
        _get_pane_position => ['get', 'position'],
    },
);

property volume => (
    type => 'Object',
    class => 'Gtk2::VolumeButton',
    required => 1,
    handles => {
        _get_volume => ['get_value'],
        _set_volume => ['set_value'],
    },
);

property shuffle => (
    type => 'Object',
    class => 'Gtk2::ToggleButton',
    required => 1,
    handles => {
        _set_shuffle_active => ['set', 'active'],
        _get_shuffle_active => ['get', 'active'],
    },
);

property playlist_selection => (
    type => 'Object',
    class => 'Gtk2::ComboBox',
    required => 1,
    handles => {
        _get_playlist_iter => 'get_active_iter',
        _set_playlist_iter => 'set_active_iter',
        _get_playlist_model => 'get_model',
    },
);

my @_toggle = qw(
    show_item_album
    show_item_year
    show_file_album
    show_file_year
    show_file_added
);

for my $toggle (@_toggle) {
    property $toggle => (
        type => 'Object',
        class => 'Gtk2::ToggleAction',
        required => 1,
        handles => {
            "_get_$toggle" => ['get', 'active'],
            "_set_$toggle" => ['set', 'active'],
        },
    );
}

my @_load = (
    ['pane_position', '_set_pane_position'],
    ['shuffle_active', '_set_shuffle_active'],
    ['playlist_id', '_set_active_playlist'],
    ['volume', '_set_volume'],
    ['show_item_album', '_set_show_item_album'],
    ['show_item_year', '_set_show_item_year'],
    ['show_file_album', '_set_show_file_album'],
    ['show_file_year', '_set_show_file_year'],
    ['show_file_added', '_set_show_file_added', 0],
);

my @_save = (
    ['pane_position', '_get_pane_position'],
    ['shuffle_active', '_get_shuffle_active'],
    ['playlist_id', '_get_active_playlist'],
    ['volume', sub { sprintf '%0.2f', $_[0]->_get_volume }],
    ['show_item_album', '_get_show_item_album'],
    ['show_item_year', '_get_show_item_year'],
    ['show_file_album', '_get_show_file_album'],
    ['show_file_year', '_get_show_file_year'],
    ['show_file_added', '_get_show_file_added'],
);

sub startup {
    my ($self) = @_;
    for my $load (@_load) {
        my ($name, $set, $default) = @$load;
        my $get_stored = "_get_stored_$name";
        my $has_stored = "_has_stored_$name";
        if ($self->$has_stored) {
            $self->$set($self->$get_stored);
        }
        elsif (@$load > 2) {
            $self->$set($default);
        }
    }
    return 1;
}

sub shutdown {
    my ($self) = @_;
    $self->_txn(sub {
        my $rs = $self->_settings_rs->search;
        $rs->delete;
        for my $save (@_save) {
            my ($key, $get) = @$save;
            $rs->create({
                key => $key,
                value => $self->$get,
            });
        }
    });
    return 1;
}

sub _set_active_playlist {
    my ($self, $id) = @_;
    if (defined $id) {
        my $model = $self->_get_playlist_model;
        $model->foreach(sub {
            my ($model, $path, $iter) = @_;
            if ($model->get($iter, 0) eq $id) {
                $self->_set_playlist_iter($iter);
                return 1;
            }
            return undef;
        });
    }
    return 1;
}

sub _get_active_playlist {
    my ($self) = @_;
    my $iter = $self->_get_playlist_iter
        or return undef;
    return $self->_get_playlist_model->get($iter, 0);
}

register;
