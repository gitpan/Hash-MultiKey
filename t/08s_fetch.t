# -*- Mode: CPerl -*-

use Test::More 'no_plan';

BEGIN { use_ok('Hash::MultiKey') }

tie %hmk, 'Hash::MultiKey';

@idxs = 1..6;

@key1 = ("foo");
@key2 = ("foo", "bar", "baz");
@key3 = ("foo", "bar", "baz", "zoo");
@key4 = ("goo");
@key5 = ("goo", "car", "caz");
@key6 = ("goo", "car", "caz", "aoo");

$val1 = undef;
$val2 = 1;
$val3 = 'string';
$val4 = ['array', 'ref'];
$val5 = {hash => 'ref', with => 'two', keys => undef};
$val6 = \7;

# initialize %hmk
$hmk{join $;, @{"key$_"}} = ${"val$_"} foreach @idxs;

# fetch values
is_deeply($hmk{join $;, @{"key$_"}}, ${"val$_"}, "fetch key $_") foreach @idxs;


