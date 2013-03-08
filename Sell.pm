#########A Sell Trade
package Sell;


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

    $self->init();

    $self;
}

#initializes a sell
sub init
{
    $self->{'allocatedShares'} = 0;
    $self->{'washedShares'} = 0;
    $self->{'processed'} = 0;
    $self->{'buys'} = []; #buys for this sell
}

sub type
{
    "sell";
}

#returns unallocated shares up to $shares. These shares become allocated
sub allocateShares
{
    my ($self, $shares, $buy) = @_;

    my $unallocatedShares = $self->{'shares'} - $self->{'allocatedShares'};

    if($unallocatedShares > $shares)
    {
	$unallocatedShares = $shares;
    }

    $self->{'allocatedShares'} += $unallocatedShares;

    #mark the buy as one of the buys to allocate shares for this sell
    push @{$self->{'buys'}}, $buy;

    return $unallocatedShares;
}


#returns unallocated wash shares up to $shares. These shares become allocated for wash
sub allocateWashShares
{
    my ($self, $shares) = @_;

    my $unallocatedShares = $self->{'shares'} - $self->{'washedShares'};

    if($unallocatedShares > $shares)
    {
	$unallocatedShares = $shares;
    }

    $self->{'washedShares'} += $unallocatedShares;

    #whether the buy gets the basis or not
    return ($unallocatedShares, $self->{'washedShares'} == $unallocatedShares);
}


#returns true if all the shares were allocated
sub allSharesAllocated
{
    my ($self) = @_;

    if($self->{'allocatedShares'} == $self->{'shares'}) 
    {
	return 1;
    }

    return 0;
}



#returns true if all the shares were washed
sub allSharesWashed
{
    my ($self) = @_;

    if($self->{'washedShares'} == $self->{'shares'}) 
    {
	return 1;
    }

    return 0;
}


#splits sell into washed and non washed
sub splitWashed
{
    my ($self, $trades) = @_;

    if($self->{'washedShares'} < $self->{'shares'} && $self->{'washedShares'} != 0)
    {
	print "Warning: untested code - splitting a wash!\n";
	
	print $self->{'date'}." ".$self->{'symbol'}."\n";

	$self->_split($self->{'washedShares'}, $trades);
    }
}


sub _split
{
    my ($self, $shares, $trades) = @_;
    
    #create a new sell split off from this one. No charge for this sell, and give it the shares not allocated
    my $splitSell = new Sell($self->{'date'}, $self->{'shares'} - $shares, 
			     ($self->{'shares'} - $shares) * $self->{'sharePrice'}, 0, 
			     $self->{'symbol'}, $self->{'sharePrice'});
    
    $self->{'shares'} = $shares;
    $self->{'price'} = $self->{'shares'} * $self->{'sharePrice'};

    #
    # reallocate first buys for this sell and the split sell
    #
    $buys = $self->{'buys'};

    $self->{'allocatedShares'} = 0;
    $self->{'buys'} = []; #buys for this sell

    my $allocateForSelf = 1;

    foreach $buy (@$buys)
    {
	if($allocateForSelf)
	{
	    my $splitBuy = $buy->markFirstBuy($trades, $self);
	    
	    #if we've allocated all the shares to the first sell
	    if(defined $splitBuy)
	    {
		$allocateForSelf = 0;

		#add the split buy to the list to allocate for the other
		push @$buys, $splitBuy;
	    }
	}
	else
	{
	    my $splitBuy = $buy->markFirstBuy($trades, $splitSell);

	    #if we've allocated all the shares to the first sell
	    if(defined $splitBuy)
	    {
		die "Sanity check failed! Too many buys for sell and split sell";
	    }
	}
    }
    
    #insert the new sell right after us
    $trades->insertAfter($splitSell, $self);
}

#returns  the gain or loss based on "First Buy"(s) and the buy date as a string
sub getBuyPrice
{
    my ($self) = @_;

    my $buyPrice = 0;

    my $buyDate = "";
    my $buy;

    foreach $buy (@{$self->{'buys'}})
    {
	my $buyBuyDate = &main::convertDaysToText($buy->{'date'});
	if($buyDate ne "" && $buyDate ne $buyBuyDate)
	{
	    $buyDate = 'VARIOUS';
	}
	else
	{
	    $buyDate = $buyBuyDate;
	}

	$buyPrice += $buy->getBasis();
    }

    return ($buyPrice, $buyDate);
}

sub isWash
{
    my ($self) = @_;
    
    return $self->{'washedShares'} != 0;
}

sub isProcessed
{
    return shift->{'processed'};
}

sub markProcessed
{
    shift->{'processed'} = 1;
}

sub printWash
{
    my ($self) = @_;

    if($self->isWash)
    {
	return "wash";
    }

    return "";
}

sub getGain
{
    my ($self) = @_;

    my ($buyPrice) = $self->getBuyPrice();
    return $self->{'price'}-$self->{'charge'} - $buyPrice;
}

sub toString
{
    my ($self) = @_;

    $s = Trade::toString($self);

    $s.="   first buys: ";
    foreach $buy (@{$self->{'buys'}})
    {
	$s .= &main::convertDaysToText($buy->{'date'})." ";
    }
    $s .= "\n";
    $s .= "    gain is ".$self->getGain()."\n";

    return $s;
}

sub toIRSStringOld
{
    my ($self) = @_;
    
    my ($buyPrice, $buyDate) = $self->getBuyPrice();

    $self->{'shares'}."\t".$self->{'symbol'}."\t".($self->{'price'}-$self->{'charge'}).
	"\t".&main::convertDaysToText($self->{'date'})."\t".
	    $buyPrice."\t".$buyDate."\t".($self->isWash ? "WASH" : " ")."\t".($self->{'price'}-$self->{'charge'} - $buyPrice)."\n";
}

sub toIRSString
{
    my ($self) = @_;
    
    my $totalSellPrice = $self->{'price'}-$self->{'charge'};
    my $sellPriceLeft = $totalSellPrice;
    
    my $i;

    my $s = "";

    for($i = 0; $i < @{$self->{'buys'}}; $i++) {
	my $buy = ${$self->{'buys'}}[$i];

	my $buyPrice = $buy->{'price'};
	
	my $shares = $buy->{'shares'};
	
	my $sellPrice;
	
	if($i != $#{$self->{'buys'}}) {
	    $sellPrice = $totalSellPrice * $buy->{'shares'}/$self->{'shares'};
	}
	else {
	    $sellPrice = $sellPriceLeft;
	}
	
	$sellPriceLeft -= $sellPrice;
	
	my $buyDate = &main::convertDaysToText($buy->{'date'});
	
	$s .= $shares."\t".$self->{'symbol'}."\t".$sellPrice.
	    "\t".&main::convertDaysToText($self->{'date'})."\t".
	    $buyPrice."\t".$buyDate."\t".($self->isWash ? "WASH" : " ")."\t".($sellPrice - $buyPrice)."\n";
    }
    
    $s;
    
}

1;
