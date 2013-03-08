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
    my ($class, $date, $shares, $price, $charge, $symbol, $sharePrice) = @_;
    
    $self = Trade::new($class, $date, $shares, $price, $charge, $symbol, $sharePrice);
    $self->{'gets_basis'} = 0;

    $self;
}

sub type
{
    "buy";
}

sub _split
{
    my ($self, $trades, $sharesAllocated) = @_;

    #create a new buy split off from this one. No charge for this buy, and give it the shares not allocated
    my $splitBuy = new Buy($self->{'date'}, $self->{'shares'} - $sharesAllocated, 
			   ($self->{'shares'} - $sharesAllocated) * $self->{'sharePrice'}, 0, 
			   $self->{'symbol'}, $self->{'sharePrice'});
    
    $self->{'shares'} = $sharesAllocated;
    $self->{'price'} = $self->{'shares'} * $self->{'sharePrice'};

    #the split buy inherits the block of firstBuys as well.
    $splitBuy->{'block'} = $self->{'block'};
    
    #and the washes
    $splitBuy->{'wash'} = $self->{'wash'};
    
    #insert the new buy right after us
    $trades->insertAfter($splitBuy, $self);

    return $splitBuy;
}

#allocates the shares to the given sell as "first buy". If there are still some shares left, buy must split itself into two
#purchases, one allocated and one not
sub markFirstBuy
{
    my ($self, $trades, $sell) = @_;

    my $splitBuy;

    $sharesAllocated = $sell->allocateShares($self->{'shares'}, $self);

    #if we weren't able to mark all the shares of the sell
    if($sharesAllocated < $self->{'shares'})
    {
	$splitBuy = $self->_split($trades, $sharesAllocated);
    }

    #mark ourselves as a firstbuy
    $self->{'firstBuy'} = $sell;

    #mark whole block to have sell as a firstBuy
    $self->{'block'}->{$sell} = $sell;

    #return the split-off buy, if any
    return $splitBuy;
}

#returns cost and any backup from wash sales
sub getBasis
{
    my ($self) = @_;

    my $basis = $self->{'price'} + $self->{'charge'};
    my $wash = $self->{'wash'};
    
    #if this is a wash buy
    if(defined $wash && $self->{'gets_basis'})
    {
	#add the loss from the wash sale
	$basis -= $wash->getGain();
    }

    return $basis;
}

sub markAsWash
{
    my ($self, $trades, $sell) = @_;

    ($sharesAllocated, $gets_basis) = $sell->allocateWashShares($self->{'shares'});

    $self->{'gets_basis'} = $gets_basis;

    #if we weren't able to mark all the shares of the sell
    if($sharesAllocated < $self->{'shares'})
    {
	$self->_split($trades, $sharesAllocated);
    }

    #mark ourselves as a wash
    $self->{'wash'} = $sell;
}

sub isWash
{
    my ($self) = @_;

    return 1 if defined $self->{'wash'};
    return 0;
}

sub isFirstBuy
{
    my ($self, $sell) = @_;
    return 1 if defined $self->{'firstBuy'} && $sell == $self->{'firstBuy'} || $self->{'block'}->{$sell};
    return 0;
}

sub printWash
{
    my ($self) = @_;

    if($self->isWash)
    {
	return &main::convertDaysToText($self->{'wash'}->{'date'})."\t".$self->{'wash'}->{'shares'};
    }

    return "";
}

sub toIRSString
{
    return "";
}

1;
