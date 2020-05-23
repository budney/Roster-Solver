#!/usr/bin/env perl

use 5.006;
use strict;
use warnings;
use Module::Build;
Module::Build->VERSION('0.4004');

my $class = Module::Build->subclass( code => <<'EOF' );

    sub ACTION_authortest {
        my ($self) = @_;

        $self->depends_on('build');
        $self->depends_on('manifest');
        $self->depends_on('distmeta');

        $self->test_files( qw< t xt/ > );
        $self->recursive_test_files(1);

        $self->depends_on('test');

        return;
    }

    sub ACTION_distdir {
        my ($self) = @_;

        $self->depends_on('authortest');

        return $self->SUPER::ACTION_distdir();
    }
EOF

my $builder = $class->new(
    module_name         => 'Roster::Solver',
    license             => 'gpl3',
    dist_author         => q{Len Budney <len.budney@gmail.com>},
    dist_version_from   => 'lib/Roster/Solver.pm',
    release_status      => 'stable',
    configure_requires  => {
        'Module::Build' => '0.4004',
        'perl'          => '5.10.0',
    },
    build_requires => {
        'Data::Dumper'      => 0,
        'Test::Exception'   => 0,
        'Test::More'   => 0,
    },
    test_requires => {
        'Data::Dumper'      => 0,
        'Test::Exception'   => 0,
        'Test::More'        => 0,
        'Test::Requires'    => 0,
        'perl'              => '5.10.0',
    },
    requires => {
        'perl'          => '5.10.0',
        'strict'        => 0,
        'warnings'      => 0,
        'CLI::Startup'  => '0.25',
        'Class::Std'    => 0,
        'Carp'          => 0,
        'Clone'         => 0,
    },
    add_to_cleanup     => [qw{
        Roster-Solver-*
        *.bak
    }],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
