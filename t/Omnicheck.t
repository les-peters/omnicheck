#!perl

use lib "../lib";
use strict;
use warnings;

use Test::More 'no_plan';

my @subs = qw(
    new 
    configure 
    go 
    version 
    get_config_file_data 
    get_config_file_mtime
);

use_ok( 'Omnicheck', @subs                   );
can_ok( __PACKAGE__, 'new'                   );
can_ok( __PACKAGE__, 'configure'             );
can_ok( __PACKAGE__, 'go'                    );
can_ok( __PACKAGE__, 'version'               );
can_ok( __PACKAGE__, 'get_config_file_data'  );
can_ok( __PACKAGE__, 'get_config_file_mtime' );

my $o_01 = new Omnicheck;
isa_ok( $o_01, 'Omnicheck');
ok($o_01->version(), '0.01');

$o_01->configure('./00config');
ok($o_01->get_config_file_data(), 
     [ 'key: value' ]);

my $o_02 = new Omnicheck('./00config');
ok($o_02->get_config_file_data(),              [ 'key: value' ]);
ok($o_02->get_config_file_mtime('./00config'), qr/^d+$/);

my $o_03 = new Omnicheck('./01config');
my $o_03_config_data = $o_03->get_config_file_data();
my $o_03_config_test = [
    'key1: value1',
    'key2: value2',
    'key3: value3'
];

is_deeply($o_03_config_data, $o_03_config_test, "equivalent config data");

