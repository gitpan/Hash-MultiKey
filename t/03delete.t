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

# delete all
foreach $i (@idxs) {
    # delete must return the element being removed if it exists
    is_deeply(delete $hmk{${"key$i"}}, ${"val$i"}, "delete key $i");
    ok(!exists $hmk{${"key$i"}}, "! exists key $i");
}

# delete must return undef on non-existent entries
ok(!defined $hmk{['zoo']}, 'delete non-existent entries');
