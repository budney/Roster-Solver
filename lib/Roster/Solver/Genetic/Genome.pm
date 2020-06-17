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
# The problem we're solving.
my %problem_of :ATTR( :init_arg<problem> :get<problem> :default<undef> );
# The DNA representation of this schedule, as a hex string.
my %hex_of :ATTR( :get<hex> );
#>>>

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

    $problem_of{ident $self} = $problem;
    weaken($problem_of{ident $self});

    return;
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
C<problem> initializer, if any, to a weak reference.

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

