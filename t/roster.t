# Basic accessor tests

use Test::More;
use Test::Exception;

use Roster::Solver;
use Data::Dumper;

my $solver = Roster::Solver->new;

# Accessors exist
ok $solver->can('set_dates'),        "<dates> attribute has setter.";
ok $solver->can('get_dates'),        "<dates> attribute has getter.";
ok $solver->can('set_jobs'),         "<jobs> attribute has setter.";
ok $solver->can('get_jobs'),         "<jobs> attribute has getter.";
ok $solver->can('set_workers'),      "<workers> attribute has setter.";
ok $solver->can('get_workers'),      "<workers> attribute has getter.";
ok $solver->can('set_head_counts'),  "<head_counts> attribute has setter.";
ok $solver->can('get_head_counts'),  "<head_counts> attribute has getter.";
ok $solver->can('set_availability'), "<availability> attribute has setter.";
ok $solver->can('get_availability'), "<availability> attribute has a getter.";
ok $solver->can('set_eligibility'),  "<eligibility> attribute has setter.";
ok $solver->can('get_eligibility'),  "<eligibility> attribute has a getter.";

# Basic validation
throws_ok { $solver->set_dates } qr/called without array/,
    "set_dates() with no arguments throws exception.";
throws_ok { $solver->set_jobs } qr/called without array/,
    "set_jobs() with no arguments throws exception.";
throws_ok { $solver->set_workers } qr/called without array/,
    "set_workers() with no arguments throws exception.";

throws_ok { $solver->set_head_counts } qr/called without hashref/,
    "set_head_counts() with no arguments throws exception.";
throws_ok { $solver->set_head_counts( [] ) } qr/called without hashref/,
    "set_head_counts() with arrayref throws exception.";
lives_ok { $solver->set_head_counts( {} ) }
"set_head_counts() with hashref lives.";

throws_ok { $solver->set_availability } qr/called without hashref/,
    "set_availability() with no arguments throws exception.";
throws_ok { $solver->set_availability( [] ) } qr/called without hashref/,
    "set_availability() with arrayref throws exception.";
lives_ok { $solver->set_availability( {} ) }
"set_availability() with hashref lives.";

throws_ok { $solver->set_eligibility } qr/called without hashref/,
    "set_eligibility() with no arguments throws exception.";
throws_ok { $solver->set_eligibility( [] ) } qr/called without hashref/,
    "set_eligibility() with arrayref throws exception.";
lives_ok { $solver->set_eligibility( {} ) }
"set_eligibility() with hashref lives.";

throws_ok { $solver->set_exclusivity } qr/called without hashref/,
    "set_exclusivity() with no arguments throws exception.";
throws_ok { $solver->set_exclusivity( [] ) } qr/called without hashref/,
    "set_exclusivity() with arrayref throws exception.";
lives_ok { $solver->set_exclusivity( {} ) }
"set_exclusivity() with hashref lives.";

# Immutabilty of attribute content
my $list = [qw{a b c}];
lives_ok { $solver->set_dates($list) } "set_dates() with arrayref lives";
lives_ok { $solver->set_jobs($list) } "set_jobs() with arrayref lives";
lives_ok { $solver->set_workers($list) } "set_workers() with arrayref lives";
$list->[1] = 'd';
is_deeply $solver->get_dates(), [qw{a b c }], "dates attribute is unchanged";
is_deeply $solver->get_jobs(),  [qw{a b c }], "jobs attribute is unchanged";
is_deeply $solver->get_workers(), [qw{a b c }],
    "workers attribute is unchanged";

# Repeat, using an array instead of an arrayref
my @list = qw{a};
lives_ok { $solver->set_dates(@list) } "set_dates() with array lives";
lives_ok { $solver->set_jobs(@list) } "set_jobs() with array lives";
lives_ok { $solver->set_workers(@list) } "set_workers() with array lives";
is_deeply $solver->get_dates(),   [qw{a}], "dates attribute is correct";
is_deeply $solver->get_jobs(),    [qw{a}], "jobs attribute is correct";
is_deeply $solver->get_workers(), [qw{a}], "workers attribute is correct";

# Immutability of hashref attributes
my $hashref = { a => 1, b => 1 };
lives_ok { $solver->set_head_counts($hashref) }
"set_head_counts() with hashref lives";
lives_ok { $solver->set_availability($hashref) }
"set_availability() with hashref lives";
lives_ok { $solver->set_eligibility($hashref) }
"set_eligibility() with hashref lives";
lives_ok { $solver->set_exclusivity($hashref) }
"set_exclusivity() with hashref lives";
$hashref->{b} = 2;
$hashref->{c} = 3;
is_deeply $solver->get_head_counts(), { a => 1, b => 1 },
    "head_counts attribute is correct";
is_deeply $solver->get_availability(), { a => 1, b => 1 },
    "availability attribute is correct";
is_deeply $solver->get_eligibility(), { a => 1, b => 1 },
    "eligibility attribute is correct";
is_deeply $solver->get_exclusivity(), { a => 1, b => 1 },
    "exclusivity attribute is correct";

done_testing();
