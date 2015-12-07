#!/usr/bin/perl -w

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
    print "Usage $0 -a <assets regexp> -i <income regexp> -e <expenses regexp> -bc <base currency (usually \$ or USD)> [-accuracy (decimal accuracy, defaults to 20 places)]  <dat file1> [dat file2...]

Reads a ledger style file and creates a capital gains report using the FIFO method, including the calculation of wash sales.

This program will look for any transaction where two different currencies are included in a transaction,
and are both designated within accounts you own (ex. USD and BTC, or BTC and ETH). These transactions
will be hereto referred to as 'trades'.

It will also look for transactions from an Income account and an Asset account. These are considered
taxable income events and included in the report.

Accounts are split into three categories. Assets, Expenses and Income.

Assets are accounts you own and you wish to calculate capital gains for. Note that you'll probably
 want to include liability accounts in this category, since paying down a CC is really the addition
 to a negative asset.
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

use Data::Dumper;

use Getopt::Long;
my ($assets_reg,
    $income_reg,
    $expenses_reg,
    $base_curr, 
    $accuracy
    ) = ('^Assets', '^Income', '^Expenses', '$', 20);

GetOptions ("assets=s" => \$assets_reg,    
	    "income=s"   => \$income_reg,  
	    "expenses=s"  => \$expenses_reg,
	    "accuracy=i"  => \$accuracy,
	    "basecurr=s" => \$base_curr)
    or die("Error in command line arguments\n");

use bignum('a',$accuracy);

use IO::File;

our $date_reg = '\d{4}[/-]\d{1,2}[/-]\d{1,2}';
our $time_reg = '\d\d:\d\d:\d\d';
our $curr_reg = '(?:\"[^"]*\"|[^\s0-9+.-]+)';
#                   ^ "foo $" ^ BTC or $, ...

our $amt_curr_reg = "(?:[+-]?\\s*${curr_reg}\\s*[+-]?\\s*\\d*\\.?\\d+|[+-]?\\s*\\d*\\.?\\d+\\s+${curr_reg})";
#                     ^ +/- <curr> <amount>                          ^ +/- <amount> curr
#                       or <curr> +/- <amount>

our $curr_file;
our $curr_text;
our $curr_line;

our @curr_tran_text;
my %curr_to_price_quotes;

our @trades; #the list of trades sent to the capital gain logic

{
    my (@account_lines, %curr_datetime_to_price_quote_data);
    
    my $tran_index = 0;
    foreach $curr_file (@ARGV)
    {
	my $f = new IO::File;
	
	if($curr_file ne '-')
	{
	    open($f, $curr_file) || die "Can't open $curr_file";
	}
	else
	{
	    $f = \*STDIN;
	    bless $f, 'IO::Handle' unless eval { $f->isa('IO::Handle') };
	}

	my ($date, $time,$desc, @account_lines, $curr_tran_line, $curr_tran_file);

	$curr_line = 0;
	
	foreach $curr_text (<$f>)
	{
	    $curr_line++;
	    chomp $curr_text;

	    #remove comment
	    $curr_text =~ s/;.*//;

	    #remove trailing whitespace
	    $curr_text =~ s/^(.*?)\s*$/$1/;
	    
	    if($curr_text =~ /^$/)
	    {
		next;
	    }

	    if($curr_text =~ /^P/) # price quote
	    {
		#P 2015-04-29 BTC $224.16
		my ($date,$time,$curr, $amt_curr) = 
		    $curr_text =~ 
		    /^P (${date_reg})(?:\s+(${time_reg}))?\s+(${curr_reg})\s+(${amt_curr_reg})$/
		    or error(msg => "Can't read price quote");

		$time = "00:00:00" if !defined $time;

		add_price_quote($date,$time,$tran_index,
				$curr, parse_amt_curr($amt_curr));
		
	    }
	    elsif($curr_text =~ /^account .*/) # account command, ignore
	    {
		next;
	    }
	    elsif($curr_text =~ /^\d\d/)
	    {
		#2013/05/15 01:29:42 * TID 1368581382704406
		#add previous tran if any to db
		add_tran($date,$time, $tran_index, $desc, 
			 $curr_tran_line, $curr_tran_file, \@curr_tran_text, @account_lines);

		$tran_index++;
		$curr_tran_line = $curr_line;
		$curr_tran_file = $curr_file;
		@account_lines = ();

		@curr_tran_text = ($curr_text);

		($date,$time,$desc) = $curr_text =~ /^(${date_reg})(?:\s+(${time_reg}))?\s+(.*)/ 
		    or error(txt=>$curr_text, msg => "Can't parse datetime, must be YYYY-MM-DD or YYYY-MM-DD hh:mm:ss");
		$time = "00:00:00" if !defined $time;
		
		next;
	    }
	    elsif($curr_text =~ /^[^\s]/)
	    {
		error(msg => "Don't understand line, '$curr_text'");
	    }
	    else
	    {
		#    Assets:MtGox                  -17.51286466 BTC @ $ 110.10000
		#    Assets:MtGox                  $ 1916.59740
		my ($account, $amt_curr, $price_amt_curr) = 
		    $curr_text =~ /^\s+((?:[^\s]| [^\s])+)(?:[  \s|\t]\s*(${amt_curr_reg})(?: @ (${amt_curr_reg}))?)?$/ 
		    or error(txt=>$curr_text, msg => "Can't read account line");

		my ($amt,$curr) = parse_amt_curr($amt_curr) if $amt_curr;

		my ($price_amt, $price_curr) = parse_amt_curr($price_amt_curr) if $price_amt_curr;

		push @account_lines, { acct => $account, amt => $amt, 
				       curr => $curr, price_amt => $price_amt,
				       price_curr => $price_curr
		};
		
		push @curr_tran_text, $curr_text;
	    }
	}

	add_tran($date, $time, $tran_index, $desc, $curr_tran_line, $curr_tran_file,
		 \@curr_tran_text, @account_lines);
    }
}

die "TODO: send \@trades to wash stuff";


#utility to convert a hash to an array sorted by keys
sub hv_to_a
{
    my ($size, $hash) = @_;

    if($size != (keys %$hash))
    {
	die "size $size doesn't match hash count ".(keys %$hash)." hash is ".
	    Dumper($hash);
    }

    map { ($hash->{$_}); } (sort keys %$hash);
}

sub balance_account_lines
{
    my ($file, $line, $tran_text, @account_lines) = @_;
    #balance lines (this is the standard ledger operation to fill values for lines that don't exist
    my $empty_account;
    my %curr_to_balance;
    my %curr_to_price_amt;
    
    my $index = 0;
    @account_lines = map {
	; #you must keep the ';'!
	my ($acct,$amt,$curr,$price_amt,$price_curr) = hv_to_a(5,$_);
	if(defined $curr)
	{
	    if(defined $price_amt)
	    {
		$curr = $price_curr;
		$amt = $amt * $price_amt;
	    }
	    
	    $curr_to_balance{$curr} = 
		($curr_to_balance{$curr} or 0)
		+ $amt;

	    ($_);
	}
	else
	{
	    error(file=>$file, line=>$line, tran_text => $tran_text, msg=>"More than one empty account line. Cannot balance")
		if $empty_account;

	    $empty_account = $acct;
	    (); #eat the empty line
	}
    } @account_lines;

    #if there is an account to scoop up the remainders
    if(defined $empty_account)
    {
	my @res;
	
	#put all non balancing currencies into it
	@res = map {
	    my $bal = $curr_to_balance{$_};
	    if($bal != 0)
	    {
		({ acct => $empty_account, amt => -$bal, curr => $_, price_amt => undef, price_curr => undef });
	    }
	    else { delete $curr_to_balance{$_}; }
	} (sort keys %curr_to_balance);

	push @res, @account_lines; #add the other lines

	return @res;
    }
    else 
    {
	if((keys %curr_to_balance) == 1)
	{
	    #make sure all the account values balance
	    foreach (keys %curr_to_balance)
	    {
		if($curr_to_balance{$_} != 0)
		{
		    error(file=>$file, line=>$line, tran_text => $tran_text, 
			  msg => "Non balancing currency, $_: ".$curr_to_balance{$_});
		}
	    }
	}
	
	return @account_lines;
    }
}

sub assign_hash_defaults
{
    my ($defaults, %hash) = @_;
    return (map { 
	($_, ($hash{$_} or $defaults->{$_})) 
	    } 
	    (keys %$defaults));
}    



sub error
{
    my ($file, $line, $msg,$tran_text, $txt) =
	hv_to_a(5,
		{assign_hash_defaults({file => $curr_file,
				      line => $curr_line,
				      msg => "",
				      tran_text => undef,
				      txt => "",
				      },
				     @_)});
    
    print STDERR "ERROR $file: $line  -- $msg\n";
    if($txt)
    {
	print STDERR "    Line is: $txt\n\n";
    }
    if($tran_text)
    {
	print STDERR "Tran is:\n".join("\n",@$tran_text)."\n\n";
    }
}

sub add_tran
{
    my ($date, $time, $index, $desc, $line, $file, $tran_text, @account_lines) = @_;

    #if there are no accounts, there is no transaction
    if(@account_lines == 0)
    {
	return;
    }

    @account_lines = balance_account_lines($file, $line, $tran_text, @account_lines);

    #figure out the currency types on each side of the transaction
    #and the amounts
    my ($pos_asset_currency, $pos_asset_amount,
	$neg_asset_currency, $neg_asset_amount) = (undef, 0, undef, 0);

    foreach (@account_lines)
    { 
	my ($acct,$amt,$curr, $price_amt, $price_curr) = hv_to_a(5,$_);

	if($acct =~ /${assets_reg}/)
	{
	    my ($asset_curr, $asset_amt) =
		$amt > 0 ? 
		(\$pos_asset_currency, \$pos_asset_amount)
		:
		(\$neg_asset_currency, \$neg_asset_amount);
	    
	    error(file => $file, line => $line, msg => "Only one currency per side of the transaction is allowed, $$asset_curr and $curr exist")
		if (defined $$asset_curr) && $$asset_curr ne $curr;
	    
	    $$asset_curr = $curr;
	    $$asset_amt += $amt;
	}
    }

    my ($pos_expense, $neg_expense) = (0,0);

    #figure out where to put the expense accounts
    foreach (@account_lines)
    { 
	my ($acct,$amt,$curr,$price_amt, $price_curr) = hv_to_a(5,$_);

	if($acct =~ /${expenses_reg}/)
	{
	    if($pos_asset_currency && $curr eq $pos_asset_currency)
	    {
		$pos_expense += $amt;
	    }
	    elsif($neg_asset_amount && $curr eq $neg_asset_currency)
	    {
		$neg_expense += $amt;
	    }
	    else
	    {
		error(file => $file, line => $line, msg => "Expense currency must be equal to one of the currencies of the transaction, got: $curr, pos curr $pos_asset_currency, neg curr $neg_asset_currency");
	    }
	}
    }

    if(map { 	
	if($_->{acct} =~ /${income_reg}/) { (1) }
	else { (); }
       } (@account_lines))
    {
	#an income transaction

	error(file => $file, line => $line, msg => "Income can't have expense accounts")
	    if $pos_expense || $neg_expense;
	
	
	push @trades, { sort_by => create_sort_by($date,$time,$index),
			type => 'buy',
			amt => $pos_asset_amount,
			price => 0,
			curr => $pos_asset_currency };
	error(file => $file, line => $line, msg => "TODO handle income transaction");
    }
    else
    {
	if((!defined $pos_asset_currency) || (!defined $neg_asset_currency))
	{
	    #we only care about internal (asset to asset) transactions. If the money is being sent/received
	    #somewhere else, its not 
	    return;
	}
	
	#if an internal transfer from one asset account to another
	if($pos_asset_currency eq $neg_asset_currency)
	{
	    #fees from transferring funds around are not deductable AFAIK
	    #http://www.beansmart.com/taxes/are-wire-transfer-cost-deductible-20873-.htm
	    #so we ignore it
	    return;
	}
	
	my ($pos_expense, $neg_expense) = (0,0);	

	if($pos_asset_currency ne $base_curr)
	{
	    push @trades, {
		type => 'buy',
		date => $date,
		time => $time,
		index => $index,
		amt => $pos_asset_amount,
		expense => $pos_expense,
		#if the other side is the base currency, we use it as
		#the cost basis, otherwise we leave it undef, to calculate
		#after we are done reading the files
		curr => $pos_asset_currency,

		#value adjusting for expenses
		total_value => ($neg_asset_currency eq $base_curr ?
			  -($neg_asset_amount + $neg_expense)
			  : undef)
	    };
	}
	if($neg_asset_currency ne $base_curr)
	{
	    push @trades, {
		
		type => 'sell',
		date => $date,
		time => $time,
		index => $index,
		amt => $neg_asset_amount,
		expense => $neg_expense,
		#if the other side is the base currency, we use it as
		#the cost basis, otherwise we leave it undef, to calculate
		#after we are done reading the files
		curr => $neg_asset_currency,

		#value adjusting for expenses
		total_value => ($pos_asset_currency eq $base_curr ?
			  $pos_asset_amount + $pos_expense 
			  : undef)
	    };
	}
    }
}


sub create_sort_by
{
    my ($date, $time, $index) = @_;

    #note if there is no time, then there will be 2 spaces between date and index. This will make
    #all transactions without a time the first for the day
    return $date." ".$time." I".$index;
}

sub add_price_quote
{
    my ($date, $time, $index, $curr, $amt, $pq_base_curr) = @_;

    $time = (!defined $time) ? "" : $time;

    if($pq_base_curr eq $base_curr)
    {
	push @{$curr_to_price_quotes{$curr}}, 
	{
	    date => $date,
	    time => $time,
	    index => $index,
	    curr => $curr,
	    amt => $amt,
	};
    }
    #else ignore it, because it's not associated to our currency
}


sub parse_amt_curr
{
    my ($s) = @_;

    my ($curr,$amt);

    #if sign is first, currency is second, ex -$ 1.23
    if($s =~ /([+-]?)\s*(${curr_reg})\s*(\d*\.?\d+)/)
    {
	$curr = $2;
	if($1 eq "-")
	{
	    $amt = -$3;
	}
	else
	{
	    $amt = $3;
	}
    } 
    #if currency is printed first, sign second, ex $ - 1.23
    if($s =~ /(${curr_reg})\s*([+-]?)\s*(\d*\.?\d+)/)
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
    elsif($s =~ /([+-]?)\s*(\d*\.?\d+)\s+(${curr_reg})/)
    {
	$curr = $3;
	if($1 eq "-")
	{
	    $amt = -$2;
	}
	else
	{
	    $amt = $2;
	}
    }
    else
    {
	return undef;
    }

    #convert $amt to a bigfloat with specified precision
    my $precision = 0;
    
    if($amt =~ /\.(.*)/)
    {
	$precision = -(length $1);
    }

    use Math::BigFloat;

    $amt = Math::BigFloat->new($amt);
    $amt->precision($precision);

    return ($amt, $curr);
    
}

