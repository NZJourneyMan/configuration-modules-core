#!/usr/bin/perl
# -*- mode: cperl -*-
use strict;
use warnings;
use Test::Quattor;
use Test::More;
use Cwd;
use File::Path qw(rmtree mkpath);

=pod

=head1 DESCRIPTION

Test the C<initialize_user> method, ensuring that all the directories
are properly created if needed.

=cut

rmtree("target/test/home");

# OK, this is tricky AND ugly.  All at the same time.  We want to
# capture the calls to chown in the component. Since it's a builtin,
# we must provide our redefinition BEFORE NCM::Component::useraccess
# is compiled. Otherwise, the CORE version will rule and we won't be
# able to intercept it ever again. So, first we define the backup
# module, which allows us to see the arguments for each call via an
# ugly global:

my @chown;

*NCM::Component::useraccess::chown = sub {
    push(@chown, \@_);
};

# And only then, we REQUIRE and NOT USE the component package. We need
# REQUIRE because it's executed at runtime, and thus after our fake
# chown is in place.
require NCM::Component::useraccess;

no warnings 'redefine';

*NCM::Component::useraccess::getpwnam = sub {
    my ($uid, $gid) = ($<, $();
    my $dir = getcwd();
    $dir .= "/target/test/home";
    mkpath($dir);
    return ($uid, $gid, $dir);
};



use warnings 'redefine';



my $cmp = NCM::Component::useraccess->new("useraccess");

my ($u, $g, $h) = $cmp->initialize_user("foo");
ok(defined($u), "Existing user gets properly initialized");
is(scalar(@chown), 1, "chown is called");
is($chown[0]->[-1], "$h/.ssh", "The SSH directory is reassigned to its owner");
is($chown[0]->[0], $u, "The SSH directory is assigned to the correct owner");
ok(-d "$h/.ssh", "SSH directory is created");

($u, $g, $h) = $cmp->initialize_user("foo");
ok(defined($u), "Calling initialize_user multiple times succeeds");
is(scalar(@chown), 1, "The SSH directory is initialized exactly once");

no warnings 'redefine';
*NCM::Component::useraccess::getpwnam = sub {
    return undef;
};
use warnings 'redefine';

is($cmp->initialize_user("foo"), undef,
   "An error in pwnam is transmitted to the caller");



done_testing();
