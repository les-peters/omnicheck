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

my $config_file;

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

$config_file = './00config';
open(CFG, "> $config_file");
print CFG "key: value\n";
close(CFG);
$o_00->configure($config_file);
ok($o_00->_get_config_file_data(), 
     [ 'key: value' ]);
unlink($config_file);

$config_file = './02config';
open(CFG, "> $config_file");
print CFG "id: omnicheck\n";
print CFG "homedir: /opt/omnicheck\n";
close(CFG);
my $o_02 = new Omnicheck($config_file);
ok($o_02->_get_config_file_data(),              [ 'key: value' ]);
ok($o_02->_get_config_file_mtime($config_file), qr/^d+$/);
unlink($config_file);

$config_file = './03config';
open(CFG, "> $config_file");
print CFG "key1: value1\n";
print CFG "#include ${config_file}.incl_file\n";
print CFG "#!include ${config_file}.incl_script\n";
close(CFG);
open(CFG, "> ${config_file}.incl_file");
print CFG "key2: value2\n";
close(CFG);
open(CFG, "> ${config_file}.incl_script");
print CFG "#!/bin/sh\n";
print CFG "\n";
print CFG "echo 'key3: value3'\n";
close(CFG);
chmod(0755, "${config_file}.incl_script");
my $o_03 = new Omnicheck($config_file);
my $o_03_config_data = $o_03->_get_config_file_data();
my $o_03_config_test = [
    'key1: value1',
    'key2: value2',
    'key3: value3'
];

is_deeply($o_03_config_data, $o_03_config_test, "equivalent config data");
unlink($config_file);
unlink("${config_file}.incl_file");
unlink("${config_file}.incl_script");

$config_file = './04config';
open(CFG, "> $config_file");
print CFG "id: omnicheck-04\n";
print CFG "homedir: /opt/omnicheck\n";
close(CFG);
my $o_04 = new Omnicheck($config_file);
$o_04->go();
unlink($config_file);

$config_file = './05config';
open(CFG, "> $config_file");
print CFG "id: omnicheck-05\n";
close(CFG);
my $o_05 = new Omnicheck($config_file);
ok($o_05->go(), qr/configuration data missing mandatory item\(s\)/);
unlink($config_file);

my $o_06 = new Omnicheck;
ok($o_06->go(), qr/cannot go without configuration data/);

$config_file = './07config';
open(CFG, "> $config_file");
print CFG "id: omnicheck-07\n";
print CFG "homedir: /opt/omnicheck\n";
print CFG "logdir: /opt/not_there\n";
close(CFG);
my $o_07 = new Omnicheck($config_file);
ok($o_07->go(), qr/directory \S+ does not exist/);
unlink($config_file);

$config_file = './08config';
open(CFG, "> $config_file");
print CFG "id: omnicheck-08\n";
print CFG "homedir: /opt/omnicheck\n";
print CFG "logdir: /\n";
close(CFG);
my $o_08 = new Omnicheck($config_file);
ok($o_08->go(), qr/directory \S+ not writable by user/);
unlink($config_file);

$config_file = './09config';
open(CFG, "> $config_file");
print CFG "id: 09\n";
print CFG "homedir: /opt/omnicheck\n";
print CFG "logdir: .\n";
close(CFG);
open(OUT, "> ./09.out"); close(OUT); chmod(0444, './09.out');
open(ERR, "> ./09.err"); close(ERR); chmod(0644, './09.err');
my $o_09 = new Omnicheck($config_file);
ok($o_09->go(), qr/stdout file \S+ not writable by user/);
unlink($config_file);
unlink('./09.out');
unlink('./09.err');

$config_file = './10config';
open(CFG, "> $config_file");
print CFG "id: 10\n";
print CFG "homedir: /opt/omnicheck\n";
print CFG "logdir: .\n";
close(CFG);
open(OUT, "> ./10.out"); close(OUT); chmod(0644, './10.out');
open(ERR, "> ./10.err"); close(ERR); chmod(0444, './10.err');
my $o_10 = new Omnicheck('./10config');
ok($o_10->go(), qr/stderr file \S+ not writable by user/);
unlink($config_file);
unlink('./10.out');
unlink('./10.err');

use_ok( 'Omnicheck::File'   );
use_ok( 'Omnicheck::Ignore' );

$config_file = './11config';
open(CFG, "> $config_file");
print CFG "id: 11\n";
print CFG "homedir: /opt/omnicheck\n";
print CFG "logdir: /opt/omnicheck\n";
print CFG "\n";
print CFG "block: 1\n";
print CFG "file: /var/log/\n";
close(CFG);

my $o_11 = new Omnicheck($config_file);
Omnicheck::File::register($o_11);
Omnicheck::Ignore::register($o_11);
ok($o_11->go(), qr/configuration not ok/);
unlink($config_file);

$config_file = './12config';
open(CFG, "> $config_file");
print CFG "id: 12\n";
print CFG "homedir: /opt/omnicheck\n";
print CFG "\n";
print CFG "block: 1\n";
print CFG "file:  ./12test.log ./12test.log2\n";
print CFG "rules: 12rules/\n";
close(CFG);

open(RULES, "> ./12rules");  close(RULES); chmod(0644, './12rules');
open(LOG, "> ./12test.log"); close(LOG);   chmod(0644, './12test.log');
my $o_12 = new Omnicheck('./12config');
Omnicheck::File::register($o_12);
Omnicheck::Ignore::register($o_12);
$o_12->go();
unlink($config_file);
unlink('./12test.log');
unlink('./12rules');

$config_file = './13config';
open(CFG, "> $config_file");
print CFG "id: 13\n";
print CFG "homedir: /opt/omnicheck\n";
print CFG "\n";
print CFG "block: 1\n";
print CFG "file:  /tmp/date.log\n";
print CFG "rules: 13rules/\n";
close(CFG);

open(RULES, "> ./13rules");  close(RULES); chmod(0644, './13rules');
my $o_13 = new Omnicheck($config_file);
Omnicheck::File::register($o_13);
Omnicheck::Ignore::register($o_13);
$o_13->go();
unlink($config_file);
unlink('./13rules');

$config_file = './14config';
open(CFG, "> $config_file");
print CFG "id: 14\n";
print CFG "homedir: .\n";
print CFG "\n";
print CFG "block: 1\n";
print CFG "file:  /tmp/date.log\n";
print CFG "rules: 14rules/\n";
close(CFG);

open(RULES, "> ./14rules");
print RULES "error\n";
print RULES "file /tmp/error_file\n";
print RULES "\n";
print RULES ".*\n";
print RULES "file /tmp/all\n";
print RULES "\n";
print RULES "a\n";
print RULES "... b\n";
print RULES "file /tmp/a_dot_b\n";
print RULES "\n";
print RULES "a\n";
print RULES "&& b\n";
print RULES "file /tmp/a_amp\n";
print RULES "\n";
print RULES "a\n";
print RULES "|| b\n";
print RULES "file /tmp/a_or_b\n";
print RULES "\n";
print RULES "a\n";
print RULES "+3 b\n";
print RULES "file /tmp/a_plus_b\n";
close(RULES);

my $o_14 = new Omnicheck($config_file);
Omnicheck::File::register($o_14);
Omnicheck::Ignore::register($o_14);
$o_14->go();
unlink($config_file);
unlink('./14rules');
unlink('./14.out');
unlink('./14.err');

$config_file = './15config';
open(CFG, "> $config_file");
print CFG "id: 15\n";
print CFG "homedir: .\n";
print CFG "\n";
print CFG "block: 1\n";
print CFG "file:  /tmp/date.log\n";
print CFG "rules: 15rules/\n";
close(CFG);

open(RULES, "> ./15rules");
print RULES "error\n";
print RULES "file /tmp/error_file\n";
print RULES "file /tmp/second_file\n";
print RULES "\n";
print RULES ".*\n";
print RULES "ignore\n";
close(RULES);

my $o_15 = new Omnicheck($config_file);
Omnicheck::File::register($o_15);
Omnicheck::Ignore::register($o_15);
$o_15->go();
unlink($config_file);
unlink('./15rules');
unlink('./15.out');
unlink('./15.err');

$config_file = './16config';
open(CFG, "> $config_file");
print CFG "id: 16\n";
print CFG "homedir: .\n";
print CFG "\n";
print CFG "block: 1\n";
print CFG "file:  ./16test.file\n";
print CFG "rules: 16rules\n";
close(CFG);

open(RULES, "> ./16rules");
print RULES ".*\n";
print RULES "ignore\n";
close(RULES);

open(FILE, "> ./16test.file");
print FILE "abcdefghi\n";
close(FILE);
system('cat ./16test.file');

my $o = new Omnicheck($config_file);
Omnicheck::Ignore::register($o);
ok($o->go(), qr/wrote 1 checkpoint entries/);

open(FILE, ">> ./16test.file") or die;
print FILE "abcdefghi\n";
close(FILE);
system('cat ./16test.file');

ok($o->go(), qr/wrote 1 checkpoint entries/);

unlink($config_file);
unlink('./16rules');
system('cat ./16.out');
unlink('./16.out');
unlink('./16.err');

__END__
