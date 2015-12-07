#!/usr/bin/perl -w

use strict;

# Copyright 2012 Rareventure, LLC
#
# This file is part of Bitcoin Tax Calculator
# Bitcoin Tax Calculator is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# Bitcoin Tax Calculator is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Bitcoin Tax Calculator.  If not, see <http://www.gnu.org/licenses/>.
#
# If you make modifications to this software that you feel
# increases it usefulness for the rest of the community, please
# email the changes, enhancements, bug fixes as well as any and
# all ideas to me. This software is going to be maintained and
# enhanced as deemed necessary by the community.
#
# Tim Engler (engler@gmail.com)



if(@ARGV == 0)
{
    print <<EoF;
Usage $0 <file.csv> [file2.csv] ...
Takes in one or more bitcoin USD csv file from mtgox.com and collesces transactions of the same type that occurred on the same day. ex:
300,"2012-01-12 13:22:24",spent,"BTC bought: [tid:1326374544285515] 4.94891789| BTC at \$6.70001",33.1578,3233.91816
301,"2012-01-12 13:22:25",spent,"BTC bought: [tid:1326374545565847] 7.93650000| BTC at \$6.70001",53.17463,3180.74353
302,"2012-01-12 13:22:30",spent,"BTC bought: [tid:1326374550232878] 50.00000000| BTC at \$6.70001",335.0005,2845.74303
303,"2012-01-12 13:22:48",spent,"BTC bought: [tid:1326374568682022] 96.78993256| BTC at \$6.70001",648.49352,2197.24951
304,"2012-01-12 13:22:57",spent,"BTC bought: [tid:1326374576996508] 45.00000000| BTC at \$6.70001",301.50045,1895.74906
305,"2012-01-12 13:23:11",spent,"BTC bought: [tid:1326374591237406] 49.97750000| BTC at \$6.70001",334.84975,1560.89931
306,"2012-01-12 13:41:11",spent,"BTC bought: [tid:1326375671581196] 7.77232698| BTC at \$6.70001",52.07467,1508.82464
307,"2012-01-12 13:41:39",spent,"BTC bought: [tid:1326375699826978] 30.14848000| BTC at \$6.70001",201.99512,1306.82952
308,"2012-01-12 13:46:12",spent,"BTC bought: [tid:1326375972451018] 23.38005696| BTC at \$6.70001",156.64662,1150.1829
309,"2012-01-12 13:48:21",spent,"BTC bought: [tid:1326376101025292] 171.66883333| BTC at \$6.70001",1150.1829,0

becomes:
Date,BTC,USD (without fee),Fee \$,Price Per Share
2012-01-12,487.62254772,-3267.07596,0,6.70001002881434

Duplicate lines with the same Index (the first column) are only counted once. In this way you can specify multiple
overlapping files. Also, if there are any gaps in the Index, this is reported to stderr
EoF

exit -1;
}


#Index,Date,Type,Info,Value,Balance
#1,"2011-05-28 23:56:09",in,65792414-21c5-41f4-9ddd-b869b993b209,2999,2999
#2,"2011-05-31 17:54:54",spent,"BTC bought: [tid:96003] 76.75300000Â à¸¿TC at $9.10000",698.452,2300.548
#3,"2011-05-31 17:57:30",spent,"BTC bought: [tid:96011] 252.80700000Â à¸¿TC at $9.10000",2300.543,0.005
#4,"2011-06-01 22:33:13",earned,"BTC sold: [tid:99574] 69.89200000Â à¸¿TC at $9.44000",659.78048,659.78548
#5,"2011-06-01 22:33:13",fee,"BTC sold: [tid:99574] 69.89200000Â à¸¿TC at $9.44000 (fee)",4.28848,655.497
#6,"2011-06-01 22:33:24",earned,"BTC sold: [tid:99575] 1.00000000Â à¸¿TC at $9.44000",9.44,664.937
#7,"2011-06-01 22:33:24",fee,"BTC sold: [tid:99575] 1.00000000Â à¸¿TC at $9.44000 (fee)",0.061,664.876
#8,"2011-06-01 22:34:08",earned,"BTC sold: [tid:99576] 39.10800000Â à¸¿TC at $9.44000",369.17952,1034.05552
#9,"2011-06-01 22:34:08",fee,"BTC sold: [tid:99576] 39.10800000Â à¸¿TC at $9.44000 (fee)",2.39952,1031.656

print "Date,BTC,USD (minus fee),Fee \$,Price Per Share\n";


#daily spent earned and fees
my ($dbtcb,$dusdb,$dbtcs,$dusds,$dfee);

my ($last_date) = "";

my %index_to_line;

my $max_index = 0;

my $HEADER = "Index,Date,Type,Info,Value,Balance";

my $file;

foreach $file (@ARGV)
{
    open(F, $file) || die "Can't open file '$file' for reading";
    

    #read header
    $_ = <F>;

    chomp;

    if($_ ne $HEADER)
    {
	die "Error: In file '$file', Expected header, $HEADER, not present, got: $_\n";
    }

    while(<F>)
    {
	chomp;
	
	#if there are an odd number of quotes, then it's multiline, ex:
#424,"2012-06-11 21:39:18",deposit,"Jeffrey G
#MTGOXxxxxX",5000,5000
	while(($_ =~ tr/"//) % 2 == 1)
	{
	    $_ .= <F>;
	    chomp;
	}
	
	@_ = split /,/,$_;
	
	my $dup = $index_to_line{$_[0]};
	
	if(defined $dup)
	{
	    if ( $dup ne $_)
	    {
		die "Error: File '$file', line $., Index $_[0] has two entries and they differ. Entries below:
$dup
---
$_
";
	    }
	    #skip duplicate entries
	    else { next; }
	    
	}
	$index_to_line{$_[0]} = $_;
	
	$max_index = $max_index > $_[0] ? $max_index : $_[0];
    }
}

	
#    print $_."\n";

for(my $i = 0; $i <= $max_index	; $i++)
{
    $_ = $index_to_line{$i};

    next unless defined $_;
    
    @_ = split /,/,$_;
    
    my $date = $_[1];
    $date =~ s/"(.*?) .*/$1/;
    
    if(!($date eq $last_date))
    {
	if($last_date ne "") {
	    print_date_info($last_date, $dbtcb, $dusds, $dbtcs, $dusdb, $dfee);
	}
	$last_date = $date;
	$dusds=$dbtcs=
	    $dusdb=$dbtcb=
	    $dfee=0;
    }
    
    my $t = $_[2];
    
    if($t eq "in" || $t eq "withdraw" || $t eq "deposit")
    {}
    elsif ($t eq "spent")
    {
	$dbtcb += calc_btc("bought",$_[3]);
	$dusds += $_[4];
    }
    elsif ($t eq "earned")
    {
	$dbtcs += calc_btc("sold",$_[3]);
	$dusdb += $_[4];
    }
    elsif ($t eq "fee")
    {
	$dfee += $_[4];
    }
    else {die "Cannot read transaction type, file '$file', line $., transaction type '$t'";}

}

print_date_info($last_date, $dbtcb, $dusds, $dbtcs, $dusdb, $dfee);

#print gaps in %index_to_line
my $last_found = 1;
my $start_gap = 1;

for(my $i = 1; $i <= $max_index; $i++)
{
    my $found = (defined $index_to_line{$i});

    if(!$last_found && $found)
    {
	print STDERR "Warning: Index range from $start_gap to ".($i-1)." (inclusive) is missing..\n";
    }
    elsif ($last_found && !$found)
    {
	$start_gap = $i;
    }
    $last_found = $found;
}




sub calc_btc
{
    my ($type, $str) = @_;

    $str =~ /^"BTC ${type}: \[tid:\d+\] ([0-9.]+).*? at \$(.*?)"$/ || die "What is $str in file $file at line $.";
#    print "calc btc $1\n";
    $1;
}

sub print_date_info 
{
    my ($date, $dbtcb, $dusds, $dbtcs, $dusdb, $dfee) = @_;

    my $price;

    if($dbtcs != 0)
    {
	$price = $dusdb/$dbtcs;
	print "$date,-$dbtcs,$dusdb,$dfee,$price\n";
    }
    if($dbtcb != 0)
    {
	$price = $dusds/$dbtcb;
	print "$date,$dbtcb,-$dusds,0,$price\n";
    }
}
