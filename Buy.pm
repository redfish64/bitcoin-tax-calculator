############A Buy Trade
package Buy;

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

use Trade;

@ISA = qw(Trade);

sub new
{
    my ($class, $date, $shares, $price, $symbol) = @_;
    
    $self = Trade::new($class, $date, $shares, $price, $symbol);
    $self->{'gets_basis'} = 0;

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

    #buys and sells point to each other. So if a buy is split, we have to split
    #the corresponding sell and vice versa.
    if(!(defined $sellCause))
    {
	if($self->{'sell'})
	{
	    #when we split our sell, it will automatically split us (this time with sellCause defined)
	    #so after this, we just return
	    $self->{'sell'}->split($trades,$newShares,$self);
	    return;
	}
    }

    my $otherShares = $self->{'shares'} - $newShares;
    my $newPrice = $self->{'price'} * $newShares / $self->{'shares'};
    my $otherPrice = $self->{'price'} * $otherShares / $self->{'shares'};

    #create a new buy split off from this one. No charge for this buy, and give it the shares not allocated
    my $splitBuy = new Buy($self->{'date'}, $otherShares, $otherPrice,
			   $self->{'symbol'});

    #if there is a splitSell, we use it
    $splitBuy->{'sell'} = $splitSell;

    $self->{'shares'} = $newShares;
    $self->{'price'} = $newPrice;

    #insert the new buy right after us
    $trades->insertAfter($splitBuy, $self);

    #now split the washSell recursively, naming us and our newly defined split cousin as the cause
    if($self->{'washSell'} && $cause != $self->{'washSell'})
    {
	$self->{'washSell'}->split($trades, $newShares, $self, $splitBuy);
    }

    return $splitBuy;
}

#allocates the shares to the given sell as its buy. If there are still some shares left, buy must split itself into two
#purchases, one allocated and one not
sub markBuyForSell
{
    my ($self, $sell) = @_;

    #if we weren't able to mark all the shares of the sell
    if($sell->{'shares'} != $self->{'shares'})
    {
	die "cannot mark buy for sell if number of shares differ"
    }

    $self->{'sell'} = $sell;
    $sell->{'buy'} = $self;
}

#returns cost and any backup from wash sales
sub getBasis
{
    my ($self) = @_;

    my $basis = $self->{'price'};
    my $washSale = $self->{'washSell'};
    
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
    my ($self, $trades, $sell) = @_;

    if($self->{'shares'} != $sell->{'shares'})
    {
	die "Buy must have same number of shares as sell";
    }

    #mark ourselves as a wash
    $self->{'washSell'} = $sell;
    $sell->{'washBuy'} = $self;
}

sub isWash
{
    my ($self) = @_;

    return 1 if defined $self->{'washSell'};
    return 0;
}

sub isBuy
{
    my ($self, $sell) = @_;
    return 1 if $sell == $self->{'sell'};
    return 0;
}

sub toWashString
{
    my ($self) = @_;

    if($self->isWash)
    {
	return &main::convertDaysToText($self->{'washSell'}->{'date'})."\t".$self->{'washSell'}->{'shares'};
    }

    return "";
}

sub toIRSString
{
    return "";
}

1;
