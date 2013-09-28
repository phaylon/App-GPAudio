use strictures 1;

package App::GPAudio::Schema::Result::Source;
use DBIx::Class::Candy;

use namespace::clean;

table 'sources';

primary_column path => { data_type => 'text' };

1;
