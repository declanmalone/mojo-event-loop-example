use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new(Mojo::File->new('./eventy'));

$t->get_ok('/')->status_is(200)->content_like(qr/started:.*active:.*elapsed:/i);

# test whether we have the add_timer interface (assume parameter = seconds)
$t->get_ok('/add_timer/0')->status_is(200);

# 4d19f4c4: setting a zero-second timer is invalid
# ("4d19f4c4" is just a magic string showing that we went down this test path)
$t->content_like(qr/4d19f4c4/);

done_testing();
