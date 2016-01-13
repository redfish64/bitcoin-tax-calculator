#!/usr/bin/perl -w -s

# Copyright 2012 Rareventure, LLC
# Copyright 2015,2016 Rareventure, LLC
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

require 'util.pl';

use Sell;
use Buy;
use TradeList;

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
	($date_text, $shares, $price, $fee) = ($1, $2, $3, $4);

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
	    $trades->add(new Sell(&main::convertTextToDays($date_text), $shares, $price-$fee,$symbol));
	}
	#else if we're buying
	elsif ($action eq "B")
	{
	    #buy the stock
	    $trades->add(new Buy(&main::convertTextToDays($date_text), $shares, $price+ $fee, $symbol));
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

$trades->checkWashesAndAssignBuysToSells;
$trades->print;
print "------------------------------------\n";
$trades->printIRS;
print "------------------------------------\n";
#$trades->generateScheduleDFormData;



