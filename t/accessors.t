# Basic accessor tests

use Test::More;
use Test::Exception;

use Roster::Solver;
use Data::Dumper;

my $solver = Roster::Solver->new;

# Accessors exist
ok $solver->can('set_dates'),   "<dates> attribute has setter.";
ok $solver->can('get_dates'),   "<dates> attribute has getter.";
ok $solver->can('set_jobs'),    "<jobs> attribute has setter.";
ok $solver->can('get_jobs'),    "<jobs> attribute has getter.";
ok $solver->can('set_workers'), "<workers> attribute has setter.";
ok $solver->can('get_workers'), "<workers> attribute has getter.";

# Basic validation
throws_ok { $solver->set_dates   } qr/setting attribute without array/,
    "set_dates() with no arguments throws exception.";
throws_ok { $solver->set_jobs    } qr/setting attribute without array/,
    "set_jobs() with no arguments throws exception.";
throws_ok { $solver->set_workers } qr/setting attribute without array/,
    "set_workers() with no arguments throws exception.";

# Immutabilty of attribute content
my $list = [qw{a b c}];
lives_ok { $solver->set_dates($list) }   "set_dates() with arrayref lives";
lives_ok { $solver->set_jobs($list) }    "set_jobs() with arrayref lives";
lives_ok { $solver->set_workers($list) } "set_workers() with arrayref lives";
$list->[1] = 'd';
is_deeply $solver->get_dates(),   [qw{a b c }], "dates attribute is unchanged";
is_deeply $solver->get_jobs(),    [qw{a b c }], "jobs attribute is unchanged";
is_deeply $solver->get_workers(), [qw{a b c }], "workers attribute is unchanged";

# Repeat, using an array instead of an arrayref
my @list = qw{a b c};
lives_ok { $solver->set_dates(@list) }   "set_dates() with array lives";
lives_ok { $solver->set_jobs(@list) }    "set_jobs() with array lives";
lives_ok { $solver->set_workers(@list) } "set_workers() with array lives";
is_deeply $solver->get_dates(),   [qw{a b c }], "dates attribute is correct";
is_deeply $solver->get_jobs(),    [qw{a b c }], "jobs attribute is correct";
is_deeply $solver->get_workers(), [qw{a b c }], "workers attribute is correct";

done_testing();
