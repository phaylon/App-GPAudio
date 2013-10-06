use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;
use File::ShareDir::Install;

(do 'maint/Makefile.PL.include' or die $@) unless -f 'META.yml';

install_share 'share';

my %_deps_runtime = (
    'aliased' => 0,
    'Audio::Scan' => '0.93',
    'curry::weak' => 0,
    'Data::Dump' => 0,
    'DateTime' => 0,
    'DBIx::Class::Candy' => 0,
    'DBIx::Class' => 0,
    'Desktop::Notify' => 0,
    'File::ShareDir' => 0,
    'Gnome2' => 0,
    'GStreamer' => 0,
    'GStreamer::Interfaces' => 0,
    'namespace::clean' => 0,
    'Net::DBus::GLib' => '0.33.0',
    'Net::DBus' => 0,
    'Object::Glib' => 0,
    'parent' => 0,
    'Path::Tiny' => 0,
    'strictures' => 0,
    'Sub::Install' => 0,
    'Try::Tiny' => '0.18',
);

my %_deps_tests = (
);

WriteMakefile(
  NAME => 'App::GPAudio',
  VERSION_FROM => 'lib/App/GPAudio.pm',
  PREREQ_PM => { %_deps_runtime },
  BUILD_REQUIRES => { %_deps_tests },
  LICENSE => 'perl',
  EXE_FILES => ['bin/gpaudio'],
);

package MY;
use File::ShareDir::Install qw( postamble );
