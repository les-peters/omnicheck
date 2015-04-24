package Omnicheck::Mail;

use strict;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);

use Exporter;
$VERSION = '0.01';
@ISA = qw(Exporter);

@EXPORT      = qw();
@EXPORT_OK   = qw();
%EXPORT_TAGS = ( );

sub register {
    my ($self) = @_;
    $self->_add_action_entry('mail');
    $self->_add_peraction_entry('smtphost');

    return $self;
}

sub mail {
    my ($self) = @_;



    return;
}

1;

__DATA__
