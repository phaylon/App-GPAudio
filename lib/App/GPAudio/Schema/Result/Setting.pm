use strictures 1;

package App::GPAudio::Schema::Result::Setting;
use DBIx::Class::Candy;

use namespace::clean;

table 'settings';

primary_column key => { data_type => 'text' };
column value => { data_type => 'text', is_nullable => 1 };

1;
