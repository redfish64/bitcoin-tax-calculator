###############list of all the buys and sells
package TradeList;

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

sub new
{
    my ($class) = @_;
    my $self = { list => [] #list of trades
	     };

    bless $self, $class;
}

#inserts trade after specified trade
sub insertAfter
{
    my ($self, $trade, $afterMe) = @_;
    my $i;
    my $list = $self->{list};

    #search through entire list for $afterMe
    for($i = 0; $i < @$list; $i++)
    {
	if($list->[$i] == $afterMe)
	{
	    splice @{$list}, $i+1, 0, $trade;
	}
    }
}

#adds a transaction to the tradelist. Actual transaction is returned.
#
# refs - References to the file and line number of the trade
# report_type - Defined in Sell.pm. Depending the report type, the transaction
#   will be reported either in the irs reports, the gift reports, or nowhere.
#   Not applicable for buys. 
# unique - if specified, then the trade cannot be merged with nearby trades.
#   Otherwise, trades on the same day of the same type that appear consecutively will be
#   merged (to prevent over long and complex returns)
#
#adds must be done in chronological order
#
#Transaction added is returned, or if the transaction was merged into another,
#the tran representing the combined result is returned.
sub add
{
    my ($self, $type_b_or_s, $date, $shares, $price, $symbol, $refs, $report_type, $unique) = @_;

    my $trade;

    if($type_b_or_s eq "b")
    {
	$trade = new Buy($date,$shares,$price,$symbol,$refs);
    }
    elsif($type_b_or_s eq "s")
    {
	$trade = new Sell($date,$shares,$price,$symbol,$refs,$report_type);
    }
    else {
	die "Can't understand type: $type_b_or_s";
    }

    my $list = $self->{list};

    #try to combine with previous trades
    $pos = $#{$list};

    #some trades are unique, which means they can't be combined
    #This would include income transactions, because after we add
    #it, we assign the buy to the sell immediately. If we allowed the
    #trade to be combined, then the buy would be marked to the wrong sell
    if(!$unique)
    {
	while($pos >= 0)
	{
	    my $otherTrade = $list->[$pos];
	    
	    #if it was on the same day and there aren't any intervening opposite transactions
	    #(ie buy for sell, sell for buy)
	    if($otherTrade->{date} eq $trade->{date})
	    {
		if($otherTrade->combine($trade))
		{
		    #if we successfully combined it with another trade, we're done
		    return $otherTrade;
		}
		
		#does not allow trades to be combined if there are  intervening buys/sells
		#warning, if you comment this out, then 'income' transactions won't work
		#properly, since they create:
		# 1. buy for $0
		# 2. sell for market price
		# 3. buy for market price
		#
		# So without this, then a trade for sell price and a basis of 
		# (buy1 + buy3) / 2 would be created. The actual basis should be zero.
		if($otherTrade->{symbol} eq $trade->{symbol} && $otherTrade->type ne $trade->type)
		{
		    last;
		}
	    }
	    else  #other trade
	    {
		last;
	    }
	    
	    $pos--;
	}
    }

    #we have to add it to the end of the list
    push @{$list}, $trade;

    return $trade;
}

#assigns buys to sells
sub assignBuysToSells
{
    my ($self) = @_;

    my $list = $self->{list};

    my $sell;

    #NOTE, this uses FIFO method for allocating shares

#1. Find each sell in chronological order
    #For each sell,

    print STDERR "Matching sells to buys, FIFO\n";
    
    for($j = 0; $j < (@{$list}); $j++)
    {
	$j % 50 == 0 and print STDERR "$j out of ".($#{$list}+1)." trades ... (may grow due to splitting sells in order to match buys)\n";
	
	my $sell = $list->[$j];

	#print STDERR "Working on trade ".$sell->toString."\n";
	#if the trade is a sell
	if($sell->type eq "sell" && !(defined $sell->{buy}))
	{
	    #print STDERR "Working on sell ".$sell->toString."\n";
#2. Find first buy which has not been allocated as a buy for any sell. 
#   Continue this process until all shares of the sells have a buy. Last buy may have to be split 
#   into two buys.
	    my $buy;

	    #if shares weren't already allocated(they may be allocated if
	    # this is part of previous sell that was split)
	    for($i = 0; $i < @{$list}; $i ++)
	    {
		$buy = $list->[$i];
		
		#if buy is the same symbol as sell and hasn't already been allocated as a buy for another sell
		if($buy->type eq "buy" && $buy->{symbol} eq $sell->{symbol} && !(defined $buy->{sell}))
		{
		    #print STDERR "Found buy ".$buy->toString."\n";
		    verify_buy_sell_chain($buy);
		    verify_buy_sell_chain($sell);
			
		    if($buy->{shares} > $sell->{shares})
		    {
			#print STDERR "Split buy\n";
			$buy->split($self, $sell->{shares});
		    }
		    elsif($sell->{shares} > $buy->{shares})
		    {
			#print STDERR "Split sell\n";
			$sell->split($self, $buy->{shares});
		    }

		    if($buy->{shares} != $sell->{shares})
		    {
			die;
		    }
			
		    #allocates the shares to the buy
		    $buy->markBuyForSell($sell);

		    verify_buy_sell_chain(find_chain_top($buy));
		    verify_buy_sell_chain($sell);
			
		    last;
		}
		
	    } #for each trade in list

	    if(!defined $sell->{buy})
	    {
		die "Couldn't find buy for sell: ".$sell->toString();
	    }
	}
    }

}

#prints out the list in the internal data format
sub print
{
    my ($self) = @_;

    my $trade;
    my $currentDate = 0;
    my $btc_balance = $main::ZERO;
    my $usd_balance = $main::ZERO;

    print "Date\tSymbol\tType\tShares\tPrice\tShare Price\tRefs\n";
    
    foreach $trade (@{$self->{list}})
    {
	if($trade->{date} != $currentDate)
	{
	    $currentDate = $trade->{date};
	}
	
	print $trade->toString();
    }
    
    
}



#prints out a set of trades in IRS format.
#only sells are printed.
sub printIRSForm
{
    my ($self, $is_long, $trades) = @_;
    
    my $trade;

    my($day, $month, $year)=(localtime)[3,4,5];
    
    print "
-------------------------------------------------------
".($is_long ? "Long" : "Short")." term Trades\n\n";
    print "Shares\tSymbol\tBuy Date\tSell Date\tSell Price\tBuy Price\tGain\tRunning Total Gain\tRefs\n";

    my %vals_per_symbol;
    my $running_gain = $main::ZERO;
    foreach $trade (@$trades)
    {
	my $symbol = $trade->{symbol};
	
	if($trade->type eq "sell" && ($trade->isLongTerm() ? $is_long : !$is_long))
	{
	    $running_gain += $trade->getGain() || $main::ZERO;
	    print getIRSRow($trade, $running_gain)."\n";
	    $vals = $vals_per_symbol{$symbol};
	    if(!defined $vals) {
		#shares,sell price, buy price, gain
		$vals = [$main::ZERO,$main::ZERO,$main::ZERO,$main::ZERO];
		$vals_per_symbol{$symbol} = $vals;
	    }
	    my $buy = $trade->{buy};
	    my $shares = $trade->{shares};
	    my $sellPrice = $trade->{price};
	    
	    $vals->[0]+= $shares;
	    $vals->[1]+= $sellPrice;

	    if(defined $buy)
	    {
		my $buyPrice = $buy->getBasis();
		$vals->[2] += $buyPrice;
		$vals->[3] += $sellPrice - $buyPrice;
	    }
	}
    }

    print "
-------------------------------------------------------
".($is_long ? "Long" : "Short")." term Totals\n\n";
    print "Symbol\tShares\tSell Price\tBuy Price\tGain\n";

    foreach my $sym (sort (keys %vals_per_symbol))
    {
	my $vals = $vals_per_symbol{$sym};
	print join("\t",
		   $sym,
		   main::format_amt($vals->[0]),
		   main::format_amt($vals->[1]),
		   main::format_amt($vals->[2]),
		   main::format_amt($vals->[3]))."\n";
    }
}


#prints out a list of trades in the IRS format
sub printIRS
{
    my ($self, $trades, $report_type) = @_;

    if(!defined $trades)
    {
	$trades = $self->{list};
    }

    $report_type = RT_NORMAL unless defined $report_type;

    #limit to only trades for the specific report type
    my @trades = grep { $_->type eq "sell" && $_->{report_type} eq $report_type } @$trades;
    $trades = \@trades;

    printIRSForm($self,0, $trades);
    print "


";
    printIRSForm($self,1, $trades);
}

sub printRemainingBalances
{
    my ($self) = @_;
 
    print "

Remaining balances:
Shares\tSymbol\tBuy Date\tBuy Price\tRefs
";
    foreach $_ ($self->getUnsoldBuys)
    {
	my ($shares, $sym, $date, $buy_price) = ($_->{shares}, $_->{symbol}, $_->{date}, $_->{price});
	print join("\t",
		   main::format_amt($shares),
		   $sym,
		   main::convertDaysToText($date),
		   main::format_amt($buy_price),
		   $_->refs_string())."\n";
	
	
    }
}


sub getUnsoldBuys
{
    my ($self) = @_;

    return grep {$_->type eq "buy" && (!defined $_->{sell})} (@{$self->{list}});
}
    

    

sub getIRSRow
{
    my ($trade, $running_gain) = @_;
    
    my $buy = $trade->{buy};
    my $shares = $trade->{shares};
    my $sellPrice = $trade->{price};

    if(!defined $buy)
    {
	return (join("\t",
		     main::format_amt($shares),
		     $trade->{symbol},
		     &main::convertDaysToText($trade->{date}),
		     "No buy found for this sell",
		     "",
		     main::format_amt($sellPrice),
		     "",
		     "",
		     main::format_amt($running_gain),
		     $trade->refs_string(),
		));
    }
    
    my $buyPrice = $buy->getBasis();
    my $buyDate = &main::convertDaysToText($buy->{date});
	    
    return (join("\t",
		 main::format_amt($shares),
		 $trade->{symbol},
		 $buyDate,
		 &main::convertDaysToText($trade->{date}),
		 main::format_amt($sellPrice),
		 main::format_amt($buyPrice),
		 main::format_amt($sellPrice - $buyPrice),
		 main::format_amt($running_gain),
		 "S: ".$trade->refs_string()." B: ".$buy->refs_string()
	    ));
}


sub verify_buy_sell_chain
{
    my ($t) = @_;

    if ($t->type eq "buy")
    {
	if($buy->{sell})
	{
	    die "not starting at the top of the chain";
	}
    }

    my $depth =0;    
    my $lt;

    while(1)
    {
	$depth++;
	$lt = $t;
	$t = ($t->type eq "buy") ? $t->{washSell} : $t->{buy};

	if(!defined $t)
	{
	    last;
	}

	if ($lt->{shares} != $t->{shares})
	{
	    die "shares don't match $lt->{shares} != $t->{shares}";
	}

	if($t->type eq "buy")
	{
	    if ($t->{sell} != $lt)
	    {
		die "chain doesn't link forward properly $t->{sell} != $lt";
	    }
	}
	else
	{
	    if ($t->{washBuy} != $lt)
	    {
		die "chain doesn't link forward properly $t->{washBuy} != $lt";
	    }
	}
    }

    $depth;
}

sub find_chain_top
{
    my ($t) = @_;

    while(1)
    {
	my $lt = $t;
	$t = ($t->type eq "buy") ? $t->{sell} : $t->{washBuy};

	if(!defined $t)
	{
	    return $lt;
	}

	if($t->type eq "buy")
	{
	    if ($t->{washSell} != $lt)
	    {
		die "chain doesn't link forward properly $t->{washSell} != $lt";
	    }
	}
	else
	{
	    if ($t->{buy} != $lt)
	    {
		die "chain doesn't link forward properly $t->{buy} != $lt";
	    }
	}
    }
}

sub debug_str
{
    my($t) = @_;

    my $refs = join("", map { "Ref:\n".(join "\n", @{$_->{tran_text}})."\n" } @{$t->{refs}});

    return $t->type."\n".
	"curr $t->{symbol}
shares: ".$t->{shares}->as_float."
date: ".main::convertDaysToText($t->{date})."
depth: ".verify_buy_sell_chain(find_chain_top($t))."\n";

}    


1;

