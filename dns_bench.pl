#!/usr/bin/perl

use strict;
use warnings;
use Net::DNS;
use Time::HiRes;
use Socket;

my $number_args = $#ARGV + 1;
my $host = "";

my $arg = $ARGV[0];
chomp($arg) if defined $arg;

if ($number_args == 1)
{
	if ($arg eq '--help')
	{
		print "\nUsage: ".$0. " [lookup_hostname]\n";
		print "If no hostname is provided www.google.com will be used\n\n";
		exit;
	}
	else
	{
		$host = $ARGV[0];
	}
}
else
{
	$host = 'www.google.com';
}

my $errorList = "";

my %servers = (
	'OpenDNS_1' => '208.67.222.222',
	'OpenDNS_2' => '208.67.220.220',
	'DNSPrivacy' => '94.130.110.185',
	'L3?' => '209.244.0.3',
	'L3?' => '209.244.0.4',
	'Verisign' => '64.6.64.6',
	'Google_1' => '8.8.8.8',
	'Google_2' => '8.8.4.4',
	'Quad9_1' => '9.9.9.9',
	'CloudFlare' => '1.1.1.1',
	'Quad9_2' => '149.112.112.112',
	'DNS.com?' => '8.26.56.26', 
	'DNS.com?' => '8.20.247.20',
	'DNSINC_1' => '216.146.35.35', 
	'DNSINC_2' => '216.146.36.36', 
	'EMERION?' => '37.235.1.174', 
	'EMERION?' => '37.235.1.177', 
	'CensurFriDNS' => '89.233.43.71', 
	'DNSWatch_1' => '84.200.69.80', 
	'DNSWatch_2' => '84.200.70.40', 
	'Hurricane Electric' => '74.82.42.42', 
	'guifi-net?' => '109.69.8.51',
	'OpenNIC' => '94.247.43.254',
    'DNS4EU Protective' => '86.54.11.1',
    'DNS4EU Child' => '86.54.11.12',
    'DNS4EU Adblock' => '86.54.11.13',
    'DNS4EU Unfiltered' => '86.54.11.100'
	);

my @results;        # successful lookups so far: { name, ip, time }
my $prev_lines = 0; # how many lines the last render printed

$| = 1;             # autoflush so the live updates show immediately

# Redraw the whole table, sorted by time, overwriting the previous render.
sub render
{
	my @sorted = sort { $a->{time} <=> $b->{time} } @results;

	my $out = "\nTiming lookups for $host\n\n";
	$out .= sprintf("%-20s %-15s %4s\n", "Server", "IP", "Time");
	$out .= ("-" x 45) . "\n";
	for my $r (@sorted)
	{
		$out .= sprintf("%-20s %-15s %.5f\n", $r->{name}, $r->{ip}, $r->{time});
	}

	# Move the cursor back up over the previous render and clear it,
	# so the table updates in place instead of scrolling.
	print "\033[${prev_lines}A\033[J" if $prev_lines > 0;
	print $out;
	$prev_lines = ($out =~ tr/\n//);
}

# OS default resolver
my $start = Time::HiRes::gettimeofday();
inet_ntoa(inet_aton($host));
my $end = Time::HiRes::gettimeofday();
push @results, { name => 'OS_Default', ip => 'local', time => $end - $start };
render();

while (my ($name, $ip) = each(%servers))
{
	#todo: this should be a function
	my $res = Net::DNS::Resolver->new(nameservers => [$ip]);
	$res->udp_timeout(2);
	$res->retry(1);
	my $start = Time::HiRes::gettimeofday();
	my $query = $res->search($host);
	my $end = Time::HiRes::gettimeofday();

	if ($query)
	{
		foreach my $rr ($query->answer)
		{
			next unless $rr->type eq "A";
			#print $rr->address, "\n";
		}

		push @results, { name => $name, ip => $ip, time => $end - $start };
		render();
	}
	else
	{
		my $err = sprintf("%-10s %-15s failed: %s \n", $name, $ip, $res->errorstring);
		$errorList .= $err;
	}
}

print "\n", $errorList, "\n";
