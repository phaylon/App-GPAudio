use strictures 1;

package App::GPAudio::Model::Sources;
use Object::Glib;

use namespace::clean;

extends ['Gtk2', 'ListStore'];

property schema => (
    type => 'Object',
    class => 'DBIx::Class::Schema',
    required => 1,
    handles => {
        _get_source_rs => ['resultset', 'Source'],
    },
);

sub BUILD_INSTANCE {
    my ($self) = @_;
    $self->set_column_types(qw( Glib::String ));
    for my $row ($self->_get_source_rs->all) {
        $self->insert_with_values(0, 0 => $row->path);
    }
}

sub get_paths {
    my ($self) = @_;
    my @paths;
    $self->foreach(sub {
        my ($self, undef, $iter) = @_;
        push @paths, $self->get($iter, 0);
        return undef;
    });
    return sort @paths;
}

sub has_source {
    my ($self, $path) = @_;
    my $found;
    $self->foreach(sub {
        my ($self, undef, $iter) = @_;
        if ($path eq $self->get($iter, 0)) {
            $found = $iter;
            return 1;
        }
        return undef;
    });
    warn "FOUND $found" if $found;
    return $found;
}

sub add_source {
    my ($self, $path) = @_;
    if (my $iter = $self->has_source($path)) {
        return $iter;
    }
    $self->_get_source_rs->create({ path => $path });
    return $self->insert_with_values(0, 0 => $path);
}

sub remove_source {
    my ($self, $path) = @_;
    $self->foreach(sub {
        my ($self, undef, $iter) = @_;
        if ($path eq $self->get($iter, 0)) {
            $self->remove($iter);
            return 1;
        }
        return undef;
    });
    $self->_get_source_rs->search({ path => $path })->delete;
    return 1;
}

register;
