# -*- Mode: CPerl -*-

use Test::More 'no_plan';

use Data::Dumper;

use Hash::MultiKey;

tie %hmk, 'Hash::MultiKey';

@idxs = 1..7;

$key1 = ["foo"];
$key2 = ["foo", "bar", "baz"];
$key3 = ["foo", "bar", "baz", "zoo"];
$key4 = ["goo"];
$key5 = ["goo", "car", "caz"];
$key6 = ["goo", "car", "caz", "aoo"];
$key7 = ["branch", "with", "no", "bifur$;ations"];

$val1 = undef;
$val2 = 1;
$val3 = 'string';
$val4 = ['array', 'ref'];
$val5 = {hash => 'ref', with => 'two', keys => undef};
$val6 = \7;
$val7 = undef;

# initialize %hmk
$hmk{${"key$_"}} = ${"val$_"} foreach @idxs;

# each in list context
while (($k, $v) = each %hmk) {
    is_deeply($hmk{$k}, $v, "each all: list context");
}

# each in scalar context
$i = 0;
while ($k = each %hmk) {
    ++$i;
    ok(exists $hmk{$k}, 'each all: scalar context');
}
is(scalar(keys %hmk), $i, 'each all: number of iterations');

foreach $i (@idxs) {
    delete $hmk{${"key$i"}};
    while (my ($k, $v) = each %hmk) {
        is_deeply($hmk{$k}, $v, "each $i: @$k");
    }
}

# initialize %hmk again
$hmk{${"key$_"}} = ${"val$_"} foreach @idxs;

# deletion of the last element must be safe
while (($k, $v) = each %hmk) {
    is_deeply(delete $hmk{$k}, $v, 'deletion in each');
}