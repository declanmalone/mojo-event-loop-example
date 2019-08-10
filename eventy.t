use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new(Mojo::File->new('./eventy'));

$t->get_ok('/')->status_is(200)->content_like(qr/started:.*active:.*elapsed:/i);

# test whether we have the add_timer interface (assume parameter = seconds)
$t->get_ok('/add_timer/0')->status_is(200);

done_testing();
