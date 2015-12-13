###############list of all the buys and sells
package TradeList;

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

#adds must be done in chronological order
sub add
{
    my ($self, $trade) = @_;

    my $list = $self->{list};

    #try to combine with previous trades
    $pos = $#{$list};

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
		return;
	    }

	    #co: allows all trades to be combined regardless of intervening buys/sells
	    # if($otherTrade->{symbol} eq $trade->{symbol} && $otherTrade->type ne $trade->type)
	    # {
	    # 	last;
	    # }
	}
	else  #other trade
	{
	    last;
	}

	$pos--;
    }

    #we have to add it to the end of the list
    push @{$list}, $trade;
}

#check for wash sales, must be done after all adds
sub checkWashesAndAssignBuysToSells
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

	#if the trade is a sell
	if($sell->type eq "sell" && !(defined $sell->{buy}))
	{
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
		    verify_buy_sell_chain($buy);
		    verify_buy_sell_chain($sell);
			
		    if($buy->{shares} > $sell->{shares})
		    {
			$buy->split($self, $sell->{shares});
		    }
		    elsif($sell->{shares} > $buy->{shares})
		    {
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

    #we don't worry about wash sales anymore, they don't apply to virtual currency, it seems!
    return;
    
    print STDERR "Identifying wash sales\n";

    my $do_print ;    
     for($j = 0; $j < (@{$list}); $j++)
     {
	 my $sell = $list->[$j];

	 $do_print = 1 if $j % 50 == 0;
   
	if($sell->type eq "sell" && !$sell->{washBuy})
	{
	    
#3. Find buy which is not a wash for any sell and is not the buy for *this* sell and has been traded within
#   the 61 day gap. Mark this as a wash buy, and count the shares as wash shares for the sell. 
#    May have to split buys, or sell as part wash/part non-wash.
#   Only do this if sell is a loss
	    
	    my $gain = $sell->getGain();
	    #print "gain is $gain\n";
	    
	    if($gain < 0)
	    {
		for($i = 0;$i < @{$list}; $i ++)
		{
		    $buy = $list->[$i];
		    
		    #if we've gone past the wash sale interval
		    if($buy->{date} > $sell->{date} + 30)
		    {
			last;
		    }

		    my $buy_top;
		    if($buy->type eq "buy" && $buy->{symbol} eq $sell->{symbol} 
		       && $buy->{date} >= $sell->{date} - 30 
		       && ($buy_top = find_chain_top($buy)) != $sell && ! $buy->isWash()

		       #this last line is very important, but hard to comprehend
		       #the issue is that if you can wash sale and resell on the same
		       #day you will end up with a huge number of washes for a very
		       #tiny trades. This is because every time you make a tiny trade
		       #it eats a little bit from the big trades around it, but the
		       #result is ultimately another buy/sell pair that has to again
		       #be checked and rewashed. This goes in a nearly endless circle
		       #over and over again
		       #
		       #example, the following will end up with 200 wash sale lines without
		       #this condition

# 2015-08-12 11:08:00
#   Assets:Kraken     -$ 10
#   Assets:Kraken     2 ETH
#   Expenses:Fees     $ 0.01
#   Expenses:Fees     0.0000000000 ETH

# 2015-08-13 07:23:41
#   Assets:Wallet:ethereum     -0.01 ETH
#   Expenses:Fees:Gas

# 2015-08-15 11:08:00
#   Assets:Kraken     $ 5
#   Assets:Kraken     -1.99 ETH
#   Expenses:Fees     $ 0.01
#   Expenses:Fees     0.0000000000 ETH

		       && $buy_top->type eq "sell" && $buy_top->{date} != $sell->{date}
			)
		    {
			if($do_print)
			{
			    print STDERR "$j out of ".($#{$list}+1)." trades ... (and growing)";

			    print STDERR "Buy:\n".debug_str($buy);
			    print STDERR "Sell:\n".debug_str($sell);
				
			    $do_print = undef;
			}
	 
			#allocates the shares as a wash to the sell(this may split the buy into two or
			#split the sell in two)

			verify_buy_sell_chain($buy_top);
			verify_buy_sell_chain($sell);

			if($buy->{shares} > $sell->{shares})
			{
			    my $split = $buy_top->split($self, $sell->{shares});
			    verify_buy_sell_chain($split);
			    $buy_top == find_chain_top($buy) or die;
			}
			elsif($sell->{shares} > $buy->{shares})
			{
			    my $split = $sell->split($self, $buy->{shares});
			    verify_buy_sell_chain($split);
			}

			$buy->markAsWash($sell);

			verify_buy_sell_chain($buy_top);
			verify_buy_sell_chain($sell);
			
			last;
		    }
		} #for each trade in list
	    } #if sell was a loss
	} #if type was a sell
     } #for each trade in list
    
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

#prints out the list in the IRS format
sub printIRS
{
    my ($self) = @_;

    my $trade;

    print "
-------------------------------------------------------
Short term Trades\n\n";
    print "Shares\tSymbol\tBuy Date\tSell Date\tSell Price\tBuy Price\tGain\tRunning Total Gain\tRefs\n";

    my $running_gain = $main::ZERO;
    foreach $trade (@{$self->{list}})
    {
	if($trade->type eq "sell" && !$trade->isLongTerm())
	{
	    $running_gain += $trade->getGain() || $main::ZERO;
	    print getIRSRow($trade, $running_gain)."\n";
	}
    }
    print "
-------------------------------------------------------
Long term Trades\n\n";
    print "Shares\tSymbol\tBuy Date\tSell Date\tSell Price\tBuy Price\tGain\tRunning Total Gain\tRefs\n";

    $running_gain = $main::ZERO;
    foreach $trade (@{$self->{list}})
    {
	if($trade->type eq "sell" && $trade->isLongTerm())
	{
	    $running_gain += $trade->getGain() || $main::ZERO;
	    print getIRSRow($trade, $running_gain)."\n";
	}
    }
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
		 &main::convertDaysToText($trade->{date}),
		 $buyDate,
		 main::format_amt($sellPrice),
		 main::format_amt($buyPrice),
		 main::format_amt($sellPrice - $buyPrice),
		 main::format_amt($running_gain),
		 $trade->refs_string(),
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

