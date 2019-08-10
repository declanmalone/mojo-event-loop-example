use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

# Run our script as a server so that it is stateful?
my $t;
if (0) {
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
is(get_counts()->[0],1,  "a07a314e: is 'started' count updated?");

# 0ec96f56: Is 'active' count updated?
is_deeply(get_counts(), [1,1,0], "0ec96f56: is 'active' count updated?");

# fc9e616a: Can we wait for less than a second?
$t->get_ok("/add_timer/0.5")->status_is(200);
$t->content_unlike(qr/4d19f4c4/);   # timer can't be zero

# a9922c5e: does an expiring timer update count?
sleep(1);
$t->get_ok("/")->status_is(200);
is_deeply(get_counts(), [2,1,1], "a9922c5e: counter expires OK?");

# b975fad2: non-local control flow with emit/subscribe
#
# Introduce a temporary "trampoline" event emitter so that:
#
# * we can migrate towards better refactored code
# * we can introduce event emitters
# * we can write our test before the code
# * we can continue to evolve the code without breaking past/future tests

# parse new section of /
sub get_bounces {
    local($_) = $t->tx->result->body || die;
    if (/starts:\s*(\d+).*ends:\s*(\d+).*total:\s*(\d+)/) {
      return [$1,$2,$3];
    } else {
      return undef;
    }
}
my ($starts, $ends, $total);
my $blist = get_bounces();

# a3838fd0: interim test to see if / has this section
isnt(undef, $blist, "a3838fd0: Count of bounces in / page?");

# b975fad2: non-local control flow with emit/subscribe
ok($blist->[0] > 0) or say "b975fad2: Count started timers/events";

# f4751860: make sure "total events recieved" counter is updated
ok($blist->[2] > 0) or say "f4751860: count total consumed events";

# 8ce61d2a: migrate timer ending code using event trampoline
ok($blist->[1] > 0) or say "8ce61d2a: count timer finish events";

# Conformance tests. We expect these all to pass since we didn't trip
# up and fail any tests from before the migration to using the
# trampoline. Usually we write tests so that they will fail the first
# time around, but since these tests won't lead to new functionality,
# we can ignore that principle here.

($starts, $ends, $total) = @{$blist};   # unpack event counts
my ($started, $active, $elapsed) = @{get_counts()};

is($started, $active + $elapsed, 'started = active + elapsed counts?');
is($starts, $started,            'start events = started count?');
is($ends, $elapsed,              'end events = elapsed count?');
is($starts + $ends, $total,      'event tally correct?');
is($total, $active + $elapsed*2, 'two events for every elapsed?');
 
# 4705ca02: Introspect into the app to see if noisy_timer can timer
my $noisy_timer = $t->app->{noisy_timer};
ok($noisy_timer->can("timer")) or say "Has NoisyTimer got a timer method?";

done_testing();
