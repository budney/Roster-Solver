# Basic accessor tests

use Test::More;
use Test::Exception;

use Roster::Solver::App;
use Roster::Solver::Genetic::Genome;

use Data::Dumper;

# Initialize a solver with some simple attributes:
# two jobs being done by three workers on one date.
our $app = Roster::Solver::App->new();
our $solver;

{
    # We need to use some private methods for convenience
    package Roster::Solver::App;

    $main::app->_process_options(
        qw{ --jobs j,k --workers u,v,w --dates d --eligibility u=11,v=11,w=11 --job-counts 2 }
    );
    $main::solver = $main::app->_setup_solver();
}

# Create a genome object
our $gene;
lives_ok
{
    $gene = Roster::Solver::Genetic::Genome->new( { problem => $solver } )
}
"constructing a genome lives";

# Read-only attributes
for my $attr (qw{ dates digits head_counts jobs workers })
{
    my $getter = "get_$attr";

    ok !$gene->can("set_$attr"), "attribute is read-only";
    ok $gene->can("get_$attr"), "$attr attribute has a getter";
    ok ref $gene->$getter, "getter returns a reference"
        unless $attr eq 'digits';
}

# Attribute values
is_deeply $gene->get_dates(), [qw{d}], "dates are correct";
is $gene->get_digits(), 1, "number of digits is correct";
is $gene->get_length(), 5, "length of genome is correct";
is_deeply $gene->get_head_counts(), { j => 2, k => 1 },
    "head counts are correct";
is_deeply $gene->get_jobs(),    [qw{j k}],     "jobs are correct";
is_deeply $gene->get_workers(), [qw{ u v w }], "workers are correct";

# Problem attribute
ok $gene->can("get_problem"), "problem attribute has a getter";
is ref $gene->get_problem(), ref $solver,
    "problem attribute has correct type";
throws_ok { $gene->set_problem( {} ) } qr/called more than once/,
    "set_problem() throws exception when called a second time";

done_testing();
