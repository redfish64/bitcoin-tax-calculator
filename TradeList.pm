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
    my $list = $self->{'list'};

    #search through entire list for $afterMe, yes I know this is slow.
    for($i = 0; $i < @$list; $i++)
    {
	if($list->[$i] == $afterMe)
	{
	    splice @{$list}, $i+1, 0, $trade;
	}
    }
}

#adds must be done in chronilogical order
sub add
{
    my ($self, $trade) = @_;

    my $list = $self->{'list'};
 
    #if there were previous trades
    if($#{$list} >= 0)
    {
	#try to combine the trade with the previous one
	my $otherTrade = $list->[$#{$list}];

	#try to combine trades together
	if($otherTrade->combine($trade))
	{
	    #if we successfully combined it with another trade, we're done
	    return;
	}

	#if they can't be combined, they might be closely related enough to be in the same block
	$otherTrade->match($trade);
    }

    #we have to add it to the end of the list
    push @{$list}, $trade;
}

#check for wash sales, must be done after all adds
sub checkWashes
{
    my ($self) = @_;

    my $list = $self->{'list'};

    my $sell;

#1. Find each sell in chronological order
#For each sell,
    for($j = 0; $j < (@{$list}); $j++)
    {
	my $sell = $list->[$j];

	#if the trade is a sell
	if($sell->type eq "sell" && !$sell->isProcessed())
	{
	    #we need to determine if it's a wash
	    
#2. Find first buy which has not been allocated as a "first buy" for any sell. This buy becomes "First Buy" for this sell
#   Continue this process until all shares of the sells have a "first buy". Last buy may have to be split into two buys.
	    my $buy;

	    #if shares weren't already allocated(they may be allocated if
	    # this is part of previous sell that was split)
	    if(!$sell->allSharesAllocated())
	    {
		for($i = 0; $i < @{$list}; $i ++)
		{
		    $buy = $list->[$i];
		    
		    #if buy is the same symbol as sell and hasn't already been allocated as a first buy
		    if($buy->type eq "buy" && $buy->{'symbol'} eq $sell->{'symbol'} && !defined $buy->{'firstBuy'})
		    {
			#allocates the shares to the buy(this may split the buy into two)
			$buy->markFirstBuy($self, $sell);
			
			if($sell->allSharesAllocated())
			{
			    last;
			}
		    }
		    
		} #for each trade in list
	    }

	    #bug, all shares for the sell should be allocated(I didn't do shorts last year)
	    print "Warning: Only ".$sell->{'allocatedShares'}." allocated for ".$sell->toString() if(!$sell->allSharesAllocated());

#3. Find first buy which is not a wash for any sell and is not the "first buy" for *this* sell or is part of the same block
#   of the "first buy" and has been traded within
#   the 61 day gap. Mark this as a wash buy, and count the shares as wash shares for the sell. Continue until all shares
#   are marked wash or run out of buys. May have to split buys, or sell as part wash/part non-wash.
#   Only do this if sell is a loss
	    
	    my $gain = $sell->getGain();
	    #print "gain is $gain\n";

	    if($gain < 0)
	    {
		#we'll start from where we are in the list, since the previous ones should be marked as "first buys"
		for(;$i < @{$list}; $i ++)
		{
		    $buy = $list->[$i];
		    
		    #if we've gone past the wash sale interval
		    if($buy->{'date'} > $sell->{'date'} + 30)
		    {
			last;
		    }
		    
		    if($buy->type eq "buy" && $buy->{'symbol'} eq $sell->{'symbol'} && $buy->{'date'} >= $sell->{'date'} - 30 
		       && ! $buy->isFirstBuy($sell) && ! $buy->isWash())
		    {
			#allocates the shares as a wash to the sell(this may split the buy into two)
			$buy->markAsWash($self, $sell);
			
			#if all the shares are allocated as "washed"
			if($sell->allSharesWashed())
			{
			    last;
			}
		    }
		} #for each trade in list
	    } #if sell was a loss
		
	    #last we tell the sell to split itself into washed and unwashed parts
	    $sell->splitWashed($self);

	    $sell->markProcessed();
	} #if type was a sell
    } #for each trade in list
}

#prints out the list in the internal data format
sub print
{
    my ($self) = @_;

    my $trade;
    my $currentDate = 0;
    my $pricePerDay = 0;
    my $btc_balance = 0;

    print "Date\tSymbol\tType\tShares\tPrice\tFee\tShare Price\tIs Wash?";

    foreach $trade (@{$self->{'list'}})
    {
	if($trade->{'date'} != $currentDate)
	{
#	    print $pricePerDay."\n";
	    $pricePerDay = 0;
	    $currentDate = $trade->{'date'};
	}

	print $trade->toString();

	$pricePerDay += $trade->{'price'};

	my $is_buy = $trade->type eq "buy" ? 1 : 0;

	$btc_balance += $trade->{'shares'} * ($is_buy ? 1 : -1);
	$usd_balance += $trade->{'price'} * ($is_buy ? -1 : 1);

	print "BTC: $btc_balance USD: $usd_balance\n";
    }

    
}

#prints out the list in the IRS format
sub printIRS
{
    my ($self) = @_;

    my $trade;

    print "Shares\tSymbol\tSell Price\tDate\tBuy Price\tBuy Date\tIs Wash?\tGain\n";

    foreach $trade (@{$self->{'list'}})
    {
	print $trade->toIRSString();
    }
}

1;

