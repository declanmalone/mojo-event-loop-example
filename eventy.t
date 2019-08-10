use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

# Run our script as a server so that it is stateful?
my $t;
if (1) {
  my $server = Mojo::Server::Daemon->new(listen => ["http://127.0.0.1:5555"]);
  my $app = $server->load_app('./eventy') || die;
  $server->start;

  $t = Test::Mojo->new($app);
} else {
  $t = Test::Mojo->new(Mojo::File->new('./eventy'));
}


$t->get_ok('/')->status_is(200)->content_like(qr/started:.*active:.*elapsed:/i);

# test whether we have the add_timer interface (assume parameter = seconds)
$t->get_ok('/add_timer/0')->status_is(200);

# 4d19f4c4: setting a zero-second timer is invalid
# ("4d19f4c4" is just a magic string showing that we went down this test path)
$t->content_like(qr/4d19f4c4/);

# a07a314e: calling get /add_timer/ with a positive value should update
#           the number of started timers.

# Before writing the test, a routine to parse out the timer counts
sub get_counts {
    local($_) = $t->tx->result->body || die;
    if (/started:\s*(\d+).*active:\s*(\d+).*elapsed:\s*(\d+)/) {
      return [$1,$2,$3];
    } else {
      return undef;
    }
}

# We don't care what the add_timer page returns, so we expect the
# following to pass. (Our real test is coming in a bit)
$t->get_ok("/add_timer/99999")->status_is(200);

# self-test our get_counts
is(undef, get_counts()) or die "Internal testing error (get_counts)";

# Now the real test: check that our home page has updated totals
$t->get_ok("/")->status_is(200);
is_deeply(get_counts(), [1,0,0], "a07a314e: are timer counts updated?");


done_testing();
