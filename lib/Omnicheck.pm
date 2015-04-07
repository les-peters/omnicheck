package Omnicheck;

use 5.018002;
use strict;
use warnings;
use Carp;
use Data::Dumper;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Omnicheck ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.

our %EXPORT_TAGS = ( 'all' => [ qw(
    new 
    configure 
    go 
    version 
    get_config_file_data 
    get_config_file_mtime
    open_logs
    close_logs
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

sub new {
    my $classname       = shift;
    my $config_filename = shift;
    my $self            = {};
    bless($self, $classname);

    # initialize version, mtime hash
    $self->{'_VERSION'} = $VERSION;
    $self->{'_MTIME'} = {};

    # load configuration file if present
    if ($config_filename) {
        $self->read_config_file($config_filename);
    }
    return $self;
}

sub version {
    my ($self) = @_;
    return $self->{'_VERSION'};
}

sub configure {
    my ($self, $config_filename) = @_;
    $self->read_config_file($config_filename);
    return $self;
}

sub read_config_file {
    my ($self, $config_filename) = @_;
    if (! -e $config_filename) {
        croak "config file $config_filename does not exist";
    }
    open(CONFIG, "< $config_filename") or 
        croak "cannot open config file $config_filename";
    $self->{'_MTIME'}->{$config_filename} = (stat(CONFIG))[9] or die;
    while(<CONFIG>) {
        chomp;

        if (/^#include\s+(.*)$/) {
            my $included_config_file = $1;
            if (! -e $included_config_file) {
                croak "included config file $included_config_file does not exist";
            }
            open(INCL_CONFIG, "< $included_config_file") or 
                croak "cannot open config file $included_config_file";
            $self->{'_MTIME'}->{$included_config_file} = (stat(INCL_CONFIG))[9] or die;
            while(<INCL_CONFIG>) {
                chomp;
                push @{$self->{'config_file_data'}}, $_;
            }
            close(INCL_CONFIG);
        } elsif (/^#!include\s+(.*)$/) {
            my $included_config_script = $1;
            if (! -e $included_config_script) {
                croak "included config script $included_config_script does not exist";
            }
            if (! -x $included_config_script) {
                croak "included config script $included_config_script not executable";
            }
            open(INCL_SCRIPT, "$included_config_script|") or 
                croak "cannot run config script $included_config_script";
            while(<INCL_SCRIPT>) {
                chomp;
                push @{$self->{'config_file_data'}}, $_;
            }
            close(INCL_SCRIPT);
        } else {
            push @{$self->{'config_file_data'}}, $_;
        }
    }
    close(CONFIG);
    return $self;
}

sub get_config_file_data {
    my ($self) = @_;

    return $self->{'config_file_data'};
}

sub get_config_file_mtime {
    my ($self, $config_file) = @_;

    return $self->{'_MTIME'}->{$config_file};
}

sub parse_config_data {
    my ($self) = @_;

    my $mandatory_main_items = {
        'id'      => '',
        'homedir' => ''
    };
    my $mandatory_perstanza_items = {
        'file'    => '',
        'rules'   => ''
    };

    my $config_stanza = 'main';
    for my $config_file_line (@{$self->{'config_file_data'}}) {
        my ($key, $value) = split(/: /, $config_file_line, 2);
        $self->{'config_data'} ||= {};
        $self->{'config_data'}->{$config_stanza} ||= {};
        $self->{'config_data'}->{$config_stanza}->{$key} = $value;
    }

    my $config_ok = 1;

    for my $mandatory_main_item (sort keys %$mandatory_main_items) {
        if (! defined($self->{'config_data'}->{'main'}->{$mandatory_main_item})) {
            $config_ok = 0;
            last;
        }
    }

    for my $stanza (grep(!/main/, sort keys %{$self->{'config_data'}})) {
        for my $mandatory_perstanza_item (sort keys %$mandatory_perstanza_items) {
            if (! defined($self->{'config_data'}->{$stanza}->{$mandatory_perstanza_item})) {
                $config_ok = 0;
                last;
            }
        }
    }

    $self->{'_CONFIG_OK'} = "ok" if $config_ok;
    return $self;
}

sub open_logs {
    my ($self) = @_;

    # establish temporary directory for log files until configuration file data is processed

    my $tmpdir;
    if ($^O eq /win32/i) {
        if ( -d "C:\\TEMP" ) {
            $tmpdir = "C:\\TEMP";
        } elsif ( -d "C:\\TMP" ) {
            $tmpdir = "C:\\TMP";
        } else {
            $tmpdir = "C:";
        }
    } else {
        $tmpdir = "/tmp";
    }

    if (defined($self->{'config_file_data'})) {

        # if configuration file data has been processed, migrate logs to proper directory    

        my $logdir;
        if (defined($self->{'config_file_data'}->{'main'}->{'logdir'})) {
            $logdir = $self->{'config_file_data'}->{'main'}->{'logdir'};
        } else {
            $logdir = $self->{'config_file_data'}->{'main'}->{'homedir'};
        }

        close($self->{'_OUT_fh'});
        close($self->{'_ERR_fh'});

        my $stdout_filename = join("/", 
            $logdir,
            $self->{'config_file_data'}->{'main'}->{'id'}) . ".out";
        my $stderr_filename = join("/", 
            $logdir,
            $self->{'config_file_data'}->{'main'}->{'id'}) . ".err";

        # make sure files can be opened by user

        open($self->{'_OUT_fh'}, ">> $stdout_filename");
        open($self->{'_ERR_fh'}, ">> $stderr_filename");

        select( ( select($self->{'_OUT_fh'}), $| = 1 )[0] );
        select( ( select($self->{'_ERR_fh'}), $| = 1 )[0] );

        # copy temporary log entries to permanent log files

        open(TMP, "< $tmpdir/omnicheck.out");
        while(<TMP>) {
            chomp;
            print $self->{'_OUT_fh'} "$_\n";
        }
        close(TMP);
        unlink("$tmpdir/omnicheck.out");
        $self->log('stdout entries migrated');

        open(TMP, "< $tmpdir/omnicheck.err");
        while(<TMP>) {
            chomp;
            print $self->{'_ERR_fh'} "$_\n";
        }
        close(TMP);
        unlink("$tmpdir/omnicheck.err");
        $self->log('stderr entries migrated');


    } else {

        # if not, open temporary files

        my $stdout_filename = join("/", $tmpdir, 'omnicheck') . ".out";
        my $stderr_filename = join("/", $tmpdir, 'omnicheck') . ".err";

        # make sure files can be opened by user

        open($self->{'_OUT_fh'}, ">> $stdout_filename");
        open($self->{'_ERR_fh'}, ">> $stderr_filename");

        select( ( select($self->{'_OUT_fh'}), $| = 1 )[0] );
        select( ( select($self->{'_ERR_fh'}), $| = 1 )[0] );

        $self->log('temporary stdout created');
        $self->log('temporary stderr created');

    }
    return;
}

sub close_logs {
    my ($self) = @_;
}

sub log {
    my ($self, $message) = @_;
    my $timestamp = &_create_timestamp;
    print $self->{'_OUT_fh'} "$timestamp $message\n";
    return;
}

sub err {
    my ($self, $message) = @_;
    my $timestamp = &_create_timestamp;
    print $self->{'_ERR_fh'} "$timestamp $message\n";
    return;
}


sub go {
    my ($self) = @_;
    if (! defined($self->{'config_file_data'})) {
        carp "cannot go without configuration data";
    }
    $self->open_logs();
    $self->parse_config_data();
    if (! defined($self->{'_CONFIG_OK'})) {
        carp "configuration data missing mandatory item(s)";
    }
    $self->open_logs();
    do {

    } while $self->{'_PERSISTENT'};
    $self->close_logs();

    return $self;
}

1;

__END__

=head1 NAME

Omnicheck - Perl extension for parsing logs with regexes for actionable events

=head1 SYNOPSIS

  use Omnicheck;
  #use Omnicheck daughter-modules

  # all-in-one instantiation/configure
  my $o = Omnicheck->new('./omnicheck.config');

  # separated instantiation and configure
  my $o = new Omnicheck;
  $o->configure('./omnicheck.config');

  $o->go();


=head1 DESCRIPTION

OmniCheck was a Perl script that is designed to monitor the logfiles of 
process (or the direct output of processes), perform regular-expression 
pattern matches against that data, and take a specified notification action(s).

Omnicheck.pm is a Perl module that embodies the essence of the original
script, while allowing users to extend its capabilties by creating their own
sub-modules.  It is the author's hope that these extensions will be created
in such a way that they can be shared with other groups, thus enriching the
community as a whole.

=head1 CONSTRUCTOR

=over 4

=item new ( [ FILENAME ] )

Creates an Omnicheck object.  If it receives a string parameter, an attempt
is made to use it as a filename and read its contents into the newly-created
object.  The object is returned to the caller.

=back

=head1 METHODS

=over 4

=item configure ( FILENAME )

C<configure> accepts one parameter, which it attempts to use as a filename.
If the filename exists and is able to be opened, its contents are read into
the calling object.  The object is returned to the caller.

=item go

C<go> is the executive method for Omnicheck; when called, C<go> will verify
that it is properly configured, then will begin its monitoring and alerting 
functions.  Depending on the configuration, this method will either exit
with a clean return code once its monitoring/alerting functions are complete,
exit with an abnormal return code if an exception condition is detected, or
pause for a specific period of time before resuming its functions.

=back

=head1 EXPORT

None by default.

=head1 SEE ALSO

Omnicheck wiki: http://sourceforge.net/p/omnicheck/wiki/Home/

=head1 AUTHOR

Les Peters, E<lt>les.peters@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 1997-2008 AOL LLC
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
* Neither the name of the AOL LLC nor the names of its contributors may
be used to endorse or promote products derived from this software without
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
