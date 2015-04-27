package Omnicheck;

use 5.018002;
use strict;
use warnings;
use Carp;
use Data::Dumper;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
    new 
    configure 
    go 
    version 
    _get_config_file_data 
    _get_config_file_mtime
    _add_action_entry
    _add_mandatory_main_entry
    _add_mandatory_perstanza_entry
    _add_mandatory_peraction_entry
    _open_logs
    _close_logs
    _log
    _err
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
    $self->{'_VERSION'}                     = $VERSION;
    $self->{'_MTIME'}                       = {};

    $self->{'_actions'}                     = {};
    $self->{'_mandatory_main_entries'}      = {};
    $self->{'_mandatory_perstanza_entries'} = {};
    $self->{'_mandatory_peraction_entries'} = {};

    $self->_add_mandatory_main_entry('id');
    $self->_add_mandatory_main_entry('homedir');

    $self->_add_mandatory_perstanza_entry('file');
    $self->_add_mandatory_perstanza_entry('rules');

    if ($config_filename) {
        $self->_read_config_file($config_filename);
    }

    return $self;
}

sub _add_action_entry {
    my ($self, $entry_key) = @_;
    $self->{'_actions'}->{$entry_key}++;
    return $self;
}

sub _add_mandatory_main_entry {
    my ($self, $entry_key) = @_;
    $self->{'_mandatory_main_entries'}->{$entry_key}++;
    return $self;
}

sub _add_mandatory_perstanza_entry {
    my ($self, $entry_key) = @_;
    $self->{'_mandatory_perstanza_entries'}->{$entry_key}++;
    return $self;
}

sub _add_mandatory_peraction_entry {
    my ($self, $entry_key) = @_;
    $self->{'_mandatory_peraction_entries'}->{$entry_key}++;
    return $self;
}

sub version {
    my ($self) = @_;
    return $self->{'_VERSION'};
}

sub configure {
    my ($self, $config_filename) = @_;
    $self->_read_config_file($config_filename);
    return $self;
}

sub _read_config_file {
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
            next if /^#/;
            push @{$self->{'config_file_data'}}, $_;
        }
    }
    close(CONFIG);
    return $self;
}

sub _get_config_file_data {
    my ($self) = @_;

    return $self->{'config_file_data'};
}

sub _get_config_file_mtime {
    my ($self, $config_file) = @_;

    return $self->{'_MTIME'}->{$config_file};
}

sub _parse_config_data {
    my ($self) = @_;

    my $config_stanza = 'main';
    for my $config_file_line (@{$self->{'config_file_data'}}) {
        next if $config_file_line =~ /^\s*$/;
        my ($key, $value) = split(/: +/, $config_file_line, 2);
        if ($key eq "block") {
            $config_stanza = $value; 
            next;
        }
        $self->{'_config_data'} ||= {};
        $self->{'_config_data'}->{$config_stanza} ||= {};
        if ($key eq 'file') {
            $self->{'_config_data'}->{$config_stanza}->{$key} ||= [];
            for my $v (split(/\s+/, $value)) {
                push @{$self->{'_config_data'}->{$config_stanza}->{$key}}, $v;
            }
        } else {
            $self->{'_config_data'}->{$config_stanza}->{$key} = $value;
        }
    }

    my $config_ok = 1;

    for my $mandatory_main_entry (sort keys %{$self->{'_mandatory_main_entries'}}) {
        if (! defined($self->{'_config_data'}->{'main'}->{$mandatory_main_entry})) {
            $config_ok = 0;
            last;
        }
    }

    for my $stanza (grep(!/main/, sort keys %{$self->{'_config_data'}})) {
        for my $mandatory_perstanza_entry (sort keys %{$self->{'_mandatory_perstanza_entries'}}) {
            if (! defined($self->{'_config_data'}->{$stanza}->{$mandatory_perstanza_entry})) {
                $config_ok = 0;
                last;
            }
        }
    }

    # need to read the rules files and make sure that any action-based config entries are present

    for my $stanza (grep(!/main/, sort keys %{$self->{'_config_data'}})) {
        $self->{'rule_data'}->{$stanza} ||= [];
        if (defined($self->{'_config_data'}->{$stanza}->{'rules'})) {
            my $rule_files = $self->{'_config_data'}->{$stanza}->{'rules'};
            for my $rule_file (split(/[\s,]/, $rule_files)) {
                my $full_rule_filename = join("/",
                    $self->{'_config_data'}->{'main'}->{'homedir'}, 
                    $rule_file);
                if (! -e $full_rule_filename) {
                    $self->_err("rule file $rule_file does not exist");
                    return 1;
                }
                if (! -r $full_rule_filename) {
                    $self->_err("rule file $rule_file cannot be read by user");
                    return 2;
                }
                my $rule_state = 0;
                my $rule_hash = {};
                open(RULE, "< $full_rule_filename");
                while(<RULE>) {
                    chomp;
                    if ($rule_state == 0) {
                        next if /(^\s*$|^#)/;
                        $rule_hash->{'pattern'} = $_;
                        $rule_state++;
                        next;
                    }

                    if ($rule_state == 1) {
                        next if /^#/;
                        if (/^(
                                \.\.\. |
                                &&     |
                                \|\|   |
                                \+\d+  )
                            \s+
                            (.*)
                            $/x) {
                            $rule_hash->{'pattern'} .= " $1 $2";
                            next;
                        }
                        if (/^\s*$/) {
                            if (scalar @{$rule_hash->{'actions'}} == 0) {
                                $self->_err('found rule with no actions; discarding');
                            } else {
                                push @{$self->{'rule_data'}->{$stanza}}, $rule_hash;
                            }
                            $rule_state = 0;
                            $rule_hash = {};
                        } else {
                            $rule_hash->{'actions'} ||= [];
                            push @{$rule_hash->{'actions'}}, $_;
                        }
                        next;
                    }
                }
                close(RULE);
                if (scalar @{$rule_hash->{'actions'}} == 0) {
                    $self->_err('found rule with no actions; discarding');
                } else {
                    push @{$self->{'rule_data'}->{$stanza}}, $rule_hash;
                }
            }
        }
    }

    for my $stanza (grep(!/main/, sort keys %{$self->{'_config_data'}})) {
        for my $mandatory_perstanza_entry (sort keys %{$self->{'_mandatory_perstanza_entries'}}) {
            if (! defined($self->{'_config_data'}->{$stanza}->{$mandatory_perstanza_entry})) {
                $config_ok = 0;
                last;
            }
        }
    }

    if ($config_ok) {
        $self->{'_CONFIG_OK'} = "ok";
        return $self;
    } else {
        return "configuration not ok";
    }
}

sub _open_logs {
    my ($self) = @_;

    # establish temporary directory for log files until configuration file 
    #   data is processed

    my $tmpdir;
    if ($^O =~ m/win32/i) {
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
    $self->{'_TMPDIR'} = $tmpdir;

    if (defined($self->{'_CONFIG_OK'})) {

        # if configuration file data has been processed, migrate logs to 
        #   proper directory    

        my $logdir;
        if (defined($self->{'_config_data'}->{'main'}->{'logdir'})) {
            $logdir = $self->{'_config_data'}->{'main'}->{'logdir'};
        } else {
            $logdir = $self->{'_config_data'}->{'main'}->{'homedir'};
        }

        if (! -d $logdir)  {
            $self->_err("directory $logdir does not exist");
            return "directory $logdir does not exist";
        }

        if (! -w $logdir)  {
            $self->_err("directory $logdir not writable by user");
            return "directory $logdir not writable by user";
        }

        my $stdout_filename = join("/", 
            $logdir,
            $self->{'_config_data'}->{'main'}->{'id'}) . ".out";

        if (-e $stdout_filename && ! -w $stdout_filename) {
            $self->_err("stdout file $stdout_filename not writable by user");
            return "stdout file $stdout_filename not writable by user";
        }

        my $stderr_filename = join("/", 
            $logdir,
            $self->{'_config_data'}->{'main'}->{'id'}) . ".err";

        if (-e $stdout_filename && ! -w $stderr_filename) {
            $self->_err("stderr file $stderr_filename not writable by user");
            return "stderr file $stderr_filename not writable by user";
        }

        $self->_close_logs();

        if (! open($self->{'_OUT_fh'}, ">> $stdout_filename")) {
            return "stdout file $stdout_filename open fail";
        }

        if (! open($self->{'_ERR_fh'}, ">> $stderr_filename")) {
            return "stderr file $stderr_filename open fail";
        }

        select( ( select( $self->{'_OUT_fh'} ), $| = 1 )[0] );
        select( ( select( $self->{'_ERR_fh'} ), $| = 1 )[0] );

        # copy temporary log entries to permanent log files

        if (! open(TMP, "< $tmpdir/omnicheck.out")) {
            return "cannot read $tmpdir/omnicheck.out";
        }
        while(<TMP>) {
            chomp;
            print { $self->{'_OUT_fh'} } "$_\n";
        }
        close(TMP);
        unlink("$tmpdir/omnicheck.out");
        $self->_log('stdout entries migrated');

        if (! open(TMP, "< $tmpdir/omnicheck.err")) {
            return "cannot read $tmpdir/omnicheck.err";
        }
        while(<TMP>) {
            chomp;
            print { $self->{'_ERR_fh'} } "$_\n";
        }
        close(TMP);
        unlink("$tmpdir/omnicheck.err");
        $self->_log('stderr entries migrated');


    } else {

        # if not, open temporary files

        my $stdout_filename = join("/", $tmpdir, 'omnicheck') . ".out";
        my $stderr_filename = join("/", $tmpdir, 'omnicheck') . ".err";

        # make sure files can be opened by user

        open($self->{'_OUT_fh'}, "> $stdout_filename") or croak "3";
        open($self->{'_ERR_fh'}, "> $stderr_filename") or croak "4";

        select( ( select( $self->{'_OUT_fh'} ), $| = 1 )[0] );
        select( ( select( $self->{'_ERR_fh'} ), $| = 1 )[0] );

        $self->_log('temporary stdout created');
        $self->_log('temporary stderr created');

    }
    return;
}

sub _close_logs {
    my ($self) = @_;
    close($self->{'_OUT_fh'});
    close($self->{'_ERR_fh'});
    return;
}

sub _log {
    my ($self, $message) = @_;
    my $timestamp = _create_timestamp();

    my ($called_sub) = ( caller(1) )[3] || "";
    $called_sub =~ s/^.[^:]+:://x;
    my ($called_line) = ( caller(0) )[2];

    my $id = $self->{'_config_data'}->{'main'}->{'id'} || "unknown";
    print { $self->{'_OUT_fh'} } 
        "$timestamp [$id] $called_sub:$called_line $message\n";
    return;
}

sub _err {
    my ($self, $message) = @_;
    my $timestamp = _create_timestamp();

    my ($called_sub) = ( caller(2) )[3] || "";
    $called_sub =~ s/^.[^:]+:://x;
    my ($called_line) = ( caller(1) )[2];

    my $id = $self->{'_config_data'}->{'main'}->{'id'} || "unknown";
    print { $self->{'_ERR_fh'} } 
        "$timestamp [$id] $called_sub:$called_line $message\n";
    return;
}

sub _create_timestamp {
   my @lt = localtime();
   my $timestamp = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
        $lt[5] + 1900, $lt[4] + 1, $lt[3],
        $lt[2], $lt[1], $lt[0]);
   return $timestamp;
}

sub _get_file_checkpoints {
    my ($self) = @_;

    my $checkpoint_filename = join("/",
        $self->{'_TMPDIR'},
        $self->{'_config_data'}->{'main'}->{'id'}) . ".ckpt";
    if (! -e $checkpoint_filename) {
        $self->_log("checkpoint file $checkpoint_filename not found");
        return;
    }
    if (! -r $checkpoint_filename) {
        $self->_err('checkpoint file cannot be read by user');
        return;
    }
    my $checkpoint_entries = 0;
    if (-e $checkpoint_filename && -r $checkpoint_filename) {
        open(CKPT, "< $checkpoint_filename") or croak;
        $self->_log('checkpoint file opened for reading');
        while(<CKPT>) {
            chomp;
            my ($stanza, $monitored_file, $checkpoint) = split(/\t/);
            $self->{'_checkpoint_data'}                              ||= {};
            $self->{'_checkpoint_data'}->{$stanza}                   ||= {};
            $self->{'_checkpoint_data'}->{$stanza}->{$monitored_file}  = $checkpoint;
            $checkpoint_entries++;
        }
        close(CKPT);
    }
    my $msg = sprintf "read %d checkpoint entries", $checkpoint_entries;
    $self->_log($msg);

    return $self;
}

sub _update_file_checkpoints {
    my ($self) = @_;

    my $checkpoint_filename = join("/",
        $self->{'_TMPDIR'},
        $self->{'_config_data'}->{'main'}->{'id'}) . ".ckpt";
    my $temp_checkpoint_filename = $checkpoint_filename . ".tmp";

    if (! -e $checkpoint_filename) {
        $self->_log("checkpoint file $checkpoint_filename not found: must create");
    } elsif (! -w $checkpoint_filename) {
        $self->_err('checkpoint file cannot be read by user');
        return;
    }

    my $checkpoint_entries = 0;
    open(CKPT, "> $temp_checkpoint_filename") or croak;
    $self->_log('temp checkpoint file opened for writing');
    for my $stanza (grep(!/main/, sort keys %{$self->{'_config_data'}})) {
        $self->_log("stanza $stanza");
        for my $monitored_file (@{$self->{'_config_data'}->{$stanza}->{'file'}}) {
            $self->_log("monitored_file $monitored_file");
            my $checkpoint_value  = 
                $self->{'_checkpoint_data'}->{$stanza}->{$monitored_file};
            $self->_log("ckpt $checkpoint_value");
            printf CKPT "%s\t%s\t%d\n",
                $stanza,
                $monitored_file,
                $checkpoint_value;
            $checkpoint_entries++;
        }
    }
    close(CKPT);

    if (! unlink($checkpoint_filename)) {
        $self->_err('checkpoint file cannot be deleted by user');
        return;
    }

    if (! rename($temp_checkpoint_filename, $checkpoint_filename) ) {
        $self->_err('temp checkpoint file cannot be renamed by user');
        return;
    } else {
        $self->_log("temp checkpoint file $temp_checkpoint_filename moved to $checkpoint_filename");
    }

    my $msg = sprintf "wrote %d checkpoint entries", $checkpoint_entries;
    $self->_log($msg);

    return $msg;
}

sub _process_data {
    my ($self) = @_;

    $self->{'_file_data'} ||= {};
    for my $stanza (grep(!/main/, sort keys %{$self->{'_config_data'}})) {
        $self->_log("stanza $stanza");
        $self->{'_file_data'}->{$stanza} ||= {};
        for my $monitored_file (@{$self->{'_config_data'}->{$stanza}->{'file'}}) {
            $self->_log("monitored file $monitored_file");
            $self->{'_file_data'}->{$stanza}->{$monitored_file} ||= [];
            # get new data, if any
            my $previous_checkpoint = 
                $self->{'_checkpoint_data'}->{$stanza}->{$monitored_file} || 0;
            $self->_log("found prev checkpoint $previous_checkpoint for $monitored_file");
            if (! open(DATA, "< $monitored_file")) {
                $self->_err("cannot open $monitored_file for reading");
                return;
            } else {
                $self->_log("opened $monitored_file for reading");
            }
            if (-s DATA < $previous_checkpoint) {
                $self->_log("rolled checkpoint on $monitored_file to 0");
                $previous_checkpoint = 0;
            }
            seek(DATA, $previous_checkpoint, 0);
            while(<DATA>) {
                chomp;
                push @{$self->{'_file_data'}->{$stanza}->{$monitored_file}}, $_;
            }
            my $tell = tell DATA;
            $self->_log("tell $tell");
            $self->{'_checkpoint_data'}->{$stanza}->{$monitored_file} = $tell;
            close(DATA);
            my $message = sprintf "found %d lines in %s",
                scalar @{$self->{'_file_data'}->{$stanza}->{$monitored_file}}, 
                $monitored_file;
            $self->_log($message);
            # analyze new data, if any
            for my $data (@{$self->{'_file_data'}->{$stanza}->{$monitored_file}}) {
                $self->_log("data $data");
            }

        }

    }

    return $self;
}

sub go {
    my ($self) = @_;
    my $rc;
    $rc = $self->_open_logs();
    return $rc if $rc;
    if (! defined($self->{'config_file_data'})) {
        $self->_err("cannot go without configuration data");
        return "cannot go without configuration data";
    } else {
        $rc = $self->_parse_config_data();
        if (! defined($self->{'_CONFIG_OK'})) {
            $self->_err("configuration data missing mandatory item(s)");
            return "configuration data missing mandatory item(s)";
        }
        $rc = $self->_open_logs();
        return $rc if $rc;
        do {
            $self->_get_file_checkpoints();
            $self->_process_data();
            $rc = $self->_update_file_checkpoints();
            return $rc if $rc;
        } while $self->{'_PERSISTENT'};
    }
    $self->_close_logs();
    return;
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

=head1 STANDARD METHODS

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

=head1 DAUGHTER-MODULE METHODS

The following methods are to be used in the creation of 'daughter' modules to
extend the functionality of Omnicheck, either internally to an organization
or for use by all via open source.

=over 4

=item _add_action_entry

C<_add_action_entry> is the method that daughter modules can use
to add to the list of actions to take when a regular expression
matches content from the log/program being monitored.

=item _add_mandatory_main_entry

C<_add_mandatory_main_entry> is the method that daughter modules can use
to add to the list of mandatory entries for the Omnicheck configuration file
main stanza.

=item _add_mandatory_perstanza_entry

C<_add_mandatory_perstanza_entry> is the method that daughter modules can use
to add to the list of mandatory entries for the Omnicheck configuration file
stanzas (beyond the 'main' stanza, if present).

=item _add_mandatory_peraction_entry

C<_add_mandatory_peraction_entry> is the method that daughter modules can use
to add to the list of mandatory entries for the Omnicheck configuration file
stanzas when a particular action is used.

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
