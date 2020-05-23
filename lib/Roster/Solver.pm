package Roster::Solver;

use 5.006;
use strict;
use warnings;

use Carp 'croak';
use Clone 'clone';
use Class::Std;

our $VERSION = '0.01';

# Attributes
my ( %dates_of, %jobs_of, %workers_of, ) : ATTRS;

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
        # This shouldn't happen
        croak 'Fatal: setting attribute without array or arrayref';
    }

    return;
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

1;    # End of Roster::Solver
__END__

=head1 NAME

Roster::Solver - The great new Roster::Solver!

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Roster::Solver;

    my $foo = Roster::Solver->new();
    ...

=head1 ATTRIBUTES

=over

=item dates

  $solver->set_dates(qw{ 1/1 1/8 1/15 1/22 1/29 2/5 ... });
  @dates = $solver->get_dates();

The dates for which we wish to schedule workers.

=back

=head1 SUBROUTINES/METHODS

=head2 function1

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

