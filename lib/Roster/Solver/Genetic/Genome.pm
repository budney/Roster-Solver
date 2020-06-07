package Roster::Solver::Genetic::Genome;

# Genome that turns an array of integers into a valid schedule

use 5.006;
use strict;
use warnings;

use Carp qw{carp croak};

#use Clone 'clone';
use Class::Std;

use List::Util qw{min max};

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

# The DNA representation of this schedule, as a hex string.
my %hex_of :ATTR( :init_arg<hex> :get<hex> :default<undef> );

# The number of hex digits per codon
my %digits_of :ATTR( :get<digits> );

# The length of the complete genome
my %length_of :ATTR( :get<length> );

#>>> End perltidy

# Constructor stuff:
sub BUILD
{
    my ( $self, $ident, $arg_ref ) = @_;

    # There's nothing to do if we don't know the problem yet.
    return unless defined $arg_ref->{problem};

    # Make sure the "problem" attribute is a weak reference.
    # Generally the problem object creates genomes, so we don't want
    # circular references.
    $self->set_problem( $arg_ref->{problem} );

    # If we were given a hex string, save it as well.
    $self->set_hex( $arg_ref->{hex} ) if defined $arg_ref->{hex};

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

# Set the hex representation of the genome.
sub set_hex
{
    my ( $self, $hex ) = @_;

    if ( length($hex) != $self->get_length() )
    {
        croak "Invalid hex string: $hex";
    }

    $hex_of{ ident $self} = $hex;

    return;
}

# Set the problem attribute. This is a read-only attribute,
# so calling it after it's been set once will throw an
# exception.
sub set_problem
{
    my ( $self, $problem ) = @_;

    if ( defined $problem_of{ ident $self} )
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

# Convert a hex string into a permutation. The string must
# be of the same format generated by _encode_permutation().
sub _decode_hex
{
    my ( $self, $encoding ) = @_;

    # Append zero, using the correct number of digits,
    # to represent the final element of the permutaiton.
    my $prec = $self->get_digits();
    $encoding .= '0' x $prec;

    #<<< NO perltidy
    # Split the encoding into separate hex numbers,
    # each $prec digits long, and then convert to decimal.
    my @permutation =
        map { hex("0x$_") }
        $encoding =~ /(.{$prec})/xmsg;
    #>>>

    # Perform the steps of _encode_permutation(), exactly
    # backward.
    for my $i ( reverse 0 .. $#permutation - 1 )
    {
        for my $j ( reverse $i + 1 .. $#permutation )
        {
            $permutation[$j]++ if $permutation[$j] >= $permutation[$i];
        }
    }

    return \@permutation;
}

# Encode a permuted set of integers, assumed to be
# exactly the first N integers in some order.
sub _encode_permutation
{
    my ( $self, $permutation ) = @_;

    my @encoding = map { sprintf('%X', $_) } @{$permutation};

    for my $i ( 0 .. $#encoding )
    {
        for my $j ( $i + 1 .. $#encoding )
        {
            $encoding[$j]-- if $encoding[$j] > $encoding[$i];
        }
    }

    pop(@encoding);    # Last digit is always zero.

    my $prec = $self->get_digits();
    return sprintf "%0${prec}X" x scalar(@encoding), @encoding;
}

# Calculate the GCD of two numbers
sub _gcd : PRIVATE
{
    my ( $self, $x, $y ) = @_;
    return ($y) ? $self->_gcd( $y, $x % $y ) : $x;
}

# Calculate the least common multiple of two numbers
sub _lcm : PRIVATE
{
    my ( $self, $x, $y ) = @_;
    return $x * $y / $self->_gcd( $x, $y );
}

# Parse the genome, and return a hash of permuted indices.
sub _parse_genome : PRIVATE
{
    my ($self) = @_;

    # Get the genome, and make sure it exists
    my $hex = $self->get_hex();
    croak '_parse_genome() called before set_hex()'
        unless defined $hex;

    # Get the canonical list of jobs, and the
    # list of eligible workers, along with dates
    # and head counts.
    my $digits = $self->get_digits();
    my $jobs   = $self->get_jobs();
    my $dates  = $self->get_dates();
    my $ndates = scalar( @{$dates} );

    my $problem = $self->get_problem();
    my $workers = $problem->get_eligible_workers();
    my $count   = $problem->get_head_counts();

    my @parsed;

    # Step through the jobs
    for my $job ( @{$jobs} )
    {
        # Build a partial schedule for this job.
        my $schedule = {
            job      => $job,
            rotation => [],
            trades   => [],
            expanded => [],
            offsets  => [0],
        };
        push @parsed, $schedule;

        # Snip off the gene for the permutation of workers for this job
        my $npeople = scalar( @{ $workers->{$job} } );
        my $bytes   = $digits * ( $npeople - 1 );
        my $gene    = substr $hex, 0, $bytes, '';

        # Save the permutation of workers
        push @{ $schedule->{rotation} }, $self->_decode_hex($gene);

        # In addition, if the job requires more than 1
        # worker, we find the other workers by using the
        # same rotation shifted by some number.
        for ( 1 .. $count->{$job} - 1 )
        {
            my $offset = hex( "0x" . substr $hex, 0, $digits, '' );

            # Save the new rotation
            push @{ $schedule->{rotation} },
                [ map { ( $_ + $offset ) % $npeople }
                    @{ $schedule->{rotation}[0] } ];

            # Also save the corresponding offset
            push @{ $schedule->{offsets} }, $offset;
        }

        # Finally, for each worker for each job, there's
        # a permutation of dates that represents trades
        # between two workers -- i.e., to resolve a schedule
        # conflict.
        for my $i ( 0 .. $count->{$job} - 1 )
        {
            # Read the permutation of dates from the genome
            my $trades = substr $hex, 0, $digits * ( $ndates - 1 ), '';
            $trades = $self->_decode_hex($trades);
            push @{ $schedule->{trades} }, $trades;

            # Extend the list of workers to fill the schedule dates
            $schedule->{expanded}[$i]
                = $self->_extend( $schedule->{rotation}[$i], $ndates );

            # <<< No Perltidy
            # Apply the trades to the expanded list, and convert each
            # element to the worker's name
            @{ $schedule->{expanded}[$i] } =
                map { $workers->{$job}[$_] }
                map { $schedule->{expanded}[$i][$_] }
                @{$trades};
            # >>> Perltidy
        }
    }

    return \@parsed;
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

=item digits

  $solver = Roster::Solver->new();
  $gene   = Roster::Solver::Genetic::Genome->new({ problem = $solver });
  $digits = $gene->get_digits();

The number of hex digits needed for one codon. A gene represents
permutations of eligible workers for each job, along with permutations
of dates representing "trades" to resolve schedule conflicts.

We represent a permutation of N items using a Lehman code, which
is a series of N-1 digits between 0 and N. Long story short, the
biggest number we're going to need is N. So however many hex digits
we need to store the size of the largest set is what this method will
return.

=item head_counts

  $solver      = Roster::Solver->new();
  $gene        = Roster::Solver::Genetic::Genome->new({ problem = $solver });
  $head_counts = $gene->get_head_counts();

A hashref giving the number of people required for each job.
This is a read-only "attribute" which is actually gotten by
interrogating the C<Roster::Solver> in this genome's C<problem>
attribute.

=item hex

  $solver      = Roster::Solver->new();
  $gene        = Roster::Solver::Genetic::Genome->new({
    problem => $solver,
    hex     => 'D7D65BF6B856FF2C53AEB7174D4ABBA3',
  });
  $gene->set_hex('2EB13DC60FC68CF17A46AFAF106735C3');

A hex representation of the full genome. The length of that
representation depends on the roster problem to be solved, and
the interpretation of the genome is complicated. It includes a
rotation of eligible workers for each job, and a permutation of
the schedule dates for each spot in the total head count.

Giving a hex string of the wrong length is a fatal error, and
an exception will be thrown.

This method is mainly used by C<Roster::Solver::Genetic::Genome>
objects interacting with each other.

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

=head2 _decode_hex

  # Returns [0, 1, 2]
  $self->_decode_hex("000");

  # Returns [1, 0, 2]
  $self->_decode_hex("100");

This is a private helper method that reverses a Lehman-encoding
to create a permuted array of integers. It can in turn be used
to permute any array by using each element in turn as an index
into that array.

The return value us always an array of integers from 0 through
the length of the string I<divided by> C<$self->get_digits()>,
minus 1.

=head2 _encode_permutation

  # Returns "000"
  $self->_encode_permutation( [0, 1, 2] );

  # Returns "100"
  $self->_encode_permutation( [1, 0, 2] );

This is a private helper method that Lehman-encodes a permuted list
of integers. Note that we're permuting array indices, not array
elements, so this is I<always> a list of integers, and it's always
I<exactly> the integers C<0> through C<$n> in some order, where
C<$n> is the size of the array reference argument.

Although this is a concatenation of hex digits, bear in mind that
the "digits" of the Lehman code are actually C<$self->get_digits()>
long, so the string isn't a perfect representation of the factorial-base
number denoting this permutation unless C<$self->get_digits()>
equals 1.

=head2 _gcd

  # This will return 2
  $self->_gcd( 4, 6 );

Compute the greatest common divisor of the two arguments. This is
used to compute the least common multiple of the same arguments.
See C<_lcm()>.

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

=head2 _lcm

  # This will return 12
  $self->_lcm( 4, 6 );

Compute the least common multiple of the two arguments. This is
just the product of the arguments, divided by the greatest common
divisor. This is used to calculate how far out in time we need to
extrapolate when checking for collisions, for example.

=head2 _parse_genome

  # Define a solver and initialize the schedule information
  $solver = Roster::Solver->new();
  $solver->set_jobs(qw{ cooking dishes trash });
  $solver->set_workers(qw{ Alice Bob Harry Gwen });
  $solver->set_dates(qw{ 1/1 1/2 1/3 1/4 1/5 1/6 1/7 });

  $gene = Roster::Solver::Genetic::Genome->new({ problem = $solver });
  $gene->set_hex('000000000111000000220000000');

  $parsed = $gene->_parse_genome();
  # Equivalent to:
  # $parsed = [
  #   { job => 'cooking',
  #     expanded => [ [ qw{ Alice Bob Gwen Harry Alice Bob Gwen } ] ],
  #     rotation => [ [ 0, 1, 2, 3, ] ],
  #     trades   => [ [ 0, 1, 2, 3, 4, 5, 6 ] ],
  #     offsets  => [ 0 ],
  #   },
  #   { job => 'dishes',
  #     expanded => [ [ qw{ Bob Gwen Harry Alice Bob Gwen Harry } ] ],
  #     rotation => [ [ 1, 2, 3, 0, ] ],
  #     trades   => [ [ 0, 1, 2, 3, 4, 5, 6 ] ],
  #     offsets  => [ 0 ],
  #   },
  #   { job => 'trash',
  #     expanded => [ [ qw{ Gwen Harry Alice Bob Gwen Harry Alice } ] ],
  #     rotation => [ [ 2, 3, 0, 1, ] ],
  #     trades   => [ [ 0, 1, 2, 3, 4, 5, 6 ] ],
  #     offsets  => [ 0 ],
  #   },
  # ]

Parses the hex representation of the genome into a data structure that
completely describes the corresponding work schedule.

The return value is an array of hash references, one per job. The
C<job> field identifies the job by name. The C<rotation>, C<trades>,
and C<offsets> fields reflect verbatim the contents of the genome.
The C<expanded> field gives the actual rotation of workers for that
job, for all the dates covered by the roster.

In other words, you can take the C<expanded> field's contents for
every hashref in the array, and you've got your schedule. The C<jobs>
field gives the row headings, and C<$gene->get_dates()> gives the
column headings.

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

