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
            pane_position
            shuffle_active
            playlist_id
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

sub startup {
    my ($self) = @_;
    $self->_set_pane_position($self->_get_stored_pane_position)
        if $self->_has_stored_pane_position;
    $self->_set_shuffle_active($self->_get_stored_shuffle_active)
        if $self->_has_stored_shuffle_active;
    $self->_set_active_playlist($self->_get_stored_playlist_id)
        if $self->_has_stored_playlist_id;
    return 1;
}

sub shutdown {
    my ($self) = @_;
    $self->_txn(sub {
        my $rs = $self->_settings_rs->search;
        $rs->delete;
        $rs->create({
            key => 'pane_position',
            value => $self->_get_pane_position,
        });
        $rs->create({
            key => 'shuffle_active',
            value => $self->_get_shuffle_active,
        });
        $rs->create({
            key => 'playlist_id',
            value => $self->_get_active_playlist,
        });
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
