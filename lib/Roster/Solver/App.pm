package Roster::Solver::App;

use warnings;
use strict;

use Class::Std;

use Carp qw( croak );
use CLI::Startup;

use Roster::Solver;

our $VERSION = '0.01';

# Attributes
my %app_of : ATTR( :get<app> )
    ;    # Command line options, etc., from CLI::Startup;

# Run the actual app. This is the meat of the app.
sub run
{
    my ( $self, @options ) = @_;

    $self->_process_options(@options);

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
                'exclusive-jobs=i@' =>
                    'Flags indicating jobs that fully occupy a worker',
                'job-counts|job-count=i@' =>
                    'Number of people needed for each job',
                'jobs|job=s@'       => 'List of jobs to be done',
                'workers|worker=s@' => 'List of workers to roster',
                'eligibility:s%' =>
                    'Hash of bitmasks of jobs workers are eligible for',
            },
        } );
    $app->init();

    $app_of{ ident($self) } = $app;

    return;
}

1;    # End of Email::Fingerprint
__END__

=head1 NAME

Roster::Solver::App - App code for generating duty rosters

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

See the manpage for C<make-roster>. This module is not intended to be
used except by that script.

=head1 METHODS

=head2 new

  $app = new Roster::Solver::App;

Create a new object. Takes no options.

=head2 run

  $app->run(@ARGV);

Actually run the eliminate-dups application.

=head2 _process_options

Process command-line options and/or loads a config file. Uses
C<CLI::Startup>. This is called internally from the C<run()> method,
which among other things enables the caller to massage the command
line options. It's hard to imagine why you'd want
to, but the real reason for doing it this way is to avoid surprises
by parsing command line args exactly when the caller expects
that to happen.

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

