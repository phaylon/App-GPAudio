use strictures 1;

package App::GPAudio::Model::Bin;
use Object::Glib;

use namespace::clean;

property value => (
    is => 'rw',
    predicate => 'has_value',
);

register;
