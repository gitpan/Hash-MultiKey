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

# positive exists
ok(exists $hmk{${"key$_"}}, "exists key $_") foreach @idxs;

# negative exists
@nidxs = 1..3;
$nonkey1 = ["hoo"];                                   # beginning
$nonkey2 = ["foo", "bar"];                            # intermediate
$nonkey3 = ["foo", "bar", "baz", "zoo", "none here"]; # end

ok(!exists $hmk{${"nonkey$_"}}, "! exists key $_") foreach @nidxs;
