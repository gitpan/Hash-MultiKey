# -*- Mode: CPerl -*-

use Test::More 'no_plan';

use Hash::MultiKey;

tie %hmk, 'Hash::MultiKey';

@idxs = 1..4;

$key1 = [""];
$key2 = ["", "", ""];
$key3 = ["", "", "", ""];
$key4 = ["", "", "", "", "", ""];

$val1 = undef;
$val2 = 1;
$val3 = 'string';
$val4 = ['array', 'ref'];

# initialize %hmk
$hmk{${"key$_"}} = ${"val$_"} foreach @idxs;

# fetch values
is_deeply($hmk{${"key$_"}}, ${"val$_"}, "fetch key $_") foreach @idxs;

# delete all
foreach $i (@idxs) {
    is_deeply(delete $hmk{${"key$i"}}, ${"val$i"}, "delete key $i");
    ok(!exists $hmk{${"key$i"}}, "! exists key $i");
}

is(scalar(%hmk), 0, 'scalar empty %hmk')
