# -*- Mode: CPerl -*-

use Test::More 'no_plan';

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

# all returned keys exists
ok(exists $hmk{$_}, "exists - all keys") foreach keys %hmk;

# in scalar context we get the number of keys
is(scalar(keys %hmk), scalar(@idxs), "number of keys - all keys");

foreach $i (@idxs) {
    delete $hmk{${"key$i"}};
    ok(exists $hmk{$_}, "exists - $i") foreach keys %hmk;
    is(scalar(keys %hmk), @idxs - $i, "number of keys - $i");
}
