package Roster::Solver::Genetic::Genome;

# Genome that turns an array of integers into a valid schedule

use 5.006;
use strict;
use warnings;

use Carp qw{carp croak};
#use Clone 'clone';
use Class::Std;

#use List::Util qw{min max};
#use Math::Counting qw{:big combination};
#use Math::Round;
use ntheory ':rand';
use Readonly;
use Scalar::Util 'weaken';

our $VERSION = '0.01';

# Constants
#Readonly my $SUB       => 3;               # Returned from caller()

#<<< Leave this alone, perltidy
# Attributes:

# The problem we're solving.
my %problem_of :ATTR( :init_arg<problem> :get<problem> :default<undef> );

# The number of hex digits per codon
my %digits_of :ATTR( :get<digits> );

# The length of the complete genome
my %length_of :ATTR( :get<length> );

#>>> End perltidy

# Constructor stuff:
sub BUILD
{
    my ( $self, $ident, $arg_ref ) = @_;

    # All we really want to do is make sure the "problem" attribute
    # is a weak reference.  Generally the problem object creates
    # genomes, so we don't want circular references.
    if ( defined $arg_ref->{problem} )
    {
        $problem_of{$ident} = $arg_ref->{problem};
        weaken( $problem_of{$ident} );
    }

    return;
}

# Accessors:

# Return dates. This is delegated to the problem object.
sub get_dates
{
    my ($self) = @_;

    my $problem = $self->get_problem();
    return defined $problem ? $problem->get_dates() : undef;
}

# Return head counts. This is delegated to the problem object.
sub get_head_counts
{
    my ($self) = @_;

    my $problem = $self->get_problem();
    return defined $problem ? $problem->get_head_counts() : undef;
}

# Return jobs. This is delegated to the problem object.
sub get_jobs
{
    my ($self) = @_;

    my $problem = $self->get_problem();
    return defined $problem ? $problem->get_jobs() : undef;
}

# Set the problem attribute. This is a read-only attribute,
# so calling it after it's been set once will throw an
# exception.
sub set_problem
{
    my ($self, $problem) = @_;

    if (defined $problem_of{ident $self})
    {
        croak 'set_problem() called more than once';
    }

    # Save the problem using a weak reference
    $problem_of{ ident $self} = $problem;
    weaken( $problem_of{ ident $self} );

    # Also, decide now how many hex digits we need
    # for one codon. We overestimate by looking at
    # the total number of workers, rather than the
    # number eligible for each job. For medium size
    # problems that's fine. You might save a few bytes
    # if you have an enormous, specialized, workforce.
    my $largest_section = max
        scalar( @{ $problem->get_dates() } ),
        scalar( @{ $problem->get_jobs() } ),
        scalar( @{ $problem->get_workers() } );

    # The order of the next two steps is important. _genome_length()
    # references $digits_of{ident self}.
    $digits_of{ ident $self} = length( sprintf '%X', $largest_section );
    $length_of{ ident $self} = $self->_genome_length();

    return;
}

# Calculate the length of the full genome, based on the
# problem to be solved. I.e., permutations of eligible
# workers for each job.
sub _genome_length : PRIVATE
{
    my ($self) = @_;

    # Can't be done without a problem specified
    my $problem = $self->get_problem();
    return unless defined $problem;

    # Get the canonical list of jobs, and the
    # list of eligible workers, along with dates
    # and head counts.
    my $dates   = $self->get_dates();
    my $jobs    = $self->get_jobs();
    my $workers = $problem->get_eligible_workers();
    my $count   = $problem->get_head_counts();

    # Keep count of the logical digits, ignoring the
    # number of hex digits require to represent each one.
    my $places = 0;

    # Step through the jobs
    for my $job ( @{$jobs} )
    {
        # A permutation of workers has length 1 less
        # than the number of workers
        $places += scalar( @{ $workers->{$job} } ) - 1;

        # In addition, if the job requires more than 1
        # worker, we find the other workers by using the
        # same rotation shifted by some number.
        $places += $count->{$job} - 1;

        # Finally, for each worker for each job, there's
        # a permutation of dates that represents trades
        # between two workers -- i.e., to resolve a schedule
        # conflict.
        $places += $count->{$job} * ( scalar( @{$dates} ) - 1 );
    }

    # Return the computed result. This result will be cached
    # by set_problem(), and thereafter can be retrieved using
    # get_length().
    return $places * $self->get_digits();
}

# Return workers. This is delegated to the problem object.
sub get_workers
{
    my ($self) = @_;

    my $problem = $self->get_problem();
    return defined $problem ? $problem->get_workers() : undef;
}

1;    # End of Roster::Solver::Genetic::Genome
__END__

=head1 NAME

Roster::Solver::Genetic::Genome - Represent a schedule as an array of ints

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

C<Roster::Solver::Genetic::Genome> thinks of a schedule as a strict rotation
of some permutation of the eligible workers, together with a permutation of
the dates representing "trades" by the workers of their "turns."

    use Roster::Solver::Genetic::Genome;

    my $foo = Roster::Solver::Genetic::Genome->new();
    ...

=head1 ATTRIBUTES

=over

=item dates

  $solver = Roster::Solver->new();
  $gene   = Roster::Solver::Genetic::Genome->new({ problem = $solver });
  $dates  = $gene->get_dates();

The list of dates for which we're assigning jobs to workers.
This is a read-only "attribute" which is actually gotten by
interrogating the C<Roster::Solver> in this genome's C<problem>
attribute.

=item head_counts

  $solver      = Roster::Solver->new();
  $gene        = Roster::Solver::Genetic::Genome->new({ problem = $solver });
  $head_counts = $gene->get_head_counts();

A hashref giving the number of people required for each job.
This is a read-only "attribute" which is actually gotten by
interrogating the C<Roster::Solver> in this genome's C<problem>
attribute.

=item jobs

  $solver  = Roster::Solver->new();
  $gene    = Roster::Solver::Genetic::Genome->new({ problem = $solver });
  my $jobs = $gene->get_jobs();

The list of jobs to be done. This is a read-only "attribute"
gotten by interrogating the C<Roster::Solver> in this genome's
C<problem> attribute.

=item length

  $solver  = Roster::Solver->new();
  $gene    = Roster::Solver::Genetic::Genome->new({ problem = $solver });
  $length  = $gene->get_length();

The length of the full genome in bytes. The genome is a hex string
that uses C<$gene->get_digits()> bytes to represent each "digit" of
multiple permutations. Taking each job in sorted order, we represent:

=over

=item A permutation of all workers eligible for that job.

=item For each worker required more than one, an offset into that permutation.

=item A permutation of all dates on the roster, representing "trades" by workers with conflicts.

=back

=item problem

  $solver = Roster::Solver->new();
  $gene1  = Roster::Solver::Genetic::Genome->new({ problem = $solver });
  $gene2  = Roster::Solver::Genetic::Genome->new();
  $gene2->set_problem($solver);

The solver for the roster problem we're working on, which
the genome will interrogate to find out the list of dates,
jobs, and workers, which it needs to determine the offsets
for the hex encoding.

The solver is stored as a weak reference, to avoid possible
circular references that might cause memory leaks. You really
shouldn't be trusting genomes to keep track of the solver for
you: you should hold on to a reference of your own.

=item workers

  $solver  = Roster::Solver->new();
  $gene    = Roster::Solver::Genetic::Genome->new({ problem = $solver });
  $workers = $gene->get_workers();

The workers to be assigned jobs on dates. This is a read-only
"attribute" which is gotten by interrogating the C<Roster::Solver>
object in this genome's C<problem> attribute.

=back

=head1 PUBLIC METHODS

=head1 PRIVATE METHODS

=head2 BUILD

  $solver  = Roster::Solver->new();
  $gene    = Roster::Solver::Genetic::Genome->new({ problem = $solver });

C<BUILD()> is called automatically by the C<Class::Std> framework
when a new genome object is constructed. It just converts the
C<problem> initializer, if any, to a weak reference. It also computes
and caches the number of digits needed for a single codon.

=head2 _genome_length

  $solver  = Roster::Solver->new();
  $gene    = Roster::Solver::Genetic::Genome->new({ problem = $solver });
  $bytes   = $gene->_genome_length();

Compute the length of the full genome, given the problem to be
solved. The genome encodes a rotation for each job, AND a permutation
of dates for each spot in the head count. The rotation determines
the basic schedule, and the permuted dates represent "swaps" by
workers who can't (or don't want to) work their regularly scheduled
days.

Remember that a permutation of N items is represented as a factoradic
number with N-1 digits, I<BUT> the leftmost digit can be anything
between 0 and N-1. We represent this digit in hexadecimal, which
requires multiple bytes if N>15. For simplicity, we find the largest
such number, and then use that many bytes for every digit in the
genome.

In other words, a hexadecimal digit isn't the same thing as a digit
in the factoradic representations of the permutations, and if that's
confusing you should probably avoid trying to parse the encoded genome
yourself.

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

