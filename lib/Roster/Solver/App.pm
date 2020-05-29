package Roster::Solver::App;

use warnings;
use strict;

use Class::Std;

use Carp qw( croak );
use CLI::Startup;

use Roster::Solver;

our $VERSION = '0.01';

# Attributes
my %app_of : ATTR( :get<app> );
my %solver_of : ATTR( :get<solver> );

# Run the actual app. This is the meat of the app.
sub run
{
    my ( $self, @options ) = @_;

    # Process the command line and config file
    $self->_process_options(@options);

    # Setup the actual problem to be solved
    my $solver = $self->_setup_solver();

    # Solve the problem and generate a schedule
    my $schedule = $solver->solve();

    # Success
    exit 0;
}

# Use CLI::Startup to process command line args.
sub _process_options : PRIVATE
{
    my ( $self, @args ) = @_;

    # This method can only be called once per object
    if ( defined $app_of{ ident($self) } )
    {
        croak '_process_options() called a second time';
    }

    # Fool CLI::Startup, since we're using a weird
    # calling convention to facilitate unit testing.
    local @ARGV = @args;

    my $app = CLI::Startup->new( {
            options => {
                'dates=s@' => 'Dates to include in the roster',
                'days-off:s%' =>
                    'Hask of bitmasks of dates workers are unavailable',
                'exclusive-jobs=i@' =>
                    'Flags indicating jobs that fully occupy a worker',
                'job-counts=i@' => 'Number of people needed for each job',
                'jobs=s@'       => 'List of jobs to be done',
                'workers=s@'    => 'List of workers to roster',
                'eligibility:s%' =>
                    'Hash of bitmasks of jobs workers are eligible for',
            },
        } );
    $app->init();
    my $options = $app->get_options();

# Validate basic options. The only mandatory ones are jobs, workers, and dates.
    if ( not defined $options->{jobs} )
    {
        $app->die_usage(
            '--jobs option must be set on command line or in config file');
    }
    elsif ( not defined $options->{workers} )
    {
        $app->die_usage(
            '--workers option must be set on command line or in config file');
    }
    elsif ( not defined $options->{dates} )
    {
        $app->die_usage(
            '--dates option must be set on command line or in config file');
    }

    $app_of{ ident($self) } = $app;

    return;
}

# Setup a roster solver with the problem datea
sub _setup_solver : PRIVATE
{
    my ($self)  = @_;
    my $solver  = Roster::Solver->new();
    my $options = $self->get_app()->get_options();

    $solver_of{ ident $self} = $solver;

    # Some options can be copied verbatim
    $solver->set_dates( $options->{dates} );
    $solver->set_jobs( $options->{jobs} );
    $solver->set_workers( $options->{workers} );

    # The eligibility and availability bitmasks must be parsed
    $solver->set_eligibility( $self->_eligibility() );
    $solver->set_availability( $self->_availability() );

    # Exclusivity and head-count are both attributes of jobs
    $solver->set_exclusivity( $self->_exclusivity() );
    $solver->set_head_counts( $self->_head_count() );

    return $solver;
}

# Parse the eligibility bitmask
sub _eligibility : PRIVATE
{
    my ($self) = @_;
    return $self->_parse_bitmasks( {
        columns => 'jobs',
        rows    => 'workers',
        bitmask => 'eligibility',
        default => 0,
    } );
}

# Parse the availability bitmask
sub _availability : PRIVATE
{
    my ($self) = @_;

    # The CLI option specifies UNavailable dates,
    # and we want AVAILABLE dates.
    my $available = $self->_parse_bitmasks( {
        columns => 'dates',
        rows    => 'workers',
        bitmask => 'days-off',
        default => 0,
    } );

    # Invert all the bits
    for my $k1 (qw{ dates workers })
    {
        for my $k2 ( keys %{ $available->{$k1} } )
        {
            for my $k3 ( keys %{ $available->{$k1}{$k2} } )
            {
                my $bit = $available->{$k1}{$k2}{$k3};
                $available->{$k1}{$k2}{$k3} = $bit ? 0 : 1;
            }
        }
    }

    return $available;
}

sub _parse_bitmasks : PRIVATE
{
    my ( $self, $args ) = @_;
    my ( $label1, $label2, $bitmask, $default )
        = @{$args}{qw{ rows columns bitmask default }};

    my $options = $self->get_app()->get_options();

    my $rows     = $options->{$label1};
    my $columns  = $options->{$label2};
    my $bitmasks = $options->{$bitmask};

    my $parsed = { $label1 => {}, $label2 => {} };

    for my $row ( @{$rows} )
    {
        my @bits = split //xms, +( $bitmasks->{$row} // '' );

        for my $column ( @{$columns} )
        {
            # Extract the bit and convert to integer
            my $bit = 0 + ( ( shift @bits ) // $default );
            $parsed->{$label1}{$row}{$column} = $bit;
            $parsed->{$label2}{$column}{$row} = $bit;
        }
    }

    return $parsed;
}

# Read the optional "exclusivity" flags
sub _exclusivity
{
    my ($self) = @_;
    return $self->_job_flags( {
        flag    => 'exclusive-jobs',
        default => 0,
    } );
}

# Read the optional "job-count" flags
sub _head_count
{
    my ($self) = @_;
    return $self->_job_flags( {
        flag    => 'job-counts',
        default => 1,
    } );
}

# Read the specified array of flags and assign one to
# each job, falling back to the given default
sub _job_flags
{
    my ( $self, $args )    = @_;
    my ( $flag, $default ) = @{$args}{qw{ flag default }};

    my $options = $self->get_app()->get_options();
    my @flags   = @{ $options->{$flag} // [] };
    my @jobs    = @{ $options->{jobs} };

    my %result;

    for my $job (@jobs)
    {
        my $bit = 0 + ( ( shift @flags ) // $default );
        $result{$job} = $bit;
    }

    return \%result;
}

1;    # End of Roster::Solver::App
__END__

=head1 NAME

Roster::Solver::App - App code for generating duty rosters

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

See the manpage for C<make-roster>. This module is not intended to be
used except by that script.

=head1 PUBLIC METHODS

=head2 new

  $app = new Roster::Solver::App;

Create a new object. Takes no options.

=head2 run

  $app->run(@ARGV);

Actually run the eliminate-dups application.

=head1 PRIVATE METHODS

=head2 _eligibility

Step through the workers and jobs, marking which ones
are eligibile for which, using the bitmasks supplied
in the C<--eligibility> command-line option, if any.
Where bitmasks are missing, it's assumed that every
worker is eligible for every job.

=head2 _parse_bitmasksk

  $worker_eligibility = $self->_parse_bitmasks({
      rows    => 'jobs',
      columns => 'workers',
      bitmask => 'eligibility',
      default => 1,
  });

This method reads bitmasks from the command-line option specified
by the C<bitmask> argument, and parses it as a partial matrix with
rows and columns given by the command-line options specified in the
C<rows> and C<columns> arguments, respectively. Any missing data
in the bitmask is set to the value given in the C<default> argument.

This private method is used for parsing both worker/job eligibility,
and worker/date availability.

=head2 _process_options

Process command-line options and/or loads a config file. Uses
C<CLI::Startup>. This is called internally from the C<run()> method,
which among other things enables the caller to massage the command
line options. It's hard to imagine why you'd want
to, but the real reason for doing it this way is to avoid surprises
by parsing command line args exactly when the caller expects
that to happen.

=head2 _setup_solver

Initialize a C<Roster::Solver> object with the data supplied on the
command line and config file.

=head1 AUTHOR

Len Budney, C<< <len.budney at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-email-fingerprint at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Roster-Solver>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Roster::Solver

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Roster-Solver>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Roster-Solver>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Roster-Solver>

=item * Search CPAN

L<http://search.cpan.org/dist/Roster-Solver>

=back

=head1 SEE ALSO

See B<Mail::Header> for options governing the parsing of email headers.

=head1 COPYRIGHT & LICENSE

Copyright 2006-2011 Len Budney, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of the GPL3.

