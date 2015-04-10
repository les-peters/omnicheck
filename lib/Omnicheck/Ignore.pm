package Omnicheck::Ignore;

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
    $self->_add_action_entry('ignore');

    return $self;
}

sub ignore {
    my ($self) = @_;


    return;
}

1;

__DATA__
