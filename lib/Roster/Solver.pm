package Roster::Solver;

use 5.006;
use strict;
use warnings;

use Carp qw{carp croak};
use Clone 'clone';
use Class::Std;
use List::Util qw{min max};
use Math::Counting qw{:big combination};
use Math::Round;
use ntheory ':rand';
use Readonly;

our $VERSION = '0.01';

Readonly my $SUB       => 3;               # Returned from caller()
Readonly my $HARD_COST => 1_000_000_000;
Readonly my $FIRM_COST => 1_000_000;
Readonly my $SOFT_COST => 1_000;

#<<< Leave this alone, perltidy
# Solver Setting Attributes
my %hard_cost_of :ATTR( :name<hard_cost> :default<undef> );
my %firm_cost_of :ATTR( :name<firm_cost> :default<undef> );
my %soft_cost_of :ATTR( :name<soft_cost> :default<undef> );

# Problem Attributes
my (
    %dates_of,
    %jobs_of,
    %exclusivity_of,
    %head_counts_of,
    %workers_of,
    %eligibility_of,
    %availability_of,
    %benchmarks_of,
) : ATTRS;
#>>>

# Constructor:
sub START
{
    my ( $self, $id, $args_ref ) = @_;

    # Defaults defined by compile-time constants
    # have to be set in the constructor.
    if ( !defined $hard_cost_of{$id} )
    {
        $hard_cost_of{$id} = $HARD_COST;
    }
    if ( !defined $firm_cost_of{$id} )
    {
        $firm_cost_of{$id} = $FIRM_COST;
    }
    if ( !defined $soft_cost_of{$id} )
    {
        $soft_cost_of{$id} = $SOFT_COST;
    }

    return;
}

# Accessors:

# Handle array-like attributes by copying judiciously,
# so nobody is tempted to modify our innards.
sub _set_array_attr : PRIVATE
{
    my ( $self, $attr, @args ) = @_;

    if ( @args == 1 && ref $args[0] eq 'ARRAY' )
    {
        # It's a reference: clone it
        $attr->{ ident $self} = clone( $args[0] );
    }
    elsif ( @args > 0 )
    {
        # It's an array: store it
        $attr->{ ident $self} = [@args];
    }
    else
    {
        my @caller = caller(1);
        my $sub    = $caller[$SUB];

        # This shouldn't happen
        croak "Fatal: $sub\(\) called without array or arrayref";
    }

    return;
}

# For getters, check whether the caller is inside
# this package. If not, clone the attribute before
# returning it, so the caller can't use it to change
# our data.
sub _get_clone
{
    my ( $self, $hashref ) = @_;
    my $retval = $hashref->{ ident $self};

    if ( (caller)[0] eq __PACKAGE__ )
    {
        return $retval;
    }
    else
    {
        return clone($retval);
    }
}

# Set availability. This method expects a hashref
# and saves a clone.
sub set_availability
{
    my ( $self, $hashref ) = @_;

    # Basic validation
    if ( !defined $hashref || ref $hashref ne 'HASH' )
    {
        croak 'Fatal: set_availability() called without hashref';
    }

    $availability_of{ ident $self } = clone($hashref);

    return;
}

# Get availability. Returns a bare hashref, but
# that's OK because it's private.
sub get_availability
{
    my ($self) = @_;
    return $self->_get_clone( \%availability_of );
}

# Get benchmarks. This is a read-only attribute,
# because it's computed from the problem parameters.
sub get_benchmarks
{
    my ($self) = @_;

    my $eligible   = $self->get_eligibility();
    my @workers    = @{ $self->get_workers() };
    my $head_count = $self->get_head_counts();

    # If they're cached, return 'em.
    if ( defined $benchmarks_of{ ident $self } )
    {
        return clone( $benchmarks_of{ ident $self } );
    }

    # Otherwise, compute 'em.
    my $benchmarks = {};

    # First, for each job, compute the average number of
    # times each eligible worker should have to do it,
    # and the number of dates between turns for that worker.
    for my $job ( @{ $self->get_jobs() } )
    {
        my @dates    = @{ $self->get_dates() };
        my @eligible = grep { $eligible->{jobs}{$job}{$_} } @workers;

        # The percentage of dates on which I do job X is the percentage
        # of teams that include me. For one-person teams that's easy,
        # but for larger teams it takes a little extra calculation.
        my $percent;

        if ( $head_count->{$job} > 1 && @eligible > 1 )
        {
            $percent
                = 1.0 * combination( @eligible - 1, $head_count->{$job} - 1 )
                / combination( scalar(@eligible), $head_count->{$job} );
        }
        else
        {
            $percent = 1.0 / @eligible;
        }

        # Note: if the number of workers doesn't divide evenly into
        # the number of dates, then the remainder might be the very
        # lowest value we can get for the satisfactoriness of a
        # schedule, because the people who get an extra turn might
        # be disgruntled.
        $benchmarks->{turns}{$job}
            = round( scalar(@dates) * $percent ) + 1;
        $benchmarks->{break}{$job}  = round( 1 / $percent ) - 1;
        $benchmarks->{people}{$job} = { map { ( $_ => 1 ) } @eligible };
    }

    # Save the benchmarks
    $benchmarks_of{ ident $self} = $benchmarks;

    # Recurse, which this time will return a clone.
    return $self->get_benchmarks();
}

# Set dates. If handed a reference, copy it so
# ours can't be tampered with.
sub set_dates
{
    my ( $self, @args ) = @_;
    return $self->_set_array_attr( \%dates_of, @args );
}

# Return dates, but copy the list so ours can't
# be tampered with.
sub get_dates
{
    my ($self) = @_;
    return clone( $dates_of{ ident $self } );
}

# Set eligibility. This method expects a hashref
# and saves a clone.
sub set_eligibility
{
    my ( $self, $hashref ) = @_;

    # Basic validation
    if ( !defined $hashref || ref $hashref ne 'HASH' )
    {
        croak 'Fatal: set_eligibility() called without hashref';
    }

    $eligibility_of{ ident $self } = clone($hashref);

    return;
}

# Get eligibility. Returns a bare hashref, but
# that's OK because it's private.
sub get_eligibility
{
    my ($self) = @_;
    return $self->_get_clone( \%eligibility_of );
}

# Set exclusivity. Expects a hashref; saves a clone.
sub set_exclusivity
{
    my ( $self, $hashref ) = @_;

    # Basic validation
    if ( !defined $hashref || ref $hashref ne 'HASH' )
    {
        croak 'Fatal: set_exclusivity() called without hashref';
    }

    $exclusivity_of{ ident $self } = clone($hashref);

    return;
}

# Return exclusivity, but copy the hash so ours can't
# be tampered with.
sub get_exclusivity
{
    my ($self) = @_;
    return $self->_get_clone( \%exclusivity_of );
}

# Set job head-counts. Expects a hashref; saves a clone.
sub set_head_counts
{
    my ( $self, $hashref ) = @_;

    # Basic validation
    if ( !defined $hashref || ref $hashref ne 'HASH' )
    {
        croak 'Fatal: set_head_counts() called without hashref';
    }

    $head_counts_of{ ident $self } = clone($hashref);

    return;
}

# Return head counts, but copy the hash so ours can't
# be tampered with.
sub get_head_counts
{
    my ($self) = @_;
    return $self->_get_clone( \%head_counts_of );
}

# Set jobs. If handed a reference, copy it so
# ours can't be tampered with.
sub set_jobs
{
    my ( $self, @args ) = @_;
    return $self->_set_array_attr( \%jobs_of, sort @args );
}

# Return jobs, but copy the list so ours can't
# be tampered with.
sub get_jobs
{
    my ($self) = @_;
    return $self->_get_clone( \%jobs_of );
}

# Set workers. If handed a reference, copy it so
# ours can't be tampered with.
sub set_workers
{
    my ( $self, @args ) = @_;
    return $self->_set_array_attr( \%workers_of, sort @args );
}

# Return workers, but copy the list so ours can't
# be tampered with.
sub get_workers
{
    my ($self) = @_;
    return $self->_get_clone( \%workers_of );
}

# Solve the scheduling problem.
sub solve
{
    my ($self) = @_;

    # Step 1: generate a random schedule
    my $schedule = $self->_generate_schedule();
    my $score    = $self->_score_schedule($schedule);

    return;
}

# Generate a random schedule (that honors days off
# and job eligibility)
sub _generate_schedule : PRIVATE
{
    my ($self) = @_;

    my @dates      = @{ $self->get_dates() };
    my @jobs       = @{ $self->get_jobs() };
    my @workers    = @{ $self->get_workers() };
    my $head_count = $self->get_head_counts();
    my $eligible   = $self->get_eligibility();
    my $available  = $self->get_availability();

    my $schedule = {};

    # Step through the dates
    for my $date (@dates)
    {
        my %assigned;

        # Step through the jobs
        for my $job (@jobs)
        {
            # Find eligible, available people
            my @list = grep { $available->{dates}{$date}{$_} }
                grep { $eligible->{jobs}{$job}{$_} } @workers;

            # Exclude people with jobs already
            my @list2 = grep { !$assigned{$_} } @list;

            # Use the shortest list we can
            if ( @list2 >= $head_count->{$job} )
            {
                @list = @list2;
            }
            elsif ( @list >= $head_count->{$job} )
            {
                # Warn, if we're in verbose mode
            }
            else
            {
                croak "Unable to fill roster for date: $date\n";
            }

            # Pick head-count many workers
            for ( 1 .. $head_count->{$job} )
            {
                my $i      = int( rand( scalar(@list) ) );
                my $choice = splice @list, $i, 1;

                $assigned{$choice} = 1;
                push @{ $schedule->{$date}{$job} }, $choice;
            }
        }
    }

    return $schedule;
}

# Review a schedule, and score it based on the hard, firm,
# and soft constraints it violates.
sub _score_schedule : PRIVATE
{
    my ( $self, $schedule ) = @_;

    my $benchmarks   = $self->get_benchmarks();
    my $available    = $self->get_availability();
    my $eligible     = $self->get_eligibility();
    my $is_exclusive = $self->get_exclusivity();

    my $complaints = { hard => {}, firm => {}, soft => {} };
    my @dates      = @{ $self->get_dates() };
    my $turns      = {};

    # Populate the $turns hash with a list of jobs and people.
    for my $job ( @{ $self->get_jobs() } )
    {
        for my $worker ( keys %{ $benchmarks->{people}{$job} } )
        {
            $turns->{$job}{$worker} = [];
        }
    }

    # Step through the schedule, counting up complaints.
    # In the process, build a flattened table of turns taken
    # by each worker, which we can use to find more complaints.
    for my $i ( 0 .. $#dates )
    {
        my $date   = $dates[$i];
        my %roster = %{ clone( $schedule->{$date} ) };

        my $assignments = {};

        # Step through the jobs, checking that each worker
        # was qualified and available.
        for my $job ( keys %roster )
        {
            # If there's nobody assigned, that's
            # a hard complaint.
            if ( @{ $roster{$job} } == 0 )
            {
                $complaints->{hard}{$date}{$job}++;
            }

            for my $worker ( @{ $roster{$job} } )
            {
                # Record the turns taken
                push @{ $turns->{$job}{$worker} }, $i;

                # Build a reverse lookup of what they did today
                push @{ $assignments->{$worker} }, $job;

                # If the assignee isn't qualified, that's a
                # hard complaint.
                if ( !$eligible->{jobs}{$job}{$worker} )
                {
                    $complaints->{hard}{$date}{$job}++;
                }

                # If this is the assignee's day off, that's
                # a hard complaint
                if ( !$available->{dates}{$date}{$worker} )
                {
                    $complaints->{hard}{$date}{$worker}++;
                }
            }
        }

        my ( @exclusive, @nonexclusive );

        # Now review the assignments for this date, looking
        # for double-assignments.
        for my $worker ( keys %{$assignments} )
        {
            next if @{ $assignments->{$worker} } == 1;

            # Now count up how many exclusive vs non-exclusive
            # jobs were involved in this double-booking.
            for my $job ( @{ $assignments->{$worker} } )
            {
                if ( $is_exclusive->{$job} )
                {
                    push @exclusive, $job;
                }
                else
                {
                    push @nonexclusive, $job;
                }
            }

            # If we're double-booked, then every exclusive job merits
            # a firm complaint.
            if (@exclusive)
            {
                # Complain about every nonexclusive job
                $complaints->{firm}{$date}{$_}++ for @nonexclusive;

                # Complain about all but the first exclusive job
                shift @exclusive;
                $complaints->{firm}{$date}{$_}++ for @exclusive;
            }
            else
            {
                # Should we lodge a mild complaint here?
            }
        }
    }

    # Now we do the petty thing, and look at all the turns taken.
    # Omitting someone is a firm complaint. Receiving too many turns,
    # or too short a break, is a soft complaint.
    for my $job ( keys %{$turns} )
    {
        for my $worker ( keys %{ $turns->{$job} } )
        {
            my @indices = @{ $turns->{$job}{$worker} };
            if ( @indices == 0 )
            {
                # This complaint has no date
                $complaints->{firm}{''}{$job}++;
            }
            if ( @indices > $benchmarks->{turns}{$job} )
            {
                # Remove the first bunch of jobs, and complain
                # about the rest.
                splice @indices, 0, $benchmarks->{turns}{$job};
                $complaints->{soft}{ $dates[$_] }{$job}++ for @indices;
            }

            for my $i ( 1 .. $#indices )
            {
                # Complain about each job that occurs after too
                # short a break
                my $break = $indices[$i] - $indices[ $i - 1 ];
                $complaints->{soft}{ $dates[$i] }{$job}++
                    if $break < $benchmarks->{break}{$job};
            }
        }
    }

    my @trouble_spots;
    my $score = 0;

    my $cost = {
        hard => $self->get_hard_cost,
        firm => $self->get_firm_cost,
        soft => $self->get_soft_cost,
    };

    # Now count up the score and also list the trouble spots
    for my $type (qw{ hard firm soft })
    {
        for my $date ( keys %{ $complaints->{$type} } )
        {
            for my $job ( keys %{ $complaints->{$type}{$date} } )
            {
                my $points
                    = $cost->{$type} * $complaints->{$type}{$date}{$job};
                $score += $points;
                next unless $date;

                push @trouble_spots, [ $points, $date, $job ];
            }
        }
    }

    # Sort by descending score, but otherwise we don't care.
    @trouble_spots = reverse sort { $a->[0] <=> $b->[0] } @trouble_spots;

    return $score, \@trouble_spots;
}

# Mate two schedules using simple point crossover: pick a date,
# and copy everything before that date from one schedule, and
# everything after that date from the other schedule.
sub _point_crossover
{
    my ( $self, $schedule1, $schedule2 ) = @_;

    my $child = {};

    my @dates = @{ $self->get_dates() };
    my $point = int( rand( scalar(@dates) ) );

    for my $i ( 0 .. $point - 1 )
    {
        $child->{ $dates[$i] } = clone( $schedule1->{ $dates[$i] } );
    }

    for my $i ( $point .. $#dates )
    {
        $child->{ $dates[$i] } = clone( $schedule2->{ $dates[$i] } );
    }

    return $child;
}

# Mate two schedules using uniform crossover: for each date,
# decide randomly which parent to take it from.
sub _uniform_crossover
{
    my ( $self, $schedule1, $schedule2 ) = @_;

    my @parent = ( $schedule1, $schedule2 );
    my $child  = {};
    my @dates  = @{ $self->get_dates() };

    for my $i ( 0 .. $#dates )
    {
        my $j = int( rand(2) );
        $child->{ $dates[$i] } = clone( $parent[$j]->{ $dates[$i] } );
    }

    return $child;
}

# Point mutations focus on spots where there's a complaint,
# just to speed things along.
sub _point_mutation
{
    my ( $self, $node ) = @_;
    my ( $score, $hotspots, $schedule ) = @{$node};

    my @dates      = @{ $self->get_dates() };
    my @jobs       = @{ $self->get_jobs() };
    my @workers    = @{ $self->get_workers() };
    my $head_count = $self->get_head_counts();
    my $eligible   = $self->get_eligibility();
    my $available  = $self->get_availability();

    Readonly my $P_HOTSPOT => 0.80;

    my ( $date, $job );

    # Pick a point to mutate
    if ( @{$hotspots} && rand() < $P_HOTSPOT )
    {
        my @candidates = map { int( rand( @{$hotspots} ) ) } 1 .. 3;
        my $index      = min @candidates;
        ( $date, $job ) = @{ $hotspots->[$index] }[ 1 .. 2 ];
    }
    else
    {
        my @jobs  = @{ $self->get_jobs };
        my @dates = @{ $self->get_dates };

        $date = $dates[ int( rand(@dates) ) ];
        $job  = $jobs[ int( rand(@jobs) ) ];
    }

    # Now pick the replacement

    # Find eligible, available people
    my @list = grep { $available->{dates}{$date}{$_} }
        grep { $eligible->{jobs}{$job}{$_} } @workers;

    # Use the shortest list we can
    if ( @list < $head_count->{$job} )
    {
        croak "Unable to fill roster for date: $date\n";
    }

    $schedule->{$date}{$job} = [];

    # Pick head-count many workers
    for ( 1 .. $head_count->{$job} )
    {
        my $i      = int( rand( scalar(@list) ) );
        my $choice = splice @list, $i, 1;

        push @{ $schedule->{$date}{$job} }, $choice;
    }

    # Recalculate score for the modified schedule.
    ( $node->[0], $node->[1] ) = $self->_score_schedule($schedule);

    return;
}

1;    # End of Roster::Solver
__END__

=head1 NAME

Roster::Solver - Solve the "nurse rostering problem"

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

C<Roster::Solver> accepts a list of jobs, workers, and dates,
along with the following constraints:

=over

=item 1. Which workers can do which jobs

=item 2. Which workers are available on which dates

=item 3. How many workers are needed for each job

=back

Based on this, it searches for a work schedule that fills every
job on every date, subject to the above hard constraints, as well
as the following "soft" constraints:

=over

=item 1. Inclusion

Every eligible worker should get at least one chance to do the job.

=item 2. Fairness

No eligible worker should be expected to do more than their fair
share. E.g., if we're scheduling 10 dates, and there are 5 workers
eligible to do the job, no one worker should do the job more than
twice.

=item 3. Spacing

Once a worker has done a job, they should not be called on to do it
again too soon. So in our previous example, if we have 10 dates and
5 eligible workers, a worker should have 4 weeks off before their
turn comes up again.


=back

    use Roster::Solver;

    my $foo = Roster::Solver->new();
    ...

=head1 SOLVER ATTRIBUTES

=over

=item firm_cost

  $solver = Roster::Solver->new({ firm_cost => 1_000_000 });
  $solver->set_firm_cost(1_000);
  $firm_cost = $solver->get_firm_cost();

The cost associated with each violation of firm constraints, like
leaving someone completely off the schedule. This should be greater
than C<soft_cost>, but less than C<hard_cost>. The default is
1,000,000 (one million).

=item hard_cost

  $solver = Roster::Solver->new({ hard_cost => 1_000_000 });
  $solver->set_hard_cost(1_000);
  $hard_cost = $solver->get_hard_cost();

The cost associated with each violation of hard constraints,
like scheduling a worker on their day off. This should be
I<very> high. Default is 1,000,000,000 (one billion).

=item soft_cost

  $solver = Roster::Solver->new({ soft_cost => 1_000_000 });
  $solver->set_soft_cost(1_000);
  $soft_cost = $solver->get_soft_cost();

The cost associated with each violation of soft constraints,
like scheduling a worker to do the same job twice in a row.
This should be fairly low. The default is 1,000, but a value
of 1 is probably just as good.

=back

=head1 PROBLEM ATTRIBUTES

=over

=item availability

  $solver->set_availability({
    dates => {
        '1/1' => { Bob => 1, Alice => 1, Glenn => 0 },
        '1/8' => { Bob => 1, Alice => 0, Glenn => 1 },
    },
    people => {
        Bob   => { '1/1' => 1, '1/8' => 1 },
        Alice => { '1/1' => 1, '1/8' => 0 },
        Glenn => { '1/1' => 0, '1/8' => 1 },
    },
  });

The availability attribute is write-only: the reader is private.
The value of the attribute is a data structure that spells out which
people are available on which dates, I<and> which dates are allowed
to schedule which people. The solver uses it as a lookup table
when attempting to assign dates I<or> to find alternate people for
changing the schedule on a given date.

=item benchmarks

  $benchmarks = $solver->get_benchmarks();

The C<benchmarks> attribute is read-only: it's computed from the
dates, workers, eligibility, etc., but ignoring days off. It's
a hash giving the expected number of turns for each job, the
expected break between doing the same job again, and a hash of
the people expected to do the job at least once.

The solver uses this to score a schedule by "lodging a complaint"
if someone gets too many turns, too short a break, or if someone
isn't scheduled to do the job at least once.

Failure to include everyone is a "firm" constraint. The others are
"soft" constraints.

=item dates

  $solver->set_dates(qw{ 1/1 1/8 1/15 1/22 1/29 2/5 ... });
  $dates = $solver->get_dates();

The dates for which we wish to schedule workers. These are just
string labels; no effort is made to parse, validate, or sort them.
So for example you could use names of holidays, or other meaningful
designations, rather than actual dates.

=item eligibility

  $solver->set_eligibility({
    jobs => {
        cook  => { Bob => 1, Alice => 1, Glenn => 0 },
        clean => { Bob => 1, Alice => 0, Glenn => 1 },
    },
    people => {
        Bob   => { cook => 1, clean => 1 },
        Alice => { cook => 1, clean => 0 },
        Glenn => { cook => 0, clean => 1 },
    },
  });

The eligibility attribute is write-only: the reader is private.
The value of the attribute is a data structure that spells out which
people can do which jobs, I<and> which jobs can be done by which
people. The solver uses it as a lookup table when attempting to
assign jobs I<or> to find alternates when reassigning.

=item exclusivity

  $solver->set_exclusivity({
    lead  => 1,
    cook  => 0,
    clean => 0,
  });

The exclusivity hash indicates, for each job, whether the person
holding that job can also do any other jobs on the same date. In
the example code, a cook can also clean, but a leader can only lead.

=item head_counts

  $solver->set_head_counts({
    lead  => 1,
    cook  => 2,
    clean => 6,
  });

The C<head_count> attribute is a hash that specifies, for each job,
how many people are needed to do that job. So in this example there's
only one leader, but there are two cooks and six people needed for
cleanup.

=item jobs

  $solver->set_jobs(qw{ cooking dishes trash shopping ... });
  $jobs = $solver->get_jobs();

The jobs to be assigned to workers. It's assumed that every job
must be filled on every date. The list of jobs is stored in sorted
order, regardless of the order it's provided in.

=item workers

  $solver->set_dates(qw{ Alice Bob Harry Gwen ... });
  $workers = $solver->get_workers();

The people available to be added to the roster. The list of workers
is stored in sorted order, regardless of the order it's provided in.

=back

=head1 PUBLIC METHODS

=head2 solve

The C<solve> method finds and returns the best schedule it can,
subject to the hard constraints that every worker must be available
on the dates scheduled and eligible for the jobs assigned, as well
as the "soft" constraints of inclusion, fairness, and spacing,
described in the summary for this module.

=head1 PRIVATE METHODS

=head2 _set_array_attr($hashref, @args)

If C<@args> is an array with at least one element, copy it into the
attribute hashref C<$hashref>. If C<@args> has exactly one element
and it's an arrayref, then clone it and save the copy in C<$hashref>.

This is a helper method for the attribute setters, so we can safely
store a copy of what we're given. We do this to discourage users
storing an arrayref, but holding on to the reference thinking they
can use it to modify the attribute's contents in place.

=head1 AUTHOR

Len Budney, C<< <len.budney at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-roster-solver at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Roster-Solver>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Roster::Solver


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Roster-Solver>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Roster-Solver>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Roster-Solver>

=item * Search CPAN

L<https://metacpan.org/release/Roster-Solver>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2020 by Len Budney.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

