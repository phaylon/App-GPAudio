use strictures 1;

package App::GPAudio::Schema::Result::Library;
use DBIx::Class::Candy;

use namespace::clean;

table 'library';

primary_column id => {
    data_type => 'int',
    is_auto_increment => 1,
};

column title => { data_type => 'text' };
column album => { data_type => 'text', is_nullable => 1 };
column artist => { data_type => 'text', is_nullable => 1 };
column length => { data_type => 'int' };
column year => { data_type => 'int', is_nullable => 1 };
column track => { data_type => 'int', is_nullable => 1 };
column path => { data_type => 'text' };
column added => { data_type => 'int' };

1;
