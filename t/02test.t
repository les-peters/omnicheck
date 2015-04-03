use lib '../lib';
use Omnicheck;
use Data::Dumper;

my $o = Omnicheck->new('./02test.config');
$o->go();
print Dumper($o);
