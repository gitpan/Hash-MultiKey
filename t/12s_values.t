# -*- Mode: CPerl -*-

use Test::More 'no_plan';

use Data::Dumper;

use Hash::MultiKey;

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

# values must be returned in the same order as keys reports their
# corresponding keys
push @vals, $hmk{$_} foreach keys %hmk;
is_deeply([values %hmk], \@vals, "values - all");

# aliased values?
$_ = 1 foreach values %hmk;
is($_, 1, 'aliased value') foreach values %hmk;

# initialize %hmk again
$hmk{join $;, @{"key$_"}} = ${"val$_"} foreach @idxs;

foreach $i (@idxs) {
    delete $hmk{join $;, @{"key$_"}};
    @vals = ();
    push @vals, $hmk{$_} foreach keys %hmk;
    is_deeply([values %hmk], \@vals, "values - all");
}
