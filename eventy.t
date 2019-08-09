use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('eventy');
$t->get_ok('/');

done_testing();
