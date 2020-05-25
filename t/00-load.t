#!/usr/bin/env perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN
{
    use_ok('Roster::Solver') || print "Bail out!\n";
}

diag("Testing Roster::Solver $Roster::Solver::VERSION, Perl $], $^X");
