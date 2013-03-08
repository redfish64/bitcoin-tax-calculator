#!/usr/bin/perl -w -s

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
Usage $0 <file.csv>

where <file.csv> is the output of bitcoin_mtgox_balance_calculator.pl

converts a dat file to a dat file with wash sales
main algorithm:
1. Find each sell in chronological order
For each sell,
2. Find first buy which has not been allocated as a "first buy" for any sell. This buy becomes "First Buy" for this sell
   Continue this process until all shares of the sells have a "first buy". Last buy may have to be split into two buys.
3. Find first buy which is not a wash for any sell and is not the "first buy" for *this* sell and has been traded within
   the 61 day gap. Mark this as a wash buy, and count the shares as wash shares for the sell. Continue until all shares
   are marked wash or run out of buys. May have to split buys, or sell as part wash/part non-wash.
End for each 

Creates two formats of output data and prints both.

First shows each transaction split up into lots and then corresponding sells for each lot as they occur. 
(For example, one buy on 5/31/12 may be split up into 3 buys, if there were 3 corresponding sells)

Second shows an irs friendly format similar to the Schedule D format. It will also attempt to locate
"wash" sales


WARNING: This code is ALPHA!!! Do your own verification!! This may produce completely bogus results! No warranty to fitness is expressed or implied! Also, I had the flu when I wrote this and my delirium might be affect the code quality

EoF

    exit -1;
}

use Sell;
use Buy;
use TradeList;

sub testConvertTextToDays
{
    $x = convertTextToDays("2011-01-01");
    for($i=0; $i < 366; $i++)
    {
	print $x.",".convertDaysToText($x).",".convertTextToDays(convertDaysToText($x))."\n";
	die unless $x == convertTextToDays(convertDaysToText($x));
	$x++;
    }
}

$lineno = 0;

$trades = new TradeList();

#Date,BTC,USD (minus fee),Fee $,Price Per Share
#2011-05-31,329.56,-2998.995,0,9.09999696565117
#2011-06-01,-110,1038.4,6.749,9.44
#2011-06-05,60.33,-1031.642,0,17.0999834244986
#2011-06-06,-57,1019.16,6.624,17.88
#2011-06-06,58.529,-1012.545,0,17.2998855268328
#2011-06-07,-59,1135.16,7.387,19.24
#2011-06-08,41.73,-1127.543,0,27.0199616582794
#2011-06-09,-78.05,2256.33191,14.66391,28.908800896861
#2011-06-10,-79.9,2117.35,13.762,26.5
#2011-06-16,18.088,-345.48,0,19.0999557717824
#2011-07-23,258.23153817,-3488.70808,0,13.5099999973795
#2011-07-28,111.77531969,-1511.30292,0,13.5209000000311
#2011-07-31,371.12010796,-4950,0,13.3380000000795
#2011-09-28,-83.18088525,410.91357,2.46549,4.93999996231105
#2011-09-29,-776.71026536,3658.39699,19.60932,4.71011798499194

#read header
<>;

$symbol = "BTC";

#print convertDaysToText(11885);
while($line = <>)
{
    $lineno++;

    my $found;
    
    if($line =~ /^(.*),(.*),(.*),(.*),(.*)$/)
    {
	#read next line
	($date_text, $shares, $price, $fee, $sharePrice) = ($1, $2, $3, $4, $5, $6);

	if($shares > 0)
	{
	    $action = "B";
	    $price = -$price;
	}
	else
	{
	    $action = "S";
	    $shares = -$shares;
	}

	$found = 1;
    }
    else
    {
	die "What is it? $line";
    }

    if($found)
    {
	#if we're selling
	if($action eq "S")
	{
	    #create a sell trade
	    $trades->add(new Sell(&main::convertTextToDays($date_text), $shares, $price, $fee, $symbol, $sharePrice));
	}
	#else if we're buying
	elsif ($action eq "B")
	{
	    #buy the stock
	    $trades->add(new Buy(&main::convertTextToDays($date_text), $shares, $price, $fee, $symbol, $sharePrice));
	}
	else
	{
	    warn("$lineno: Ignored, not a buy or sell");
	}
    }
    else
    {
	warn("$lineno: ignored, what is this?");
    }
}

$trades->checkWashes;
$trades->print;
print "------------------------------------\n";
$trades->printIRS;
print "------------------------------------\n";
#$trades->generateScheduleDFormData;



#converts dd-mmm-yyyy or mm-dd-yyyy to days
sub convertTextToDays
{
    require 'timelocal.pl';

    my $month_list = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    
    $_ = shift;

    # 31-JAN-2003
    if (/^([0-9]{1,2})[-,\/]([A-Z]{3})[-,\/]([0-9]{2,4})$/) {
	my $month_text = $2;
	my $day = $1;
	my $year = $3;

	for($month = 0; $month < 12; $month++)
	{
	    if($month_list->[$month] eq $month_text)
	    {
		last;
	    }
	}

	die "Couldn't understand month $month_text" if $month == 12;
	
	if($month < 0 || $month > 11 || $day < 1 || $day > 31)  {
	    return 0; #not a valid date
	}
	return timegm(0,0,0,$day,$month-1,$year-1900) / (24 * 3600); #divide it by the number of seconds so we get days
    }
    
    # 01-31-2003
    if(/^([0-9]{2})[-\/]([0-9]{2})[-\/]([0-9]{4})$/)
    {
	my ($month, $day, $year) = ($1, $2, $3);

	return timegm(0,0,0,$day,$month-1,$year-1900) / (24 * 3600); #divide it by the number of seconds so we get days
    }

    # 2003-01-31
    if(/^([0-9]{4})[-\/]([0-9]{2})[-\/]([0-9]{2})$/)
    {
	my ($year, $month, $day) = ($1, $2, $3);

	return timegm(0,0,0,$day,$month-1,$year-1900) / (24 * 3600); #divide it by the number of seconds so we get days
    }

    # not a valid date
    die "What is $_";
}

#converts the days to mm/dd/yyyy
sub convertDaysToText
{
	my $date_days = shift;
	my $date_seconds = $date_days * 24 * 3600;
	my ($date,$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);

	if ($date_seconds != 0) {
	    $date = 
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = 
		    gmtime($date_seconds);
	    $mon ++; # add 1 to month, returned in format (0..11)
	    $year += 1900; 
	    
	    if(length $mon == 1) {
		$mon = "0".$mon;
	    }
	    if(length $mday == 1) {
		$mday = "0".$mday;
	    }
	    if(length $year == 1) {
		$year = "0".$year;
	    }
	    $date = "$mon-$mday-$year";

	}
	
	return $date;
}




#if numbers are equal enough to match diff
sub about_equal
{
    my ($n1, $n2, $diff) = @_;

    if($n1 - $n2 > $diff || $n2 - $n1 > $diff)
    {
	return 0; #false
    }

    return 1; #about equal
}

