package Hash::MultiKey;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.01';

# ---[ Implementation Overview ]----------------------------------------
#
# This tied hash is implemented as kind of a tree.
#
# The structure follows this pattern:
#
#   $self->{tree}->{foo =>                   # node for key ["foo"]
#                         [value,            # value at this node, if any
#                          has_value,        # flag, for exists()
#                          subtree,          # nested hashref
#                          already_visited]} # flag, for tree walking
#
# In the example above, if ["foo", "bar"] was a key of the tied hash
# $self the hash under subtree would have "bar" as key, with its
# corresponding arrayref. See how it works?
#
# So it is basically a nested hash, only nesting has arrayrefs between
# levels to allow values in any of the nodes. Those arrayrefs are
# encapsulated in the private class Hash::MultiKey::Node you'll find at
# the end of this file.
#
# The current iterator of the hash is represented in a pair of arrayrefs
# which are object attributes: the current key-chain, and the current
# subtree-chain. This way in NEXTKEY we can go directly to the current
# node.
#
# ----------------------------------------------------------------------


# Construct a new hash.
sub TIEHASH {
    my ($class_or_obj) = @_;

    my $self = {};
    $self->{tree} = {};

    return bless $self, ref $class_or_obj || $class_or_obj;
}


# Clear the hash.
sub CLEAR {
    my ($self) = @_;

    delete $self->{iter_keys};
    delete $self->{iter_trees};
    $self->{tree} = {};
}


# Fetch value if key exists, or else return undef.
sub FETCH {
    my ($self, $keys) = @_;

    # syntactic sugar
    $keys = [$keys eq '' ? ('') : split /$;/, $keys, -1] unless ref $keys eq 'ARRAY';

    # walk down the tree until the last but one node
    my $tree = $self->{tree};
    foreach my $key (@$keys[0..($#$keys-1)]) {
        return undef unless exists $tree->{$key};
        $tree = $tree->{$key}->tree;
    }

    my $last_key = $keys->[-1];
    return exists $tree->{$last_key} ? $tree->{$last_key}->value : undef;
}


# Store value under given key. Construct intermediate nodes as
# needed. Return the very value (AFAIK not required, but recommended).
sub STORE {
    my ($self, $keys, $value) = @_;

    # syntactic sugar
    $keys = [$keys eq '' ? ('') : split /$;/, $keys, -1] unless ref $keys eq 'ARRAY';

    # walk down the tree until the last but one node
    my $tree = $self->{tree};
    foreach my $key (@$keys[0..($#$keys-1)]) {
        $tree->{$key} = Hash::MultiKey::Node->new unless exists $tree->{$key};
        $tree = $tree->{$key}->tree;
    }

    my $last_key = $keys->[-1];
    $tree->{$last_key} = Hash::MultiKey::Node->new unless exists $tree->{$last_key};
    $tree->{$last_key}->value($value);

    return $value; # recommended behaviour
}


# If the key exists delete the corresponding entry and return its value.
# Return undef otherwise.
#
# If the key exists, after deletion purge the tree as much as possible.
sub DELETE {
    my ($self, $keys) = @_;

    # syntactic sugar
    $keys = [$keys eq '' ? ('') : split /$;/, $keys, -1] unless ref $keys eq 'ARRAY';

    # keep track of the path to purge the tree later, for all $i
    # $keys_stack[$i] is the key chosen in tree $trees_stack[$i]
    my @keys_stack  = ();
    my @trees_stack = ();

    # walk down the tree until the last but one node
    my $tree = $self->{tree};
    foreach my $key (@$keys[0..($#$keys-1)]) {
        return undef unless exists $tree->{$key};
        push @keys_stack, $key;
        push @trees_stack, $tree;
        $tree = $tree->{$key}->tree;
    }

    my $last_key = $keys->[-1];

    return undef unless exists $tree->{$last_key};
    return undef unless $tree->{$last_key}->has_value;

    push @keys_stack, $last_key;
    push @trees_stack, $tree;

    my $rmed_value = $tree->{$last_key}->rm_value;

    # purge the tree
    while ($tree = pop @trees_stack) {
        my $key  = pop @keys_stack;
        last if %{$tree->{$key}->tree};
        last if $tree->{$key}->has_value;
        delete $tree->{$key};
    }

    return $rmed_value;
}


# Return true if and only if the given key exists in the hash, no matter
# its associated value.
sub EXISTS {
    my ($self, $keys) = @_;

    # syntactic sugar
    $keys = [$keys eq '' ? ('') : split /$;/, $keys, -1] unless ref $keys eq 'ARRAY';

    # walk down the tree until the last but one node
    my $tree = $self->{tree};
    foreach my $key (@$keys[0..($#$keys-1)]) {
        return undef unless exists $tree->{$key};
        $tree = $tree->{$key}->tree;
    }

    my $last_key = $keys->[-1];
    return exists $tree->{$last_key} && $tree->{$last_key}->has_value;
}


# Reset all already_visited flags, and reset all iterators in nested
# hashes.
#
# If the hash is empty return undef, otherwise return a copy of the
# first key to be visited according to each().
sub FIRSTKEY {
    my ($self) = @_;

    $self->reset($self->{tree});

    delete $self->{iter_keys};
    delete $self->{iter_trees};

    $self->firstkeys($self->{tree});

    return exists $self->{iter_keys} ? [ @{$self->{iter_keys}} ] : undef;
}


# Private: reset all already_visited flags.
sub reset {
    my ($self, $tree) = @_;

    foreach my $node (values %$tree) {
        $node->already_visited(0);
        $self->reset($node->tree);
    }
}


# Private: construct the first iteration node.
sub firstkeys {
    my ($self, $tree) = @_;

    if (my ($key, $node) = each %$tree) {
        push @{$self->{iter_keys}}, $key;
        push @{$self->{iter_trees}}, $tree;
        $self->firstkeys($node->tree) unless $node->has_value;
    }
}


# Return a copy of the key-chain corresponding to the next node with
# value in each() order. Return undef if we have exhausted the tree.
sub NEXTKEY {
    my ($self) = @_;

    while (@{$self->{iter_keys}}) {
        my $current_key  = $self->{iter_keys}[-1];
        my $current_tree = $self->{iter_trees}[-1];

        # This provides support for deletion of the current key in
        # each().
        unless (exists $current_tree->{$current_key}) {
            pop @{$self->{iter_keys}};
            pop @{$self->{iter_trees}};
            next;
        }

        my $current_node = $current_tree->{$current_key};

        unless ($current_node->already_visited) {
            # if $current_node has not been visited already we'll try to
            # walk down the tree
            if (my ($key_down, $node_down) = each %{$current_node->tree}) {
                # go down a level if this node has a non-empty hash
                push @{$self->{iter_keys}}, $key_down;
                push @{$self->{iter_trees}}, $current_node->tree;
                return [ @{$self->{iter_keys}} ] if $node_down->has_value;
            } else {
                # backtrack if there is an empty hash here
                $current_node->already_visited(1);
            }
        } else {
            # otherwise, we'll try to continue with next keys at this
            # very level
            if (my ($next_key, $next_node) = each %$current_tree) {
                # inspect the next key in this hash
                $self->{iter_keys}[-1] = $next_key;
                return [ @{$self->{iter_keys}} ] if $next_node->has_value;
            } else {
                # this hash has been exhausted, go up
                pop @{$self->{iter_keys}};
                pop @{$self->{iter_trees}};
                if (@{$self->{iter_keys}}) {
                    $current_key  = $self->{iter_keys}[-1];
                    $current_tree = $self->{iter_trees}[-1];
                    $current_node = $current_tree->{$current_key};
                    $current_node->already_visited(1);
                }
            }
        }
    }

    return undef;
}


# Private: auxiliary class.
package Hash::MultiKey::Node;

sub new {
    bless [undef, 0, {}, 0], shift;
}

sub value {
    my $self  = shift;
    if (@_) {
        $self->[0] = shift;
        $self->has_value(1);
    }
    $self->[0];
}

sub rm_value {
    my ($self) = @_;
    my $rmed_value = $self->[0];
    $self->value(undef);
    $self->has_value(0);
    $rmed_value;
}

sub has_value {
    my $self = shift;
    $self->[1] = shift if @_;
    $self->[1];
}

# No setter needed because the constructor initializes it and we work
# always with the returned reference to modify it.
sub tree {
    my ($self) = @_;
    $self->[2];
}

sub already_visited {
    my $self = shift;
    $self->[3] = shift if @_;
    $self->[3];
}

1;


__END__

=head1 NAME

Hash::MultiKey - hashes whose keys can be multiple

=head1 SYNOPSIS

  use Hash::MultiKey;

  # tie first
  tie %hmk, 'Hash::MultiKey';

  # store
  $hmk{['foo', 'bar', 'baz']} = 1;

  # fetch
  $v = $hmk{['foo', 'bar', 'baz']};

  # exists
  exists $hmk{['foo', 'bar', 'baz']}; # true
  exists $hmk{['foo', 'bar']};        # false

  # each
  while (($mk, $v) = each %hmk) {
      @keys = @$mk;
      # ...
  }

  # keys
  foreach $mk (keys %hmk) {
      @keys = @$mk;
      # ...
  }

  # values
  foreach $v (values %hmk) {
      # ...
  }

  # delete
  $rmed_value = delete $hmk{['foo', 'bar', 'baz']};

  # clear
  %hmk = ();

  # syntactic sugar, but see risks below
  $hmk{'foo', 'bar', 'baz', 'zoo'} = 2;

  # finally, untie
  untie %hmk;

=head1 DESCRIPTION

Hash::MultiKey provides true multi-key hashes.

The next sections document how hash-related operations work in a
multi-key hash. Some parts have been copied from standard documentation,
since everything has standard semantics.

=head2 tie

Once you have tied a hash variable to Hash::MultiKey as in

    tie %hmk, 'Hash::MultiKey';

you've got a hash whose keys are arrayrefs of strings. Having that in
mind everything works as expected.

=head2 store

Assignment is this easy:

    $hmk{['foo', 'bar', 'baz']} = 1;

Different keys can have different lengths in the same array:

    $hmk{['zoo']} = 1;

=head2 fetch

The arrayrefs used for retrieving need I<not> be the same ones used for
storing:

    $v = $hmk{['foo', 'bar', 'baz']}; # $v is 1

In general, when you work with these hashes the idea is that two keys
are regarded as being equal if and only if their I<contents> are equal.

=head2 exists

Testing for existence works as usual:

    exists $hmk{['foo', 'bar', 'baz']}; # true

Only whole multi-keys as they were used in assigments have entries.
Sub-chains do not exist unless they were assigned some value.

For instance, C<['foo']> is a sub-chain of C<['foo', 'bar', 'baz']>, but
since it has no entry in %hmk so far

    exists $hmk{['foo']}; # false

=head2 each

As with everyday C<each()>, when called in list context returns a
2-element list consisting of the key and value for the next element of
the hash, so that you can iterate over it. When called in scalar
context, returns only the key for the next element in the hash.

Remember keys are arrayrefs now:

    while (($mk, $v) = each %hmk) {
        @keys = @$mk;
        # ...
    }

The order in which entries are returned is guaranteed to be the same one
as either the C<keys()> or C<values()> function would produce on the
same (unmodified) hash.

When the hash is entirely read, a null array is returned in list context
(which when assigned produces a false (0) value), and C<undef> in scalar
context. The next call to C<each()> after that will start iterating
again.

There is a single iterator for each hash, shared by all C<each()>,
C<keys()>, and C<values()> function calls in the program.

Adding or deleting entries while we're iterating over the hash results
in undefined behaviour. Nevertheless, it is always safe to delete the
item most recently returned by C<each()>, which means that the following
code will work:

    while (($mk, $v) = each %hmk) {
        print "@$mk\n";
        delete $hmk{$mk}; # this is safe
    }

=head2 keys

Returns a list consisting of all the keys of the named hash. (In scalar
context, returns the number of keys.) The keys are returned in an
apparently random order. The actual random order is subject to change in
future versions of perl, but it is guaranteed to be the same order as
either the C<values()> or C<each()> function produces (given that the
hash has not been modified). As a side effect, it resets hash's
iterator.

Remember keys are arrayrefs now:

    foreach $mk (keys %hmk) {
        @keys = @$mk;
        # ...
    }

There is a single iterator for each hash, shared by all C<each()>,
C<keys()>, and C<values()> function calls in the program.

The returned values are copies of the original keys in the hash, so
modifying them will not affect the original hash. Compare C<values()>.

=head2 values

Returns a list consisting of all the values of the named hash. (In a
scalar context, returns the number of values.) The values are returned
in an apparently random order. The actual random order is subject to
change in future versions of perl, but it is guaranteed to be the same
order as either the C<keys()> or C<each()> function would produce on the
same (unmodified) hash.

Note that the values are not copied, which means modifying them will
modify the contents of the hash:

   s/foo/bar/g foreach values %hmk;       # modifies %hmk's values
   s/foo/bar/g foreach @hash{keys %hash}; # same

As a side effect, calling C<values()> resets hash's internal iterator.

There is a single iterator for each hash, shared by all C<each()>,
C<keys()>, and C<values()> function calls in the program.


=head2 delete

Deletes the specified element(s) from the hash. Returns each element so
deleted or the undefined value if there was no such element.

The following (inefficiently) deletes all the values of %hmk:

    foreach $mk (keys %hmk) {
        delete $hmk{$mk};
    }

And so do this:

    delete @hmk{keys %hmk};

But both methods are slower than just assigning the empty list to %hmk:

    %hmk = (); # clear %hmk, the efficient way

=head2 untie

Untie the variable when you're done:

    untie %hmk;

=head1 SYNTACTIC SUGAR

Hash::MultiKey supports also this syntax:

    $hash{'see', '$;', 'in', 'perldoc', 'perlvar'} = 1;

If the key is a string instead of an arrayref the underlying code splits
it using C<$;> (see why in L<MOTIVATION>) and from then on the key is an
arrayref as any true multi-key. Thus, the assigment above is equivalent
to

    $hash{['see', '$;', 'in', 'perldoc', 'perlvar']} = 1;

once it has been processed.

You I<don't> need to split the string back while iterating with
C<each()> or C<keys()>, it already comes as an arrayref of strings.

Nevertheless take into account that this is B<slower> and B<broken> if
any of the components contains C<$;>. It is supported just for
consistency's sake.


=head1 MOTIVATION

Perl comes already with some support for hashes with multi-keys. As you
surely know, if perl sees

    $hash{'foo', 'bar', 'baz'} = 1;

it joins C<('foo', 'bar', 'baz')> with C<$;> to obtain the actual key,
thus resulting in a string. Then you retrieve the components of the
multi-key like this:

    while (($k, $v) = each %hash) {
        @keys = $k eq '' ? ('') : split /$;/, $k, -1;
        # ...
    }

Since C<$;> is C<\034> by default, a non-printable character, this is
often enough.

Sometimes, however, that's not the most convenient way to work with
multi-keys. For instance, that magic join doesn't work with arrays:

    @array = ('foo', 'bar', 'baz');
    $hash{@array} = 1; # WARNING, @array evaluated in scalar context!

You could be dealing with binary data. Or you could be writing a public
module that uses user input in such a hash and don't want to rely on
input not coming with C<$;>, or don't want to document such an obscure,
gratuitous, and implementation dependent constraint.

In such cases, Hash::MultiKey can help.

=head1 AUTHOR

Xavier Noria E<lt>fxn@hashref.comE<gt>.

=head1 COPYRIGHT and LICENSE

Copyright (C) 2003, Xavier Noria E<lt>fxn@hashref.comE<gt>. All rights
reserved. This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<perlvar>, L<perltie>

=cut
