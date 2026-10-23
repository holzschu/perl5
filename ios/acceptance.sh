#!/bin/sh
# Run inside a-Shell from a disposable directory: dash /path/to/ios/acceptance.sh
set -eu
assert_bytes() {
  perl -e 'local $/; open A,"<",$ARGV[0] or die $!; open B,"<",$ARGV[1] or die $!; die "byte mismatch\n" if <A> ne <B>;' "$1" "$2"
}
perl -v >version.txt
grep 'v5.34.0' version.txt
printf 'input\n' >input.txt
perl -e 'print uc scalar <STDIN>; print STDERR "diagnostic\n"' <input.txt >stdout.txt 2>stderr.txt
printf 'INPUT\n' >expected.txt
assert_bytes stdout.txt expected.txt
printf 'diagnostic\n' >expected.txt
assert_bytes stderr.txt expected.txt
perl -MPOSIX -MFile::Spec -e 'print POSIX::floor(3.75), ":", File::Spec->catfile("a", "b"), "\n"' >modules.txt
printf '3:a/b\n' >expected.txt
assert_bytes modules.txt expected.txt
set +e
perl -e 'exit 7'
status=$?
set -e
[ "$status" = 7 ]
printf 'exit=%s\n' "$status"
perl -e 'print "first\n"' >first.txt
perl -e 'print "second\n"' >second.txt
perl -e 'print "third\n"' >third.txt
printf 'first\n' >expected.txt
assert_bytes first.txt expected.txt
printf 'second\n' >expected.txt
assert_bytes second.txt expected.txt
printf 'third\n' >expected.txt
assert_bytes third.txt expected.txt
printf 'pipe\n' | perl -ne 'print uc $_' | cat >pipe.txt
printf 'PIPE\n' >expected.txt
assert_bytes pipe.txt expected.txt
perl -e 'system("perl", "-e", "print qq(nested\\n)") == 0 or die "child failed"' >nested.txt
printf 'nested\n' >expected.txt
assert_bytes nested.txt expected.txt
perl -e '$ENV{PERL_IOS_CHILD_ENV}="inherited"; system("perl", "-e", q{die "environment missing\n" unless ($ENV{PERL_IOS_CHILD_ENV} // "") eq "inherited"}) == 0 or die "child failed\n"'
perl -e '$ENV{PERL5LIB}="perl5lib-probe"; system("perl", "-e", q{exit((grep { $_ eq "perl5lib-probe" } @INC) ? 0 : 1)}) == 0 or die "PERL5LIB not inherited\n"'
perl -e '%ENV=(PERL_IOS_ONLY=>1); die "environment replacement failed\n" unless join(",", keys %ENV) eq "PERL_IOS_ONLY"; system("perl", "-e", q{exit(exists $ENV{HOME} ? 1 : 0)}) == 0 or die "environment not cleared\n"'
perl -e '$ENV{PERL_IOS_RESTORE}="before"; { local %ENV=(PERL_IOS_LOCAL=>1); die "local environment failed\n" unless join(",", keys %ENV) eq "PERL_IOS_LOCAL" } die "environment restoration failed\n" unless $ENV{PERL_IOS_RESTORE} eq "before" && !exists $ENV{PERL_IOS_LOCAL}'
perl -e 'my @fds; while (open my $fd, "<", "/dev/null") { push @fds, $fd } my $opened = open my $pipe, "-|", "perl", "-e", "exit 0"; close $_ for @fds; die "pipe unexpectedly opened\n" if $opened; system("perl", "-e", "exit 0") == 0 or die "pipe failure recovery failed\n"'
perl -e 'for (1..3) { my $out = `ios-perl-missing-command 2>&1`; die "missing command succeeded\n" unless $? } system("perl", "-e", "exit 0") == 0 or die "after missing command\n"'
perl -e 'my $status = system("perl", "-e", "exit(-1)"); die "negative system status=$status\n" unless $status == 65280; my $out = `perl -e "exit(-1)"`; die "negative pipe status=$?\n" unless $? == 65280'
perl -e 'die "redirected output is a terminal\n" if -t STDOUT' >tty.txt
perl -e '$s=system("perl", "-e", q{select undef,undef,undef,0.2; print "waited\n"; exit 7}); die "child status=$s\n" unless $s == 1792' >waited.txt 2>waited.err
printf 'waited\n' >expected.txt
assert_bytes waited.txt expected.txt
[ ! -s waited.err ]
perl -e 'my $out = `perl -e "print qq(pipe child\\n); exit 3"`; die "pipe output\n" unless $out eq "pipe child\n"; die "pipe status=$?\n" unless $? == 768'
perl -e 'print "first\n"; open my $pipe, "|-", "perl", "-e", q{print while <STDIN>; select undef,undef,undef,0.2; exit 3} or die $!; print $pipe "second\n"; die "pipe close succeeded\n" if close $pipe; die "writer status=$?\n" unless $? == 768' >pipe-order.txt
printf 'first\nsecond\n' >expected.txt
assert_bytes pipe-order.txt expected.txt
perl -e 'system {"perl"} "other-argv-zero", "-e", q{print "explicit program\n"} and die "explicit program failed\n"' >explicit-program.txt
printf 'explicit program\n' >expected.txt
assert_bytes explicit-program.txt expected.txt
perl -e 'unlink "stderr-ack"; open my $script, ">", "stderr-child.pl" or die $!; print $script q{print STDERR "ready\n"; for (1..20) { if (-e "stderr-ack") { print "acked\n"; exit 0 } select undef,undef,undef,0.1 } die "stderr was buffered\n";}; close $script or die $!; open my $pipe, "-|", "perl stderr-child.pl 2>&1" or die $!; die "stderr missing\n" unless <$pipe> eq "ready\n"; open my $ack, ">", "stderr-ack" or die $!; close $ack; local $/; die "stderr acknowledgement missing\n" unless <$pipe> eq "acked\n"; close $pipe or die "stderr child failed\n"; unlink "stderr-ack", "stderr-child.pl";'
printf 'PERL_IOS_ACCEPTANCE_OK\n'
