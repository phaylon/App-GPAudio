#!/usr/bin/env perl
use strictures 1;
use FindBin;
use DateTime;
use lib "$FindBin::Bin/../lib";
use aliased 'App::GPAudio::Schema';

my $schema = Schema->connect('dbi:SQLite:dbname=test.db');
$schema->deploy({ add_drop_table => 1 });
