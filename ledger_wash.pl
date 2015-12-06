3#!/usr/bin/perl -w -s

#TODO 2: Change Copyright to 2012, 2015 for all files

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
    print "Usage $0 -a <assets regexp> -i <income regexp> -e <expenses regexp> -bc <base currency (usually $ or USD)> [-accuracy (decimal accuracy, defaults to 20 places)]  <dat file1> [dat file2...]

Reads a ledger style file and creates a capital gains report using the FIFO method, including the calculation of wash sales.

This program will look for any transaction where two different currencies are included in a transaction,
and are both designated within accounts you own (ex. USD and BTC, or BTC and ETH). These transactions
will be hereto referred to as 'trades'.

It will also look for transactions from an Income account and an Asset account. These are considered
taxable income events and included in the report.

Accounts are split into three categories. Assets, Expenses and Income.

Assets are accounts you own and you wish to calculate capital gains for.
Income are accounts from which you receive an Asset. For example, if you mine bitcoin and you have
    an 'Income:Mining' account.
Expenses are accounts where expenses go. When expenses are one or more of the outputs for trades or
    income transactions, they are deducted from the capital gains received. In any other transaction,
    (such as those associated with transferring assets around), they are ignored.

<assets regex> : Regex for when an account should be included in Assets
<income regex> : Same as above, but for Income accounts 
<expenses regex> : Same as above, but for Expenses accounts 

If an account matches two or more of the above, it will be considered an error.

<base currency> : The currency used to calculate the capital gains report in. Usually this will be USD,
   $, or whatever you use for your countries currency.

Transactions will be combined if on the same day, for the same types of currency and are adjacent
in time order.

If a time is present after the date, ex:

2015-08-15 11:09:05
  Assets:Kraken     -0.123052 BTC
  Assets:Kraken     25.126 ETH
  Expenses:Fees     0.0000520000 BTC

the time will be used to sort transactions. Otherwise, transactions on the same day will be sorted in the
order specified in the file(s).
";

    exit -1;
}

use Getopt::Long;
my ($assets,$income,$expenses,$base_curr, $accuracy);

$accuracy = 20;
GetOptions ("a=s" => \$assets,    
	    "i=s"   => \$income,  
	    "e=s"  => \$expenses,
	    "accuracy=i"  => \$accuracy,
	    "bc=s" => \$base_curr)
    or die("Error in command line arguments\n");

die "missing option" unless $assets && $income && $expenses && $base_cur;

use bignum(a,$accuracy)

use IO::File;

#warning, this is used verbatim for sorting. Make sure that if you loosen the restrictions on this
# you clean it up to a canonical form before use
#also, the absolute index is appended with two spaces. This will make items without a
#time will be ordered before items with a time. 
my $date_reg = '\d{4}-\d{1,2}-\d{1,2}';
my $time_reg = '\d\d:\d\d:\d\d';
my $curr_reg = '(?:\"[^"]*\"|[^\s]+)';
my $amt_curr_reg = '(?:${curr_reg}\s*[+-]?\s*\d*\.\d+|([+-]?)\s*(\d*\.\d+)\s+(${curr_reg}))';

my (@account_lines, %curr_datetime_to_price_quote_data);
 
my $tran_index = 0;

my $line;
my $line_number;


foreach my $file (@ARGV)
{
    my $f = new IO::File;
    
    if($file ne '-')
    {
	open($f, $file) || die "Can't open $file";
    }
    else
    {
	$f = \*STDIN;
	bless $f, 'IO::Handle' unless eval { $f->isa('IO::Handle') };
    }

    my ($date, $time,$desc, @account_lines, $curr_tran_line, $curr_tran_file);
    
    foreach $line (<$f>)
    {
	$line_number = $.; #for error func
	chomp $line;

	#remove comment
	$line =~ s/;.*//;

	#remove trailing whitespace
	$line =~ s/^(.*)\s*/$1/;
	
	if($line =~ /^$/)
	{
	    next;
	}

	if($line =~ /^P/) # price quote
	{
	    #P 2015-04-29 BTC $224.16
	    my ($date,$time,$curr, $amt_curr) = $line =~ /^P (${date_reg})\s+(${time_reg})\s+(${curr_reg})\s+(.*)$/ 
		|| error(msg => "Can't read price quote");

	    

	    $price_quote = add_price_quote(0,
					   create_sort_by($date,$time, $tran_index), 
					   $curr, parse_amt_curr($amt_curr));
	    
	}
	elsif($line =~ /^\d\d/)
	{
	    #2013/05/15 01:29:42 * TID 1368581382704406
	    #add previous tran if any to db
	    add_tran($date,$time, $tran_index, $desc, @account_lines,
		     $curr_tran_line, $curr_tran_file);

	    $tran_index++;
	    $curr_tran_line = $.;
	    $curr_tran_file = $file;
	    @account_lines = ();

	    ($date,$time,$desc) = $line =~ /^$({date_reg})(?:\s+(${time_reg}))\s+(.*)/ 
		|| error(msg => "Can't parse datetime, must be YYYY-MM-DD or YYYY-MM-DD hh:mm:ss");
	    next;
	}
	elsif($line =~ /^[^\s]/)
	{
	    error(msg => "Don't understand line");
	}
	else
	{
	    #    Assets:MtGox                  -17.51286466 BTC @ $ 110.10000
	    #    Assets:MtGox                  $ 1916.59740
	    my ($account, $amt_curr, $price_amt_curr) = 
		$line =~ /^\s+(.*?)(?:  |\t)\s*(${amt_curr_reg})(?: @ (${amt_curr_reg}))?/ 
		|| error(msg => "Can't read account line");

	    my ($amt,$curr) = parse_amt_curr($amt_curr) if $amt_curr;

	    my ($price_amt, $price_curr) = parse_amt_curr($price_amt_curr) if $price_amt_curr;

	    #we only care about our base currency
	    if($price_curr ne $base_cur)
	    {
		$price_amt = undef;
	    }

	    push @account_lines, { account => $account, amt => $amt, 
				   curr => $curr, price_amt => $price_amt
	    };
	    
	}
    }

    add_tran($date, $time, $tran_index, $desc, @account_lines,
	     $curr_tran_line, $curr_tran_file);
}

#utility to convert a hash to an array sorted by keys
sub hv_to_a
{
    my ($size, $hash) = @_;

    die unless $size == %hash;

    map { $hash{$_} } (sort keys %hash);
}

sub balance_account_lines
{
    #balance lines (this is the standard ledger operation to fill values for lines that don't exist
    my $empty_account;
    my %curr_to_balance;

    my $index = 0;
    @_ = map 
    {
	my ($acct,$amt,$curr) = hv_to_a(3,\$_);
	if(defined $curr)
	{
	    $curr_to_balance{$curr} = 
		($curr_to_balance{$curr} or 0)
		+ $amt;

	    delete $curr_to_balance{$curr} if $curr_to_balance{$curr} == 0;

	    ($_);
	}
	else
	{
	    error(msg=>"More than one empty account line. Cannot balance\n")
		if $empty_account;

	    $empty_account = $acct;
	    (); #eat the empty line
	}
    }
    (@_);

    if(defined $empty_account)
    {
	my @res;
	
	#put all non balancing currencies into it
	@res = map {
	    my $bal = $curr_to_balance{$_};
	    ({ acct => $empty_account, amt => -$bal, curr => $_ });
	    else { (); }
	} (sort keys %curr_to_balance);

	push @res, @_; #add the other lines

	return @res;
    }
    else 
    {
	#make sure all the account values balance
	use Data::Dumper;
	foreach (sort keys %curr_to_balance)
	{
	    error(msg => "Non balancing currency, $_: ".$curr_to_balance{$_}.", ".Dumper(@_));
	}

	return @_;
    }
}

sub assign_hash_defaults
{
    my ($defaults, %hash) = @_;
    map { ($_, $hash{$_} or $defaults->{$_}) } (keys %$defaults);
}    



sub error
{
    my ($file, $line, $msg) =
	hv_to_a(3,
		assign_hash_defaults({file => $curr_file,
				      line => $curr_line_number,
				      msg => ""},
				     @_);
    
    print STDERR "ERROR $file: $line  -- $msg\n";
}

sub add_tran
{
    my ($date, $time, $index, $desc, @account_lines, $line, $file) = @_;

    #if there are no accounts, there is no transaction
    if(@account_lines == 0)
    {
	return;
    }

    @account_lines = balance_account_lines($file, $line, @account_lines);

    #figure out the currency types on each side of the transaction
    #and the amounts
    my ($pos_asset_currency, $pos_asset_amount,
	$neg_asset_currency, $neg_asset_amount) = (undef, 0, undef, 0);

    foreach (@account_lines)
    { 
	my ($acct,$amt,$curr) = hv_to_a(3,$$_);

	if($acct =~ /${assets}/)
	{
	    my ($asset_curr, $asset_amt, $expense) =
		$amt > 0 ? 
		(\$pos_asset_currency, \$pos_asset_amount, \$pos_expense)
		:
		(\$neg_asset_currency, \$neg_asset_amount, \$neg_expense);
	    
	    error(file => $file, line => $line, msg => "Only one currency per side of the transaction is allowed, $pos_asset_currency and $curr exist")
		if (defined $$asset_curr) && $$asset_curr ne $curr;
	    
	    $$asset_curr = $curr;
	    $$asset_amt += $amt;
	}
    }
    
    

sub add_price_quote
{
    my ($weight, $date, $time, $curr, $amt, $pq_base_curr) = @_;

    $time = (!defined $time) ? "" : $time;

    if($pq_base_curr eq $base_curr)
    {
	my $pq_data = $curr_datetime_to_price_quote_data{$curr}->{$date}->{$time} 
	or ($curr_datetime_to_price_quote_data{$curr}->{$datetime} = { total_weight => 0, pq_list => [] });

	$pq_data->{total_weight} += $weight;
	push @{$pq_data->{pq_list}}, { weight => $weight, 
				       curr => $curr,
				       amt => $amt,
				       pq_base_curr => $pq_base_curr
	};
    }
    #else ignore it, because it's not associated to our currency
}


sub parse_amt_curr
{
    my ($s) = @_;

    my ($curr,$amt);

    #if currency is printed first, ex $ 1.23
    if($s =~ /(${curr_reg})\s*([+-]?)\s*(\d*\.\d+)/)
    {
	$curr = $1;
	if($2 eq "-")
	{
	    $amt = -$3;
	}
	else
	{
	    $amt = $3;
	}
    } 
    #if currency is second, ex 1.23 BTC
    elsif($s =~ /([+-]?)\s*(\d*\.\d+)\s+(${curr_reg})/)
    {
	$curr = $1;
	if($2 eq "-")
	{
	    $amt = -$3;
	}
	else
	{
	    $amt = $3;
	}
    }
    else
    {
	return undef;
    }

    return ($curr,$amt);
    
}

sub read_account_line
{
    my ($line) = @_;


    
}

sub add_tran
{
    
}
