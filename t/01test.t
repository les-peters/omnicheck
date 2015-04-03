use lib '../lib';
use Omnicheck;
use Data::Dumper;

my $o = Omnicheck->new('./01test.config');
print Dumper($o);
