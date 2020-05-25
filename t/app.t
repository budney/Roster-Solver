# Basic tests of Roster::Solver::App

use Test::More;
use Test::Exception;
use Test::Trap;

use Roster::Solver::App;
use Data::Dumper;

my $app = Roster::Solver::App->new;

# Validation of mandatory command line arguments
{
    # No arguments
    trap { $app->run() };
    like $trap->stderr, qr/--jobs option must be set/,
        "Run with no arguments, complains about missing --jobs:";
    is $trap->exit, 1, "Exit code was 1";
}
{
    # Only --jobs
    trap { $app->run(qw{ --jobs j }) };
    like $trap->stderr, qr/--workers option must be set/,
        "Run with only --jobs argument, complains about missing --workers";
    is $trap->exit, 1, "Exit code was 1";
}
{
    # Only --jobs and --workers
    trap { $app->run(qw{ --jobs j --workers w }) };
    like $trap->stderr, qr/--dates option must be set/,
        "Run with --jobs and --workers arguments, complains about missing --dates";
    is $trap->exit, 1, "Exit code was 1";
}
{
    # All three: --jobs, --workers, --dates
    trap { $app->run(qw{ --jobs j --workers w --dates d }) };
    is $trap->stdout, '',
        'No output when --jobs, --workers, --dates all supplied';
    is $trap->stderr, '',
        'No errors when --jobs, --workers, --dates all supplied';
    is $trap->exit, 0, "Exit code was 0";
}
{
    # Calling run() a second time is an error
    throws_ok { $app->run() } qr/called a second time/,
        "Throws an exception when run() is called twice";
}

# Call with optional days-off specified. Need to provide two workers,
# or the app will die complaining that scheduling is impossible.
{
    my $app = Roster::Solver::App->new;

    trap { $app->run(qw{ --jobs j --workers w,v --dates d --days-off w=1 }) };
    is $trap->stdout, '',
        'No output for --jobs, --workers, --dates, --days-off';
    is $trap->stderr, '',
        'No errors for --jobs, --workers, --dates, --days-off';
    is $trap->exit, 0, "Exit code was 0";
}

# Call with only one date and only one worker, who is off on that date.
# App should die, complaining that it can't schedule the date.
{
    my $app = Roster::Solver::App->new;

    throws_ok
    {
        $app->run(qw{ --jobs j --workers w --dates d --days-off w=1 })
    }
    qr/unable to fill roster/i,
        "Throws an exception when schedule is unsatisfiable for some date";
}

# Two jobs and one worker. In this case the the worker will be
# assigned both jobs. App should complete successfully.
{
    my $app = Roster::Solver::App->new;

    trap { $app->run(qw{ --jobs j,k --workers w --dates d }) };
    is $trap->stdout, '', 'No output for case of one worker doing two jobs';
    is $trap->stderr, '', 'No errors for case of one worker doing two jobs';
    is $trap->exit,   0,  "Exit code was 0";
}

# Two workers and one job that requires a head-count of two.  In
# this case the the workers will both be assigned. App should
# complete successfully.
{
    my $app = Roster::Solver::App->new;

    trap { $app->run(qw{ --jobs j --workers v,w --dates d --job-counts 2 }) };
    is $trap->stdout, '', 'No output for case of two workers doing one job';
    is $trap->stderr, '', 'No errors for case of two workers doing one job';
    is $trap->exit,   0,  "Exit code was 0";
}

# Three workers and two jobs that require a total head-count of
# three.  In this case all the workers will be assigned. App should
# complete successfully.
{
    my $app = Roster::Solver::App->new;

    trap
    {
        $app->run(qw{ --jobs j,k --workers u,v,w --dates d --job-counts 2 })
    };
    is $trap->stdout, '',
        'No output for case of three workers doing two jobs';
    is $trap->stderr, '',
        'No errors for case of three workers doing two jobs';
    is $trap->exit, 0, "Exit code was 0";
}

done_testing();
