#!/usr/bin/perl -w

#TODO 2: Change Copyright to 2012, 2015-2016 for all files

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
    print "Usage perl ledger_wash.pl [-a <assets regexp>] [-i <income regexp>] [-e <expenses regexp>] [-g <gift regexp>] [-bc <base currency (usually \$ or USD)>] [-accuracy (decimal accuracy, defaults to 20 places)]  [-unr-date <unrealized cap gain date>] <dat file1> [dat file2...]

Reads a ledger style file (see http://www.ledger-cli.org/) and creates a capital gains report using the FIFO method.

This program will look for any transaction where two different currencies are included in a transaction,
and are both designated within accounts you own (ex. USD and BTC, or BTC and ETH). These transactions
will be hereto referred to as 'trades'.

It will also look for transactions from an Income account and an Asset account. These are considered
taxable income events and included in the report.

Accounts are split into three categories. Assets, Expenses and Income.

Assets are accounts you own and you wish to calculate capital gains for. Note that you'll probably
 want to include liability accounts in this category, since paying down a CC is really the addition
 to a negative asset (if you pay your credit card with a cryptocurrency, that is)
Income are accounts from which you receive an Asset. For example, if you mine bitcoin and you have
    an 'Income:Mining' account.
Expenses are accounts where expenses go. When expenses are one or more of the outputs for trades or
    income transactions, they are deducted from the capital gains received. In any other transaction,
    (such as those associated with transferring assets around), they are ignored for reporting,
    but still kept track of, so that funds spent in expenses don't appear as a basis for sells.

<assets regex> : Regex for when an account should be included in Assets (default '^Assets' which means 
   begins with Assets)
<income regex> : Same as above, but for Income accounts (default '^Income')
<expenses regex> : Same as above, but for Expenses accounts (default '^Expenses')
<gift regex> : Regex for gifts. If there are transfers to a gift account, the cost basis is
               shown in a separate report

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

If unr_date is specified, then the total unrealized long term and short term gains are reported as of the given date. Prices for the held currencies on that date must be available
";

    exit -1;
}

require 'util.pl';

use Data::Dumper;

use Getopt::Long;
my ($assets_reg,
    $income_reg,
    $expenses_reg,
    $gift_reg,
    $base_curr, 
    $accuracy,
    $unr_date,
    $unr_reg
    ) = ('^Assets', '^Income', '^Expenses', '^Gift', '$', 20, undef, '^Assets');

GetOptions ("assets=s" => \$assets_reg,    
	    "income=s"   => \$income_reg,  
	    "expenses=s"  => \$expenses_reg,
	    "gift=s"  => \$gift_reg,
	    "basecurr=s" => \$base_curr,
	    "unr-date=s" => \$unr_date,
	    "unr-reg=s" => \$unr_reg,
    )
    or die("Error in command line arguments\n");

use Math::BigRat;

$ZERO = new Math::BigRat(0);

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

our $file_prefix = $ARGV[0];

if((defined $unr_date) && !($unr_date =~ $date_reg))
{
    die "Can't understand unr-date '$unr_date'";
}

foreach $curr_file (@ARGV)
{
    while(!($curr_file =~ /^\Q$file_prefix\E/)) { chop $file_prefix; }
}

my $tran_index = 0;

{
    my (@account_lines, %curr_datetime_to_price_quote_data);
    
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

	$curr_file =~ s/^$file_prefix// or die "Why we can't remove prefix? $file_prefix $curr_file";

	my ($date, $time,$desc, @account_lines, $curr_tran_line, $curr_tran_file);

	$curr_line = 0;
	
	foreach $curr_text (<$f>)
	{
	    $curr_line++;
	    chomp $curr_text;

	    #ledger first character in line comments 
	    if($curr_text =~ /^[\#\;\*\|]/)
	    {
		next;
	    }

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

		$date = normalize_date($date);
		$time = "00:00:00" if !defined $time;

		add_price_quote($date,$time,$tran_index,
				$curr, parse_amt_curr($amt_curr));
		
		$tran_index++;
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
			 $curr_tran_line, $curr_tran_file, [@curr_tran_text], @account_lines);

		$tran_index++;
		$curr_tran_line = $curr_line;
		$curr_tran_file = $curr_file;
		@account_lines = ();

		@curr_tran_text = ($curr_text);

		($date,$time,$desc) = $curr_text =~ /^(${date_reg})(?:\s+(${time_reg}))?\s+(.*)/ 
		    or error(txt=>$curr_text, msg => "Can't parse datetime, must be YYYY-MM-DD or YYYY-MM-DD hh:mm:ss");
		$date = normalize_date($date);
		$time = "00:00:00" if !defined $time;
		
		next;
	    }
	    elsif($curr_text =~ /^[^\s]/)
	    {
		error(msg => "Don't understand line, '$curr_text'");
	    }
	    else
	    {
		#    Assets:Bank:Unknown	  $2574.59 @@ 5.0000 BTC
		#    Assets:MtGox                  -17.51286466 BTC @ $ 110.10000
		#    Assets:MtGox                  $ 1916.59740
		my ($account, $amt_curr, $at_or_atat, $price_amt_curr) = 
		    $curr_text =~ /^\s+((?:[^\s]| [^\s])+)(?:[  \s|\t]\s*(${amt_curr_reg})(?: (@@?) (${amt_curr_reg}))?)?$/ 
		    or error(txt=>$curr_text, msg => "Can't read account line");

		my ($amt,$curr) = parse_amt_curr($amt_curr) if $amt_curr;

		my ($price_amt, $price_curr);

		if ($price_amt_curr)
		{ 
		    ($price_amt, $price_curr) = parse_amt_curr($price_amt_curr) if $price_amt_curr;

		    $price_amt = bigrat($price_amt);
		    
		    if($at_or_atat eq "@@")
		    {
			$price_amt = $price_amt / $amt;
		    }
		}

		#push all lines except those with a specified zero value,ex:
		# Assets:xxxx     0.0000 ETH
		$amt_curr && $amt == 0 or
		    push @account_lines, { acct => $account, amt => bigrat($amt), 
					   curr => $curr, price_amt => $price_amt,
					   price_curr => $price_curr
		};
		
		push @curr_tran_text, $curr_text;

		error(txt=>$curr_text, msg => "Account $account matches both income and assets at the same time") if $account =~ /${assets_reg}/ && $account =~ /{$income_reg}/;
		error(txt=>$curr_text, msg => "Account $account matches both income and expenses at the same time") if $account =~ /${expenses_reg}/ && $account =~ /{$income_reg}/;
		error(txt=>$curr_text, msg => "Account $account matches both assets and expenses at the same time") if $account =~ /${expenses_reg}/ && $account =~ /{$assets_reg}/;
	    }
	}# for each line of text

	#at end of file, so add final transaction
	add_tran($date, $time, $tran_index, $desc, $curr_tran_line, $curr_tran_file,
		 [@curr_tran_text], @account_lines);
    } # foreach file
}

sort_trades();

foreach $curr (keys %curr_to_price_quotes)
{
    $curr_to_price_quotes{$curr} =    
	[sort compare_date_time_index @{$curr_to_price_quotes{$curr}}];
}

#print_csv();


#print_reports();

create_tax_items();

$tl->assignBuysToSells;

#$tl->print;
print "------------------------------------\n";
print "IRS Forms\n";
print "------------------------------------\n";
$tl->printIRS(undef, RT_NORMAL);
print "\n------------------------------------\n";
print "Gift Report\n";
print "------------------------------------\n";
$tl->printIRS(undef, RT_GIFT);

print "\n------------------------------------\n";
print "Other reports\n";
print "------------------------------------\n";
$tl->printRemainingBalances;
print "------------------------------------\n";

#if we are tasked to calculate the long term and short term gains if we sold on a particular date
if($unr_date)
{
    #add fake sells for each buy on the unrealized date

    my $d = &main::convertTextToDays($unr_date);

    my @sells;

    foreach my $buy ($tl->getUnsoldBuys())
    {
	{
	    my ($shares, $sym, $date, $buy_price) = ($buy->{shares}, $buy->{symbol}, $buy->{date}, $buy->{price});
	    # print "HACK: ".join("\t",
	    # 	   main::format_amt($shares),
	    # 	   $sym,
	    # 	   main::convertDaysToText($date),
	    # 	   main::format_amt($buy_price),
	    # 			$buy->refs_string())."\n";
	}			
	
	if($buy->{date} > $d) { die "unrealized cap gains sell date '$d', earlier than buy date, ".
				    $buy->{date}."\n"; }

	my $sell_price = figure_base_curr_price($buy->{shares},$buy->{symbol}, $unr_date,"00:00:00",++$tran_index);

	if(!defined $sell_price)
	{
	    error(file=>"<none>", line=>1, tran_text =>"Unreliazed Gain Report", type=>'WARN',
		  msg => "Couldn't figure sell price for ".$buy->{symbol}." on $unr_date, won't include in unrealized gain report");
	    next;
	}

	my $sell = $tl->add("s",$d,$buy->{shares},$sell_price,$buy->{symbol},[],RT_NORMAL,1);
	push @sells, $sell;

	$buy->markBuyForSell($sell);
    }

    print "\n\n*** Unrealized gains sold on $unr_date ***\n\n";

    $tl->printIRS(\@sells);
}


sub sort_trades
{
    @trades = sort compare_date_time_index @trades;
}

#this creates taxable events from the list of trades
sub create_tax_items
{

    use Sell;
    use Buy;
    use TradeList;
    
    $tl = new TradeList();
    
    foreach my $t (@trades)
    {
	my ($file,$line,$tran_text,$date,$time,$index) = hv_to_a(undef,$t,qw { file line tran_text date time index });
	    
	if($t->{type} eq 'transfer')
	{
	    my $amt = $t->{amt};
	    my $curr = $t->{curr};

	    if($amt > 0)
	    {
		error(file=>$file, line=>$line, tran_text => $tran_text, type=>'WARN',
		      msg => "Positive inflow for a transfer (non income transaction)");
	    }

	    #if a transfer and there is any difference at all, thats a fee, and we ignore it. However
	    #we still need to assign it a cost basis, so that we don't reuse the same
	    #cost basis for the fees and the transactions themselves.
	    #
	    #We do this by creating an "unreported" transaction, that won't show up
	    #on the report for the irs
	    
	    if($amt != 0 && $t->{curr} ne $base_curr)
	    {
		if($amt < 0)
		{
		    $tl->add("s", &main::convertTextToDays($date), -$amt, $ZERO,$t->{curr}, [$t],
			     RT_UNREPORTED) ;
		}
		else
		{
		    # if we gave negative units, or the transfer had a negative fee
		    # it's treated as a regular buy (warning is shown to the user above)
		    $tl->add("b",&main::convertTextToDays($date), $amt, $ZERO,$t->{curr}, [$t]) ;
		}

	    }
	}
	elsif($t->{type} eq 'gift')
	{
	    my $samt = $t->{amt};
	    my $ramt = $t->{received_amt};
	    my $fee = $samt + $ramt; # samt is negative
	    my $curr = $t->{curr};

	    if($fee > 0)
	    {
		error(file=>$file, line=>$line, tran_text => $tran_text, type=>'WARN',
		      msg => "Positive inflow for a gift (non income transaction)");
	    }

	    if($t->{curr} eq $base_curr)
	    {
		error(file=>$file, line=>$line, tran_text => $tran_text, type=>'ERROR',
		      msg => "Gifts in base currency, $base_curr, not currently supported");
	    }	

	    #for gifts, we create two transactions. One is for the fee
	    #and works just like a transfer
	    #The other is a regular 'sell' transaction that is put on a special gift report

	    #the fee transaction
	    if($fee != 0)
	    {
		if($fee < 0)
		{
		    $tl->add("s", &main::convertTextToDays($date), -$fee, $ZERO,$t->{curr}, [$t],
			     RT_UNREPORTED 
			     ) ;
		}
		else
		{
		    # if we gave negative units, or the transfer had a negative fee
		    # it's treated as a regular buy (warning is shown to the user above)
		    $tl->add("b",&main::convertTextToDays($date), $fee, $ZERO,$t->{curr}, [$t],
			     ) ;
		}
	    }

	    #the txn to appear on the gift report
	    $tl->add("s", &main::convertTextToDays($date), $ramt, $ZERO,$t->{curr}, [$t],
		     RT_GIFT) ;
	}
	elsif($t->{type} eq 'trade')
	{
	    my ($buy_base_val, $sell_base_val) = figure_trade_base_vals($t);

	    my ($buy_amt, $buy_curr, $sell_amt, $sell_curr) 
		= hv_to_a(undef,$t,qw { buy_amt buy_curr sell_amt sell_curr });

	    if($buy_amt != 0 && $buy_curr ne $base_curr)
	    {
		$tl->add("b",&main::convertTextToDays($date), $buy_amt, $buy_base_val,$buy_curr, [$t]);
	    }
	    if($sell_amt != 0 && $sell_curr ne $base_curr)
	    {
		$tl->add("s",&main::convertTextToDays($date), $sell_amt, $sell_base_val,$sell_curr, [$t],
		    RT_NORMAL);
	    }
	}
	elsif($t->{type} eq 'income')
	{
	    my ($amt, $curr) 
		= hv_to_a(undef,$t,qw { amt curr });

	    if($curr eq $base_curr)
	    {
		error(file => $file, line => $line, tran_text => $tran_text, type => "WARN", msg => "We don't report income of $base_curr as capital gains, so it won't be included in the report");

	    }

	    my $base_val = figure_base_curr_price($amt, $curr, $date, $time, $index);

	    if(!defined $base_val)
	    {
		#I believe even the fee technically must be reported, because it is a service
		#exchange used to transfer funds, but it's so tiny, that we allow it to be unreported
		error(file=>$file, line=>$line, tran_text => $tran_text, type=>'ERROR',
		      msg => "Can't determine base val for $amt $curr for income transaction");
	    }

	    
	    #first create a buy for 0 (since we acquired it through normal means, such as mowing lawns,
	    # etc., and according to the IRS your man-hours are worth *nothing*, as further demonstrated 
	    # by the incredible complexity and vagueness of the tax rules)
	    my $income_buy = $tl->add("b",&main::convertTextToDays($date),$amt,$ZERO,$curr, [$t],undef,1);

	    #sell it at market price to report the gains
	    my $income_sell = $tl->add("s",&main::convertTextToDays($date), $amt, $base_val,$curr, [$t],RT_NORMAL,1);

	    #join the buy and sell ahead of time, so the income line cost basis will always be
	    #zero. Otherwise it will use its standard matching algorithm, which means that the buy 
	    #assigned might be from an earlier purchase.
	    $income_buy->markBuyForSell($income_sell);

	    #finally, rebuy it
	    $tl->add("b",&main::convertTextToDays($date), $amt, $base_val,$curr, [$t]);
	}
	else {
	    die "What is $t->{type}?";
	}
    }

    print STDERR (scalar @trades)." trades creating ".(scalar @{$tl->{list}})." items\n";
 
}


#utility to convert a hash to an array sorted by keys
sub hv_to_a
{
    my ($size, $hash, @fields) = @_;

    @fields = sort keys %$hash unless @fields;

    if((defined $size) && $size != @fields)
    {
	die "size $size doesn't match hash count ".@fields." hash is ".
	    Dumper($hash);
    }

    map { ($hash->{$_}); } @fields;
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
	    else { delete $curr_to_balance{$_}; (); }
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
		if(abs($curr_to_balance{$_}) > 0.0001)
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
    my ($file, $line, $msg,$tran_text, $txt, $type) =
	hv_to_a(6,
		{assign_hash_defaults({file => $curr_file,
				       line => $curr_line,
				       msg => "",
				       tran_text => $curr_tran_text,
				       txt => "",
				       type => "ERROR",
				      },
				     @_)});
    
    print STDERR "$type $file: $line  -- $msg\n";
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
    my ($date, $time, $index, $desc, $line, $file,$tran_text, @account_lines) = @_;

    #if there are no accounts, there is no transaction
    if(@account_lines == 0)
    {
	return;
    }

    @account_lines = balance_account_lines($file, $line, $tran_text, @account_lines);

    my ($asset_ag, $income_ag, $expense_ag, $gift_ag) = 
	create_account_groups(
	    sub { my $msg = shift;
		  my $type = shift;
		  error(file => $file, line => $line, tran_text => $tran_text, msg => $msg, type => $type);
	    },
	    \@account_lines, 
	    sub { /${assets_reg}/ }, 
	    sub { /${income_reg}/ },
	    sub { /${expenses_reg}/ },
	    sub { /${gift_reg}/ }
	);

    #if income transaction
    if(ag_currs($income_ag) != 0)
    {
	ag_currs($income_ag) == 1 or 
	    error(file => $file, line => $line, tran_text => $tran_text, msg => "Only one currency for income transactions is allowed");
	ag_currs($asset_ag) == 1 or 
	    error(file => $file, line => $line, tran_text => $tran_text, msg => "Only one currency for income transactions is allowed");

	my ($icurr,$iamt) =  ag_get_curr_amt($income_ag);
	my ($acurr,$aamt) =  ag_get_curr_amt($asset_ag);

	$icurr eq $acurr or
	    error(file => $file, line => $line, tran_text => $tran_text, msg => "Only one currency for income transactions is allowed");

	$aamt > 0 or
	    error(file => $file, line => $line, tran_text => $tran_text, msg => "Amount for asset accounts must be positive, got: $aamt");

	push @trades, { 
		file => $file,
		line => $line,
		tran_text => [@$tran_text],
		type => 'income',
		date => $date,
		time => $time,
		index => $index,
		amt => $aamt,
		curr => $acurr};
    }
    elsif(($_ = ag_currs($asset_ag)) != 0)
    {
	if($_ == 1) #if a gift or a transfer
	{
	    my ($acurr,$aamt) =  ag_get_curr_amt($asset_ag);
	    
	    my ($rcurr,$ramt);

	    if (ag_currs($gift_ag) != 0) {
		$type = 'gift';

		#if a gift, then there might be expenses.
		#So the amount received by the receipient may differ from
		#the amount given.
		#So we find the amount received here
		($rcurr,$ramt) =  ag_get_curr_amt($gift_ag);

		if($rcurr ne $acurr)
		{
		    error(file => $file, line => $line, tran_text => $tran_text, msg => "The currency of the received amount of a gift ($rcurr) must equal the currency of the sent amount ($acurr)");
		}
	    }
	    else
	    {
		$type = 'transfer';
	    }
	    
	    #transfers are ignored for tax, but we need it for our balancing report, and to make sure
	    #we don't claim a basis for funds that we don't have anymore, due to fees

	    #gifts are also not included in the irs report. The cost basis from them has to be eliminated,
	    #also, however
	    push @trades, { 
		file => $file,
		line => $line,
		tran_text => [@$tran_text],
		type => $type,
		date => $date,
		time => $time,
		index => $index,
		amt => $aamt,
		curr => $acurr,
		received_amt => $ramt
	    };
	}
	elsif($_ == 2) # two currencies mean a trade
#TODO 2: This is not always true! See the LSK transaction in test.dat (right now generates an error)
	{
	    my ($curr1,$amt1,$curr2,$amt2) =  ag_get_curr_amt($asset_ag);

	    my ($expense_curr, $expense_amt);
	    if(($_ = ag_currs($expense_ag)) == 1)
	    {
		($expense_curr, $expense_amt) = ag_get_curr_amt($expense_ag);
	    }
	    elsif($_ == 0) #if no expense account, we default to zero
	    {
		$expense_curr = $base_curr;
		$expense_amt = $ZERO;
	    }
	    else {
		error(file => $file, line => $line, tran_text => $tran_text, msg => "The expense account may contain only one currency");
	    }
           
	    $amt1 < 0 && $amt2 > 0 || $amt1 > 0 && $amt2 < 0 or
		error(file => $file, line => $line, tran_text => $tran_text, msg => "If a transfer or trade, and contains two currencies, then there must be a positive and negative amount");

	    if($amt1 < 0)
	    {
		my ($tamt,$tcurr) = ($amt1,$curr1);

		$amt1 = $amt2;
		$curr1 = $curr2;
		$amt2 = $tamt;
		$curr2 = $tcurr;
	    }

	    #a real trade
	    push @trades, {
		file => $file,
		line => $line,
		tran_text => [@$tran_text],
		type => 'trade',
		date => $date,
		time => $time,
		index => $index,
		buy_amt => $amt1,
		buy_curr => $curr1,
		sell_amt => -$amt2,
		sell_curr => $curr2,
		expense_amt => $expense_amt,
		expense_curr => $expense_curr,
	    };
	}
	else # more than 2 currencies
	{
		error(file => $file, line => $line, tran_text => $tran_text, msg => "A transaction cannot contain more than 2 currencies in the asset category");
	}
    }
    else #assets hasn't changed
    {
	#no-op
    }
}

sub add_price_quote
{
    my ($date, $time, $index, $curr, $amt, $pq_base_curr) = @_;

    $time = (!defined $time) ? "" : $time;

    push @{$curr_to_price_quotes{$curr}}, 
    {
	date => $date,
	time => $time,
	index => $index,
	curr => $curr,
	amt => bigrat($amt),
	base_curr => $pq_base_curr
    };
}

sub binary_search {
    my ($array_ref, $compare_func, $left, $right) = @_;

    my $middle = 0;
    while ($left <= $right) {
	$middle = int(($right + $left) >> 1);
	my $value = $compare_func->($array_ref->[$middle]);
	if ($value == 0) {
	    return $middle;
	} elsif ($value < 0) {
	    $right = $middle - 1;
	} else {
	    $left = $middle + 1;
	}
    }

    # returns the index at which the key was found, or -n-1 if it was not
    # found, where n is the index of the first value greater than key or
    # length if there is no such value.
    return -$left-1;
}

sub compare_date_time_index($$)
{
    my ($a,$b) = @_;
    $a->{date} cmp $b->{date} 
    or $a->{time} cmp $b->{time} 
    or $a->{index} cmp $b->{index};
}

#finds the price of the currency in base units. Will even find the result if it has to chain
#currency prices together (ie we know NEU to BTC and BTC to $, so we can calculate NEU to $)
#tried_currencies should not be set (for internal use)
sub figure_base_curr_price
{
    my ($amt, $curr, $date, $time, $index, %tried_currencies) = @_;

    return $amt if($curr eq $base_curr);

    return $ZERO if $amt == 0;

    $tried_currencies{$curr} = 1;
    
    my $pq = $curr_to_price_quotes{$curr};

    my $target = { date => $date,
		   time => $time,
		   index => $index
    };

    if (!defined $pq)
    {
	return undef;
    }

    my $pos = binary_search($pq, sub { compare_date_time_index($target, $_[0]) } , 0, $#{$pq});

    if($pos >= 0)
    {
	die "Why is there an exact match, every row should have a unique index????";
    }

    #pos = -n-1
    #we want n-1, which is the index prior to the target in the order sorted by compare_date_time_index
    #n = -1 -pos
    #n - 1 = -2 -pos
    $pos = -2-$pos;

    if($pos < -1)
    {
	return undef;
    }
    
    $pos == -1 and $pos = 0;

    my $start_pos = $pos;

    my $search = 
	sub {
	    my ($pos, $dir, $test) = @_;
	    
	    #search in the direction specified until $test returns not false, or the date
	    #isn't the current date
	    while($pos >= 0 && $pos <= $#{$pq})
	    {
		my $r = $pq->[$pos];

		if($r->{date} ne $date)
		{
		    last;
		}

		$_ = $test->($r) and return $_;

		$pos += $dir;
	    }

	    undef;
    };

    my $base_curr_test =
	sub {
	    my ($r) = @_;
	    if($r->{base_curr} eq $base_curr)
	    {
		return $r->{amt} * $amt;
	    }
	    
	    undef;
    };
    
    #search for for any currency not already tried, and we'll recursively search that
    #to find a chain of currency prices. 
    #
    # ex, 1 NEU = .3 BTC and 1 BTC = $0.50
    # means 1 NEU = .3 * .5 = $ .15 
    #first search backwards
    my $other_curr_test =
	sub {
	    my ($r) = @_;
	    if(!$tried_currencies{$r->{base_curr}})
	    {
		my $ratio =  figure_base_curr_price(1, $r->{base_curr}, $date, $time, $index,
						    %tried_currencies);
		
		if(defined $ratio)
		{
		    return $r->{amt} * $amt * $ratio;
		}

		undef;
	    }
	    if($r->{base_curr} eq $base_curr)
	    {
		return $r->{amt} * $amt;
	    }
    };
    

    my $res = $search->($pos, -1, $base_curr_test) 
	|| $search->($pos+1, 1, $base_curr_test) 
	|| $search->($pos, -1, $other_curr_test) 
	|| $search->($pos+1, 1, $other_curr_test) ;

    $res = undef if (defined $res) && $res eq '';

    return $res;
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
    elsif($s =~ /(${curr_reg})\s*([+-]?)\s*(\d*\.?\d+)/)
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

    # co: this would make all operations round to the given precision, which would
    # be bad
    # #convert $amt to a bigfloat with specified precision
    # my $precision = 0;
    
    # if($amt =~ /\.(.*)/)
    # {
    # 	$precision = -(length $1);
    # }

    # use Math::BigFloat;

    # $amt = Math::BigFloat->new($amt);
    # $amt->precision($precision);

    return ($amt, $curr);
    
}

#check balance
sub print_reports
{
    my %curr_to_balance;

    print "reg report:\n";

    foreach my $t (@trades)
    {

	if($t->{type} eq 'trade')
	{
	    $curr_to_balance{$t->{buy_curr}} = $ZERO unless defined $curr_to_balance{$t->{buy_curr}};
	    $curr_to_balance{$t->{sell_curr}} = $ZERO unless defined $curr_to_balance{$t->{sell_curr}};
	    $curr_to_balance{$t->{buy_curr}} += $t->{buy_amt};
	    $curr_to_balance{$t->{sell_curr}} += -$t->{sell_amt};
	}
	else {
	    $curr_to_balance{$t->{curr}} = $ZERO unless defined $curr_to_balance{$t->{curr}};
	    if($t->{type} eq 'transfer' || $t->{type} eq 'gift' || $t->{type} eq 'income')
	    {
		$curr_to_balance{$t->{curr}} += $t->{amt};
	    }
	    else
	    { die $t->{type};}
	}

	print "$t->{date} $t->{time} $t->{index}\n";
	foreach my $c (sort keys %curr_to_balance)
	{
	    print "   $c ".$curr_to_balance{$c}->as_float()."\n";
	}

	print "\n";
    }

    print "bal report:\n";

    foreach my $c (sort keys %curr_to_balance)
    {
	print "   $c ".$curr_to_balance{$c}->as_float()."\n";
    }
    
}

sub normalize_date
{
    my ($date) = @_;

    my ($y,$m,$d) = $date =~ /(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})/ or die "Can't read date '$date'";

    return sprintf('%04d-%02d-%02d',$y,$m,$d);
}

sub create_account_groups
{
    my ($error_sub, $accts, @subs) = @_;

    #create one account group per sub
    my @res_ag =
	map { ;{
	    curr_to_amt => {}
	      };} 1..(scalar @subs);


    #add the currency of each account to its account group
    foreach my $a (@{$accts})
    {
	my $found_sub_already;
	for(my $i = $#subs; $i >=0; $i--)
	{
	    $_ = $a->{acct};
	    if($subs[$i]->())
	    {
		!$found_sub_already or
		    $error_sub->("Account appears in more than one category, $a->{acct}","ERROR");
		$found_sub_already = 1;

		my ($amt,$curr) = ($a->{amt},$a->{curr});
		
		my $curr_to_amt = $res_ag[$i]->{curr_to_amt};

		defined $curr_to_amt->{$curr} or $curr_to_amt->{$curr} = $ZERO;

		$curr_to_amt->{$curr} += $amt;
	    }
	}
	if(!(defined $found_sub_already))
	{
	    $error_sub->("Account doesn't appear in any category, $a->{acct}","ERROR");
	}
    }
    
    return @res_ag;
}

sub ag_currs
{
    return scalar keys %{shift->{curr_to_amt}};
}

#returns each currency and corresponding amount of the accounting group as a list
sub ag_get_curr_amt
{
    my ($ag) = @_;
    
    return map { ($_, $ag->{curr_to_amt}->{$_}); } keys %{$ag->{curr_to_amt}};
}


sub figure_trade_base_vals
{
    my ($t) = @_;

    my ($file,$line,$tran_text,$date,$time,$index,$buy_curr,$buy_amt,$sell_curr,$sell_amt,
	$expense_curr,$expense_amt) = 
	    hv_to_a(undef,$t,
		    qw {  file  line  tran_text  date  time  index  buy_curr  buy_amt  sell_curr  sell_amt 
	 expense_curr  expense_amt });

    my ($buy_base_val, $sell_base_val);
    
    if($sell_curr eq $base_curr)
    {
	$buy_base_val = figure_trade_base_val_from_other_side('B', $t);
	$sell_base_val = $sell_amt;
    }
    elsif($buy_curr eq $base_curr)
    {
	$sell_base_val = figure_trade_base_val_from_other_side('S', $t);
	$buy_base_val = $sell_amt;
    }
    else
    {
	$buy_base_val = 
	    figure_base_curr_price($buy_amt, $buy_curr, $date, $time, $index)
	    || $expense_curr eq $sell_curr &&
	    figure_base_curr_price($sell_amt+$expense_amt, $sell_curr, $date, $time, $index)
	    || $expense_curr eq $base_curr &&
	    (defined ($_ = figure_base_curr_price($sell_amt, $sell_curr, $date, $time, $index)))
	    && ($_ + $expense_amt);

	$buy_base_val = undef unless $buy_base_val ne '';

	$sell_base_val = 
	     figure_base_curr_price($sell_amt, $sell_curr, $date, $time, $index)
	     || $expense_curr eq $buy_curr &&
	     figure_base_curr_price($buy_amt-$expense_amt, $buy_curr, $date, $time, $index)
	     || $expense_curr eq $base_curr &&
	     (defined ($_ = figure_base_curr_price($buy_amt, $buy_curr, $date, $time, $index)))
	     && ($_ - $expense_amt);

	$sell_base_val = undef unless $sell_base_val ne '';
    }

    #if we still can't find the value of a side, we can try to determine it by the value of the
    #other side after expenses
    if(!defined $buy_base_val)
    {
	$buy_base_val = figure_trade_base_val_from_other_side('B', $t);
    }
    if(!defined $sell_base_val)
    {
	$sell_base_val = figure_trade_base_val_from_other_side('S', $t);
    }

    (defined $buy_base_val) or
	error(file => $file, line => $line, tran_text => $tran_text, msg => "Couldn't calculate base val of buy currency, $buy_amt $buy_curr");

    (defined $sell_base_val) or
	error(file => $file, line => $line, tran_text => $tran_text, msg => "Couldn't calculate base val of sell currency, $sell_amt $sell_curr");
	     

    return ($buy_base_val, $sell_base_val);
}

#figures the expense given the amount traded and its price
sub figure_expense_base_amt
{
    my($expense_amt,  #amout of expense
       $expense_curr, #currency of expense
       $amt,      #amount bought
       $curr,     #currency of amount bought
       $base_amt, #expense + amount bought in base currency
       $date, $time, $index) = @_;

    if($expense_curr eq $curr)
    {
	# e - expense amt (in expense curr)
	# a - amt (also in expense curr)
	# r - ratio from base to amt (base_curr / amt_curr)
	# b - base amount (in base currency)
	# (e + a) * r == b
	# r = b / (e + a)
	#
	# e * r = (e in base currency)
	# so, e * r = b / (e + a) * r

	#returns the expense amount in the base currency
	return $base_amt / ($expense_amt + $amt) * $expense_amt;
    }
 
    return figure_base_curr_price($expense_amt, $expense_curr, $date, $time, $index);
}


#figures the trade base val for both sides of equation by using the calculated value and expense
#of one side to determine the calculate d
sub figure_trade_base_val_from_other_side
{
    my ($type, $t) = @_;

    my ($file,$line,$tran_text,$date,$time,$index,$buy_curr,$buy_amt,$sell_curr,$sell_amt,
	$expense_curr,$expense_amt) = 
	    hv_to_a(undef,$t,
		    qw {  file  line  tran_text  date  time  index  buy_curr  buy_amt  sell_curr  sell_amt 
	 expense_curr  expense_amt });

    my ($buy_base_val, $sell_base_val);
    if($type eq 'B')
    {
	#here is where expenses come into play. Normally when we trade two currencies
	#we use the fair market value of each (expenses won't affect this, because
	# they are subtracted out beforehand)
	#however, if we are trading one currency for the base currency (effectively
	# "buying" or "selling" it), we use it as the price we sold/bought the other 
	# currency at. We use the expenses to determine the effective base price to do this
	#
	# For example, lets say we bought 10 BTC valued at $1 each. We had a fee of $2
	# for this transaction. So the total cost is $12, and we received $10 of value.
	# The expenses store this $2 fee.
	# So we take the amount it cost us, $12, and subtract the fee, $2, to get the
	# base value of $10.

	if($sell_curr eq $base_curr)
	{
	    $sell_base_val = $sell_amt;
	}
	else
	{
	    $sell_base_val = figure_base_curr_price($sell_amt, $sell_curr,
						   $date, $time, $index);
		
	}

	return undef unless defined $sell_base_val;
	
	my $expense_base_amt = figure_expense_base_amt($expense_amt, $expense_curr,
						       $buy_amt, $buy_curr, $sell_base_val,
						       $date, $time, $index);
	
	(defined $expense_base_amt) or 
	    error(file => $file, line => $line, tran_text => $tran_text, 
		  msg => "Expense be in $base_curr or $buy_curr");
	
	return undef unless defined $expense_base_amt;
	
	return $sell_base_val + $expense_base_amt;
    }
    elsif($type eq 'S') #figure the sell amount
    {
	if($buy_curr eq $base_curr)
	{
	    $buy_base_val = $buy_amt;
	}
	else
	{
	    $buy_base_val = figure_base_curr_price($buy_amt, $buy_curr,
						   $date, $time, $index);
		
	}

	return undef unless defined $buy_base_val;
	
	my $expense_base_amt = figure_expense_base_amt($expense_amt, $expense_curr,
						       $sell_amt, $sell_curr, $buy_base_val,
						       $date, $time, $index);
	
	(defined $expense_base_amt) or 
	    error(file => $file, line => $line, tran_text => $tran_text, 
		  msg => "Expense be in $base_curr or $sell_curr");
	
	return undef unless defined $expense_base_amt;
	
	return $buy_base_val + $expense_base_amt;
    }
    else { die $type; }
}
