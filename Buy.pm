############A Buy Trade
package Buy;

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

use Trade;

@ISA = qw(Trade);

sub new
{
    my ($class, $date, $shares, $price, $symbol, $refs) = @_;

    $self = Trade::new($class, $date, $shares, $price, $symbol, $refs);
    $self->{gets_basis} = 0;

    $self;
}

sub type
{
    "buy";
}

sub split
{
    #sellCause may be undef, which means this call is not being split because its attached to a sell
    my ($self, $trades, $newShares, $sellCause, $splitSell) = @_;

    if((defined $sellCause) && (defined $self->{sell}) && $self->{sell} ne $sellCause)
    {
	die "why another sell cause then our sell?";
    }

    if((defined $sellCause) && $self ne $sellCause->{buy})
    {
	die "why sell cause doesn't mark us as the buy?";
    }
    

    if(!(defined $sellCause))
    {
	if($self->{sell})
	{
	    die "Always split from the top of the chain";
	}
    }

    my $otherShares = $self->{shares} - $newShares;
    my $newPrice = $self->{price} * $newShares / $self->{shares};
    my $otherPrice = $self->{price} * $otherShares / $self->{shares};

    #create a new buy split off from this one. No charge for this buy, and give it the shares not allocated
    my $splitBuy = new Buy($self->{date}, $otherShares, $otherPrice,
			   $self->{symbol}, $self->{refs});

    if(defined $splitSell)
    {
	if(defined $splitSell->{buy})
	{
	    die "trying to replace the buy?";
	}

	if($splitSell->{shares} != $splitBuy->{shares})
	{
	    die "Split sell has differing shares from split buy";
	}
	
	#if there is a splitSell, we use it
	$splitBuy->{sell} = $splitSell;
	$splitSell->{buy} = $splitBuy;
    }
    
    $self->{shares} = $newShares;
    $self->{price} = $newPrice;

    #insert the new buy right after us
    $trades->insertAfter($splitBuy, $self);

    #now split the washSell recursively, naming us and our newly defined split cousin as the cause
    if((defined $self->{washSell}) && ((!defined $cause) || $cause != $self->{washSell}))
    {
	$self->{washSell}->split($trades, $newShares, $self, $splitBuy);
    }

    return $splitBuy;
}

#allocates the shares to the given sell as its buy. If there are still some shares left, buy must split itself into two
#purchases, one allocated and one not
sub markBuyForSell
{
    my ($self, $sell) = @_;

    #if we weren't able to mark all the shares of the sell
    if($sell->{shares} != $self->{shares})
    {
	die "cannot mark buy for sell if number of shares differ"
    }

    if(defined $self->{sell})
    {
	die "Trying to replace the sell?";
    }

    if(defined $sell->{buy})
    {
	die "Trying to replace the buy for the sell?";
    }
	
    

    $self->{sell} = $sell;
    $sell->{buy} = $self;
}

#returns cost and any backup from wash sales
sub getBasis
{
    my ($self) = @_;

    my $basis = $self->{price};
    my $washSale = $self->{washSell};
    
    #if this is a wash buy
    if(defined $washSale)
    {
	#add the loss from the wash sale
	$basis -= $washSale->getGain();
    }

    return $basis;
}


sub markAsWash
{
    my ($self, $sell) = @_;

    if($self->{shares} != $sell->{shares})
    {
	die "Buy must have same number of shares as sell";
    }

    die if $self->{washSell};

    #mark ourselves as a wash
    $self->{washSell} = $sell;
    $sell->{washBuy} = $self;

    if($sell->{buy} eq $self)
    {
	die "Trying to create a loop?";
    }
}

sub isWash
{
    my ($self) = @_;

    return 1 if defined $self->{washSell};
    return 0;
}

sub isBuy
{
    my ($self, $sell) = @_;
    return 1 if $sell == $self->{sell};
    return 0;
}

sub toWashString
{
    my ($self) = @_;

    if($self->isWash)
    {
	return &main::convertDaysToText($self->{washSell}->{date})."\t".main::format_amt($self->{washSell}->{shares});
    }

    return "";
}

sub toIRSString
{
    return "";
}

#checks if sell date is more than a year past this buy date
sub isLongTermToDate
{
    my ($self,$sell_date) = @_;

    my $buy_date = main::convertDaysToText($self->{date});
    
    my ($byear,$bmonth,$bday) = $buy_date =~ /^(\d{4})-(\d\d)-(\d\d)$/ or die;
    my ($syear,$smonth,$sday) = $sell_date =~ /^(\d{4})-(\d\d)-(\d\d)$/ or die;


    return 1 if($byear <= $syear - 2);
    return 0 if($byear >= $syear);
    return 1 if($bmonth < $smonth);
    return 0 if($bmonth > $smonth);
    return 1 if($bday < $sday);

    return 0;
}
    
1;
