package Roster::Solver;

use 5.006;
use strict;
use warnings;

use Carp 'croak';
use Clone 'clone';
use Class::Std;
use ntheory ':rand';
use Readonly;

our $VERSION = '0.01';

Readonly my $SUB => 3;    # Returned from caller()

#<<< Leave this alone, perltidy
# Attributes
my (
    %dates_of,
    %jobs_of,
    %exclusivity_of,
    %head_counts_of,
    %workers_of,
    %eligibility_of,
    %availability_of,
) : ATTRS;
#>>>

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
sub get_availability : PRIVATE
{
    my ($self) = @_;
    return $availability_of{ ident $self };
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
sub get_eligibility : PRIVATE
{
    my ($self) = @_;
    return $eligibility_of{ ident $self };
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
    return clone( $exclusivity_of{ ident $self } );
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
    return clone( $head_counts_of{ ident $self } );
}

# Set jobs. If handed a reference, copy it so
# ours can't be tampered with.
sub set_jobs
{
    my ( $self, @args ) = @_;
    return $self->_set_array_attr( \%jobs_of, @args );
}

# Return jobs, but copy the list so ours can't
# be tampered with.
sub get_jobs
{
    my ($self) = @_;
    return clone( $jobs_of{ ident $self } );
}

# Set workers. If handed a reference, copy it so
# ours can't be tampered with.
sub set_workers
{
    my ( $self, @args ) = @_;
    return $self->_set_array_attr( \%workers_of, @args );
}

# Return workers, but copy the list so ours can't
# be tampered with.
sub get_workers
{
    my ($self) = @_;
    return clone( $workers_of{ ident $self } );
}

# Solve the scheduling problem.
sub solve
{
    my ($self) = @_;

    # Step 1: generate a random schedule
    my $schedule = $self->_generate_schedule();

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

=head1 ATTRIBUTES

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

=item dates

  $solver->set_dates(qw{ 1/1 1/8 1/15 1/22 1/29 2/5 ... });
  $dates = $solver->get_dates();

The dates for which we wish to schedule workers. These are
just string labels; no effort is made to parse or validate
them. So for example you could use names of holidays, or
other meaningful designations, rather than actual dates.

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
must be filled on every date.

=item workers

  $solver->set_dates(qw{ Alice Bob Harry Gwen ... });
  $workers = $solver->get_workers();

The people available to be added to the roster.

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

