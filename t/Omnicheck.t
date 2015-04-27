#!perl

use lib "../lib";
use strict;
use warnings;
use Data::Dumper;

use Test::More 'no_plan';

my @subs = qw(
    new 
    configure 
    go 
    version 
    _get_config_file_data 
    _get_config_file_mtime
);

use_ok( 'Omnicheck', @subs                    );
can_ok( __PACKAGE__, 'new'                    );
can_ok( __PACKAGE__, 'configure'              );
can_ok( __PACKAGE__, 'go'                     );
can_ok( __PACKAGE__, 'version'                );
can_ok( __PACKAGE__, '_get_config_file_data'  );
can_ok( __PACKAGE__, '_get_config_file_mtime' );

my $o_00 = new Omnicheck;
isa_ok( $o_00, 'Omnicheck');
ok($o_00->version(), '0.01');

open(CFG, "> ./00config");
print CFG "key: value\n";
close(CFG);
$o_00->configure('./00config');
ok($o_00->_get_config_file_data(), 
     [ 'key: value' ]);
unlink("./00config");

my $o_02 = new Omnicheck('./02config');
ok($o_02->_get_config_file_data(),              [ 'key: value' ]);
ok($o_02->_get_config_file_mtime('./02config'), qr/^d+$/);

my $o_03 = new Omnicheck('./03config');
my $o_03_config_data = $o_03->_get_config_file_data();
my $o_03_config_test = [
    'key1: value1',
    'key2: value2',
    'key3: value3'
];

is_deeply($o_03_config_data, $o_03_config_test, "equivalent config data");

my $o_04 = new Omnicheck('./04config');
$o_04->go();

my $o_05 = new Omnicheck('./05config');
ok($o_05->go(), qr/configuration data missing mandatory item\(s\)/);

my $o_06 = new Omnicheck;
ok($o_06->go(), qr/cannot go without configuration data/);

my $o_07 = new Omnicheck('./07config');
ok($o_07->go(), qr/directory \S+ does not exist/);

my $o_08 = new Omnicheck('./08config');
ok($o_08->go(), qr/directory \S+ not writable by user/);

my $o_09 = new Omnicheck('./09config');
ok($o_09->go(), qr/stdout file \S+ not writable by user/);

my $o_10 = new Omnicheck('./10config');
ok($o_10->go(), qr/stderr file \S+ not writable by user/);

use_ok( 'Omnicheck::File'   );
use_ok( 'Omnicheck::Ignore' );

my $o_11 = new Omnicheck('./11config');
Omnicheck::File::register($o_11);
Omnicheck::Ignore::register($o_11);
ok($o_11->go(), qr/configuration not ok/);

my $o_12 = new Omnicheck('./12config');
Omnicheck::File::register($o_12);
Omnicheck::Ignore::register($o_12);
$o_12->go();

my $o_13 = new Omnicheck('./13config');
Omnicheck::File::register($o_13);
Omnicheck::Ignore::register($o_13);
$o_13->go();

my $o_14 = new Omnicheck('./14config');
Omnicheck::File::register($o_14);
Omnicheck::Ignore::register($o_14);
$o_14->go();

my $o_15 = new Omnicheck('./15config');
Omnicheck::File::register($o_15);
Omnicheck::Ignore::register($o_15);
$o_15->go();
print Dumper($o_15);

__END__
